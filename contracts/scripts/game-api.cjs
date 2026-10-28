// Local / srv server: the same API router as Vercel plus Socket.IO multiplayer.
const http = require("http");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env"), quiet: true });

const { createApp } = require("../lib/router.cjs");
const { getReadyDb } = require("../lib/db.cjs");
const { initMultiplayer } = require("../lib/multiplayer-service.cjs");

const HOST = process.env.TANIIN_GAME_API_HOST || "0.0.0.0";
const PORT = Number(process.env.TANIIN_GAME_API_PORT || 8787);

if (!Number.isInteger(PORT) || PORT <= 0 || PORT > 65535) {
  console.error("[game-api] TANIIN_GAME_API_PORT tidak valid.");
  process.exit(1);
}

const multiplayerOnly = String(process.env.TANIIN_MULTIPLAYER_ONLY || "").trim().toLowerCase() === "true";
const app = createApp({ getDb: getReadyDb, multiplayerOnly });
const server = http.createServer((req, res) => {
  app(req, res);
});
initMultiplayer(server);
server.listen(PORT, HOST, () => {
  console.log(`[game-api] listening http://${HOST}:${PORT}`);
});
