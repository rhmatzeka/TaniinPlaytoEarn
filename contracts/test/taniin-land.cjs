const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TaniinLand", function () {
  async function deployLand() {
    const [owner, player] = await ethers.getSigners();
    const factory = await ethers.getContractFactory("TaniinLand");
    const land = await factory.deploy(owner.address);
    await land.waitForDeployment();
    return { land, player };
  }

  it("rejects selling a plot that was never minted", async function () {
    const { land, player } = await deployLand();

    await expect(
      land.sellLandFor(player.address, 1, "ipfs://unused")
    ).to.be.revertedWith("PLOT_NOT_MINTED");
  });

  it("requires planting before owner-driven harvest", async function () {
    const { land, player } = await deployLand();
    await land.mintLandFor(player.address, 1, "ipfs://land/1");

    await expect(
      land.harvestFor(player.address, 1, "ipfs://unused")
    ).to.be.revertedWith("NOT_PLANTED");

    await land.plantFor(player.address, 1, "ipfs://unused");
    await expect(land.harvestFor(player.address, 1, "ipfs://unused"))
      .to.emit(land, "PlayerLandHarvested")
      .withArgs(player.address, 1, 1, 3);
  });

  it("rejects selling planted land", async function () {
    const { land, player } = await deployLand();
    await land.mintLandFor(player.address, 1, "ipfs://land/1");
    await land.plantFor(player.address, 1, "ipfs://unused");

    await expect(
      land.sellLandFor(player.address, 1, "ipfs://unused")
    ).to.be.revertedWith("LAND_PLANTED");
  });
});
