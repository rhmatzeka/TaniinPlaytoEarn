const {
  applyAction,
  httpError,
  importGuestState,
  jakartaDay,
  newPlayerState,
  publicState
} = require("./economy.cjs");
const { checkRateLimit, withIdempotency } = require("./session-service.cjs");

const SIGNER_LOCK_KEY = 7271;
const WALLET_ACTION_LIMIT = 30;
const IP_ACTION_LIMIT = 60;
const RATE_WINDOW_MS = 60_000;
const DEFAULT_DAILY_TANI_MINT = 2000;
const DEFAULT_DAILY_ETH_PAYOUT_WEI = "10000000000000000";

let chainExecutorOverride = null;

function chainExecutor() {
  return chainExecutorOverride || require("./game-action-service.cjs").executeChainOps;
}

function setChainExecutorForTests(fn) {
  chainExecutorOverride = fn;
}

async function lockPlayer(tx, session, nowMs) {
  await tx.query(
    `INSERT INTO players (wallet, privy_user_id, state) VALUES ($1, $2, $3)
     ON CONFLICT (wallet) DO NOTHING`,
    [session.wallet, session.privyUserId, JSON.stringify(newPlayerState(nowMs))]
  );
  const { rows } = await tx.query(
    "SELECT state, imported_guest FROM players WHERE wallet = $1 FOR UPDATE",
    [session.wallet]
  );
  const state = typeof rows[0].state === "string" ? JSON.parse(rows[0].state) : rows[0].state;
  return { state, importedGuest: rows[0].imported_guest };
}

async function getPlayer(db, session, nowMs) {
  const player = await db.transaction((tx) => lockPlayer(tx, session, nowMs));
  return { ok: true, state: publicState(player.state), importedGuest: player.importedGuest };
}

async function importGuest(db, session, guestState, nowMs) {
  return db.transaction(async (tx) => {
    const player = await lockPlayer(tx, session, nowMs);
    if (player.importedGuest || (player.state.actionCount || 0) > 0) {
      throw httpError(409, "Progres tamu sudah pernah dibawa ke akun ini.");
    }
    const state = importGuestState(guestState, nowMs);
    await tx.query(
      "UPDATE players SET state = $2, imported_guest = true, updated_at = now() WHERE wallet = $1",
      [session.wallet, JSON.stringify(state)]
    );
    return { ok: true, state: publicState(state), importedGuest: true };
  });
}

async function runGameAction(db, session, body, idempotencyKey, { ip, nowMs }) {
  if (String(process.env.TANIIN_ECONOMY_PAUSED || "").trim().toLowerCase() === "true") {
    throw httpError(503, "Ekonomi on-chain sedang dijeda.");
  }
  await checkRateLimit(db, `action:${session.wallet.toLowerCase()}`, WALLET_ACTION_LIMIT, RATE_WINDOW_MS);
  await checkRateLimit(db, `ip:${ip || "unknown"}`, IP_ACTION_LIMIT, RATE_WINDOW_MS);
  const type = String(body?.type || "").trim().toUpperCase();

  return withIdempotency(db, session.wallet, idempotencyKey, async () => {
    try {
      const result = await db.transaction(async (tx) => {
        const player = await lockPlayer(tx, session, nowMs);
        const { state, chainOps, summary } = applyAction(player.state, body, nowMs);
        await reserveDailyUsage(tx, session.wallet, chainOps, nowMs);
        // One signer for every player: serialize chain sends across instances.
        await tx.query("SELECT pg_advisory_xact_lock($1)", [SIGNER_LOCK_KEY]);
        const chain = await chainExecutor()(session.wallet, chainOps, { db: tx });
        await tx.query(
          "UPDATE players SET state = $2, updated_at = now() WHERE wallet = $1",
          [session.wallet, JSON.stringify(state)]
        );
        await audit(tx, session.wallet, type, body, chain.txHashes, "ok", null);
        return {
          ok: true,
          type,
          summary,
          txHash: chain.txHash,
          txHashes: chain.txHashes,
          etherscanUrl: chain.txHash ? `https://sepolia.etherscan.io/tx/${chain.txHash}` : "",
          state: publicState(state)
        };
      });
      return result;
    } catch (error) {
      await audit(db, session.wallet, type || "UNKNOWN", body, [], "error", error.message)
        .catch(() => undefined);
      throw error;
    }
  });
}

async function reserveDailyUsage(tx, wallet, chainOps, nowMs) {
  const taniMint = chainOps
    .filter((op) => op.kind === "mintTani")
    .reduce((sum, op) => sum + BigInt(op.amount), 0n);
  const payOps = chainOps.filter((op) => op.kind === "payEth");
  const ethWei = payOps.length
    ? payOps.reduce((sum, op) => sum + require("./game-action-service.cjs").ethWeiForCoins(op.coins), 0n)
    : 0n;
  if (taniMint === 0n && ethWei === 0n) return;

  const { rows } = await tx.query(
    `INSERT INTO daily_usage (wallet, day, tani_minted, eth_paid_wei) VALUES ($1, $2, $3, $4)
     ON CONFLICT (wallet, day) DO UPDATE SET
       tani_minted = daily_usage.tani_minted + EXCLUDED.tani_minted,
       eth_paid_wei = daily_usage.eth_paid_wei + EXCLUDED.eth_paid_wei
     RETURNING tani_minted::text AS tani, eth_paid_wei::text AS eth`,
    [wallet, jakartaDay(nowMs), taniMint.toString(), ethWei.toString()]
  );
  const taniCap = BigInt(process.env.TANIIN_DAILY_TANI_MINT || DEFAULT_DAILY_TANI_MINT);
  const ethCap = BigInt(process.env.TANIIN_DAILY_ETH_PAYOUT_WEI || DEFAULT_DAILY_ETH_PAYOUT_WEI);
  if (BigInt(rows[0].tani) > taniCap) {
    throw httpError(429, `Batas harian mint TANI (${taniCap}) tercapai. Coba lagi besok.`);
  }
  if (BigInt(rows[0].eth) > ethCap) {
    throw httpError(429, "Batas harian payout ETH tercapai. Coba lagi besok.");
  }
}

function audit(db, wallet, action, body, txHashes, result, error) {
  const amount = Number.isSafeInteger(Number(body?.amount)) ? Number(body.amount) : null;
  const plotId = Number.isSafeInteger(Number(body?.plotId)) ? Number(body.plotId) : null;
  return db.query(
    `INSERT INTO audit_log (wallet, action, amount, plot_id, tx_hashes, result, error)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [wallet, action.slice(0, 32), amount, plotId, JSON.stringify(txHashes), result, error ? String(error).slice(0, 500) : null]
  );
}

module.exports = {
  getPlayer,
  importGuest,
  runGameAction,
  setChainExecutorForTests
};
