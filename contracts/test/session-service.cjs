const crypto = require("crypto");
const { expect } = require("chai");
const { setPrivyForTests } = require("../lib/privy.cjs");
const {
  checkRateLimit,
  exchangePrivyToken,
  requireSession,
  revokeSession,
  sessionWalletForSocket,
  withIdempotency
} = require("../lib/session-service.cjs");
const { createTestDb } = require("./helpers/test-db.cjs");

const WALLET = "0x1111111111111111111111111111111111111111";

function bearer(session) {
  return { headers: { authorization: `Bearer ${session}` } };
}

async function rejects(promise, statusCode, pattern) {
  let caught;
  try {
    await promise;
  } catch (error) {
    caught = error;
  }
  expect(caught, "expected rejection").to.exist;
  expect(caught.statusCode).to.equal(statusCode);
  if (pattern) expect(caught.message).to.match(pattern);
}

describe("Privy sessions", function () {
  let db;

  beforeEach(async function () {
    db = await createTestDb();
    setPrivyForTests({
      verify: async (token) => {
        if (token !== "privy-ok") {
          const error = new Error("bad token");
          error.statusCode = 401;
          throw error;
        }
        return { privyUserId: "did:privy:user1" };
      },
      fetchWallet: async () => ({ wallet: WALLET, loginMethod: "email" })
    });
  });

  afterEach(function () {
    setPrivyForTests(null);
  });

  it("exchanges a Privy token for a Taniin session stored as a hash", async function () {
    const result = await exchangePrivyToken(db, "privy-ok", "1.2.3.4");
    expect(result.wallet).to.equal(WALLET);
    expect(result.loginMethod).to.equal("email");
    expect(result.session).to.match(/^[0-9a-f]{64}$/);
    const { rows } = await db.query("SELECT token_hash FROM sessions");
    expect(rows).to.have.length(1);
    expect(rows[0].token_hash).to.not.equal(result.session);
    expect(rows[0].token_hash).to.equal(crypto.createHash("sha256").update(result.session).digest("hex"));
  });

  it("rejects an invalid Privy token", async function () {
    await rejects(exchangePrivyToken(db, "nope", "1.2.3.4"), 401);
  });

  it("returns the session wallet for a valid bearer token", async function () {
    const { session } = await exchangePrivyToken(db, "privy-ok", "1.2.3.4");
    const found = await requireSession(db, bearer(session));
    expect(found.wallet).to.equal(WALLET);
    expect(found.privyUserId).to.equal("did:privy:user1");
  });

  it("rejects an expired session", async function () {
    const { session } = await exchangePrivyToken(db, "privy-ok", "1.2.3.4");
    await db.query("UPDATE sessions SET expires_at = now() - interval '1 minute'");
    await rejects(requireSession(db, bearer(session)), 401, /Sesi habis, masuk lagi/);
  });

  it("rejects a revoked session", async function () {
    const { session } = await exchangePrivyToken(db, "privy-ok", "1.2.3.4");
    await revokeSession(db, bearer(session));
    await rejects(requireSession(db, bearer(session)), 401);
  });

  it("resolves socket sessions and ignores unknown tokens", async function () {
    const { session } = await exchangePrivyToken(db, "privy-ok", "1.2.3.4");
    expect(await sessionWalletForSocket(db, session)).to.deep.equal({ wallet: WALLET });
    expect(await sessionWalletForSocket(db, "deadbeef")).to.equal(null);
  });

  it("rate limits the 31st request inside one window", async function () {
    for (let i = 0; i < 30; i += 1) {
      await checkRateLimit(db, "action:test", 30, 60_000);
    }
    await rejects(checkRateLimit(db, "action:test", 30, 60_000), 429);
  });

  it("requires an idempotency key", async function () {
    await rejects(withIdempotency(db, WALLET, "", async () => ({ ok: true })), 400);
    await rejects(withIdempotency(db, WALLET, "x".repeat(129), async () => ({ ok: true })), 400);
  });

  it("runs concurrent requests with the same key only once", async function () {
    let calls = 0;
    const run = async () => {
      calls += 1;
      await new Promise((resolve) => setTimeout(resolve, 50));
      return { ok: true, txHash: "0xabc" };
    };
    const [first, second] = await Promise.all([
      withIdempotency(db, WALLET, "key-1", run),
      withIdempotency(db, WALLET, "key-1", run)
    ]);
    expect(calls).to.equal(1);
    expect(first.txHash).to.equal("0xabc");
    expect(second.txHash).to.equal("0xabc");
  });

  it("forgets a key whose run failed so the client can retry", async function () {
    await rejects(withIdempotency(db, WALLET, "key-2", async () => {
      const error = new Error("chain down");
      error.statusCode = 502;
      throw error;
    }), 502);
    const result = await withIdempotency(db, WALLET, "key-2", async () => ({ ok: true }));
    expect(result.ok).to.equal(true);
  });
});
