const { expect } = require("chai");

const {
  assertPhase0ActionEnabled
} = require("../lib/game-action-service.cjs");

describe("Phase 0 economy policy", function () {
  const disabledActions = [
    "BUY_LAND",
    "SELL_LAND",
    "PLANT",
    "HARVEST",
    "BUY_SEED",
    "SWAP_CROP",
    "SWAP_COIN",
    "SWAP_ETH_COIN",
    "SWAP_COIN_ETH"
  ];

  for (const action of disabledActions) {
    it(`fails closed for ${action}`, function () {
      expect(() => assertPhase0ActionEnabled(action))
        .to.throw(`Aksi ${action} dinonaktifkan selama pengamanan ekonomi Phase 0.`)
        .with.property("statusCode", 503);
    });
  }

  it("allows only burn-only actions", function () {
    expect(() => assertPhase0ActionEnabled("SELL_CROP")).not.to.throw();
    expect(() => assertPhase0ActionEnabled("SWAP_TANI_COIN")).not.to.throw();
  });

  it("cannot be bypassed with the legacy unsafe flag", function () {
    process.env.TANIIN_ENABLE_UNSAFE_ECONOMY = "true";
    expect(() => assertPhase0ActionEnabled("SWAP_COIN"))
      .to.throw("dinonaktifkan selama pengamanan ekonomi Phase 0")
      .with.property("statusCode", 503);
    delete process.env.TANIIN_ENABLE_UNSAFE_ECONOMY;
  });
});
