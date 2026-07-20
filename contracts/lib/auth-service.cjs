const crypto = require("crypto");
const { ethers } = require("ethers");

const NONCE_TTL_MS = Number(process.env.TANIIN_AUTH_NONCE_TTL_MS || 5 * 60 * 1000);
const SESSION_TTL_MS = Number(process.env.TANIIN_AUTH_SESSION_TTL_MS || 60 * 60 * 1000);
const RATE_LIMIT_WINDOW_MS = Number(process.env.TANIIN_RATE_LIMIT_WINDOW_MS || 60 * 1000);
const AUTH_LIMIT = Number(process.env.TANIIN_AUTH_RATE_LIMIT || 20);
const ACTION_LIMIT = Number(process.env.TANIIN_ACTION_RATE_LIMIT || 30);

const nonces = new Map();
const sessions = new Map();
const rateBuckets = new Map();
const idempotencyResults = new Map();

function authRequired() {
  return String(process.env.TANIIN_REQUIRE_AUTH || "").trim().toLowerCase() === "true";
}

function createNonce(wallet, origin) {
  checkRateLimit(`auth:${origin || "unknown"}`, AUTH_LIMIT);
  const address = normalizeAddress(wallet, "wallet");
  const nonce = crypto.randomBytes(16).toString("hex");
  const issuedAt = new Date();
  const expiresAt = issuedAt.getTime() + NONCE_TTL_MS;
  const message = [
    "Taniin wallet login",
    `Wallet: ${address}`,
    `Nonce: ${nonce}`,
    `Issued At: ${issuedAt.toISOString()}`,
    "Chain ID: 11155111",
    "Purpose: Connect wallet to Taniin game session."
  ].join("\n");
  nonces.set(nonce, { address, expiresAt, message });
  cleanupExpired();
  return {
    ok: true,
    wallet: address,
    nonce,
    message,
    expiresAt: new Date(expiresAt).toISOString()
  };
}

function verifySignature({ wallet, nonce, signature }, origin) {
  checkRateLimit(`auth:${origin || "unknown"}`, AUTH_LIMIT);
  const address = normalizeAddress(wallet, "wallet");
  const record = nonces.get(String(nonce || ""));
  if (!record || record.expiresAt < Date.now()) {
    throw httpError(401, "Nonce login tidak valid atau sudah kedaluwarsa.");
  }
  if (record.address.toLowerCase() !== address.toLowerCase()) {
    throw httpError(401, "Nonce login bukan untuk wallet ini.");
  }
  let recovered;
  try {
    recovered = ethers.verifyMessage(record.message, String(signature || ""));
  } catch (_error) {
    throw httpError(401, "Signature wallet tidak valid.");
  }
  if (recovered.toLowerCase() !== address.toLowerCase()) {
    throw httpError(401, "Signature tidak cocok dengan wallet.");
  }
  nonces.delete(String(nonce));
  const session = crypto.randomBytes(32).toString("hex");
  const expiresAt = Date.now() + SESSION_TTL_MS;
  sessions.set(session, { address, expiresAt });
  cleanupExpired();
  return {
    ok: true,
    wallet: address,
    session,
    verified: true,
    expiresAt: new Date(expiresAt).toISOString()
  };
}

function requireSession(req, wallet) {
  if (!authRequired()) {
    return { wallet: normalizeAddress(wallet, "wallet"), verified: false };
  }
  const token = bearerToken(req);
  if (!token) {
    throw httpError(401, "Session wallet diperlukan. Connect dan sign wallet dulu.");
  }
  const session = sessions.get(token);
  if (!session || session.expiresAt < Date.now()) {
    throw httpError(401, "Session wallet tidak valid atau sudah kedaluwarsa.");
  }
  const address = normalizeAddress(wallet, "wallet");
  if (session.address.toLowerCase() !== address.toLowerCase()) {
    throw httpError(403, "Session wallet tidak cocok dengan request.");
  }
  checkRateLimit(`action:${address.toLowerCase()}`, ACTION_LIMIT);
  return { wallet: address, verified: true };
}

async function withIdempotency(req, wallet, run) {
  const key = String(req.headers["idempotency-key"] || "").trim();
  if (!key) {
    return run();
  }
  if (key.length > 128) {
    throw httpError(400, "Idempotency-Key terlalu panjang.");
  }
  const scopedKey = `${wallet.toLowerCase()}:${key}`;
  const cached = idempotencyResults.get(scopedKey);
  if (cached && cached.expiresAt > Date.now()) {
    return { ...cached.result, idempotentReplay: true };
  }
  const result = await run();
  idempotencyResults.set(scopedKey, {
    result,
    expiresAt: Date.now() + SESSION_TTL_MS
  });
  cleanupExpired();
  return result;
}

function checkRateLimit(key, limit) {
  if (!Number.isFinite(limit) || limit <= 0) {
    return;
  }
  const now = Date.now();
  const bucket = rateBuckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    rateBuckets.set(key, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return;
  }
  bucket.count += 1;
  if (bucket.count > limit) {
    throw httpError(429, "Terlalu banyak request. Coba lagi sebentar.");
  }
}

function cleanupExpired() {
  const now = Date.now();
  for (const [key, value] of nonces) {
    if (value.expiresAt <= now) nonces.delete(key);
  }
  for (const [key, value] of sessions) {
    if (value.expiresAt <= now) sessions.delete(key);
  }
  for (const [key, value] of idempotencyResults) {
    if (value.expiresAt <= now) idempotencyResults.delete(key);
  }
  for (const [key, value] of rateBuckets) {
    if (value.resetAt <= now) rateBuckets.delete(key);
  }
}

function bearerToken(req) {
  const header = String(req.headers.authorization || req.headers.Authorization || "");
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : "";
}

function normalizeAddress(value, name) {
  const address = String(value || "").trim();
  if (!ethers.isAddress(address)) {
    throw httpError(400, `${name} tidak valid.`);
  }
  return ethers.getAddress(address);
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

module.exports = {
  authRequired,
  createNonce,
  requireSession,
  verifySignature,
  withIdempotency
};
