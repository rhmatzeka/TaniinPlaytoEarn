const {
  enqueueGameAction,
  normalizeError
} = require("../lib/game-action-service.cjs");

module.exports = async function handler(req, res) {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "Method tidak didukung." });
  }

  try {
    const body = await readJson(req);
    const result = await enqueueGameAction(body);
    return res.status(200).json(result);
  } catch (error) {
    return res.status(error.statusCode || 500).json({ ok: false, error: normalizeError(error) });
  }
};

async function readJson(req) {
  if (req.body !== undefined) {
    if (Buffer.isBuffer(req.body)) {
      return parseJsonBody(req.body.toString("utf8"));
    }
    if (typeof req.body === "string") {
      return parseJsonBody(req.body);
    }
    if (typeof req.body === "object" && req.body !== null) {
      return req.body;
    }
  }

  let raw = "";
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 16_384) {
      throw httpError(413, "Payload terlalu besar.");
    }
  }
  return parseJsonBody(raw);
}

function parseJsonBody(raw) {
  try {
    return raw && raw.trim() ? JSON.parse(raw) : {};
  } catch (error) {
    throw httpError(400, "JSON tidak valid.");
  }
}

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}
