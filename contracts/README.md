# Taniin Sepolia Contracts

This folder contains the Solidity contracts and a small Hardhat deploy scaffold for the Android prototype.

- `TaniinCoin`: ERC-20 reward token displayed by the Android wallet/coin UI.
- `TaniinLand`: ERC-721 land ownership prototype.
- `TaniinItems`: ERC-1155 seed/crop inventory prototype.

## Setup

The Hardhat config reads the root `.env` file. Use a fresh deployer wallet and never commit a real key.

```bash
cd contracts
npm install
npm run compile
npm run deploy:sepolia
```

The deploy script prints the public contract addresses that the Android build expects:

```properties
TANIIN_COIN_CONTRACT_ADDRESS=...
TANIIN_LAND_CONTRACT_ADDRESS=...
TANIIN_ITEMS_CONTRACT_ADDRESS=...
```

## Security Notes

Do not put `DEPLOYER_PRIVATE_KEY` in Android code, app assets, Gradle committed files, screenshots, or GitHub. If a key was shared in chat, consider it compromised and replace the wallet before deploying or funding it.

The Android app can read wallet balances through Sepolia JSON-RPC. Actual game transaction signing should be handled by WalletConnect or a backend signer endpoint configured through `TANIIN_GAME_API_URL`.
