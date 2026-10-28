const { expect } = require("chai");
const {
  CATALOG,
  applyAction,
  importGuestState,
  newPlayerState,
  publicState
} = require("../lib/economy.cjs");

const NOW = Date.UTC(2026, 9, 28, 3, 0, 0);

function expectHttpError(fn, statusCode, pattern) {
  let caught;
  try {
    fn();
  } catch (error) {
    caught = error;
  }
  expect(caught, "expected an error").to.exist;
  expect(caught.statusCode).to.equal(statusCode);
  if (pattern) expect(caught.message).to.match(pattern);
}

function withCoins(coins) {
  const state = newPlayerState(NOW);
  state.coins = coins;
  return state;
}

describe("Server economy rules", function () {
  it("starts players with the same defaults as the Flutter guest", function () {
    const state = newPlayerState(NOW);
    expect(state.coins).to.equal(620);
    expect(state.seeds).to.deep.equal([6, 0, 0, 0]);
    expect(state.crops).to.deep.equal([0, 0, 0, 0]);
    expect(state.plots.map((plot) => plot.owned)).to.deep.equal([true, false, false, false, false]);
  });

  it("rejects buying land without enough coins", function () {
    expectHttpError(
      () => applyAction(withCoins(620), { type: "BUY_LAND", plotId: 2 }, NOW),
      409,
      /Coin belum cukup/
    );
  });

  it("buys land for 1000 coins and mints the land NFT", function () {
    const result = applyAction(withCoins(1000), { type: "BUY_LAND", plotId: 2 }, NOW);
    expect(result.state.coins).to.equal(0);
    expect(result.state.plots[1].owned).to.equal(true);
    expect(result.chainOps).to.deep.equal([{ kind: "mintLand", plotId: 2 }]);
  });

  it("rejects planting without seeds", function () {
    const state = newPlayerState(NOW);
    expectHttpError(
      () => applyAction(state, { type: "PLANT", plotId: 1, seedIndex: 1 }, NOW),
      409,
      /Benih Bawang habis/
    );
  });

  it("plants a seed and counts the daily quest", function () {
    const result = applyAction(newPlayerState(NOW), { type: "PLANT", plotId: 1, seedIndex: 0 }, NOW);
    expect(result.state.seeds[0]).to.equal(5);
    expect(result.state.plots[0].plantedAtMs).to.equal(NOW);
    expect(result.state.plots[0].seedIndex).to.equal(0);
    expect(result.state.quests.progress.plant).to.equal(1);
    expect(result.chainOps).to.deep.equal([{ kind: "plant", plotId: 1 }]);
  });

  it("rejects harvest one millisecond before the server grow time", function () {
    const planted = applyAction(newPlayerState(NOW), { type: "PLANT", plotId: 1, seedIndex: 0 }, NOW).state;
    expectHttpError(
      () => applyAction(planted, { type: "HARVEST", plotId: 1 }, NOW + CATALOG.growMs - 1),
      409,
      /belum siap/
    );
  });

  it("harvests the seed yield once the grow time has passed", function () {
    const planted = applyAction(newPlayerState(NOW), { type: "PLANT", plotId: 1, seedIndex: 0 }, NOW).state;
    const result = applyAction(planted, { type: "HARVEST", plotId: 1 }, NOW + CATALOG.growMs);
    expect(result.state.crops[0]).to.equal(3);
    expect(result.state.plots[0].plantedAtMs).to.equal(null);
    expect(result.chainOps).to.deep.equal([
      { kind: "harvest", plotId: 1 },
      { kind: "mintCrop", amount: 3 }
    ]);
  });

  it("sells the whole crop stack for 50 coins each and burns the crop items", function () {
    const state = newPlayerState(NOW);
    state.crops[2] = 4;
    const result = applyAction(state, { type: "SELL_CROP", cropIndex: 2 }, NOW);
    expect(result.state.crops[2]).to.equal(0);
    expect(result.state.coins).to.equal(620 + 200);
    expect(result.chainOps).to.deep.equal([{ kind: "burnCrop", amount: 4 }]);
  });

  it("refuses to sell the last owned plot", function () {
    expectHttpError(
      () => applyAction(newPlayerState(NOW), { type: "SELL_LAND", plotId: 1 }, NOW),
      409
    );
  });

  it("charges Game Coin for a seed bundle using the catalog price, not the client amount", function () {
    const result = applyAction(
      newPlayerState(NOW),
      { type: "BUY_SEED", seedIndex: 2, quantity: 2, amount: 1 },
      NOW
    );
    expect(result.state.seeds[2]).to.equal(6);
    expect(result.state.coins).to.equal(620 - 440);
    expect(result.chainOps).to.deep.equal([{ kind: "mintSeed", amount: 6 }]);
  });

  it("refuses a seed bundle the player cannot afford", function () {
    expectHttpError(
      () => applyAction(withCoins(100), { type: "BUY_SEED", seedIndex: 2, quantity: 1 }, NOW),
      409,
      /Koin belum cukup/
    );
  });

  it("swaps game coins to TANI and caps the swap amount", function () {
    const result = applyAction(withCoins(5000), { type: "SWAP_COIN", amount: 300 }, NOW);
    expect(result.state.coins).to.equal(4700);
    expect(result.chainOps).to.deep.equal([{ kind: "mintTani", amount: 300 }]);
    expectHttpError(
      () => applyAction(withCoins(50000), { type: "SWAP_COIN", amount: 10001 }, NOW),
      400
    );
  });

  it("caps imported guest progress", function () {
    const state = importGuestState({
      coins: 99999,
      playerXp: 5000,
      seedQuantities: [999, 2, 0, 1],
      cropQuantities: [0, 50, 0, 0],
      plots: Array.from({ length: 9 }, () => ({ owned: true, status: "growing", plantedAt: NOW }))
    }, NOW);
    expect(state.coins).to.equal(500);
    expect(state.xp).to.equal(400);
    expect(state.seeds).to.deep.equal([30, 2, 0, 1]);
    expect(state.crops[1]).to.equal(30);
    expect(state.plots).to.have.length(5);
    expect(state.plots.every((plot) => plot.plantedAtMs === null)).to.equal(true);
  });

  it("refuses to sell plots that came from a guest import", function () {
    const state = importGuestState({ plots: [{ owned: true }, { owned: true }, { owned: true }] }, NOW);
    expect(state.plots[1].owned).to.equal(true);
    expectHttpError(
      () => applyAction(state, { type: "SELL_LAND", plotId: 2 }, NOW),
      409,
      /mode tamu/
    );
  });

  it("unlocks the level 2 skin and achievement when XP reaches 100", function () {
    const state = newPlayerState(NOW);
    state.xp = 90;
    state.crops[0] = 1;
    state.quests.progress.sell = 0;
    const result = applyAction(state, { type: "SELL_CROP", cropIndex: 0 }, NOW);
    expect(result.state.xp).to.equal(120);
    expect(result.state.ownedCosmeticIds).to.include("farmer_nusantara");
    expect(result.state.achievements).to.include("Petani Berkembang");
  });

  it("resets daily quests on a new Jakarta day", function () {
    const state = newPlayerState(NOW);
    state.quests.progress.plant = 3;
    const nextDay = NOW + 24 * 60 * 60 * 1000;
    const result = applyAction(state, { type: "PLANT", plotId: 1, seedIndex: 0 }, nextDay);
    expect(result.state.quests.progress.plant).to.equal(1);
  });

  it("exposes state with the Flutter save keys", function () {
    const json = publicState(newPlayerState(NOW));
    expect(json).to.include.keys(
      "coins", "playerXp", "seedQuantities", "cropQuantities", "plots",
      "dailyQuests", "ownedCosmeticIds", "unlockedAchievements", "ownedLand"
    );
    expect(json.plots[0]).to.deep.equal({ owned: true, seedIndex: 0, status: "empty", plantedAt: null });
  });
});
