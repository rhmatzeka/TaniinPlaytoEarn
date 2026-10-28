const crypto = require("crypto");
const { ethers } = require("ethers");
const { fetchPrivyWallet, verifyPrivyAccessToken } = require("./privy.cjs");
const { httpError } = require("./economy.cjs");

const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const AUTH_RATE_LIMIT = 20;
const RATE_WINDOW_MS = 60_000;
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;
// A claim whose request died (e.g. a killed serverless function) frees up quickly.
const IDEMPOTENCY_PENDING_TTL_MS = 120_000;
const IDEMPOTENCY_WAIT_MS = 20_000;
const EXPIRED_SESSION = "Sesi habis, masuk lagi.";
const AUTH_CODE_TTL_MS = 2 * 60 * 1000;
const CODE_CHALLENGE = /^[A-Za-z0-9_-]{43}$/;
const CODE_VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

// Web logins get a session directly (same-origin redirect). The Android app
// passes a PKCE challenge and gets a one-time code instead, because any app can
// register the taniin:// scheme and read what the login page hands back.
async function exchangePrivyToken(db, accessToken, ip, { codeChallenge } = {}) {
  await checkRateLimit(db, `auth:${ip || "unknown"}`, AUTH_RATE_LIMIT, RATE_WINDOW_MS);
  const { privyUserId } = await verifyPrivyAccessToken(accessToken);
  const found = await fetchPrivyWallet(privyUserId);
  const wallet = ethers.getAddress(found.wallet);
  if (codeChallenge !== undefined) {
    if (!CODE_CHALLENGE.test(String(codeChallenge))) throw httpError(400, "codeChallenge tidak valid.");
    const code = crypto.randomBytes(32).toString("hex");
    await db.query("DELETE FROM auth_codes WHERE expires_at < now()");
    await db.query(
      `INSERT INTO auth_codes (code_hash, challenge, privy_user_id, wallet, login_method, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [hashToken(code), codeChallenge, privyUserId, wallet, found.loginMethod,
        new Date(Date.now() + AUTH_CODE_TTL_MS).toISOString()]
    );
    return { code };
  }
  return createSession(db, privyUserId, wallet, found.loginMethod);
}

async function redeemAuthCode(db, code, codeVerifier) {
  const verifier = String(codeVerifier || "");
  if (!CODE_VERIFIER.test(verifier)) throw httpError(401, "Kode masuk tidak valid.");
  const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
  const { rows } = await db.query(
    `DELETE FROM auth_codes WHERE code_hash = $1 AND challenge = $2 AND expires_at > now()
     RETURNING privy_user_id, wallet, login_method`,
    [hashToken(String(code || "")), challenge]
  );
  if (!rows.length) throw httpError(401, "Kode masuk tidak valid atau kedaluwarsa. Coba masuk lagi.");
  return createSession(db, rows[0].privy_user_id, rows[0].wallet, rows[0].login_method);
}

async function createSession(db, privyUserId, wallet, loginMethod) {
  const session = crypto.randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);
  await db.query("DELETE FROM sessions WHERE expires_at < now() - interval '1 day'");
  await db.query(
    `INSERT INTO sessions (token_hash, privy_user_id, wallet, login_method, expires_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [hashToken(session), privyUserId, wallet, loginMethod, expiresAt.toISOString()]
  );
  return { session, wallet, expiresAt: expiresAt.toISOString(), loginMethod };
}

async function findSession(db, token) {
  if (!token) return null;
  const { rows } = await db.query(
    `SELECT wallet, privy_user_id FROM sessions
     WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()`,
    [hashToken(token)]
  );
  return rows[0] || null;
}

async function requireSession(db, req) {
  const row = await findSession(db, bearerToken(req));
  if (!row) throw httpError(401, EXPIRED_SESSION);
  return { wallet: row.wallet, privyUserId: row.privy_user_id };
}

async function revokeSession(db, req) {
  const token = bearerToken(req);
  if (!token) return;
  await db.query("UPDATE sessions SET revoked_at = now() WHERE token_hash = $1", [hashToken(token)]);
}

async function sessionWalletForSocket(db, token) {
  const row = await findSession(db, String(token || "").trim());
  return row ? { wallet: row.wallet } : null;
}

async function checkRateLimit(db, key, limit, windowMs) {
  const { rows } = await db.query(
    `INSERT INTO rate_limits (key, count, reset_at)
     VALUES ($1, 1, now() + make_interval(secs => $2::double precision / 1000))
     ON CONFLICT (key) DO UPDATE SET
       count = CASE WHEN rate_limits.reset_at <= now() THEN 1 ELSE rate_limits.count + 1 END,
       reset_at = CASE WHEN rate_limits.reset_at <= now() THEN EXCLUDED.reset_at ELSE rate_limits.reset_at END
     RETURNING count`,
    [key, windowMs]
  );
  if (rows[0].count > limit) throw httpError(429, "Pelan-pelan, coba lagi sebentar.");
}

// Runs `run` once per (wallet, key). Concurrent duplicates wait for the first
// result; a failed run frees the key so the client can retry.
async function withIdempotency(db, wallet, key, run, fingerprint = "") {
  const cleanKey = String(key || "").trim();
  if (!cleanKey) throw httpError(400, "Idempotency-Key wajib untuk aksi ekonomi.");
  if (cleanKey.length > 128) throw httpError(400, "Idempotency-Key terlalu panjang.");
  const scopedKey = `${wallet.toLowerCase()}:${cleanKey}`;
  const deadline = Date.now() + IDEMPOTENCY_WAIT_MS;

  while (Date.now() < deadline) {
    await db.query("DELETE FROM idempotency WHERE scoped_key = $1 AND expires_at < now()", [scopedKey]);
    const claimed = await db.query(
      `INSERT INTO idempotency (scoped_key, status, expires_at, fingerprint)
       VALUES ($1, 'pending', $2, $3) ON CONFLICT (scoped_key) DO NOTHING RETURNING scoped_key`,
      [scopedKey, new Date(Date.now() + IDEMPOTENCY_PENDING_TTL_MS).toISOString(), fingerprint]
    );
    if (claimed.rows.length) {
      let result;
      try {
        result = await run();
      } catch (error) {
        await db.query("DELETE FROM idempotency WHERE scoped_key = $1", [scopedKey]);
        throw error;
      }
      await db.query(
        "UPDATE idempotency SET status = 'done', response = $2, expires_at = $3 WHERE scoped_key = $1",
        [scopedKey, JSON.stringify(result), new Date(Date.now() + IDEMPOTENCY_TTL_MS).toISOString()]
      );
      return result;
    }
    const { rows } = await db.query(
      "SELECT status, response, fingerprint FROM idempotency WHERE scoped_key = $1",
      [scopedKey]
    );
    if (rows[0] && (rows[0].fingerprint || "") !== fingerprint) {
      throw httpError(409, "Idempotency-Key ini sudah dipakai untuk aksi lain.");
    }
    if (rows[0]?.status === "done") {
      const response = typeof rows[0].response === "string" ? JSON.parse(rows[0].response) : rows[0].response;
      return { ...response, idempotentReplay: true };
    }
    if (rows[0]) await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw httpError(409, "Aksi yang sama masih diproses. Coba lagi sebentar.");
}

function bearerToken(req) {
  const header = String(req?.headers?.authorization || "");
  const match = header.match(/^Bearer\s+([0-9a-f]{64})$/i);
  return match ? match[1].toLowerCase() : "";
}

module.exports = {
  checkRateLimit,
  exchangePrivyToken,
  redeemAuthCode,
  requireSession,
  revokeSession,
  sessionWalletForSocket,
  withIdempotency
};
