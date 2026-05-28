import service from "../lib/game-action-service.cjs";

const { enqueueGameAction, normalizeError } = service;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};

export default async function handler(req, res) {
  if (res && typeof res.setHeader === "function") {
    return handleNodeRequest(req, res);
  }
  return handleWebRequest(req);
}

async function handleNodeRequest(req, res) {
  setNodeCorsHeaders(res);
  if (req.method === "OPTIONS") {
    return sendNodeJson(res, 204, null);
  }
  if (req.method !== "POST") {
    return sendNodeJson(res, 405, { ok: false, error: "Method tidak didukung." });
  }

  try {
    const body = await readNodeJson(req);
    const result = await enqueueGameAction(body);
    return sendNodeJson(res, 200, result);
  } catch (error) {
    return sendNodeJson(res, error.statusCode || 500, { ok: false, error: normalizeError(error) });
  }
}

async function handleWebRequest(request) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method tidak didukung." });
  }

  try {
    const body = await readWebJson(request);
    const result = await enqueueGameAction(body);
    return jsonResponse(200, result);
  } catch (error) {
    return jsonResponse(error.statusCode || 500, { ok: false, error: normalizeError(error) });
  }
}

async function readNodeJson(req) {
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

async function readWebJson(request) {
  const raw = await request.text();
  if (raw.length > 16_384) {
    throw httpError(413, "Payload terlalu besar.");
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

function jsonResponse(status, body) {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function sendNodeJson(res, status, body) {
  if (typeof res.status === "function" && typeof res.json === "function") {
    if (body === null) {
      return res.status(status).end();
    }
    return res.status(status).json(body);
  }
  if (body === null) {
    res.writeHead(status);
    return res.end();
  }
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload)
  });
  return res.end(payload);
}

function setNodeCorsHeaders(res) {
  for (const [name, value] of Object.entries(corsHeaders)) {
    res.setHeader(name, value);
  }
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}
