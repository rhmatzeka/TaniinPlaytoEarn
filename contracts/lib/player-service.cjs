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
// Fresh Privy accounts are free to create, so the signer also gets a daily total.
const DEFAULT_GLOBAL_DAILY_ETH_PAYOUT_WEI = "200000000000000000";
const GLOBAL_WALLET = "*";

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
    let prepared;
    try {
      prepared = await prepareAction(db, session, body, type, nowMs);
    } catch (error) {
      await audit(db, session.wallet, type || "UNKNOWN", body, [], "error", error.message).catch(() => undefined);
      throw mapLockTimeout(error);
    }

    let chain;
    try {
      // One signer for every player: serialize sends across serverless instances.
      // The player row is already committed and unlocked, so only the signer waits.
      chain = await db.transaction(async (tx) => {
        await tx.query("SET LOCAL lock_timeout = '10s'");
        await tx.query("SELECT pg_advisory_xact_lock($1)", [SIGNER_LOCK_KEY]);
        return chainExecutor()(session.wallet, prepared.chainOps, { db: tx });
      });
    } catch (error) {
      await compensate(db, session.wallet, prepared, error.message).catch(() => undefined);
      throw mapLockTimeout(error);
    }

    await db.query(
      "UPDATE audit_log SET result = 'ok', tx_hashes = $2 WHERE id = $1",
      [prepared.auditId, JSON.stringify(chain.txHashes)]
    );
    return {
      ok: true,
      type,
      summary: prepared.summary,
      txHash: chain.txHash,
      txHashes: chain.txHashes,
      etherscanUrl: chain.txHash ? `https://sepolia.etherscan.io/tx/${chain.txHash}` : "",
      state: publicState(prepared.state)
    };
  });
}

// Phase one: validate and commit the debit before anything reaches the chain, so
// a function killed mid-send can never leave minted tokens without a payment.
function prepareAction(db, session, body, type, nowMs) {
  return db.transaction(async (tx) => {
    await tx.query("SET LOCAL lock_timeout = '5s'");
    const player = await lockPlayer(tx, session, nowMs);
    const { state, chainOps, summary } = applyAction(player.state, body, nowMs);
    const usage = await reserveDailyUsage(tx, session.wallet, chainOps, nowMs);
    await tx.query(
      "UPDATE players SET state = $2, updated_at = now() WHERE wallet = $1",
      [session.wallet, JSON.stringify(state)]
    );
    const { rows } = await audit(tx, session.wallet, type, body, [], "pending", null, true);
    return { previous: player.state, state, chainOps, summary, usage, auditId: rows[0].id };
  });
}

// Undo phase one after a failed send, unless the player has acted since.
function compensate(db, wallet, prepared, reason) {
  return db.transaction(async (tx) => {
    const { rows } = await tx.query("SELECT state FROM players WHERE wallet = $1 FOR UPDATE", [wallet]);
    const current = typeof rows[0].state === "string" ? JSON.parse(rows[0].state) : rows[0].state;
    const untouched = current.actionCount === prepared.state.actionCount;
    if (untouched) {
      await tx.query(
        "UPDATE players SET state = $2, updated_at = now() WHERE wallet = $1",
        [wallet, JSON.stringify(prepared.previous)]
      );
    }
    const { taniMint, ethWei, day } = prepared.usage;
    if (taniMint > 0n || ethWei > 0n) {
      await tx.query(
        `UPDATE daily_usage SET tani_minted = tani_minted - $3, eth_paid_wei = eth_paid_wei - $4
         WHERE wallet = $1 AND day = $2`,
        [wallet, day, taniMint.toString(), ethWei.toString()]
      );
    }
    if (ethWei > 0n) {
      await tx.query(
        "UPDATE daily_usage SET eth_paid_wei = eth_paid_wei - $2 WHERE wallet = $3 AND day = $1",
        [day, ethWei.toString(), GLOBAL_WALLET]
      );
    }
    await tx.query(
      "UPDATE audit_log SET result = $2, error = $3 WHERE id = $1",
      [prepared.auditId, untouched ? "error" : "error_state_moved", String(reason).slice(0, 500)]
    );
  });
}

