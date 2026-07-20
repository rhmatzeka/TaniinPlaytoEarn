const http = require("http");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });

const {
  enqueueGameAction,
  health,
  normalizeError
} = require("../lib/game-action-service.cjs");
const {
  createNonce,
  requireSession,
  verifySignature,
  withIdempotency
} = require("../lib/auth-service.cjs");
const { initMultiplayer } = require("../lib/multiplayer-service.cjs");

const DEFAULT_PORT = 8787;
const HOST = process.env.TANIIN_GAME_API_HOST || "0.0.0.0";
const PORT = Number(process.env.TANIIN_GAME_API_PORT || DEFAULT_PORT);

main().catch((error) => {
  console.error(`[game-api] gagal start: ${normalizeError(error)}`);
  process.exit(1);
});

async function main() {
  if (!Number.isInteger(PORT) || PORT <= 0 || PORT > 65535) {
    throw new Error("TANIIN_GAME_API_PORT tidak valid.");
  }

  const healthState = await health();
  const server = http.createServer(handleRequest);
  
  // Attach Socket.io multiplayer & AI agent service
  initMultiplayer(server);

  server.listen(PORT, HOST, () => {
    console.log(`[game-api] signer ${healthState.signer}`);
    console.log(`[game-api] listening http://${HOST}:${PORT}`);
    console.log(`[game-api] Android emulator URL: http://10.0.2.2:${PORT}`);
  });
}

function handleRequest(req, res) {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  if (req.method === "GET" && url.pathname === "/health") {
    health()
      .then((result) => sendJson(res, 200, result))
      .catch((error) => sendJson(res, error.statusCode || 500, { ok: false, error: normalizeError(error) }));
    return;
  }

  if (req.method === "POST" && url.pathname === "/auth/nonce") {
    readJson(req)
      .then((body) => createNonce(body.wallet, clientKey(req)))
      .then((result) => sendJson(res, 200, result))
      .catch((error) => sendJson(res, error.statusCode || 500, { ok: false, error: normalizeError(error) }));
    return;
  }

  if (req.method === "POST" && url.pathname === "/auth/verify") {
    readJson(req)
      .then((body) => verifySignature(body, clientKey(req)))
      .then((result) => sendJson(res, 200, result))
      .catch((error) => sendJson(res, error.statusCode || 500, { ok: false, error: normalizeError(error) }));
    return;
  }

  if (req.method !== "POST" || url.pathname !== "/game-actions") {
    sendJson(res, 404, { ok: false, error: "Endpoint tidak ditemukan." });
    return;
  }

  readJson(req)
    .then((body) => {
      const session = requireSession(req, body.wallet);
      return withIdempotency(req, session.wallet, () => enqueueGameAction(body));
    })
    .then((result) => sendJson(res, 200, result))
    .catch((error) => {
      const status = error.statusCode || 500;
      sendJson(res, status, { ok: false, error: normalizeError(error) });
    });
}

function clientKey(req) {
  return String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "unknown");
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 16_384) {
        reject(httpError(413, "Payload terlalu besar."));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(raw.trim() ? JSON.parse(raw) : {});
      } catch (error) {
        reject(httpError(400, "JSON tidak valid."));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", process.env.TANIIN_ALLOWED_ORIGIN || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type,Authorization,Idempotency-Key");
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}
