const { Server } = require("socket.io");
const crypto = require("crypto");
const { interpret } = require("./ai-brain.cjs");

// AI Agent State
// Valid checksummed Sepolia address used as the AI Farmer Agent's smart account.
const AI_WALLET_ADDRESS = "0x000000000000000000000000000000000000dEaD"; // AI Virtual Address
const CHAT_INTERVAL_MS = 2000;
// Short so a logged-out session stops showing as verified within seconds.
const SESSION_CACHE_MS = 30 * 1000;
const MAX_AI_QUEUE = 20;
const MAX_CHAT_LENGTH = 300;
const MAP_MIN = 0;
const MAP_MAX = 8192;
// World coordinates match the Flutter game: 128 px per tile.
const TILE = 128;
const AI_SPAWN = { x: 18.18 * TILE, y: 26.85 * TILE };
let aiState = {
  id: "ai-agent",
  wallet: AI_WALLET_ADDRESS,
  name: "Pak Tani AI",
  x: AI_SPAWN.x,
  y: AI_SPAWN.y,
  targetX: AI_SPAWN.x,
  targetY: AI_SPAWN.y,
  path: [],
  status: "idle", // idle, walking, planting, harvesting
  speed: 2.6 * TILE, // world pixels per second
  inventory: {
    seeds: { Kentang: 5, Bawang: 0, Stroberi: 0, Bit: 0 },
    crops: { Kentang: 0, Bawang: 0, Stroberi: 0, Bit: 0 },
    coins: 500
  }
};

let io;
let aiInterval;
const players = {}; // id -> { wallet, name, x, y, anim }

// Where Pak Tani AI stands for each job, in front of the building or in the
// field corridor (same spots as the client's offline AI).
const HOTSPOTS = {
  shop: { x: 19.2 * TILE, y: 26.85 * TILE },
  sell: { x: 31.0 * TILE, y: 13.35 * TILE },
  swap: { x: 10.85 * TILE, y: 13.15 * TILE },
  plots: [4, 6, 8, 10, 12].map((tileX) => ({ x: (tileX + 1) * TILE, y: 20 * TILE })),
};

// Road network used to route around the fenced field and the houses.
const ROUTE = {
  innerY: 21.65 * TILE, // corridor inside the field fence
  outerY: 26.85 * TILE, // main road below the shop
  gateX: 5.0 * TILE, // field gate
  mainRoadX: 18.5 * TILE, // north-south road
  fenceX: 14.0 * TILE,
  fenceY: 23.0 * TILE,
};

function insideField(point) {
  return point.x < ROUTE.fenceX && point.y < ROUTE.fenceY;
}

// Waypoints from start to target along the roads, mirroring
// MultiplayerClient._calculateAiPath in the Flutter app.
function aiPath(start, target) {
  const path = [];
  const startInside = insideField(start);
  const targetInside = insideField(target);
  if (startInside && targetInside) {
    path.push({ x: start.x, y: ROUTE.innerY }, { x: target.x, y: ROUTE.innerY });
  } else if (startInside) {
    path.push(
      { x: start.x, y: ROUTE.innerY },
      { x: ROUTE.gateX, y: ROUTE.innerY },
      { x: ROUTE.gateX, y: ROUTE.outerY },
      { x: ROUTE.mainRoadX, y: ROUTE.outerY },
      { x: ROUTE.mainRoadX, y: target.y },
    );
  } else if (targetInside) {
    path.push(
      { x: start.x, y: ROUTE.outerY },
      { x: ROUTE.mainRoadX, y: ROUTE.outerY },
      { x: ROUTE.gateX, y: ROUTE.outerY },
      { x: ROUTE.gateX, y: ROUTE.innerY },
      { x: target.x, y: ROUTE.innerY },
    );
  } else {
    path.push(
      { x: start.x, y: ROUTE.outerY },
      { x: ROUTE.mainRoadX, y: ROUTE.outerY },
      { x: ROUTE.mainRoadX, y: target.y },
    );
  }
  path.push({ x: target.x, y: target.y });
  return path;
}

const chatLimiter = createChatLimiter(CHAT_INTERVAL_MS);
const sessionCache = new Map();

