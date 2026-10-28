// Server-side source of truth for Taniin's game economy. Pure functions only:
// no I/O, so the same rules run in tests, on Vercel and in the local game API.

const CATALOG = Object.freeze({
  growMs: 12_000,
  landBuyPrice: 1000,
  landSellPrice: 750,
  cropSellPrice: 50,
  seedBundleAmount: 3,
  maxSeedBundles: 9,
  seedNames: ["Kentang", "Bawang", "Stroberi", "Bit"],
  // Game Coin per bundle of 3 seeds.
  seedBundlePrices: [100, 140, 220, 180],
  harvestYields: [3, 4, 5, 4],
  startingSeeds: [6, 0, 0, 0],
  startingCoins: 620,
  plotCount: 5,
  maxSwapAmount: 10_000,
  minEthSwapAmount: 100,
  xpPerLevel: 100,
  quests: [
    { id: "plant", target: 3, xpReward: 30 },
    { id: "harvest", target: 2, xpReward: 40 },
    { id: "sell", target: 1, xpReward: 30 }
  ],
  cosmetics: [
    { id: "farmer_classic", unlockLevel: 1 },
    { id: "farmer_nusantara", unlockLevel: 2 },
    { id: "forest_keeper", unlockLevel: 4 }
  ]
});

// Limits for the one-time guest progress import (owner decision: carry over, capped).
const GUEST_IMPORT_LIMITS = Object.freeze({
  coins: 500,
  stackPerType: 30,
  xp: 400
});

const JAKARTA_OFFSET_MS = 7 * 60 * 60 * 1000;

function jakartaDay(nowMs) {
  return new Date(nowMs + JAKARTA_OFFSET_MS).toISOString().slice(0, 10);
}

function emptyQuests(nowMs) {
  return {
    day: jakartaDay(nowMs),
    progress: Object.fromEntries(CATALOG.quests.map((quest) => [quest.id, 0]))
  };
}

function newPlayerState(nowMs) {
  const state = {
    version: 1,
    coins: CATALOG.startingCoins,
    xp: 0,
    seeds: [...CATALOG.startingSeeds],
    crops: CATALOG.seedNames.map(() => 0),
    plots: Array.from({ length: CATALOG.plotCount }, (_, index) => ({
      owned: index === 0,
      seedIndex: 0,
      plantedAtMs: null
    })),
    quests: emptyQuests(nowMs),
    ownedCosmeticIds: ["farmer_classic"],
    achievements: [],
    actionCount: 0
  };
  unlockRewards(state);
  return state;
}

function level(xp) {
  return 1 + Math.floor(xp / CATALOG.xpPerLevel);
}

function ownedPlotCount(state) {
  return state.plots.filter((plot) => plot.owned).length;
}

function unlockRewards(state) {
  const playerLevel = level(state.xp);
  for (const item of CATALOG.cosmetics) {
    if (playerLevel >= item.unlockLevel && !state.ownedCosmeticIds.includes(item.id)) {
      state.ownedCosmeticIds.push(item.id);
    }
  }
  const earned = [
    [state.xp >= 30, "Langkah Pertama"],
    [playerLevel >= 2, "Petani Berkembang"],
    [ownedPlotCount(state) >= 5, "Juragan Lahan"]
  ];
  for (const [ok, name] of earned) {
    if (ok && !state.achievements.includes(name)) state.achievements.push(name);
  }
}

function recordQuest(state, questId) {
  const quest = CATALOG.quests.find((item) => item.id === questId);
  const current = state.quests.progress[questId] || 0;
  if (!quest || current >= quest.target) return;
  state.quests.progress[questId] = current + 1;
  if (current + 1 >= quest.target) state.xp += quest.xpReward;
}

