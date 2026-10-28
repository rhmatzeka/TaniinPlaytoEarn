const MAX_BODY_BYTES = 16_384;

async function readJson(req) {
  if (req.body !== undefined && req.body !== null) {
    if (Buffer.isBuffer(req.body)) return parseJson(req.body.toString("utf8"));
    if (typeof req.body === "string") return parseJson(req.body);
    if (typeof req.body === "object") {
      if (Buffer.byteLength(JSON.stringify(req.body)) > MAX_BODY_BYTES) throw httpError(413, "Payload terlalu besar.");
      return req.body;
    }
  }
  let raw = "";
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > MAX_BODY_BYTES) throw httpError(413, "Payload terlalu besar.");
  }
  return parseJson(raw);
}

function parseJson(raw) {
  if (Buffer.byteLength(raw) > MAX_BODY_BYTES) throw httpError(413, "Payload terlalu besar.");
  try {
    return raw && raw.trim() ? JSON.parse(raw) : {};
  } catch (_error) {
    throw httpError(400, "JSON tidak valid.");
  }
}

function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", process.env.TANIIN_ALLOWED_ORIGIN || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type,Authorization,Idempotency-Key");
  res.setHeader("Vary", "Origin");
}

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.end(JSON.stringify(payload));
}

function clientIp(req) {
  const forwarded = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim();
  return forwarded || req.socket?.remoteAddress || "unknown";
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

module.exports = { clientIp, httpError, readJson, sendJson, setCors };
