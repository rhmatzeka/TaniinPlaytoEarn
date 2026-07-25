const { ethers } = require("ethers");

const SEPOLIA_CHAIN_ID = 11155111n;
const SEED_ITEM_ID = 1n;
const CROP_ITEM_ID = 2n;
const LAND_SELL_REWARD = 750;
const CROP_REWARD = 50;
const COIN_SWAP_RATE = 1;
const MIN_ETH_WEI_PER_COIN = 10_000_000_000_000n;
const MIN_ETH_SWAP_COIN = 100n;
const DEFAULT_ETH_WEI_PER_COIN = "10000000000000";
const DEFAULT_MAX_ETH_PAYOUT_WEI = "100000000000000000";
const DEFAULT_MAX_GAME_COIN_SWAP = "10000";
const SEED_BUNDLE_AMOUNT = 3n;
const SEED_BUNDLE_PRICES = [100n, 140n, 220n, 180n];

const coinAbi = [
  "function mint(address to, uint256 amount) external",
  "function gameSpend(address from, uint256 amount) external"
];

const landAbi = [
  "function playerPlotLandId(address player, uint256 plotId) view returns (uint256)",
  "function planted(uint256 landId) view returns (bool)",
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
const usedFundingTransactions = new Set();

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
  const walletAddress = normalizeAddress(body.wallet, "wallet");
  const type = String(body.type || "").trim().toUpperCase();
  assertPhase0ActionEnabled(type);
  const service = await getGameService();
  const plotId = toPositiveInt(body.plotId || 0, "plotId", {
    allowZero: type === "SELL_CROP"
      || type === "SWAP_CROP"
      || type === "SWAP_COIN"
      || type === "SWAP_TANI_COIN"
      || type === "SWAP_COIN_ETH"
      || type === "SWAP_ETH_COIN"
  });
  const amount = toPositiveInt(body.amount || 1, "amount");
  const tokenUri = landTokenUri(walletAddress, plotId);
  const txHashes = [];
  let primaryTxHash = "";
  let ethPayoutAmountWei = 0n;
  const { coin, land, items } = service.contracts;

  switch (type) {
    case "BUY_LAND": {
      const existingLandId = await land.playerPlotLandId(walletAddress, plotId);
      if (existingLandId !== 0n) {
        throw httpError(409, `Lahan #${plotId} sudah minted on-chain untuk wallet ini.`);
      }
      txHashes.push(await sendTransaction("mint land", () => land.mintLandFor(walletAddress, plotId, tokenUri)));
      break;
    }
    case "SELL_LAND": {
      txHashes.push(await sendTransaction("sell land", () => land.sellLandFor(walletAddress, plotId, tokenUri)));
      txHashes.push(await sendTransaction("land sell reward", () => coin.mint(walletAddress, toTani(LAND_SELL_REWARD))));
      break;
    }
    case "PLANT": {
      const existingLandId = await land.playerPlotLandId(walletAddress, plotId);
      if (existingLandId !== 0n && await land.planted(existingLandId)) {
        throw httpError(409, `Lahan #${plotId} sudah ditanami on-chain. Panen dulu atau pilih lahan kosong.`);
      }
      txHashes.push(await sendTransaction("plant", () => land.plantFor(walletAddress, plotId, tokenUri)));
      break;
    }
    case "HARVEST": {
      txHashes.push(await sendConfirmedTransaction("harvest", () => land.harvestFor(walletAddress, plotId, tokenUri)));
      primaryTxHash = await sendTransaction("mint crop", () => items.mint(walletAddress, CROP_ITEM_ID, 3n));
      txHashes.push(primaryTxHash);
      break;
    }
    case "BUY_SEED": {
      const seedCost = seedPurchaseCost(plotId, amount);
      txHashes.push(await sendConfirmedTransaction(
        "seed payment burn",
        () => coin.gameSpend(walletAddress, toTani(seedCost))
      ));
      try {
        primaryTxHash = await sendConfirmedTransaction(
          "mint seed",
          () => items.mint(walletAddress, SEED_ITEM_ID, BigInt(amount))
        );
        txHashes.push(primaryTxHash);
      } catch (error) {
        await sendConfirmedTransaction(
          "seed payment compensation",
          () => coin.mint(walletAddress, toTani(seedCost))
        );
        throw httpError(502, "Mint benih gagal. Pembayaran TANI sudah dikembalikan.");
      }
      break;
    }
    case "SELL_CROP": {
      ensureGameCoinSwapWithinLimit(BigInt(amount) * BigInt(CROP_REWARD));
      primaryTxHash = await sendTransaction("sell crop burn", () => items.burn(walletAddress, CROP_ITEM_ID, BigInt(amount)));
      txHashes.push(primaryTxHash);
      break;
    }
    case "SWAP_CROP": {
      txHashes.push(await sendTransaction("crop reward", () => coin.mint(walletAddress, toTani(BigInt(amount) * BigInt(CROP_REWARD)))));
      break;
    }
    case "SWAP_COIN": {
      ensureGameCoinSwapWithinLimit(amount);
      txHashes.push(await sendTransaction("coin swap", () => coin.mint(walletAddress, toTani(BigInt(amount) * BigInt(COIN_SWAP_RATE)))));
      break;
    }
    case "SWAP_TANI_COIN": {
      ensureGameCoinSwapWithinLimit(amount);
      txHashes.push(await sendTransaction("TANI deposit burn", () => coin.gameSpend(walletAddress, toTani(BigInt(amount) * BigInt(COIN_SWAP_RATE)))));
      break;
    }
    case "SWAP_ETH_COIN": {
      ensureGameCoinSwapWithinLimit(amount);
      ensureEthSwapMinimum(amount);
      await verifyEthFundingTransaction(service, walletAddress, amount, body.paymentTxHash);
      txHashes.push(await sendTransaction("ETH funding receipt", () => coin.mint(walletAddress, toTani(BigInt(amount) * BigInt(COIN_SWAP_RATE)))));
      break;
    }
    case "SWAP_COIN_ETH": {
      ensureEthSwapMinimum(amount);
      const payoutWei = ethPayoutWei(amount);
      ethPayoutAmountWei = payoutWei;
      ensureRecipientIsNotSigner(service, walletAddress);
      await ensureSignerCanPayEth(service, payoutWei);
      txHashes.push(await sendConfirmedTransaction("TANI swap burn", () => coin.gameSpend(walletAddress, toTani(amount))));
      primaryTxHash = await sendTransaction("ETH swap payout", () => service.signer.sendTransaction({
        to: walletAddress,
        value: payoutWei
      }));
      txHashes.push(primaryTxHash);
      break;
    }
    default:
      throw httpError(400, `Tipe aksi tidak dikenal: ${type || "kosong"}.`);
  }

  const txHash = primaryTxHash || txHashes[0] || "";
  return {
    ok: true,
    type,
    wallet: walletAddress,
    txHash,
    txHashes,
    ethPayoutWei: ethPayoutAmountWei > 0n ? ethPayoutAmountWei.toString() : "",
    ethPayoutEth: ethPayoutAmountWei > 0n ? ethers.formatEther(ethPayoutAmountWei) : "",
    etherscanUrl: txHash ? `https://sepolia.etherscan.io/tx/${txHash}` : ""
  };
}

