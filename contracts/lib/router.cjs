const { clientIp, httpError, readJson, sendJson, setCors } = require("./http.cjs");
const { exchangePrivyToken, redeemAuthCode, requireSession, revokeSession } = require("./session-service.cjs");
const { getPlayer, importGuest, runGameAction } = require("./player-service.cjs");

// One handler for every API path, so Vercel deploys a single function.
function createApp({ getDb, now = Date.now, multiplayerOnly = false }) {
  const routes = multiplayerOnly ? {
    // srv runs only Socket.IO; the economy API lives on Vercel.
    "GET /health": async () => ({ ok: true, multiplayer: true })
  } : {
    "GET /health": async () => health(),
    "POST /auth/privy": async (req, db, body) => ({
      ok: true,
      ...await exchangePrivyToken(db, body.accessToken, clientIp(req), { codeChallenge: body.codeChallenge })
    }),
    "POST /auth/code": async (req, db, body) => ({ ok: true, ...await redeemAuthCode(db, body.code, body.codeVerifier) }),
    "POST /auth/logout": async (req, db) => {
      await revokeSession(db, req);
      return { ok: true };
    },
    "GET /player": async (req, db) => getPlayer(db, await requireSession(db, req), now()),
    "POST /player/import": async (req, db, body) =>
      importGuest(db, await requireSession(db, req), body.guestState, now()),
    "POST /game-actions": async (req, db, body) => {
      const session = await requireSession(db, req);
      return runGameAction(db, session, body, req.headers["idempotency-key"], { ip: clientIp(req), nowMs: now() });
    }
  };

  return async function handle(req, res) {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.statusCode = 204;
      res.end();
      return;
    }
    try {
      const pathname = new URL(req.url, "http://localhost").pathname.replace(/^\/api(?=\/)/, "").replace(/\/+$/, "");
      const route = routes[`${req.method} ${pathname || "/"}`];
      if (!route) throw httpError(404, "Endpoint tidak ditemukan.");
      const needsDb = pathname !== "/health";
      const db = needsDb ? await getDb() : null;
      const body = req.method === "POST" ? await readJson(req) : {};
      sendJson(res, 200, await route(req, db, body));
    } catch (error) {
      if (!error.statusCode) console.error("[api]", error);
      sendJson(res, error.statusCode || 500, { ok: false, error: error.statusCode ? error.message : "Server error." });
    }
  };
}

async function health() {
  const base = {
    ok: true,
    economyPaused: String(process.env.TANIIN_ECONOMY_PAUSED || "").trim().toLowerCase() === "true",
    multiplayerUrl: String(process.env.TANIIN_MULTIPLAYER_URL || "").trim()
  };
  try {
    const { health: chainHealth } = require("./game-action-service.cjs");
    return { ...base, ...await withTimeout(chainHealth(), 8000) };
  } catch (error) {
    return { ...base, chainError: error.message };
  }
}

function withTimeout(promise, ms) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error("Sepolia RPC lambat.")), ms);
    })
  ]).finally(() => clearTimeout(timer));
}

module.exports = { createApp };
