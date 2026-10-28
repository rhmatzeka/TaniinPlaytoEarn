// Executes the chain operations produced by lib/economy.cjs with the backend
// signer. Callers serialize access (Postgres advisory lock) before calling.
const { ethers } = require("ethers");
const { httpError } = require("./economy.cjs");

const SEPOLIA_CHAIN_ID = 11155111n;
const SEED_ITEM_ID = 1n;
const CROP_ITEM_ID = 2n;
const MIN_ETH_WEI_PER_COIN = 10_000_000_000_000n;
const DEFAULT_ETH_WEI_PER_COIN = "10000000000000";
const DEFAULT_MAX_ETH_PAYOUT_WEI = "100000000000000000";
const DEFAULT_MIN_SIGNER_BALANCE_WEI = "200000000000000000";
const CONFIRM_TIMEOUT_MS = 45_000;

const coinAbi = [
  "function balanceOf(address account) view returns (uint256)",
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
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function mint(address to, uint256 id, uint256 amount) external",
  "function burn(address from, uint256 id, uint256 amount) external"
];

let servicePromise;

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
  const provider = new ethers.JsonRpcProvider(requireEnv("SEPOLIA_RPC_URL"));
  const wallet = new ethers.Wallet(normalizePrivateKey(requireEnv("DEPLOYER_PRIVATE_KEY")), provider);
  const signer = new ethers.NonceManager(wallet);
  const network = await provider.getNetwork();
  if (network.chainId !== SEPOLIA_CHAIN_ID) {
    throw new Error(`RPC bukan Sepolia. Chain ID terdeteksi ${network.chainId}.`);
  }
  const addresses = {
    coin: requireAddress("TANIIN_COIN_CONTRACT_ADDRESS"),
    land: requireAddress("TANIIN_LAND_CONTRACT_ADDRESS"),
    items: requireAddress("TANIIN_ITEMS_CONTRACT_ADDRESS")
  };
  return {
    provider,
    wallet,
    signer,
    addresses,
    contracts: {
      coin: new ethers.Contract(addresses.coin, coinAbi, signer),
      land: new ethers.Contract(addresses.land, landAbi, signer),
      items: new ethers.Contract(addresses.items, itemsAbi, signer)
    }
  };
}

// ops: ChainOp[] from economy.applyAction. extra.db is the open transaction,
// used to mark ETH funding transactions as spent.
async function executeChainOps(walletAddress, ops, extra = {}) {
  const wallet = ethers.getAddress(walletAddress);
  const service = await getGameService();
  // Another serverless instance may have used the signer since our last call.
  service.signer.reset();
  const { coin, land, items } = service.contracts;
  const txHashes = [];
  const send = async (label, createTx, confirm = false) => {
    const hash = confirm
      ? await sendConfirmedTransaction(service, label, createTx)
      : await sendTransaction(service, label, createTx);
    txHashes.push(hash);
    return hash;
  };
  let taniSpent = 0n;

  for (const op of ops) {
    switch (op.kind) {
      case "mintLand": {
        if (await land.playerPlotLandId(wallet, op.plotId) === 0n) {
          await send("mint land", () => land.mintLandFor(wallet, op.plotId, landTokenUri(wallet, op.plotId)));
        }
        break;
      }
      case "sellLand": {
        if (await land.playerPlotLandId(wallet, op.plotId) !== 0n) {
          await send("sell land", () => land.sellLandFor(wallet, op.plotId, landTokenUri(wallet, op.plotId)));
        }
        break;
      }
      case "plant": {
        const landId = await land.playerPlotLandId(wallet, op.plotId);
        if (landId === 0n || !await land.planted(landId)) {
          await send("plant", () => land.plantFor(wallet, op.plotId, landTokenUri(wallet, op.plotId)));
        }
        break;
      }
      case "harvest": {
        const landId = await land.playerPlotLandId(wallet, op.plotId);
        if (landId !== 0n && await land.planted(landId)) {
          await send("harvest", () => land.harvestFor(wallet, op.plotId, landTokenUri(wallet, op.plotId)), true);
        }
        break;
      }
      case "mintCrop":
        await send("mint crop", () => items.mint(wallet, CROP_ITEM_ID, BigInt(op.amount)));
        break;
      case "burnCrop": {
        // Imported guest crops never existed on-chain; burn only what the wallet holds.
        const held = await items.balanceOf(wallet, CROP_ITEM_ID);
        const amount = held < BigInt(op.amount) ? held : BigInt(op.amount);
        if (amount > 0n) await send("burn crop", () => items.burn(wallet, CROP_ITEM_ID, amount));
        break;
      }
      case "mintSeed":
        try {
          await send("mint seed", () => items.mint(wallet, SEED_ITEM_ID, BigInt(op.amount)), true);
        } catch (error) {
          if (taniSpent > 0n) {
            await sendConfirmedTransaction(service, "seed refund", () => coin.mint(wallet, taniSpent));
          }
          throw httpError(502, "Mint benih gagal. Pembayaran TANI sudah dikembalikan.");
        }
        break;
      case "spendTani": {
        const amount = toTani(op.amount);
        if (await coin.balanceOf(wallet) < amount) {
          throw httpError(409, "TANI Sepolia belum cukup. Swap Game Coin ke TANI dulu.");
        }
        await send("spend TANI", () => coin.gameSpend(wallet, amount), true);
        taniSpent += amount;
        break;
      }
      case "mintTani":
        await send("mint TANI", () => coin.mint(wallet, toTani(op.amount)));
        break;
      case "verifyFunding":
        await verifyEthFunding(service, wallet, op, extra.db);
        txHashes.push(op.txHash);
        break;
      case "payEth": {
        const payoutWei = ethWeiForCoins(op.coins);
        if (wallet.toLowerCase() === service.wallet.address.toLowerCase()) {
          throw httpError(400, "Wallet penerima sama dengan signer backend.");
        }
        await ensureSignerCanPay(service, payoutWei);
        await send("ETH payout", () => service.signer.sendTransaction({ to: wallet, value: payoutWei }));
        break;
      }
      default:
        throw httpError(500, `Operasi chain tidak dikenal: ${op.kind}`);
    }
  }

  return { txHash: txHashes[txHashes.length - 1] || "", txHashes };
}

