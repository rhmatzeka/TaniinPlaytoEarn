// Privy verification: access tokens are ES256 JWTs signed per app; wallets come
// from the Privy REST API because access tokens do not carry linked accounts.

const PRIVY_API = "https://auth.privy.io/api/v1";

let jwks;
let override = null;

function appId() {
  const id = String(process.env.PRIVY_APP_ID || "").trim();
  if (!id) throw httpError(503, "Login Privy belum dikonfigurasi di server.");
  return id;
}

async function verifyPrivyAccessToken(token) {
  if (override) return override.verify(token);
  const { createRemoteJWKSet, jwtVerify } = require("jose");
  const id = appId();
  jwks ||= createRemoteJWKSet(new URL(`${PRIVY_API}/apps/${id}/jwks.json`));
  try {
    const { payload } = await jwtVerify(String(token || ""), jwks, { issuer: "privy.io", audience: id });
    if (!payload.sub) throw new Error("missing subject");
    return { privyUserId: String(payload.sub) };
  } catch (_error) {
    throw httpError(401, "Token Privy tidak valid atau sudah kedaluwarsa.");
  }
}

async function fetchPrivyWallet(privyUserId) {
  if (override) return override.fetchWallet(privyUserId);
  const id = appId();
  const secret = String(process.env.PRIVY_APP_SECRET || "").trim();
  if (!secret) throw httpError(503, "Login Privy belum dikonfigurasi di server.");
  const response = await fetch(`${PRIVY_API}/users/${encodeURIComponent(privyUserId)}`, {
    headers: {
      authorization: `Basic ${Buffer.from(`${id}:${secret}`).toString("base64")}`,
      "privy-app-id": id
    },
    signal: AbortSignal.timeout(8000)
  });
  if (!response.ok) throw httpError(502, "Gagal membaca akun Privy. Coba lagi.");
  return pickWallet(await response.json());
}

function pickWallet(user) {
  const accounts = Array.isArray(user?.linked_accounts) ? user.linked_accounts : [];
  const ethWallets = accounts.filter((item) => item.type === "wallet"
    && (item.chain_type || "ethereum") === "ethereum" && item.address);
  const wallet = ethWallets.find((item) => item.wallet_client_type === "privy") || ethWallets[0];
  if (!wallet) throw httpError(409, "Wallet Privy belum siap. Coba masuk lagi.");
  const method = accounts.find((item) => item.type === "google_oauth") ? "google"
    : accounts.find((item) => item.type === "email") ? "email"
      : "wallet";
  return { wallet: wallet.address, loginMethod: method };
}

function setPrivyForTests(value) {
  override = value;
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

module.exports = {
  fetchPrivyWallet,
  pickWallet,
  setPrivyForTests,
  verifyPrivyAccessToken
};
