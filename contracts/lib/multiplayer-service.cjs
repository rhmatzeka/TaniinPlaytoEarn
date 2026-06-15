const { Server } = require("socket.io");
const { enqueueGameAction } = require("./game-action-service.cjs");

// AI Agent State
// Valid checksummed Sepolia address used as the AI Farmer Agent's smart account.
const AI_WALLET_ADDRESS = "0x000000000000000000000000000000000000dEaD"; // AI Virtual Address
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
      origin: "*",
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
      players[socket.id] = {
        wallet: data.wallet || "0x",
        name: data.name || "Anon Player",
        x: data.x || 200,
        y: data.y || 300,
        anim: data.anim || "idle"
      };
      console.log(`[multiplayer] Player joined: ${players[socket.id].name} (${players[socket.id].wallet})`);
      socket.broadcast.emit("player_joined", {
        id: socket.id,
        player: players[socket.id]
      });
    });

    socket.on("move", (data) => {
      if (players[socket.id]) {
        players[socket.id].x = data.x;
        players[socket.id].y = data.y;
        players[socket.id].anim = data.anim;
        socket.broadcast.emit("player_moved", {
          id: socket.id,
          x: data.x,
          y: data.y,
          anim: data.anim
        });
      }
    });

    socket.on("chat", (data) => {
      const text = data.text || "";
      const wallet = players[socket.id] ? players[socket.id].wallet : "0x";
      console.log(`[chat] ${players[socket.id]?.name || "Anon"}: ${text}`);

      // Broadcast the chat message to everyone
      io.emit("chat_message", {
        sender: players[socket.id]?.name || "Anon",
        wallet: wallet,
        text: text,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      });

      // If addressed to AI, parse and respond
      if (text.toLowerCase().includes("ai") || text.toLowerCase().startsWith("tolong") || text.toLowerCase().startsWith("pak tani")) {
        processAiCommand(text, socket.id);
      }
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
  setInterval(updateAiAgent, 100);
}

// Simple NLP / Command Parser for AI Agent
async function processAiCommand(text, playerId) {
  const clean = text.toLowerCase();
  const player = players[playerId] || { name: "Player", wallet: AI_WALLET_ADDRESS };
  
  let response = "";
  let action = null; // { type, target, arg }

  // 1. GREETING
  if (clean.includes("halo") || clean.includes("hi") || clean.includes("hello")) {
    response = `Halo ${player.name}! Saya Pak Tani AI. Saya bisa disuruh bertani. Contoh perintah: "AI tolong tanam kentang di lahan 2" atau "AI tolong panen lahan 1".`;
  }
  // 2. STATUS
  else if (clean.includes("status") || clean.includes("koin") || clean.includes("benih")) {
    response = `Status saya: Koin: ${aiState.inventory.coins}, Benih Kentang: ${aiState.inventory.seeds.Kentang}, Hasil Panen: ${aiState.inventory.crops.Kentang} Kentang.`;
  }
  // 3. BELI BENIH (contoh: "ai tolong beli kentang")
  else if (clean.includes("beli") || clean.includes("shop")) {
    let seedType = "Kentang";
    if (clean.includes("bawang")) seedType = "Bawang";
    if (clean.includes("stroberi") || clean.includes("strawberry")) seedType = "Stroberi";
    if (clean.includes("bit") || clean.includes("beet")) seedType = "Bit";

    response = `Baik, saya akan pergi ke Toko Ucup untuk membeli benih ${seedType} terlebih dahulu.`;
    action = { type: "buy", target: "shop", arg: seedType };
  }
  // 4. TANAM (contoh: "ai tolong tanam kentang di lahan 2")
  else if (clean.includes("tanam") || clean.includes("plant")) {
    let seedType = "Kentang";
    if (clean.includes("bawang")) seedType = "Bawang";
    if (clean.includes("stroberi") || clean.includes("strawberry")) seedType = "Stroberi";
    if (clean.includes("bit") || clean.includes("beet")) seedType = "Bit";

    // Parse plot number (1 to 5)
    let plotNum = 1;
    const match = clean.match(/lahan\s*([1-5])/);
    if (match) {
      plotNum = parseInt(match[1]);
    } else {
      const matchNum = clean.match(/([1-5])/);
      if (matchNum) plotNum = parseInt(matchNum[1]);
    }

    if (aiState.inventory.seeds[seedType] <= 0) {
      response = `Saya tidak punya benih ${seedType}. Saya beli di Toko dulu ya, lalu saya tanam di Lahan ${plotNum}.`;
      // Queue buying first, then planting
      action = { type: "buy_then_plant", target: "shop", arg: { seedType, plotNum } };
    } else {
      response = `Siap! Saya jalan ke Lahan ${plotNum} untuk menanam ${seedType}.`;
      action = { type: "plant", target: `plot_${plotNum}`, arg: { seedType, plotNum } };
    }
  }
  // 5. PANEN (contoh: "ai tolong panen lahan 2")
  else if (clean.includes("panen") || clean.includes("harvest") || clean.includes("ambil")) {
    let plotNum = 1;
    const match = clean.match(/lahan\s*([1-5])/);
    if (match) {
      plotNum = parseInt(match[1]);
    } else {
      const matchNum = clean.match(/([1-5])/);
      if (matchNum) plotNum = parseInt(matchNum[1]);
    }

    response = `Oke, saya akan ke Lahan ${plotNum} untuk memanen hasil tanaman.`;
    action = { type: "harvest", target: `plot_${plotNum}`, arg: { plotNum } };
  }
  // 6. JUAL PANEN (contoh: "ai tolong jual hasil")
  else if (clean.includes("jual") || clean.includes("sell")) {
    response = `Baik, saya akan ke rumah pengepul untuk menjual seluruh hasil panen saya.`;
    action = { type: "sell", target: "sell", arg: null };
  }
  else {
    response = `Maaf ${player.name}, saya kurang paham perintah itu. Coba katakan: "AI tanam kentang di lahan 1" atau "AI panen lahan 1".`;
  }

  // Speak response
  speakAi(response);

  // If there's an action, queue it
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
  aiActionQueue.push(action);
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
        const res = await enqueueGameAction({
          wallet: aiState.wallet,
          type: "BUY_SEED",
          plotId: seedIndex,
          amount: 3
        });
        
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
        await enqueueGameAction({
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
        const res = await enqueueGameAction({
          wallet: aiState.wallet,
          type: "PLANT",
          plotId: plotNum,
          amount: seedIndex
        });
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
        const res = await enqueueGameAction({
          wallet: aiState.wallet,
          type: "HARVEST",
          plotId: plotNum,
          amount: 3 // Yield amount
        });
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
        
        const res = await enqueueGameAction({
          wallet: aiState.wallet,
          type: "SELL_CROP",
          plotId: 0,
          amount: cropsToSell
        });
        
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
  initMultiplayer
};