// Wallet and verified flag come only from a server-side session; guests get a random name.
async function resolvePlayer(payload, lookupSession) {
  let session = null;
  const token = String(payload.session || "").trim();
  if (token) {
    try {
      session = await lookupSession(token);
    } catch (error) {
      console.log(`[multiplayer] session lookup gagal: ${error.message || error}`);
    }
  }
  if (!session) {
    return { wallet: "", name: `Tamu-${crypto.randomBytes(2).toString("hex").toUpperCase()}`, verified: false };
  }
  return {
    wallet: session.wallet,
    name: cleanText(payload.name, 24) || `Petani-${session.wallet.slice(2, 6)}`,
    verified: true
  };
}

async function cachedSessionLookup(token) {
  const cached = sessionCache.get(token);
  if (cached && cached.expiresAt > Date.now()) return cached.value;
  const { getReadyDb } = require("./db.cjs");
  const { sessionWalletForSocket } = require("./session-service.cjs");
  const value = await sessionWalletForSocket(await getReadyDb(), token);
  sessionCache.set(token, { value, expiresAt: Date.now() + SESSION_CACHE_MS });
  if (sessionCache.size > 1000) sessionCache.delete(sessionCache.keys().next().value);
  return value;
}

// One limit per wallet (signed in) or per visitor IP, so extra tabs don't help spam.
function chatKey(player, handshake) {
  if (player?.verified && player.wallet) return `w:${player.wallet}`;
  const headers = handshake?.headers || {};
  const ip = String(headers["cf-connecting-ip"] || headers["x-forwarded-for"] || handshake?.address || "unknown")
    .split(",")[0]
    .trim();
  return `ip:${ip}`;
}

function createChatLimiter(intervalMs) {
  const lastSent = new Map();
  return {
    allow(id, nowMs) {
      const last = lastSent.get(id);
      if (last !== undefined && nowMs - last < intervalMs) return false;
      lastSent.set(id, nowMs);
      if (lastSent.size > 5000) lastSent.delete(lastSent.keys().next().value);
      return true;
    },
    forget(id) {
      lastSent.delete(id);
    }
  };
}

function initMultiplayer(server) {
  io = new Server(server, {
    cors: {
      origin: process.env.TANIIN_ALLOWED_ORIGIN || "*",
      methods: ["GET", "POST"]
    }
  });

  io.on("connection", (socket) => {
    console.log(`[multiplayer] Player connected: ${socket.id}`);

    // Send initial states
    socket.emit("init", {
      players,
      ai: aiState
    });

    socket.on("join", async (data) => {
      const payload = data && typeof data === "object" ? data : {};
      const identity = await resolvePlayer(payload, cachedSessionLookup);
      if (!socket.connected) return;
      players[socket.id] = {
        ...identity,
        x: finiteCoordinate(payload.x, 18.5 * TILE),
        y: finiteCoordinate(payload.y, 28.5 * TILE),
        anim: normalizeAnimation(payload.anim),
        skinId: normalizeSkin(payload.skinId)
      };
      console.log(`[multiplayer] Player joined: ${players[socket.id].name} (${players[socket.id].wallet})`);
      socket.broadcast.emit("player_joined", {
        id: socket.id,
        player: players[socket.id]
      });
    });

    socket.on("move", (data) => {
      if (players[socket.id]) {
        const payload = data && typeof data === "object" ? data : {};
        players[socket.id].x = finiteCoordinate(payload.x, players[socket.id].x);
        players[socket.id].y = finiteCoordinate(payload.y, players[socket.id].y);
        players[socket.id].anim = normalizeAnimation(payload.anim);
        socket.broadcast.emit("player_moved", {
          id: socket.id,
          x: players[socket.id].x,
          y: players[socket.id].y,
          anim: players[socket.id].anim
        });
      }
    });

    socket.on("chat", (data) => {
      const text = cleanText(data && data.text, MAX_CHAT_LENGTH);
      if (!text || !chatLimiter.allow(chatKey(players[socket.id], socket.handshake), Date.now())) return;
      const wallet = players[socket.id] ? players[socket.id].wallet : "0x";
      console.log(`[chat] ${players[socket.id]?.name || "Anon"}: ${text}`);

      // Broadcast the player's message to OTHER players only; the sender shows
      // their own message via an optimistic local echo on the client.
      socket.broadcast.emit("chat_message", {
        sender: players[socket.id]?.name || "Anon",
        wallet: wallet,
        text: text,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      });

      // Route every player chat to the AI so it can respond conversationally
      // and act on natural-language farming commands.
      processAiCommand(text, socket.id);
    });

    socket.on("disconnect", () => {
      if (players[socket.id]) {
        console.log(`[multiplayer] Player left: ${players[socket.id].name}`);
        delete players[socket.id];
        io.emit("player_left", { id: socket.id });
      }
    });
  });

  // Start the AI simulation loop (ticks every 100ms)
  if (aiInterval) clearInterval(aiInterval);
  aiInterval = setInterval(updateAiAgent, 100);
  aiInterval.unref?.();
  return shutdownMultiplayer;
}

