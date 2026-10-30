const { expect } = require("chai");
const { HOTSPOTS, aiPath } = require("../lib/multiplayer-service.cjs");

const TILE = 128;
const FIELD = { x: 14 * TILE, y: 23 * TILE };
const inField = (p) => p.x < FIELD.x && p.y < FIELD.y;

describe("Pak Tani AI routing", function () {
  it("uses the game's tile coordinates for every hotspot", function () {
    const spots = [HOTSPOTS.shop, HOTSPOTS.sell, HOTSPOTS.swap, ...HOTSPOTS.plots];
    for (const spot of spots) {
      // Inside the farm map (roughly 4..40 tiles), not the old 32 px layout.
      expect(spot.x).to.be.within(4 * TILE, 40 * TILE);
      expect(spot.y).to.be.within(8 * TILE, 30 * TILE);
    }
  });

  it("enters the fenced field through the gate", function () {
    const start = { x: 18.18 * TILE, y: 26.85 * TILE };
    const path = aiPath(start, HOTSPOTS.plots[2]);
    expect(path.at(-1)).to.deep.equal(HOTSPOTS.plots[2]);
    // The first waypoint inside the field is straight above the gate.
    const firstInside = path.find(inField);
    expect(firstInside.x).to.equal(5 * TILE);
  });

  it("moves only along one axis between waypoints", function () {
    const start = HOTSPOTS.plots[0];
    const path = aiPath(start, HOTSPOTS.sell);
    let previous = start;
    for (const point of path) {
      const straight = point.x === previous.x || point.y === previous.y;
      expect(straight, JSON.stringify({ previous, point })).to.equal(true);
      previous = point;
    }
  });
});
