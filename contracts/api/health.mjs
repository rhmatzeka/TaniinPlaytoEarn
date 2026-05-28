import service from "../lib/game-action-service.cjs";

const { health, normalizeError } = service;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,OPTIONS",
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
  if (req.method !== "GET") {
    return sendNodeJson(res, 405, { ok: false, error: "Method tidak didukung." });
  }

  try {
    return sendNodeJson(res, 200, await health());
  } catch (error) {
    return sendNodeJson(res, error.statusCode || 500, { ok: false, error: normalizeError(error) });
  }
}

async function handleWebRequest(request) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "GET") {
    return jsonResponse(405, { ok: false, error: "Method tidak didukung." });
  }

  try {
    return jsonResponse(200, await health());
  } catch (error) {
    return jsonResponse(error.statusCode || 500, { ok: false, error: normalizeError(error) });
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