async function health() {
  const service = await getGameService();
  const signerBalanceWei = await service.provider.getBalance(service.wallet.address);
  const { weiPerCoin, maxPayoutWei } = ethSwapConfig();
  return {
    ok: true,
    chainId: Number(SEPOLIA_CHAIN_ID),
    signer: service.wallet.address,
    signerBalanceWei: signerBalanceWei.toString(),
    signerBalanceEth: ethers.formatEther(signerBalanceWei),
    ethWeiPerCoin: weiPerCoin.toString(),
    ethPerCoin: ethers.formatEther(weiPerCoin),
    maxEthPayoutWei: maxPayoutWei.toString(),
    maxEthPayoutEth: ethers.formatEther(maxPayoutWei),
    contracts: service.addresses
  };
}

async function sendTransaction(label, createTx) {
  let tx;
  try {
    tx = await createTx();
  } catch (error) {
    if (!isReplacementFeeTooLow(error)) {
      throw error;
    }
    const service = await getGameService();
    service.signer.reset();
    await delay(1500);
    tx = await createTx();
  }
  console.log(`[game-api] ${label}: ${tx.hash}`);
  return tx.hash;
}

async function sendConfirmedTransaction(label, createTx) {
  const txHash = await sendTransaction(label, createTx);
  const service = await getGameService();
  const receipt = await service.provider.waitForTransaction(txHash, 1, 120_000);
  if (!receipt) {
    throw httpError(504, `${label} belum terkonfirmasi Sepolia. Payout ETH belum dikirim.`);
  }
  if (receipt.status !== 1) {
    throw httpError(409, `${label} gagal on-chain. Payout ETH dibatalkan.`);
  }
  return txHash;
}

