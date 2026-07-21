// AI brain for "Pak Tani AI": converts natural-language chat into structured
// farm actions using the Groq LLM, with a deterministic rule-based fallback.

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const SEEDS = ["Kentang", "Bawang", "Stroberi", "Bit"];

const SYSTEM_PROMPT = `Kamu adalah "Pak Tani AI", asisten petani ramah di game farming Web3 bernama Taniin.
Pemain bicara santai dalam Bahasa Indonesia (kadang Inggris). Tugasmu memahami maksud
pemain dan mengubahnya menjadi SATU aksi terstruktur untuk dijalankan di game.

Aksi yang tersedia (intent):
- "plant"   : menanam benih di sebuah lahan. butuh: seed (salah satu: Kentang, Bawang, Stroberi, Bit), plot (1-5).
- "harvest" : memanen tanaman di sebuah lahan. butuh: plot (1-5).
- "buy"     : membeli benih di toko. butuh: seed.
- "sell"    : menjual hasil panen di pengepul.
- "status"  : menjawab status koin/benih/panen AI.
- "chat"    : obrolan biasa / sapaan / pertanyaan umum (tidak ada aksi game).

Aturan:
- Jika pemain menyebut tanaman tapi tidak menyebut lahan untuk "plant", default plot = 1.
- Jika tidak yakin lahan untuk "harvest", default plot = 1.
- "reply" harus ramah, singkat (maks 1-2 kalimat), Bahasa Indonesia, boleh sedikit ceria.
- Selalu balas HANYA dengan JSON valid, tanpa teks lain, tanpa markdown.

Format wajib:
{"intent":"plant|harvest|buy|sell|status|chat","seed":"Kentang|Bawang|Stroberi|Bit|null","plot":1,"reply":"..."}`;

async function interpret(text) {
  const apiKey = (process.env.GROQ_API_KEY || "").trim();
  if (apiKey) {
    try {
      const result = await callGroq(apiKey, text);
      if (result) return { ...result, source: "groq" };
    } catch (err) {
      console.log(`[ai-brain] Groq gagal, fallback ke rule-based: ${err.message || err}`);
    }
  }
  return { ...ruleBased(text), source: "rules" };
}

async function callGroq(apiKey, text) {
  const model = (process.env.GROQ_MODEL || "llama-3.3-70b-versatile").trim();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const res = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        temperature: 0.4,
        max_tokens: 200,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: text }
        ]
      }),
      signal: controller.signal
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content || "";
    const parsed = JSON.parse(content);
    return normalize(parsed, text);
  } finally {
    clearTimeout(timer);
  }
}

function normalize(parsed, originalText) {
  const intent = String(parsed.intent || "chat").toLowerCase();
  const valid = ["plant", "harvest", "buy", "sell", "status", "chat"];
  const finalIntent = valid.includes(intent) ? intent : "chat";

  let seed = parsed.seed;
  if (typeof seed === "string") {
    const match = SEEDS.find((s) => s.toLowerCase() === seed.toLowerCase());
    seed = match || null;
  } else {
    seed = null;
  }
  if ((finalIntent === "plant" || finalIntent === "buy") && !seed) {
    seed = "Kentang";
  }

  let plot = parseInt(parsed.plot, 10);
  if (!Number.isInteger(plot) || plot < 1 || plot > 5) {
    plot = 1;
  }

  let reply = typeof parsed.reply === "string" ? parsed.reply.trim() : "";
  reply = reply.replace(/[\u0000-\u001F\u007F]/g, " ").replace(/\s+/g, " ").slice(0, 400);
  if (!reply) reply = defaultReply(finalIntent, seed, plot);

  return { intent: finalIntent, seed, plot, reply };
}

// Deterministic fallback used when no API key or Groq is unreachable.
function ruleBased(text) {
  const clean = (text || "").toLowerCase();
  const plotMatch = clean.match(/lahan\s*([1-5])/) || clean.match(/plot\s*([1-5])/) || clean.match(/\b([1-5])\b/);
  const plot = plotMatch ? parseInt(plotMatch[1], 10) : 1;

  let seed = null;
  if (clean.includes("kentang")) seed = "Kentang";
  else if (clean.includes("bawang")) seed = "Bawang";
  else if (clean.includes("stroberi") || clean.includes("strawberry")) seed = "Stroberi";
  else if (clean.includes("bit") || clean.includes("beet")) seed = "Bit";

  if (clean.includes("tanam") || clean.includes("plant")) {
    const s = seed || "Kentang";
    return { intent: "plant", seed: s, plot, reply: `Siap! Saya jalan ke Lahan ${plot} untuk menanam ${s}.` };
  }
  if (clean.includes("panen") || clean.includes("harvest") || clean.includes("ambil")) {
    return { intent: "harvest", seed: null, plot, reply: `Oke, saya menuju Lahan ${plot} untuk memanen.` };
  }
  if (clean.includes("beli") || clean.includes("buy") || clean.includes("shop") || clean.includes("toko")) {
    const s = seed || "Kentang";
    return { intent: "buy", seed: s, plot, reply: `Baik, saya ke Toko Ucup untuk membeli benih ${s}.` };
  }
  if (clean.includes("jual") || clean.includes("sell")) {
    return { intent: "sell", seed: null, plot, reply: `Baik, saya ke pengepul untuk menjual hasil panen.` };
  }
  if (clean.includes("status") || clean.includes("koin") || clean.includes("benih") || clean.includes("punya")) {
    return { intent: "status", seed: null, plot, reply: "" };
  }
  if (clean.includes("halo") || clean.includes("hai") || clean.includes("hi") || clean.includes("hello")) {
    return {
      intent: "chat",
      seed: null,
      plot,
      reply: 'Halo! Saya Pak Tani AI. Coba bilang: "tanam kentang di lahan 2" atau "panen lahan 1".'
    };
  }
  return {
    intent: "chat",
    seed: null,
    plot,
    reply: 'Hmm, saya kurang paham. Coba: "tanam stroberi di lahan 3", "panen lahan 1", atau "jual panen".'
  };
}

function defaultReply(intent, seed, plot) {
  switch (intent) {
    case "plant": return `Siap! Saya menanam ${seed} di Lahan ${plot}.`;
    case "harvest": return `Oke, saya memanen Lahan ${plot}.`;
    case "buy": return `Baik, saya membeli benih ${seed} di toko.`;
    case "sell": return `Baik, saya menjual hasil panen.`;
    case "status": return "";
    default: return "Siap membantu bertani! Mau tanam, panen, beli, atau jual?";
  }
}

module.exports = { interpret };
