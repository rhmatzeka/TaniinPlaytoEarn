// E2E test: Multiplayer sync + AI Farmer Agent command flow
const { io } = require("socket.io-client");

const URL = "http://127.0.0.1:8787";
const log = (tag, ...a) => console.log(`[${tag}]`, ...a);

let player1Sees = { otherPlayerMoved: false, aiMoved: false, aiPlanted: false, chatFromAi: false };
let pass = 0, fail = 0;
const check = (cond, name) => { if (cond) { pass++; log("PASS", name); } else { fail++; log("FAIL", name); } };

async function main() {
  // --- Player 1 connects ---
  const p1 = io(URL, { transports: ["websocket"], forceNew: true });
  await once(p1, "connect");
  log("P1", "connected", p1.id);

  p1.on("init", (d) => log("P1", "init received. ai=", d.ai?.name, "players=", Object.keys(d.players || {}).length));
  p1.on("player_joined", () => { player1Sees.otherPlayerJoined = true; log("P1", "saw a player join"); });
  p1.on("player_moved", () => { player1Sees.otherPlayerMoved = true; });
  p1.on("ai_moved", () => { player1Sees.aiMoved = true; });
  p1.on("ai_planted", (d) => { player1Sees.aiPlanted = true; log("P1", "saw AI plant at plot index", d.plotIndex); });
  p1.on("chat_message", (m) => {
    log("CHAT", `${m.sender}: ${m.text}`);
    if (m.sender === "Pak Tani AI") player1Sees.chatFromAi = true;
  });

  p1.emit("join", { wallet: "0xPlayer1", name: "Petani Satu", x: 2368, y: 3648, anim: "idle" });
  await wait(500);

  // --- Player 2 connects ---
  const p2 = io(URL, { transports: ["websocket"], forceNew: true });
  await once(p2, "connect");
  log("P2", "connected", p2.id);
  p2.emit("join", { wallet: "0xPlayer2", name: "Petani Dua", x: 2400, y: 3600, anim: "idle" });
  await wait(600);

  check(player1Sees.otherPlayerJoined === true, "Player1 menerima event player_joined dari Player2");

  // --- Player 2 moves, Player 1 should see it ---
  for (let i = 0; i < 5; i++) {
    p2.emit("move", { x: 2400 + i * 20, y: 3600, anim: "walk" });
    await wait(120);
  }
  await wait(400);
  check(player1Sees.otherPlayerMoved === true, "Player1 menerima sinkronisasi gerakan Player2 (multiplayer)");

  // --- Player 1 sends an AI command to plant ---
  log("P1", "Mengirim perintah: 'AI tolong tanam kentang di lahan 2'");
  p1.emit("chat", { text: "AI tolong tanam kentang di lahan 2" });

  // Wait for AI to walk + plant (server simulates movement, ~ up to 15s)
  await waitFor(() => player1Sees.aiPlanted, 25000);

  check(player1Sees.chatFromAi === true, "AI Agent membalas chat perintah");
  check(player1Sees.aiMoved === true, "AI Agent bergerak di peta (broadcast ai_moved)");
  check(player1Sees.aiPlanted === true, "AI Agent menanam benih secara otomatis (ai_planted)");

  // --- Player 1 asks AI to harvest ---
  let aiHarvested = false;
  p1.on("ai_harvested", () => { aiHarvested = true; log("P1", "saw AI harvest"); });
  log("P1", "Mengirim perintah: 'AI tolong panen lahan 2'");
  p1.emit("chat", { text: "AI tolong panen lahan 2" });
  await waitFor(() => aiHarvested, 25000).catch(() => {});
  check(aiHarvested === true, "AI Agent memanen secara otomatis (ai_harvested)");

  // --- Player 2 disconnect, Player 1 should be notified ---
  let sawLeft = false;
  p1.on("player_left", () => { sawLeft = true; });
  p2.close();
  await wait(800);
  check(sawLeft === true, "Player1 menerima event player_left saat Player2 keluar");

  p1.close();

  console.log(`\n==== E2E RESULT: ${pass} passed, ${fail} failed ====`);
  process.exit(fail === 0 ? 0 : 1);
}

function once(sock, ev, timeout = 8000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      sock.close();
      reject(new Error(`timeout menunggu event ${ev} dari ${URL}; pastikan game-api sedang berjalan`));
    }, timeout);
    sock.once(ev, (...args) => {
      clearTimeout(timer);
      resolve(...args);
    });
  });
}
function wait(ms) { return new Promise((r) => setTimeout(r, ms)); }
function waitFor(cond, timeout) {
  return new Promise((res, rej) => {
    const t0 = Date.now();
    const iv = setInterval(() => {
      if (cond()) { clearInterval(iv); res(); }
      else if (Date.now() - t0 > timeout) { clearInterval(iv); rej(new Error("timeout")); }
    }, 150);
  });
}

main().catch((e) => { console.error("E2E ERROR:", e); process.exit(1); });
