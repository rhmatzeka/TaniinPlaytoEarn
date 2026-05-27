const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  if (!deployer) {
    throw new Error("DEPLOYER_PRIVATE_KEY belum diset di .env atau formatnya tidak valid.");
  }

  const owner = await deployer.getAddress();
  console.log(`Deploying Taniin contracts with ${owner}`);

  const TaniinCoin = await hre.ethers.getContractFactory("TaniinCoin");
  const coin = await TaniinCoin.deploy(owner);
  await coin.waitForDeployment();

  const TaniinLand = await hre.ethers.getContractFactory("TaniinLand");
  const land = await TaniinLand.deploy(owner);
  await land.waitForDeployment();

  const TaniinItems = await hre.ethers.getContractFactory("TaniinItems");
  const items = await TaniinItems.deploy(owner, process.env.TANIIN_ITEMS_METADATA_URI || "ipfs://taniin/items/{id}.json");
  await items.waitForDeployment();

  const coinAddress = await coin.getAddress();
  const landAddress = await land.getAddress();
  const itemsAddress = await items.getAddress();

  console.log("\nAdd these public addresses to the root .env before building Android:");
  console.log(`TANIIN_COIN_CONTRACT_ADDRESS=${coinAddress}`);
  console.log(`TANIIN_LAND_CONTRACT_ADDRESS=${landAddress}`);
  console.log(`TANIIN_ITEMS_CONTRACT_ADDRESS=${itemsAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