// LLM-powered command handler for the AI Farmer Agent.
async function processAiCommand(text, playerId) {
  let decision;
  try {
    decision = await interpret(text);
  } catch (err) {
    console.log(`[ai-brain] interpret error: ${err.message || err}`);
    decision = { intent: "chat", seed: null, plot: 1, reply: "Maaf, saya lagi bingung. Coba lagi ya." };
  }

  const { intent, seed, plot } = decision;

  // STATUS: build a live reply from current inventory.
  if (intent === "status") {
    speakAi(
      `Status saya: ${aiState.inventory.coins} koin, benih Kentang ${aiState.inventory.seeds.Kentang}, ` +
      `hasil panen ${aiState.inventory.crops.Kentang} Kentang.`
    );
    return;
  }

  // Always speak the friendly reply first.
  if (decision.reply) speakAi(decision.reply);

  // Map the intent to a queued world action.
  let action = null;
  if (intent === "plant") {
    const seedType = seed || "Kentang";
    if ((aiState.inventory.seeds[seedType] || 0) <= 0) {
      action = { type: "buy_then_plant", target: "shop", arg: { seedType, plotNum: plot } };
    } else {
      action = { type: "plant", target: `plot_${plot}`, arg: { seedType, plotNum: plot } };
    }
  } else if (intent === "harvest") {
    action = { type: "harvest", target: `plot_${plot}`, arg: { plotNum: plot } };
  } else if (intent === "buy") {
    action = { type: "buy", target: "shop", arg: seed || "Kentang" };
  } else if (intent === "sell") {
    action = { type: "sell", target: "sell", arg: null };
  }

  if (action) {
    queueAiAction(action);
  }
}

function speakAi(text) {
  io.emit("chat_message", {
    sender: aiState.name,
    wallet: aiState.wallet,
    text: text,
    time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  });
}

const aiActionQueue = [];

function queueAiAction(action) {
  if (aiActionQueue.length >= MAX_AI_QUEUE) {
    speakAi("Antrean bantuan AI sedang penuh. Coba lagi sebentar ya.");
    return false;
  }
  aiActionQueue.push(action);
  return true;
}

