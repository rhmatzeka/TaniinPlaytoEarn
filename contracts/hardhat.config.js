require("dotenv").config({ path: "../.env" });
require("@nomicfoundation/hardhat-toolbox");

const sepoliaUrl = process.env.SEPOLIA_RPC_URL || "";
const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY || "";
const hasDeployerKey = /^0x?[0-9a-fA-F]{64}$/.test(deployerPrivateKey)
  && !deployerPrivateKey.includes("replace_with_new");

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: sepoliaUrl,
      accounts: hasDeployerKey ? [deployerPrivateKey.startsWith("0x") ? deployerPrivateKey : `0x${deployerPrivateKey}`] : []
    }
  }
};
