// Local stand-in for Vercel: serves public/ and the API router on one origin.
const fs = require("fs");
const http = require("http");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env"), quiet: true });

const { createApp } = require("../lib/router.cjs");
const { getReadyDb } = require("../lib/db.cjs");

const PORT = Number(process.env.PORT || 4174);
const PUBLIC_DIR = path.resolve(__dirname, "../public");
const API_PATHS = new Set(["/health", "/auth/privy", "/auth/logout", "/player", "/player/import", "/game-actions"]);
const TYPES = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript",
  ".css": "text/css", ".json": "application/json", ".png": "image/png", ".webp": "image/webp",
  ".jpg": "image/jpeg", ".wasm": "application/wasm", ".ttf": "font/ttf", ".otf": "font/otf",
  ".xml": "application/xml", ".txt": "text/plain", ".tmx": "application/xml", ".tsx": "application/xml",
  ".mp3": "audio/mpeg", ".wav": "audio/wav", ".ogg": "audio/ogg", ".frag": "text/plain"
};

const api = createApp({ getDb: getReadyDb });

http.createServer((req, res) => {
  const { pathname } = new URL(req.url, "http://localhost");
  if (API_PATHS.has(pathname.replace(/\/$/, ""))) return api(req, res);
  let file = path.join(PUBLIC_DIR, decodeURIComponent(pathname));
  if (!file.startsWith(PUBLIC_DIR)) {
    res.statusCode = 403;
    return res.end();
  }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
  if (!fs.existsSync(file)) {
    res.statusCode = 404;
    return res.end("Not found");
  }
  res.setHeader("Content-Type", TYPES[path.extname(file)] || "application/octet-stream");
  fs.createReadStream(file).pipe(res);
}).listen(PORT, "127.0.0.1", () => console.log(`[dev] http://127.0.0.1:${PORT}`));
