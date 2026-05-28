const {
  health,
  normalizeError
} = require("../lib/game-action-service.cjs");

module.exports = async function handler(req, res) {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  if (req.method !== "GET") {
    return res.status(405).json({ ok: false, error: "Method tidak didukung." });
  }

  try {
    return res.status(200).json(await health());
  } catch (error) {
    return res.status(error.statusCode || 500).json({ ok: false, error: normalizeError(error) });
  }
};

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}
