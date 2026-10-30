const { expect } = require("chai");
const { HOTSPOTS, aiPath } = require("../lib/multiplayer-service.cjs");

const TILE = 128;
// Seed shop house and its fenced yard, in world pixels.
const SHOP = { left: 15 * TILE, right: 21.7 * TILE, top: 18 * TILE, bottom: 25.6 * TILE };

function crossesShop(a, b) {
  for (let i = 0; i <= 20; i++) {
    const x = a.x + ((b.x - a.x) * i) / 20;
    const y = a.y + ((b.y - a.y) * i) / 20;
    if (x > SHOP.left && x < SHOP.right && y > SHOP.top && y < SHOP.bottom) return true;
  }
  return false;
}

describe("Pak Tani AI routing", function () {
  const spawn = { x: 18.18 * TILE, y: 26.85 * TILE };
  const spots = { ...HOTSPOTS, plot3: HOTSPOTS.plots[2], plot5: HOTSPOTS.plots[4] };

  it("uses the game's tile coordinates for every hotspot", function () {
    for (const spot of [HOTSPOTS.shop, HOTSPOTS.sell, HOTSPOTS.swap, ...HOTSPOTS.plots]) {
      expect(spot.x).to.be.within(4 * TILE, 40 * TILE);
      expect(spot.y).to.be.within(8 * TILE, 30 * TILE);
    }
  });

  it("ends exactly on the target", function () {
    expect(aiPath(spawn, HOTSPOTS.sell).at(-1)).to.deep.equal(HOTSPOTS.sell);
  });

  for (const [fromName, toName] of [
    ["shop", "sell"],
    ["sell", "swap"],
    ["swap", "plot3"],
    ["plot5", "sell"],
    ["shop", "swap"],
  ]) {
    it(`walks the roads from ${fromName} to ${toName} without crossing the shop`, function () {
      const start = spots[fromName];
      const path = aiPath(start, spots[toName]);
      let previous = start;
      for (const [i, point] of path.entries()) {
        const middle = i > 0 && i < path.length - 1;
        if (middle) {
          const straight = Math.abs(point.x - previous.x) < 1 || Math.abs(point.y - previous.y) < 1;
          expect(straight, JSON.stringify({ previous, point })).to.equal(true);
        }
        expect(crossesShop(previous, point), JSON.stringify({ previous, point })).to.equal(false);
        previous = point;
      }
    });
  }
});
