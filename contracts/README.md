# Taniin Sepolia Contracts

This folder contains the first contract shape for the Android prototype:

- `TaniinLand`: ERC-721 land ownership. Players buy/mint land, plant, and harvest.
- `TaniinItems`: ERC-1155 inventory items for seed and crop balances.
- `TaniinCoin`: ERC-20 reward token for later marketplace/reward logic.

Do not commit private keys. The key shared in chat should be treated as compromised and replaced.

## Suggested Deploy Flow

Use a separate Hardhat or Foundry project, install OpenZeppelin, then copy `TaniinGame.sol`.

Hardhat example:

```bash
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox dotenv
npm install @openzeppelin/contracts
npx hardhat init
```

Use a local `.env` file:

```bash
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
DEPLOYER_PRIVATE_KEY=replace_with_new_wallet_private_key
```

After deploy, put the deployed contract addresses into the Android app config. The current app already records pending actions from gameplay, but transaction signing should be done through a wallet flow, not a hardcoded private key.

## Contract Calls To Wire Next

- Buy land: `TaniinLand.buyLand(tokenUri)` with `0.001 ether`.
- Plant: `TaniinLand.plant(landId)`.
- Harvest: `TaniinLand.harvest(landId)`.
- Mint/burn seed and crop items through a server/admin wallet or a contract-controlled game economy.