async function health() {
  const service = await getGameService();
  const signerBalanceWei = await service.provider.getBalance(service.wallet.address);
  const { weiPerCoin, maxPayoutWei } = ethSwapConfig();
  return {
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

function ethWeiForCoins(coins) {
  const { weiPerCoin, maxPayoutWei } = ethSwapConfig();
  const payoutWei = BigInt(coins) * weiPerCoin;
  if (payoutWei <= 0n) throw httpError(400, "Nominal swap ETH tidak valid.");
  if (payoutWei > maxPayoutWei) throw httpError(400, "Nominal swap ETH melebihi batas payout sekali swap.");
  return payoutWei;
}

function ethSwapConfig() {
  const weiPerCoin = envBigInt("TANIIN_ETH_WEI_PER_COIN", DEFAULT_ETH_WEI_PER_COIN);
  return {
    weiPerCoin: weiPerCoin < MIN_ETH_WEI_PER_COIN ? MIN_ETH_WEI_PER_COIN : weiPerCoin,
    maxPayoutWei: envBigInt("TANIIN_MAX_ETH_PAYOUT_WEI", DEFAULT_MAX_ETH_PAYOUT_WEI)
  };
}

async function ensureSignerCanPay(service, payoutWei) {
  const balanceWei = await service.provider.getBalance(service.wallet.address);
  const reserveWei = envBigInt("TANIIN_MIN_SIGNER_BALANCE_WEI", DEFAULT_MIN_SIGNER_BALANCE_WEI);
  if (balanceWei - payoutWei < reserveWei) {
    throw httpError(402, "Hadiah ETH sedang habis, coba nanti.");
  }
}

async function verifyEthFunding(service, wallet, op, db) {
  const hash = op.txHash.toLowerCase();
  const requiredWei = ethWeiForCoins(op.amount);
  const [transaction, receipt] = await Promise.all([
    service.provider.getTransaction(hash),
    service.provider.waitForTransaction(hash, 1, CONFIRM_TIMEOUT_MS)
  ]);
  if (!transaction || !receipt) throw httpError(504, "Pembayaran ETH masih menunggu konfirmasi Sepolia.");
  if (receipt.status !== 1) throw httpError(409, "Pembayaran ETH gagal di Sepolia.");
  if (transaction.from.toLowerCase() !== wallet.toLowerCase()
      || String(transaction.to || "").toLowerCase() !== service.wallet.address.toLowerCase()) {
    throw httpError(400, "Pengirim atau penerima pembayaran ETH tidak cocok.");
  }
  if (transaction.value < requiredWei) {
    throw httpError(402, `Pembayaran ETH kurang. Butuh minimal ${ethers.formatEther(requiredWei)} ETH.`);
  }
  if (db) {
    const { rows } = await db.query(
      "INSERT INTO funding_txs (tx_hash, wallet) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING tx_hash",
      [hash, wallet]
    );
    if (!rows.length) throw httpError(409, "Transaksi pembayaran ETH sudah pernah dipakai.");
  }
}

async function sendTransaction(service, label, createTx) {
  let tx;
  try {
    tx = await createTx();
  } catch (error) {
    if (!normalizeError(error).toLowerCase().includes("replacement fee too low")) throw error;
    service.signer.reset();
    await new Promise((resolve) => setTimeout(resolve, 1500));
    tx = await createTx();
  }
  console.log(`[game-api] ${label}: ${tx.hash}`);
  return tx.hash;
}

async function sendConfirmedTransaction(service, label, createTx) {
  const txHash = await sendTransaction(service, label, createTx);
  const receipt = await service.provider.waitForTransaction(txHash, 1, CONFIRM_TIMEOUT_MS);
  if (!receipt) throw httpError(504, `${label} belum terkonfirmasi Sepolia. Coba lagi sebentar.`);
  if (receipt.status !== 1) throw httpError(409, `${label} gagal on-chain.`);
  return txHash;
}

function landTokenUri(walletAddress, plotId) {
  return `ipfs://taniin/land/${walletAddress.toLowerCase()}/${plotId}.json`;
}

function toTani(amount) {
  return ethers.parseUnits(String(amount), 18);
}

function envBigInt(name, fallback) {
  const raw = String(process.env[name] || fallback).trim();
  if (!/^\d+$/.test(raw)) throw new Error(`${name} harus berupa bilangan wei.`);
  return BigInt(raw);
}

function requireAddress(name) {
  const value = requireEnv(name);
  if (!ethers.isAddress(value)) throw new Error(`${name} tidak valid.`);
  return ethers.getAddress(value);
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) throw new Error(`${name} belum diset.`);
  return value.trim();
}

function normalizePrivateKey(value) {
  const key = value.startsWith("0x") ? value : `0x${value}`;
  if (!/^0x[0-9a-fA-F]{64}$/.test(key)) throw new Error("DEPLOYER_PRIVATE_KEY tidak valid.");
  return key;
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
  ethWeiForCoins,
  executeChainOps,
  health,
  normalizeError
};
