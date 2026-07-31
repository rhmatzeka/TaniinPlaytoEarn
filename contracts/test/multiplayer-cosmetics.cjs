const { expect } = require("chai");

const { normalizeSkin } = require("../lib/multiplayer-service.cjs");

describe("Multiplayer cosmetics", function () {
  it("accepts catalog skin IDs", function () {
    expect(normalizeSkin("farmer_classic")).to.equal("farmer_classic");
    expect(normalizeSkin("farmer_nusantara")).to.equal("farmer_nusantara");
    expect(normalizeSkin("forest_keeper")).to.equal("forest_keeper");
  });

  it("falls back for unknown or unsafe skin IDs", function () {
    expect(normalizeSkin("legendary_admin_skin")).to.equal("farmer_classic");
    expect(normalizeSkin("<script>alert(1)</script>")).to.equal("farmer_classic");
    expect(normalizeSkin(null)).to.equal("farmer_classic");
  });
});
