const http = require("http");
const path = require("path");
const { ethers } = require("ethers");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });

const DEFAULT_PORT = 8787;
const HOST = process.env.TANIIN_GAME_API_HOST || "0.0.0.0";
const PORT = Number(process.env.TANIIN_GAME_API_PORT || DEFAULT_PORT);
const SEPOLIA_CHAIN_ID = 11155111n;
const SEED_ITEM_ID = 1n;
const CROP_ITEM_ID = 2n;
const LAND_SELL_REWARD = 175;
const CROP_REWARD = 35;

const coinAbi = [
  "function mint(address to, uint256 amount) external",
  "function gameSpend(address from, uint256 amount) external"
];

const landAbi = [
  "function playerPlotLandId(address player, uint256 plotId) view returns (uint256)",
  "function mintLandFor(address player, uint256 plotId, string tokenUri) external returns (uint256)",
  "function sellLandFor(address player, uint256 plotId, string tokenUri) external returns (uint256)",
  "function plantFor(address player, uint256 plotId, string tokenUri) external returns (uint256)",
  "function harvestFor(address player, uint256 plotId, string tokenUri) external returns (uint256,uint256)"
];

const itemsAbi = [
  "function mint(address to, uint256 id, uint256 amount) external",
  "function burn(address from, uint256 id, uint256 amount) external"
];

const rpcUrl = requireEnv("SEPOLIA_RPC_URL");
const privateKey = normalizePrivateKey(requireEnv("DEPLOYER_PRIVATE_KEY"));
const coinAddress = requireAddress("TANIIN_COIN_CONTRACT_ADDRESS");
const landAddress = requireAddress("TANIIN_LAND_CONTRACT_ADDRESS");
const itemsAddress = requireAddress("TANIIN_ITEMS_CONTRACT_ADDRESS");

const provider = new ethers.JsonRpcProvider(rpcUrl);
const wallet = new ethers.Wallet(privateKey, provider);
const signer = new ethers.NonceManager(wallet);
const coin = new ethers.Contract(coinAddress, coinAbi, signer);
const land = new ethers.Contract(landAddress, landAbi, signer);
const items = new ethers.Contract(itemsAddress, itemsAbi, signer);

let actionQueue = Promise.resolve();

main().catch((error) => {
  console.error(`[game-api] gagal start: ${normalizeError(error)}`);
  process.exit(1);
});

async function main() {
  if (!Number.isInteger(PORT) || PORT <= 0 || PORT > 65535) {
    throw new Error("TANIIN_GAME_API_PORT tidak valid.");
  }
  const network = await provider.getNetwork();
  if (network.chainId !== SEPOLIA_CHAIN_ID) {
    throw new Error(`RPC bukan Sepolia. Chain ID terdeteksi ${network.chainId}.`);
  }

  const server = http.createServer(handleRequest);
  server.listen(PORT, HOST, () => {
    console.log(`[game-api] signer ${wallet.address}`);
    console.log(`[game-api] listening http://${HOST}:${PORT}`);
    console.log(`[game-api] Android emulator URL: http://10.0.2.2:${PORT}`);
  });
}

function handleRequest(req, res) {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  if (req.method === "GET" && url.pathname === "/health") {
    sendJson(res, 200, {
      ok: true,
      chainId: Number(SEPOLIA_CHAIN_ID),
      signer: wallet.address,
      contracts: {
        coin: coinAddress,
        land: landAddress,
        items: itemsAddress
      }
    });
    return;
  }

  if (req.method !== "POST" || url.pathname !== "/game-actions") {
    sendJson(res, 404, { ok: false, error: "Endpoint tidak ditemukan." });
    return;
  }

  readJson(req)
    .then((body) => enqueueAction(() => submitGameAction(body)))
    .then((result) => sendJson(res, 200, result))
    .catch((error) => {
      const status = error.statusCode || 500;
      sendJson(res, status, { ok: false, error: normalizeError(error) });
    });
}

function enqueueAction(work) {
  const run = actionQueue.then(work, work);
  actionQueue = run.catch(() => undefined);
  return run;
}