function applyAction(previous, action, nowMs) {
  const state = structuredClone(previous);
  if (state.quests.day !== jakartaDay(nowMs)) state.quests = emptyQuests(nowMs);
  const type = String(action?.type || "").trim().toUpperCase();
  let chainOps;
  let summary;

  switch (type) {
    case "BUY_LAND": {
      const plot = plotAt(state, action.plotId);
      if (plot.owned) throw httpError(409, `Lahan #${action.plotId} sudah kamu miliki.`);
      if (state.coins < CATALOG.landBuyPrice) throw httpError(409, "Coin belum cukup untuk beli tanah.");
      state.coins -= CATALOG.landBuyPrice;
      plot.owned = true;
      chainOps = [{ kind: "mintLand", plotId: action.plotId }];
      summary = `-${CATALOG.landBuyPrice} coin`;
      break;
    }
    case "SELL_LAND": {
      const plot = plotAt(state, action.plotId);
      if (!plot.owned || plot.plantedAtMs !== null || ownedPlotCount(state) <= 1) {
        throw httpError(409, "Lahan terakhir atau lahan berisi tanaman tidak bisa dijual.");
      }
      if (plot.fromGuest) {
        // Guest saves are unverified, so imported plots must never turn into coins.
        throw httpError(409, "Lahan bawaan dari mode tamu tidak bisa dijual.");
      }
      plot.owned = false;
      plot.seedIndex = 0;
      state.coins += CATALOG.landSellPrice;
      chainOps = [{ kind: "sellLand", plotId: action.plotId }];
      summary = `+${CATALOG.landSellPrice} coin`;
      break;
    }
    case "PLANT": {
      const plot = plotAt(state, action.plotId);
      const seedIndex = indexOf(action.seedIndex, CATALOG.seedNames.length, "seedIndex");
      if (!plot.owned) throw httpError(409, "Beli lahan ini dulu sebelum menanam.");
      if (plot.plantedAtMs !== null) throw httpError(409, "Lahan ini sudah ditanami.");
      if (state.seeds[seedIndex] <= 0) {
        throw httpError(409, `Benih ${CATALOG.seedNames[seedIndex]} habis. Buka toko dulu.`);
      }
      state.seeds[seedIndex] -= 1;
      plot.seedIndex = seedIndex;
      plot.plantedAtMs = nowMs;
      recordQuest(state, "plant");
      chainOps = [{ kind: "plant", plotId: action.plotId }];
      summary = `tanam ${CATALOG.seedNames[seedIndex]}`;
      break;
    }
    case "HARVEST": {
      const plot = plotAt(state, action.plotId);
      if (plot.plantedAtMs === null) throw httpError(409, "Belum ada tanaman di lahan ini.");
      if (nowMs - plot.plantedAtMs < CATALOG.growMs) throw httpError(409, "Tanaman belum siap panen.");
      const amount = CATALOG.harvestYields[plot.seedIndex];
      state.crops[plot.seedIndex] += amount;
      plot.plantedAtMs = null;
      recordQuest(state, "harvest");
      chainOps = [{ kind: "harvest", plotId: action.plotId }, { kind: "mintCrop", amount }];
      summary = `+${amount} panen`;
      break;
    }
    case "BUY_SEED": {
      const seedIndex = indexOf(action.seedIndex, CATALOG.seedNames.length, "seedIndex");
      const bundles = boundedInt(action.quantity ?? 1, 1, CATALOG.maxSeedBundles, "quantity");
      const price = CATALOG.seedBundlePrices[seedIndex] * bundles;
      const total = CATALOG.seedBundleAmount * bundles;
      if (state.coins < price) throw httpError(409, `Koin belum cukup. Butuh ${price} koin.`);
      state.coins -= price;
      state.seeds[seedIndex] += total;
      chainOps = [{ kind: "mintSeed", amount: total }];
      summary = `-${price} koin`;
      break;
    }
    case "SELL_CROP": {
      const cropIndex = indexOf(action.cropIndex, CATALOG.seedNames.length, "cropIndex");
      const sold = state.crops[cropIndex];
      if (sold <= 0) throw httpError(409, "Belum ada hasil panen untuk dijual.");
      state.crops[cropIndex] = 0;
      state.coins += sold * CATALOG.cropSellPrice;
      recordQuest(state, "sell");
      chainOps = [{ kind: "burnCrop", amount: sold }];
      summary = `+${sold * CATALOG.cropSellPrice} coin`;
      break;
    }
    case "SWAP_COIN": {
      const amount = swapAmount(action.amount, 1);
      spendCoins(state, amount);
      chainOps = [{ kind: "mintTani", amount }];
      summary = `-${amount} coin`;
      break;
    }
    case "SWAP_TANI_COIN": {
      const amount = swapAmount(action.amount, 1);
      state.coins += amount;
      chainOps = [{ kind: "spendTani", amount }];
      summary = `+${amount} coin`;
      break;
    }
    case "SWAP_ETH_COIN": {
      const amount = swapAmount(action.amount, CATALOG.minEthSwapAmount);
      const txHash = String(action.paymentTxHash || "").trim();
      if (!/^0x[0-9a-fA-F]{64}$/.test(txHash)) throw httpError(400, "paymentTxHash tidak valid.");
      state.coins += amount;
      chainOps = [{ kind: "verifyFunding", txHash, amount }];
      summary = `+${amount} coin`;
      break;
    }
    case "SWAP_COIN_ETH": {
      const amount = swapAmount(action.amount, CATALOG.minEthSwapAmount);
      spendCoins(state, amount);
      chainOps = [{ kind: "payEth", coins: amount }];
      summary = `-${amount} coin`;
      break;
    }
    default:
      throw httpError(400, `Tipe aksi tidak dikenal: ${type || "kosong"}.`);
  }

  state.actionCount = (state.actionCount || 0) + 1;
  unlockRewards(state);
  return { state, chainOps, summary };
}