function isReplacementFeeTooLow(error) {
  return normalizeError(error).toLowerCase().includes("replacement fee too low");
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function landTokenUri(walletAddress, plotId) {
  return `ipfs://taniin/land/${walletAddress.toLowerCase()}/${plotId}.json`;
}

function toTani(amount) {
  return ethers.parseUnits(String(amount), 18);
}

function ethPayoutWei(amount) {
  const { weiPerCoin, maxPayoutWei } = ethSwapConfig();
  const payoutWei = BigInt(amount) * weiPerCoin;
  if (payoutWei <= 0n) {
    throw httpError(400, "Nominal swap ETH tidak valid.");
  }
  if (payoutWei > maxPayoutWei) {
    throw httpError(400, "Nominal swap ETH melebihi batas payout signer.");
  }
  return payoutWei;
}

function ethSwapConfig() {
  const configuredWeiPerCoin = envBigInt("TANIIN_ETH_WEI_PER_COIN", DEFAULT_ETH_WEI_PER_COIN);
  const configuredMaxPayoutWei = envBigInt("TANIIN_MAX_ETH_PAYOUT_WEI", DEFAULT_MAX_ETH_PAYOUT_WEI);
  return {
    weiPerCoin: configuredWeiPerCoin < MIN_ETH_WEI_PER_COIN ? MIN_ETH_WEI_PER_COIN : configuredWeiPerCoin,
    maxPayoutWei: configuredMaxPayoutWei
  };
}

function ensureGameCoinSwapWithinLimit(amount) {
  const maximum = envBigInt("TANIIN_MAX_GAME_COIN_SWAP", DEFAULT_MAX_GAME_COIN_SWAP);
  const effectiveMaximum = maximum > 10_000n ? 10_000n : maximum;
  if (BigInt(amount) > effectiveMaximum) {
    throw httpError(400, `Swap Game Coin maksimal ${effectiveMaximum} coin per transaksi.`);
  }
}

function ensureEthSwapMinimum(amount) {
  if (BigInt(amount) < MIN_ETH_SWAP_COIN) {
    throw httpError(400, `Deposit dan payout ETH minimal ${MIN_ETH_SWAP_COIN} coin supaya perubahan terlihat di wallet.`);
  }
}

const _phase0EnabledActions = new Set([
  "SELL_CROP",
  "SWAP_TANI_COIN"
]);

function assertPhase0ActionEnabled(type) {
  if (!_phase0EnabledActions.has(type)) {
    throw httpError(
      503,
      `Aksi ${type || "kosong"} dinonaktifkan selama pengamanan ekonomi Phase 0.`
    );
  }
}

function seedPurchaseCost(seedType, amount) {
  const seedIndex = Number(seedType) - 1;
  const seedAmount = BigInt(amount);
  if (seedIndex < 0 || seedIndex >= SEED_BUNDLE_PRICES.length) {
    throw httpError(400, "Jenis benih tidak valid.");
  }
  if (seedAmount % SEED_BUNDLE_AMOUNT !== 0n) {
    throw httpError(400, `Benih hanya dapat dibeli per paket isi ${SEED_BUNDLE_AMOUNT}.`);
  }
  const bundleCount = seedAmount / SEED_BUNDLE_AMOUNT;
  if (bundleCount < 1n || bundleCount > 9n) {
    throw httpError(400, "Jumlah paket benih harus antara 1 dan 9.");
  }
  return SEED_BUNDLE_PRICES[seedIndex] * bundleCount;
}

function ensureRecipientIsNotSigner(service, walletAddress) {
  if (walletAddress.toLowerCase() === service.wallet.address.toLowerCase()) {
    throw httpError(400, "Wallet penerima ETH sama dengan signer backend. Pakai wallet pemain yang berbeda supaya saldo Sepolia bisa bertambah.");
  }
}

async function ensureSignerCanPayEth(service, payoutWei) {
  const [balanceWei, feeData] = await Promise.all([
    service.provider.getBalance(service.wallet.address),
    service.provider.getFeeData()
  ]);
  const gasPriceWei = feeData.maxFeePerGas || feeData.gasPrice || 0n;
  const gasReserveWei = gasPriceWei * 21_000n;
  const requiredWei = payoutWei + gasReserveWei;
  if (balanceWei < requiredWei) {
    throw httpError(402, `Saldo ETH signer backend tidak cukup untuk payout. Isi signer ${service.wallet.address} minimal ${ethers.formatEther(requiredWei)} ETH.`);
  }
}

async function verifyEthFundingTransaction(service, walletAddress, amount, paymentTxHash) {
  const hash = String(paymentTxHash || "").trim().toLowerCase();
  if (!/^0x[0-9a-f]{64}$/.test(hash)) {
    throw httpError(400, "Hash pembayaran ETH tidak valid.");
  }
  if (usedFundingTransactions.has(hash)) {
    throw httpError(409, "Transaksi pembayaran ETH sudah pernah dipakai.");
  }
  const requiredWei = ethPayoutWei(amount);
  const transaction = await service.provider.getTransaction(hash);
  const receipt = await service.provider.waitForTransaction(hash, 1, 120_000);
  if (!transaction || !receipt) {
    throw httpError(504, "Pembayaran ETH masih menunggu konfirmasi Sepolia. Coba Sync Wallet sebentar lagi.");
  }
  if (receipt.status !== 1) {
    throw httpError(409, "Pembayaran ETH gagal di Sepolia.");
  }
  if (transaction.from.toLowerCase() !== walletAddress.toLowerCase()
      || String(transaction.to || "").toLowerCase() !== service.wallet.address.toLowerCase()) {
    throw httpError(400, "Pengirim atau penerima pembayaran ETH tidak cocok.");
  }
  if (transaction.value < requiredWei) {
    throw httpError(402, `Pembayaran ETH kurang. Butuh minimal ${ethers.formatEther(requiredWei)} ETH.`);
  }
  usedFundingTransactions.add(hash);
}

function envBigInt(name, fallback) {
  const raw = String(process.env[name] || fallback).trim();
  if (!/^\d+$/.test(raw)) {
    throw new Error(`${name} harus berupa bilangan wei.`);
  }
  return BigInt(raw);
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
  assertPhase0ActionEnabled,
  getGameService,
  health,
  httpError,
  normalizeError,
  submitGameAction
};