async function submitGameAction(body) {
  const walletAddress = normalizeAddress(body.wallet, "wallet");
  const type = String(body.type || "").trim().toUpperCase();
  const plotId = toPositiveInt(body.plotId || 0, "plotId", { allowZero: type === "SELL_CROP" });
  const amount = toPositiveInt(body.amount || 1, "amount");
  const tokenUri = landTokenUri(walletAddress, plotId);
  const txHashes = [];

  switch (type) {
    case "BUY_LAND": {
      const existingLandId = await land.playerPlotLandId(walletAddress, plotId);
      if (existingLandId !== 0n) {
        throw httpError(409, `Lahan #${plotId} sudah minted on-chain untuk wallet ini.`);
      }
      txHashes.push(await sendTransaction("mint land", land.mintLandFor(walletAddress, plotId, tokenUri)));
      break;
    }
    case "SELL_LAND": {
      txHashes.push(await sendTransaction("sell land", land.sellLandFor(walletAddress, plotId, tokenUri)));
      txHashes.push(await sendTransaction("land sell reward", coin.mint(walletAddress, toTani(LAND_SELL_REWARD))));
      break;
    }
    case "PLANT": {
      txHashes.push(await sendTransaction("plant", land.plantFor(walletAddress, plotId, tokenUri)));
      break;
    }
    case "HARVEST": {
      txHashes.push(await sendTransaction("harvest", land.harvestFor(walletAddress, plotId, tokenUri)));
      txHashes.push(await sendTransaction("mint crop", items.mint(walletAddress, CROP_ITEM_ID, BigInt(amount))));
      break;
    }
    case "BUY_SEED": {
      txHashes.push(await sendTransaction("mint seed", items.mint(walletAddress, SEED_ITEM_ID, BigInt(amount))));
      break;
    }
    case "SELL_CROP": {
      txHashes.push(await sendTransaction("crop reward", coin.mint(walletAddress, toTani(BigInt(amount) * BigInt(CROP_REWARD)))));
      break;
    }
    default:
      throw httpError(400, `Tipe aksi tidak dikenal: ${type || "kosong"}.`);
  }

  const txHash = txHashes[0] || "";
  return {
    ok: true,
    type,
    wallet: walletAddress,
    txHash,
    txHashes,
    etherscanUrl: txHash ? `https://sepolia.etherscan.io/tx/${txHash}` : ""
  };
}

async function sendTransaction(label, txPromise) {
  const tx = await txPromise;
  console.log(`[game-api] ${label}: ${tx.hash}`);
  return tx.hash;
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 16_384) {
        reject(httpError(413, "Payload terlalu besar."));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(raw.trim() ? JSON.parse(raw) : {});
      } catch (error) {
        reject(httpError(400, "JSON tidak valid."));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function landTokenUri(walletAddress, plotId) {
  return `ipfs://taniin/land/${walletAddress.toLowerCase()}/${plotId}.json`;
}

function toTani(amount) {
  return ethers.parseUnits(String(amount), 18);
}

function toPositiveInt(value, name, options = {}) {
  const number = Number(value);
  const validZero = options.allowZero && number === 0;
  if ((!validZero && number <= 0) || !Number.isInteger(number) || number > 1_000_000) {
    throw httpError(400, `${name} tidak valid.`);
  }
  return number;
}

function normalizeAddress(value, name) {
  const address = String(value || "").trim();
  if (!ethers.isAddress(address)) {
    throw httpError(400, `${name} tidak valid.`);
  }
  return ethers.getAddress(address);
}

function requireAddress(name) {
  return normalizeAddress(requireEnv(name), name);
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`${name} belum diset.`);
  }
  return value.trim();
}

function normalizePrivateKey(value) {
  const key = value.startsWith("0x") ? value : `0x${value}`;
  if (!/^0x[0-9a-fA-F]{64}$/.test(key)) {
    throw new Error("DEPLOYER_PRIVATE_KEY tidak valid.");
  }
  return key;
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function normalizeError(error) {
  const message = error?.shortMessage
    || error?.reason
    || error?.info?.error?.message
    || error?.error?.message
    || error?.message
    || String(error);
  return String(message).replace(/\s+/g, " ").trim();
}
