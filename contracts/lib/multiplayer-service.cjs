const { Server } = require("socket.io");
const { enqueueGameAction } = require("./game-action-service.cjs");
const { interpret } = require("./ai-brain.cjs");

// AI Agent State
// Valid checksummed Sepolia address used as the AI Farmer Agent's smart account.
const AI_WALLET_ADDRESS = "0x000000000000000000000000000000000000dEaD"; // AI Virtual Address
const AI_ONCHAIN_ENABLED = String(process.env.TANIIN_AI_ONCHAIN_ENABLED || "").trim().toLowerCase() === "true";
const MAX_AI_QUEUE = 20;
const MAX_CHAT_LENGTH = 300;
const MAP_MIN = 0;
const MAP_MAX = 8192;
let aiState = {
  id: "ai-agent",
  wallet: AI_WALLET_ADDRESS,
  name: "Pak Tani AI",
  x: 200,
  y: 350,
  targetX: 200,
  targetY: 350,
  status: "idle", // idle, walking, planting, harvesting
  speed: 80, // pixels per second
  inventory: {
    seeds: { Kentang: 5, Bawang: 0, Stroberi: 0, Bit: 0 },
    crops: { Kentang: 0, Bawang: 0, Stroberi: 0, Bit: 0 },
    coins: 500
  }
};

let io;
let aiInterval;
const players = {}; // id -> { wallet, name, x, y, anim }

