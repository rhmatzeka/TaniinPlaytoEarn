# Taniin Sepolia Contracts

This folder contains the Solidity contracts and a small Hardhat deploy scaffold for the Android prototype.

- `TaniinCoin`: ERC-20 reward token displayed by the Android wallet/coin UI.
- `TaniinLand`: ERC-721 land ownership prototype with buy, sell/burn, plant, and harvest actions.
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

The Android app can read wallet balances through Sepolia JSON-RPC. Actual game transaction signing should be handled by WalletConnect or a backend signer endpoint configured through `TANIIN_GAME_API_URL`. For transaction history links, the backend should return a Sepolia transaction hash after submitting a game action.

For local emulator testing, run the included signer backend after deploying contracts and filling the root `.env`:

```bash
cd contracts
npm run game-api
```

Then set the Android-facing URL in the root `.env`. For a USB device, run `adb reverse tcp:8787 tcp:8787` and use localhost:

```properties
TANIIN_GAME_API_URL=http://127.0.0.1:8787
```

For an emulator without `adb reverse`, use `http://10.0.2.2:8787` instead.
For WiFi ADB, use the computer LAN IP, for example `http://192.168.1.9:8787`.

## Deploy Signer To Vercel

The local signer is also packaged as Vercel functions under `api/`. The project keeps the Android-facing endpoints as `/health` and `/game-actions` through `vercel.json` rewrites.

1. Import this repository into Vercel.
2. Set the Vercel project Root Directory to `contracts`.
3. Use the default Node.js/Other framework settings. No build command is required.
4. Add these Vercel environment variables for Production, Preview, and Development as needed:

```properties
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
DEPLOYER_PRIVATE_KEY=replace_with_new_private_key_do_not_commit
TANIIN_COIN_CONTRACT_ADDRESS=0x...
TANIIN_LAND_CONTRACT_ADDRESS=0x...
TANIIN_ITEMS_CONTRACT_ADDRESS=0x...
```

5. Deploy, then verify the signer health endpoint:

```bash
curl https://your-project.vercel.app/health
```

6. In the Android root `.env`, point the app at the Vercel deployment and rebuild the APK:

```properties
TANIIN_GAME_API_URL=https://your-project.vercel.app
```

The Android app posts to `/game-actions`, so do not include `/api` in `TANIIN_GAME_API_URL`.

This Vercel signer is suitable for prototype testing. Before sharing the endpoint publicly, add authentication, server-side gameplay validation, and rate limiting; otherwise anyone who knows the endpoint can submit mint/reward actions through the deployer signer.
