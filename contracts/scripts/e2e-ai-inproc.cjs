// Self-contained E2E: boots HTTP+socket server in-process, runs a client that
// drives the Groq-powered AI agent, asserts results, then exits.
const http = require("http");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });

const { initMultiplayer } = require("../lib/multiplayer-service.cjs");
const { io } = require("socket.io-client");

const PORT = 8799;
let pass = 0, fail = 0;
const check = (c, n) => { c ? (pass++, console.log("PASS", n)) : (fail++, console.log("FAIL", n)); };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const waitFor = (cond, t) => new Promise((res, rej) => {
  const t0 = Date.now();
  const iv = setInterval(() => {
    if (cond()) { clearInterval(iv); res(); }
    else if (Date.now() - t0 > t) { clearInterval(iv); rej(new Error("timeout")); }
  }, 150);
});

async function main() {
  const server = http.createServer((req, res) => { res.writeHead(200); res.end("ok"); });
  initMultiplayer(server);
  await new Promise((r) => server.listen(PORT, "127.0.0.1", r));
  console.log(`[test] server up on ${PORT}, GROQ key present: ${!!process.env.GROQ_API_KEY}`);

  const seen = { aiPlanted: false, aiMoved: false, aiHarvested: false };
  const aiReplies = [];

  const c = io(`http://127.0.0.1:${PORT}`, { transports: ["websocket"], forceNew: true });
  await new Promise((r) => c.once("connect", r));
  c.on("ai_moved", () => { seen.aiMoved = true; });
  c.on("ai_planted", (d) => { seen.aiPlanted = true; console.log("  [evt] ai_planted plot", d.plotIndex, "seed", d.seedIndex); });
  c.on("ai_harvested", () => { seen.aiHarvested = true; });
  c.on("chat_message", (m) => { if (m.sender === "Pak Tani AI") { aiReplies.push(m.text); console.log("  [AI]", m.text); } });

  c.emit("join", { wallet: "0xDd2d46cC016c0A52ce9dE011a42b6f337333F76e", name: "Tester", x: 2368, y: 3648, anim: "idle" });
  await wait(400);

  // Natural-language, slang command (tests Groq understanding)
  console.log('[test] kirim: "eh tolong tanamin stroberi di petak 3 dong"');
  c.emit("chat", { text: "eh tolong tanamin stroberi di petak 3 dong" });
  await waitFor(() => seen.aiPlanted, 25000).catch(() => {});

  check(aiReplies.length > 0, "AI membalas chat (LLM/rule)");
  check(seen.aiMoved, "AI bergerak ke lahan");
  check(seen.aiPlanted, "AI menanam otomatis (event ai_planted)");

  // Conversational, no action
  console.log('[test] kirim: "halo pak tani, lagi ngapain?"');
  const beforeCount = aiReplies.length;
  c.emit("chat", { text: "halo pak tani, lagi ngapain?" });
  await waitFor(() => aiReplies.length > beforeCount, 15000).catch(() => {});
  check(aiReplies.length > beforeCount, "AI merespons obrolan biasa");

  c.close();
  console.log(`\n==== RESULT: ${pass} passed, ${fail} failed ====`);
  server.close();
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => { console.error("ERR", e); process.exit(1); });