// Target positions on map (approximate pixels)
const HOTSPOTS = {
  shop: { x: 144, y: 160 },
  sell: { x: 384, y: 160 },
  swap: { x: 624, y: 160 },
  plots: [
    { x: 160, y: 320 }, // Plot 1
    { x: 224, y: 320 }, // Plot 2
    { x: 288, y: 320 }, // Plot 3
    { x: 352, y: 320 }, // Plot 4
    { x: 416, y: 320 }  // Plot 5
  ]
};

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

    socket.on("join", (data) => {
      const payload = data && typeof data === "object" ? data : {};
      players[socket.id] = {
        wallet: normalizeWallet(payload.wallet),
        name: cleanText(payload.name, 32) || "Anon Player",
        x: finiteCoordinate(payload.x, 200),
        y: finiteCoordinate(payload.y, 300),
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
      if (!text) return;
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

function normalizeWallet(value) {
  const wallet = cleanText(value, 42);
  return /^0x[0-9a-fA-F]{40}$/.test(wallet) ? wallet : "0x";
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
    const dx = aiState.targetX - aiState.x;
    const dy = aiState.targetY - aiState.y;
    const distance = Math.sqrt(dx * dx + dy * dy);

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

  aiState.onReachedTarget = async () => {
    aiState.status = "busy";
    
    if (action.type === "buy") {
      const seedType = action.arg;
      console.log(`[AI] Beli benih ${seedType}`);
      speakAi(`Tiba di toko. Sedang membeli benih ${seedType}...`);
      
      // Simulate API action (Local fallback or Sepolia transaction)
      try {
        const seedIndex = ["Kentang", "Bawang", "Stroberi", "Bit"].indexOf(seedType) + 1;
        const res = AI_ONCHAIN_ENABLED ? await enqueueGameAction({
          wallet: aiState.wallet,
          type: "BUY_SEED",
          plotId: seedIndex,
          amount: 3
        }) : { txHash: "" };
        
        aiState.inventory.coins -= 60; // Approximate price
        aiState.inventory.seeds[seedType] += 3;
        speakAi(`Selesai! Saya membeli 3 benih ${seedType}. (Tx: ${res.txHash ? res.txHash.substring(0, 8) : "lokal"})`);
      } catch (err) {
        speakAi(`Gagal beli benih: ${err.message || err}`);
      }
    } 
    else if (action.type === "buy_then_plant") {
      const { seedType, plotNum } = action.arg;
      speakAi(`Tiba di toko. Membeli benih ${seedType} dulu...`);
      try {
        const seedIndex = ["Kentang", "Bawang", "Stroberi", "Bit"].indexOf(seedType) + 1;
        if (AI_ONCHAIN_ENABLED) await enqueueGameAction({
          wallet: aiState.wallet,
          type: "BUY_SEED",
          plotId: seedIndex,
          amount: 3
        });
        aiState.inventory.seeds[seedType] += 3;
        speakAi(`Benih didapat. Sekarang lanjut ke Lahan ${plotNum} untuk menanam.`);
        
        // Queue the next action to plant
        queueAiAction({ type: "plant", target: `plot_${plotNum}`, arg: { seedType, plotNum } });
      } catch (err) {
        speakAi(`Gagal beli benih: ${err.message || err}`);
      }
    }
    else if (action.type === "plant") {
      const { seedType, plotNum } = action.arg;
      console.log(`[AI] Menanam di plot ${plotNum}`);
      speakAi(`Tiba di Lahan ${plotNum}. Menanam ${seedType}...`);

      const seedIndex = ["Kentang", "Bawang", "Stroberi", "Bit"].indexOf(seedType) + 1;
      let txLabel = "lokal";
      try {
        const res = AI_ONCHAIN_ENABLED ? await enqueueGameAction({
          wallet: aiState.wallet,
          type: "PLANT",
          plotId: plotNum,
          amount: seedIndex
        }) : { txHash: "" };
        if (res && res.txHash) txLabel = res.txHash.substring(0, 8);
      } catch (err) {
        console.log(`[AI] plant on-chain gagal (lanjut lokal): ${err.message || err}`);
      }

      if (aiState.inventory.seeds[seedType] > 0) aiState.inventory.seeds[seedType] -= 1;

      // Always broadcast the visual planting so the world stays in sync.
      io.emit("ai_planted", {
        plotIndex: plotNum - 1,
        seedIndex: seedIndex - 1
      });

      speakAi(`Bagus! Benih ${seedType} ditanam di Lahan ${plotNum}. (Tx: ${txLabel})`);
    }
    else if (action.type === "harvest") {
      const { plotNum } = action.arg;
      console.log(`[AI] Memanen di plot ${plotNum}`);
      speakAi(`Tiba di Lahan ${plotNum}. Memanen tanaman...`);

      let txLabel = "lokal";
      try {
        const res = AI_ONCHAIN_ENABLED ? await enqueueGameAction({
          wallet: aiState.wallet,
          type: "HARVEST",
          plotId: plotNum,
          amount: 3 // Yield amount
        }) : { txHash: "" };
        if (res && res.txHash) txLabel = res.txHash.substring(0, 8);
      } catch (err) {
        console.log(`[AI] harvest on-chain gagal (lanjut lokal): ${err.message || err}`);
      }

      // Always broadcast harvest so the world stays in sync.
      io.emit("ai_harvested", {
        plotIndex: plotNum - 1
      });

      aiState.inventory.crops.Kentang += 3; // Hardcoded yield
      speakAi(`Sukses! Hasil panen berhasil diambil. (Tx: ${txLabel})`);
    }
    else if (action.type === "sell") {
      speakAi(`Tiba di pengepul. Menjual seluruh panen...`);
      try {
        let cropsToSell = aiState.inventory.crops.Kentang;
        if (cropsToSell <= 0) {
          speakAi(`Wah, saya tidak punya hasil panen untuk dijual.`);
          aiState.status = "idle";
          return;
        }
        
        const res = AI_ONCHAIN_ENABLED ? await enqueueGameAction({
          wallet: aiState.wallet,
          type: "SELL_CROP",
          plotId: 0,
          amount: cropsToSell
        }) : { txHash: "" };
        
        const earned = cropsToSell * 35;
        aiState.inventory.coins += earned;
        aiState.inventory.crops.Kentang = 0;
        speakAi(`Hore! Terjual ${cropsToSell} panen seharga ${earned} koin. (Tx: ${res.txHash ? res.txHash.substring(0, 8) : "lokal"})`);
      } catch (err) {
        speakAi(`Gagal menjual: ${err.message || err}`);
      }
    }

    aiState.status = "idle";
  };
}

module.exports = {
  normalizeSkin,
  initMultiplayer
};