function importGuestState(raw, nowMs) {
  const state = newPlayerState(nowMs);
  const source = raw && typeof raw === "object" ? raw : {};
  state.coins = clampInt(source.coins, 0, GUEST_IMPORT_LIMITS.coins, state.coins);
  state.xp = clampInt(source.playerXp, 0, GUEST_IMPORT_LIMITS.xp, 0);
  state.seeds = state.seeds.map((fallback, index) =>
    clampInt(source.seedQuantities?.[index], 0, GUEST_IMPORT_LIMITS.stackPerType, fallback));
  state.crops = state.crops.map((_, index) =>
    clampInt(source.cropQuantities?.[index], 0, GUEST_IMPORT_LIMITS.stackPerType, 0));
  const guestPlots = Array.isArray(source.plots) ? source.plots.slice(0, CATALOG.plotCount) : [];
  state.plots = state.plots.map((plot, index) => {
    const imported = index > 0 && guestPlots[index]?.owned === true;
    return {
      owned: index === 0 || imported,
      seedIndex: 0,
      plantedAtMs: null,
      ...(imported ? { fromGuest: true } : {})
    };
  });
  unlockRewards(state);
  return state;
}

function publicState(state) {
  return {
    coins: state.coins,
    playerXp: state.xp,
    seedQuantities: [...state.seeds],
    cropQuantities: [...state.crops],
    plots: state.plots.map((plot) => ({
      owned: plot.owned,
      seedIndex: plot.seedIndex,
      status: plot.plantedAtMs === null ? "empty" : "growing",
      plantedAt: plot.plantedAtMs
    })),
    dailyQuests: CATALOG.quests.map((quest) => ({ id: quest.id, progress: state.quests.progress[quest.id] || 0 })),
    questDay: state.quests.day,
    ownedCosmeticIds: [...state.ownedCosmeticIds],
    unlockedAchievements: [...state.achievements],
    ownedLand: ownedPlotCount(state)
  };
}

function plotAt(state, plotId) {
  const index = boundedInt(plotId, 1, CATALOG.plotCount, "plotId") - 1;
  return state.plots[index];
}

function indexOf(value, length, name) {
  return boundedInt(value, 0, length - 1, name);
}

function swapAmount(value, minimum) {
  const amount = boundedInt(value, 1, CATALOG.maxSwapAmount, "amount");
  if (amount < minimum) throw httpError(400, `Jumlah minimal ${minimum} coin.`);
  return amount;
}

function spendCoins(state, amount) {
  if (state.coins < amount) throw httpError(409, "Game Coin belum cukup.");
  state.coins -= amount;
}

function boundedInt(value, minimum, maximum, name) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < minimum || number > maximum) {
    throw httpError(400, `${name} harus bilangan bulat ${minimum}-${maximum}.`);
  }
  return number;
}

function clampInt(value, minimum, maximum, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.trunc(number)));
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

module.exports = {
  CATALOG,
  GUEST_IMPORT_LIMITS,
  applyAction,
  httpError,
  importGuestState,
  jakartaDay,
  newPlayerState,
  publicState
};