function cleanText(value, maxLength) {
  return String(value || "")
    .replace(/[\u0000-\u001F\u007F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function finiteCoordinate(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(MAP_MAX, Math.max(MAP_MIN, number)) : fallback;
}

function normalizeAnimation(value) {
  const animation = String(value || "idle").toLowerCase();
  return animation === "walk" ? "walk" : "idle";
}

function normalizeSkin(value) {
  const skin = cleanText(value, 32);
  return ["farmer_classic", "farmer_nusantara", "forest_keeper"].includes(skin)
    ? skin
    : "farmer_classic";
}

function shutdownMultiplayer() {
  if (aiInterval) {
    clearInterval(aiInterval);
    aiInterval = undefined;
  }
  aiActionQueue.length = 0;
  for (const id of Object.keys(players)) delete players[id];
  io?.close();
  io = undefined;
}

function updateAiAgent() {
  if (aiActionQueue.length > 0 && aiState.status === "idle") {
    const nextAction = aiActionQueue.shift();
    executeAiAction(nextAction);
  }

  // Move towards target
  if (aiState.status === "walking") {
    let waypoint = aiState.path[0] || { x: aiState.targetX, y: aiState.targetY };
    let dx = waypoint.x - aiState.x;
    let dy = waypoint.y - aiState.y;
    let distance = Math.sqrt(dx * dx + dy * dy);
    while (distance <= 5 && aiState.path.length > 1) {
      aiState.path.shift();
      waypoint = aiState.path[0];
      dx = waypoint.x - aiState.x;
      dy = waypoint.y - aiState.y;
      distance = Math.sqrt(dx * dx + dy * dy);
    }

    if (distance > 5) {
      const step = (aiState.speed * 0.1); // 100ms step
      aiState.x += (dx / distance) * Math.min(step, distance);
      aiState.y += (dy / distance) * Math.min(step, distance);

      io.emit("ai_moved", {
        x: aiState.x,
        y: aiState.y,
        anim: "walk"
      });
    } else {
      // Reached destination
      aiState.x = aiState.targetX;
      aiState.y = aiState.targetY;
      aiState.path = [];
      aiState.status = "idle";
      io.emit("ai_moved", {
        x: aiState.x,
        y: aiState.y,
        anim: "idle"
      });
      
      // Execute the post-walk behavior callback if any
      if (aiState.onReachedTarget) {
        const cb = aiState.onReachedTarget;
        aiState.onReachedTarget = null;
        cb();
      }
    }
  }
}

function executeAiAction(action) {
  let destination = { x: aiState.x, y: aiState.y };

  if (action.target === "shop") {
    destination = HOTSPOTS.shop;
  } else if (action.target === "sell") {
    destination = HOTSPOTS.sell;
  } else if (action.target === "swap") {
    destination = HOTSPOTS.swap;
  } else if (action.target.startsWith("plot_")) {
    const plotIdx = parseInt(action.target.split("_")[1]) - 1;
    destination = HOTSPOTS.plots[plotIdx] || aiState;
  }

  aiState.status = "walking";
  aiState.targetX = destination.x;
  aiState.targetY = destination.y;
  aiState.path = aiPath({ x: aiState.x, y: aiState.y }, destination);

  aiState.onReachedTarget = async () => {
    aiState.status = "busy";
    
    if (action.type === "buy") {
      const seedType = action.arg;
      console.log(`[AI] Beli benih ${seedType}`);
      speakAi(`Tiba di toko. Sedang membeli benih ${seedType}...`);
      
      aiState.inventory.coins -= 60; // Approximate price
      aiState.inventory.seeds[seedType] += 3;
      speakAi(`Selesai! Saya membeli 3 benih ${seedType}.`);
    } 
    else if (action.type === "buy_then_plant") {
      const { seedType, plotNum } = action.arg;
      speakAi(`Tiba di toko. Membeli benih ${seedType} dulu...`);
      aiState.inventory.seeds[seedType] += 3;
      speakAi(`Benih didapat. Sekarang lanjut ke Lahan ${plotNum} untuk menanam.`);
      queueAiAction({ type: "plant", target: `plot_${plotNum}`, arg: { seedType, plotNum } });
    }
    else if (action.type === "plant") {
      const { seedType, plotNum } = action.arg;
      console.log(`[AI] Menanam di plot ${plotNum}`);
      speakAi(`Tiba di Lahan ${plotNum}. Menanam ${seedType}...`);

      const seedIndex = ["Kentang", "Bawang", "Stroberi", "Bit"].indexOf(seedType) + 1;

      if (aiState.inventory.seeds[seedType] > 0) aiState.inventory.seeds[seedType] -= 1;

      // Always broadcast the visual planting so the world stays in sync.
      io.emit("ai_planted", {
        plotIndex: plotNum - 1,
        seedIndex: seedIndex - 1
      });

      speakAi(`Bagus! Benih ${seedType} ditanam di Lahan ${plotNum}.`);
    }
    else if (action.type === "harvest") {
      const { plotNum } = action.arg;
      console.log(`[AI] Memanen di plot ${plotNum}`);
      speakAi(`Tiba di Lahan ${plotNum}. Memanen tanaman...`);

      // Always broadcast harvest so the world stays in sync.
      io.emit("ai_harvested", {
        plotIndex: plotNum - 1
      });

      aiState.inventory.crops.Kentang += 3; // Hardcoded yield
      speakAi(`Sukses! Hasil panen berhasil diambil.`);
    }
    else if (action.type === "sell") {
      speakAi(`Tiba di pengepul. Menjual seluruh panen...`);
      const cropsToSell = aiState.inventory.crops.Kentang;
      if (cropsToSell <= 0) {
        speakAi(`Wah, saya tidak punya hasil panen untuk dijual.`);
        aiState.status = "idle";
        return;
      }
      const earned = cropsToSell * 35;
      aiState.inventory.coins += earned;
      aiState.inventory.crops.Kentang = 0;
      speakAi(`Hore! Terjual ${cropsToSell} panen seharga ${earned} koin.`);
    }

    aiState.status = "idle";
  };
}

module.exports = {
  HOTSPOTS,
  aiPath,
  chatKey,
  createChatLimiter,
  initMultiplayer,
  normalizeSkin,
  resolvePlayer
};
