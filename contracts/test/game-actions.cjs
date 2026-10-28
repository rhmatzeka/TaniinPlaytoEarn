const { expect } = require("chai");
const { createApp } = require("../lib/router.cjs");
const { setPrivyForTests } = require("../lib/privy.cjs");
const { setChainExecutorForTests } = require("../lib/player-service.cjs");
const { CATALOG } = require("../lib/economy.cjs");
const { createTestDb } = require("./helpers/test-db.cjs");

const WALLET = "0x2222222222222222222222222222222222222222";

async function call(app, { method = "GET", path, headers = {}, body }) {
  const req = {
    method,
    url: path,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
    socket: { remoteAddress: "10.0.0.1" }
  };
  const res = {
    statusCode: 200,
    headers: {},
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; },
    end(payload) { this.payload = payload; }
  };
  await app(req, res);
  return { status: res.statusCode, json: res.payload ? JSON.parse(res.payload) : null };
}

describe("Game action API", function () {
  let db;
  let app;
  let session;
  let chainCalls;
  let chainBehavior;
  let clock;

  beforeEach(async function () {
    db = await createTestDb();
    clock = Date.UTC(2026, 9, 28, 3, 0, 0);
    app = createApp({ getDb: () => db, now: () => clock });
    chainCalls = 0;
    chainBehavior = async (wallet, ops) => {
      chainCalls += 1;
      await new Promise((resolve) => setTimeout(resolve, 20));
      return { txHash: `0x${"a".repeat(64)}`, txHashes: ops.map(() => `0x${"a".repeat(64)}`) };
    };
    setChainExecutorForTests((wallet, ops, extra) => chainBehavior(wallet, ops, extra));
    setPrivyForTests({
      verify: async () => ({ privyUserId: "did:privy:user2" }),
      fetchWallet: async () => ({ wallet: WALLET, loginMethod: "google" })
    });
    const login = await call(app, { method: "POST", path: "/auth/privy", body: { accessToken: "ok" } });
    expect(login.status).to.equal(200);
    session = login.json.session;
    delete process.env.TANIIN_ECONOMY_PAUSED;
  });

  afterEach(function () {
    setChainExecutorForTests(null);
    setPrivyForTests(null);
    delete process.env.TANIIN_ECONOMY_PAUSED;
  });

  function action(body, key = "k-1") {
    return call(app, {
      method: "POST",
      path: "/game-actions",
      headers: { authorization: `Bearer ${session}`, "idempotency-key": key },
      body
    });
  }

  it("logs the app in through a one-time code exchange", async function () {
    const crypto = require("crypto");
    const verifier = "w".repeat(50);
    const codeChallenge = crypto.createHash("sha256").update(verifier).digest("base64url");
    const first = await call(app, { method: "POST", path: "/auth/privy", body: { accessToken: "ok", codeChallenge } });
    expect(first.status).to.equal(200);
    expect(first.json).to.not.have.property("session");
    const second = await call(app, { method: "POST", path: "/auth/code", body: { code: first.json.code, codeVerifier: verifier } });
    expect(second.status).to.equal(200);
    expect(second.json.wallet).to.equal(WALLET);
    expect(second.json.session).to.match(/^[0-9a-f]{64}$/);
  });

  it("rejects actions without a session", async function () {
    const result = await call(app, { method: "POST", path: "/game-actions", body: { type: "PLANT", plotId: 1 } });
    expect(result.status).to.equal(401);
  });

  it("rejects actions without an idempotency key", async function () {
    const result = await call(app, {
      method: "POST",
      path: "/game-actions",
      headers: { authorization: `Bearer ${session}` },
      body: { type: "PLANT", plotId: 1, seedIndex: 0 }
    });
    expect(result.status).to.equal(400);
  });

  it("returns 503 while the economy kill switch is on", async function () {
    process.env.TANIIN_ECONOMY_PAUSED = "true";
    const result = await action({ type: "PLANT", plotId: 1, seedIndex: 0 });
    expect(result.status).to.equal(503);
  });

  it("creates the default player on first load", async function () {
    const result = await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    expect(result.status).to.equal(200);
    expect(result.json.state.coins).to.equal(620);
    expect(result.json.importedGuest).to.equal(false);
  });

  it("applies a valid harvest, returns the new state and writes the audit log", async function () {
    expect((await action({ type: "PLANT", plotId: 1, seedIndex: 0 }, "plant-1")).status).to.equal(200);
    clock += CATALOG.growMs;
    const result = await action({ type: "HARVEST", plotId: 1 }, "harvest-1");
    expect(result.status).to.equal(200);
    expect(result.json.state.cropQuantities[0]).to.equal(3);
    expect(result.json.txHash).to.match(/^0x[a]{64}$/);
    const { rows } = await db.query("SELECT action, result FROM audit_log ORDER BY id");
    expect(rows.map((row) => [row.action, row.result])).to.deep.equal([["PLANT", "ok"], ["HARVEST", "ok"]]);
  });

  it("keeps the old state when the chain call fails", async function () {
    chainBehavior = async () => {
      const error = new Error("RPC down");
      error.statusCode = 502;
      throw error;
    };
    const result = await action({ type: "PLANT", plotId: 1, seedIndex: 0 });
    expect(result.status).to.equal(502);
    const player = await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    expect(player.json.state.seedQuantities[0]).to.equal(6);
    const { rows } = await db.query("SELECT result FROM audit_log");
    expect(rows.map((row) => row.result)).to.deep.equal(["error"]);
  });

  it("commits the player debit before any chain transaction is sent", async function () {
    await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    await db.query("UPDATE players SET state = jsonb_set(state, '{coins}', '1000') WHERE wallet = $1", [WALLET]);
    let coinsSeenByChain;
    chainBehavior = async (wallet, ops, extra) => {
      chainCalls += 1;
      const { rows } = await extra.db.query("SELECT state FROM players WHERE wallet = $1", [WALLET]);
      coinsSeenByChain = rows[0].state.coins;
      return { txHash: `0x${"b".repeat(64)}`, txHashes: [`0x${"b".repeat(64)}`] };
    };
    const result = await action({ type: "SWAP_COIN", amount: 300 }, "swap-1");
    expect(result.status).to.equal(200);
    expect(coinsSeenByChain).to.equal(700);
    const { rows } = await db.query("SELECT result, tx_hashes FROM audit_log WHERE action = 'SWAP_COIN'");
    expect(rows).to.have.length(1);
    expect(rows[0].result).to.equal("ok");
  });

  it("releases the daily allowance when the chain call fails", async function () {
    await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    await db.query("UPDATE players SET state = jsonb_set(state, '{coins}', '5000') WHERE wallet = $1", [WALLET]);
    chainBehavior = async () => {
      const error = new Error("RPC down");
      error.statusCode = 502;
      throw error;
    };
    expect((await action({ type: "SWAP_COIN", amount: 1500 }, "swap-fail")).status).to.equal(502);
    const { rows } = await db.query("SELECT tani_minted::int AS n FROM daily_usage WHERE wallet = $1", [WALLET]);
    expect(rows[0].n).to.equal(0);
    const player = await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    expect(player.json.state.coins).to.equal(5000);
  });

  it("enforces the daily ETH payout limit", async function () {
    await db.query("UPDATE players SET state = jsonb_set(state, '{coins}', '100000') WHERE wallet = $1", [WALLET])
      .catch(() => undefined);
    await call(app, { path: "/player", headers: { authorization: `Bearer ${session}` } });
    await db.query("UPDATE players SET state = jsonb_set(state, '{coins}', '100000') WHERE wallet = $1", [WALLET]);
    process.env.TANIIN_ETH_WEI_PER_COIN = "10000000000000";
    const first = await action({ type: "SWAP_COIN_ETH", amount: 1000 }, "eth-1");
    expect(first.status).to.equal(200);
    const second = await action({ type: "SWAP_COIN_ETH", amount: 100 }, "eth-2");
    expect(second.status).to.equal(429);
    expect(second.json.error).to.match(/Batas harian/);
  });

  it("allows only one guest import per account", async function () {
    const guestState = { coins: 300, seedQuantities: [2, 0, 0, 0] };
    const headers = { authorization: `Bearer ${session}` };
    const first = await call(app, { method: "POST", path: "/player/import", headers, body: { guestState } });
    expect(first.status).to.equal(200);
    expect(first.json.state.coins).to.equal(300);
    const second = await call(app, { method: "POST", path: "/player/import", headers, body: { guestState } });
    expect(second.status).to.equal(409);
  });

  it("processes a double-tapped action once", async function () {
    const [first, second] = await Promise.all([
      action({ type: "PLANT", plotId: 1, seedIndex: 0 }, "same"),
      action({ type: "PLANT", plotId: 1, seedIndex: 0 }, "same")
    ]);
    expect(first.status).to.equal(200);
    expect(second.status).to.equal(200);
    expect(chainCalls).to.equal(1);
    expect(second.json.state.seedQuantities[0]).to.equal(5);
  });

  it("exposes only health in multiplayer-only mode", async function () {
    const mpApp = createApp({ getDb: () => db, now: () => clock, multiplayerOnly: true });
    expect((await call(mpApp, { method: "POST", path: "/game-actions", body: {} })).status).to.equal(404);
    expect((await call(mpApp, { method: "POST", path: "/auth/privy", body: {} })).status).to.equal(404);
    const health = await call(mpApp, { path: "/health" });
    expect(health.status).to.equal(200);
    expect(health.json).to.deep.equal({ ok: true, multiplayer: true });
  });

  it("reports health with the economy switch", async function () {
    const result = await call(app, { path: "/health" });
    expect(result.status).to.equal(200);
    expect(result.json).to.have.property("economyPaused", false);
  });
});
