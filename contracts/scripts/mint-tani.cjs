const hre = require("hardhat");

function shortAddress(address) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

async function main() {
  const coinAddress = process.env.TANIIN_COIN_CONTRACT_ADDRESS;
  if (!coinAddress || !hre.ethers.isAddress(coinAddress)) {
    throw new Error("TANIIN_COIN_CONTRACT_ADDRESS belum valid di .env.");
  }

  const [deployer] = await hre.ethers.getSigners();
  if (!deployer) {
    throw new Error("DEPLOYER_PRIVATE_KEY belum diset di .env.");
  }

  const recipient = process.env.TANIIN_DEFAULT_WALLET_ADDRESS || await deployer.getAddress();
  if (!hre.ethers.isAddress(recipient)) {
    throw new Error("TANIIN_DEFAULT_WALLET_ADDRESS belum valid di .env.");
  }

  const amount = process.env.TANIIN_MINT_AMOUNT || "1000";
  const coin = await hre.ethers.getContractAt("TaniinCoin", coinAddress);
  const decimals = await coin.decimals();
  const rawAmount = hre.ethers.parseUnits(amount, decimals);

  const owner = await coin.owner();
  const signerAddress = await deployer.getAddress();
  if (owner.toLowerCase() !== signerAddress.toLowerCase()) {
    throw new Error(`Signer ${shortAddress(signerAddress)} bukan owner TANI ${shortAddress(owner)}.`);
  }

  const tx = await coin.mint(recipient, rawAmount);
  console.log(`Minting ${amount} TANI to ${shortAddress(recipient)} with tx ${tx.hash}`);
  await tx.wait();
  const balance = await coin.balanceOf(recipient);
  console.log(`TANI balance ${shortAddress(recipient)} = ${hre.ethers.formatUnits(balance, decimals)}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
