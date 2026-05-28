const { ethers } = require("ethers");

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

let servicePromise;
let actionQueue = Promise.resolve();

function getGameService() {
  if (!servicePromise) {
    servicePromise = createGameService().catch((error) => {
      servicePromise = undefined;
      throw error;
    });
  }
  return servicePromise;
}

async function createGameService() {
  const rpcUrl = requireEnv("SEPOLIA_RPC_URL");
  const privateKey = normalizePrivateKey(requireEnv("DEPLOYER_PRIVATE_KEY"));
  const coinAddress = requireAddress("TANIIN_COIN_CONTRACT_ADDRESS");
  const landAddress = requireAddress("TANIIN_LAND_CONTRACT_ADDRESS");
  const itemsAddress = requireAddress("TANIIN_ITEMS_CONTRACT_ADDRESS");

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const signer = new ethers.NonceManager(wallet);
  const network = await provider.getNetwork();
  if (network.chainId !== SEPOLIA_CHAIN_ID) {
    throw new Error(`RPC bukan Sepolia. Chain ID terdeteksi ${network.chainId}.`);
  }

  return {
    provider,
    wallet,
    signer,
    contracts: {
      coin: new ethers.Contract(coinAddress, coinAbi, signer),
      land: new ethers.Contract(landAddress, landAbi, signer),
      items: new ethers.Contract(itemsAddress, itemsAbi, signer)
    },
    addresses: {
      coin: coinAddress,
      land: landAddress,
      items: itemsAddress
    }
  };
}

function enqueueGameAction(body) {
  const run = actionQueue.then(() => submitGameAction(body), () => submitGameAction(body));
  actionQueue = run.catch(() => undefined);
  return run;
}

async function submitGameAction(body) {
  const service = await getGameService();
  const walletAddress = normalizeAddress(body.wallet, "wallet");
  const type = String(body.type || "").trim().toUpperCase();
  const plotId = toPositiveInt(body.plotId || 0, "plotId", { allowZero: type === "SELL_CROP" || type === "SWAP_CROP" });
  const amount = toPositiveInt(body.amount || 1, "amount");
  const tokenUri = landTokenUri(walletAddress, plotId);
  const txHashes = [];
  const { coin, land, items } = service.contracts;

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
    case "SELL_CROP":
    case "SWAP_CROP": {
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

async function health() {
  const service = await getGameService();
  return {
    ok: true,
    chainId: Number(SEPOLIA_CHAIN_ID),
    signer: service.wallet.address,
    contracts: service.addresses
  };
}

async function sendTransaction(label, txPromise) {
  const tx = await txPromise;
  console.log(`[game-api] ${label}: ${tx.hash}`);
  return tx.hash;
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

module.exports = {
  enqueueGameAction,
  getGameService,
  health,
  httpError,
  normalizeError,
  submitGameAction
};