function mapLockTimeout(error) {
  if (error?.code === "55P03") {
    return httpError(503, "Server sedang sibuk. Coba lagi sebentar.");
  }
  return error;
}

async function reserveDailyUsage(tx, wallet, chainOps, nowMs) {
  const taniMint = chainOps
    .filter((op) => op.kind === "mintTani")
    .reduce((sum, op) => sum + BigInt(op.amount), 0n);
  const payOps = chainOps.filter((op) => op.kind === "payEth");
  const ethWei = payOps.length
    ? payOps.reduce((sum, op) => sum + require("./game-action-service.cjs").ethWeiForCoins(op.coins), 0n)
    : 0n;
  const day = jakartaDay(nowMs);
  if (taniMint === 0n && ethWei === 0n) return { taniMint, ethWei, day };

  const { rows } = await tx.query(
    `INSERT INTO daily_usage (wallet, day, tani_minted, eth_paid_wei) VALUES ($1, $2, $3, $4)
     ON CONFLICT (wallet, day) DO UPDATE SET
       tani_minted = daily_usage.tani_minted + EXCLUDED.tani_minted,
       eth_paid_wei = daily_usage.eth_paid_wei + EXCLUDED.eth_paid_wei
     RETURNING tani_minted::text AS tani, eth_paid_wei::text AS eth`,
    [wallet, day, taniMint.toString(), ethWei.toString()]
  );
  const taniCap = BigInt(process.env.TANIIN_DAILY_TANI_MINT || DEFAULT_DAILY_TANI_MINT);
  const ethCap = BigInt(process.env.TANIIN_DAILY_ETH_PAYOUT_WEI || DEFAULT_DAILY_ETH_PAYOUT_WEI);
  if (BigInt(rows[0].tani) > taniCap) {
    throw httpError(429, `Batas harian mint TANI (${taniCap}) tercapai. Coba lagi besok.`);
  }
  if (BigInt(rows[0].eth) > ethCap) {
    throw httpError(429, "Batas harian payout ETH tercapai. Coba lagi besok.");
  }
  if (ethWei > 0n) {
    const global = await tx.query(
      `INSERT INTO daily_usage (wallet, day, tani_minted, eth_paid_wei) VALUES ($1, $2, 0, $3)
       ON CONFLICT (wallet, day) DO UPDATE SET eth_paid_wei = daily_usage.eth_paid_wei + EXCLUDED.eth_paid_wei
       RETURNING eth_paid_wei::text AS eth`,
      [GLOBAL_WALLET, day, ethWei.toString()]
    );
    const globalCap = BigInt(process.env.TANIIN_GLOBAL_DAILY_ETH_PAYOUT_WEI || DEFAULT_GLOBAL_DAILY_ETH_PAYOUT_WEI);
    if (BigInt(global.rows[0].eth) > globalCap) {
      throw httpError(429, "Hadiah ETH untuk hari ini sudah habis. Coba lagi besok.");
    }
  }
  return { taniMint, ethWei, day };
}

function audit(db, wallet, action, body, txHashes, result, error, returningId = false) {
  const amount = Number.isSafeInteger(Number(body?.amount)) ? Number(body.amount) : null;
  const plotId = Number.isSafeInteger(Number(body?.plotId)) ? Number(body.plotId) : null;
  return db.query(
    `INSERT INTO audit_log (wallet, action, amount, plot_id, tx_hashes, result, error)
     VALUES ($1, $2, $3, $4, $5, $6, $7)${returningId ? " RETURNING id" : ""}`,
    [wallet, action.slice(0, 32), amount, plotId, JSON.stringify(txHashes), result, error ? String(error).slice(0, 500) : null]
  );
}

module.exports = {
  getPlayer,
  importGuest,
  runGameAction,
  setChainExecutorForTests
};
