ih# Taniin

Taniin is a Flutter/Flame landscape farming game prototype for Android and Web with Web3 hooks for Sepolia. The app renders a pixel farm map, lets the player buy seeds, plant, harvest, sell crops, and sync the in-game coin display with a connected wallet.

## Current Features

- Flutter/Flame game loop with TMX map rendering, collisions, foreground layers, minimap, joystick, and hardware key support.
- Fullscreen loading screen using `app/src/main/res/drawable/loadingscreen.jpg` with animated 1-100 progress before entering the game.
- Farming loop for land ownership, land selling, seed selection, quantity-based seed purchase, planting confirmation, harvest confirmation, success popups, and harvest effects.
- Separate seed shop and crop-selling house interactions.
- Local game state persistence for coins, seeds, harvest inventory, land ownership, and planted crops when the app is closed and reopened.
- Background music plus click/error/walking SFX from `res/raw`, with toggles in the hamburger menu's Audio tab.
- Wallet button that can auto-connect from a public `.env` wallet address, checks Sepolia RPC, reads ETH balance, and reads ERC-20 TANI balance when the deployed coin contract address is configured.
- Web3 action tracking for buy land, sell land, buy seed, plant, harvest, and sell crop actions. If `TANIIN_GAME_API_URL` is configured, actions are posted to that backend signer endpoint; otherwise they are recorded as local, not pending.
- In-game transaction history button and dialog. Backend responses may return `txHash`, `transactionHash`, `hash`, or a nested `data`/`result` hash; rows with a hash open the Sepolia Etherscan transaction page.
- Solidity contracts and Hardhat deploy scaffold in `contracts/`.

## Project Structure

- `taniin_flutter/lib/` - Flutter app shell, Flame game, UI panels, state controller, wallet bridge, and Sepolia client.
- `taniin_flutter/web/` - Flutter Web shell and web manifest.
- `taniin_flutter/assets/game/` - Tiled map files and tileset source images used by the runtime map renderer.
- `taniin_flutter/assets/audio/` - Flutter audio assets. Android native audio resources are mirrored under `taniin_flutter/android/app/src/main/res/raw/`.
- `taniin_flutter/android/` - Android host app, fullscreen handling, deep link bridge, and native audio bridge.
- `contracts/` - Solidity contracts and Hardhat deploy helper.
- `.env.example` - Local configuration template. Real `.env` files are ignored by git.

## Requirements

- Flutter stable with Web support enabled.
- Android Studio or Android SDK command-line tools with Android Gradle Plugin 9.1.1 support.
- JDK 17 or newer.
- Android SDK platform 36.
- A device or emulator running Android 8.0/API 26 or newer.
- Optional for contracts: Node.js 20 or newer.

## Environment

Create a local `.env` from `.env.example`. Do not commit the real file.

```properties
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
TANIIN_COIN_CONTRACT_ADDRESS=
TANIIN_ITEMS_CONTRACT_ADDRESS=
TANIIN_LAND_CONTRACT_ADDRESS=
TANIIN_GAME_API_URL=http://127.0.0.1:8787
TANIIN_GAME_API_PORT=8787
TANIIN_ALLOWED_ORIGIN=
TANIIN_REQUIRE_AUTH=false
TANIIN_AUTH_NONCE_TTL_MS=300000
TANIIN_AUTH_SESSION_TTL_MS=3600000
TANIIN_AUTH_RATE_LIMIT=20
TANIIN_ACTION_RATE_LIMIT=30
TANIIN_ETH_WEI_PER_COIN=10000000000
TANIIN_MAX_ETH_PAYOUT_WEI=10000000000000000
TANIIN_DEFAULT_WALLET_ADDRESS=
DEPLOYER_PRIVATE_KEY=replace_with_new_private_key_do_not_commit
```

The Android build reads the public values into `BuildConfig`. Flutter Web reads the same public values from `--dart-define` at build/run time. On Web, if `TANIIN_GAME_API_URL` is omitted, the app uses the current site origin, which works when the Flutter static files and Vercel API live in the same Vercel project. `TANIIN_DEFAULT_WALLET_ADDRESS` is optional and lets debug builds prefill a public wallet address when no player wallet has been saved yet. A saved in-app wallet always wins, and tapping the wallet HUD opens the wallet connect/sync dialog. When `TANIIN_GAME_API_URL` is set, or when Web uses the same-origin fallback, `/wallet-connect` can be opened in an injected Ethereum wallet browser; the page requests the public account and returns to Android through `taniin://wallet` or to Flutter Web through an `?address=...` callback. Manual address entry remains a fallback only. `TANIIN_ALLOWED_ORIGIN` can restrict browser/API/Socket.IO CORS for deployed environments; leave it empty for local development. `TANIIN_REQUIRE_AUTH=true` makes `/game-actions` require a wallet-signature session from `/auth/nonce` and `/auth/verify`; keep it `false` until the Flutter wallet bridge sends bearer sessions. For USB device testing, run `adb reverse tcp:8787 tcp:8787` and use `TANIIN_GAME_API_URL=http://127.0.0.1:8787`. For WiFi ADB, use the computer LAN IP, for example `http://192.168.1.9:8787`. For an emulator without `adb reverse`, use `http://10.0.2.2:8787`; the app also tries the matching local fallback. Only public values should be shipped in the APK or web build. Never put a real private key in Android source, Gradle config, Flutter assets, screenshots, commits, or browser-delivered files. If a private key has been pasted into chat or git, treat it as compromised and move funds/assets to a new wallet.

> **Economy Safety Phase 0:** `/game-actions` now fails closed when `TANIIN_REQUIRE_AUTH` is not `true`. Authenticated requests also require a verified wallet session and an `Idempotency-Key`. The current Flutter bridge does not send these yet, so public on-chain economy actions are intentionally unavailable. Only burn-only `SELL_CROP` and `SWAP_TANI_COIN` are allowlisted at the signer boundary; mint, reward, land, seed, ETH funding, and payout actions remain disabled until persistent authentication and authoritative accounting are available. This notice supersedes the earlier prototype instruction to leave authentication disabled.

## Build And Run

From the repository root:

```bash
./gradlew :app:assembleDebug
```

Install to a connected device or emulator:

```bash
./gradlew :app:installDebug
```

On Windows from this WSL workspace, this command is known to work:

```bash
cmd.exe /c gradlew.bat :app:assembleDebug --console=plain
```

For local Flutter Web testing against an existing API URL:

```bash
cd taniin_flutter
flutter config --enable-web
flutter run -d chrome \
  --dart-define=TANIIN_GAME_API_URL=https://your-project.vercel.app \
  --dart-define=TANIIN_COIN_CONTRACT_ADDRESS=0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8 \
  --dart-define=TANIIN_LAND_CONTRACT_ADDRESS=0x55D768D736b66B842EE72Ff7fa143f03245F81cc \
  --dart-define=TANIIN_ITEMS_CONTRACT_ADDRESS=0x9414eD4F6d9beF484484D72da3d8361989348AEf
```

For a production web bundle:

```bash
cd taniin_flutter
flutter build web --release \
  --dart-define=TANIIN_COIN_CONTRACT_ADDRESS=0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8 \
  --dart-define=TANIIN_LAND_CONTRACT_ADDRESS=0x55D768D736b66B842EE72Ff7fa143f03245F81cc \
  --dart-define=TANIIN_ITEMS_CONTRACT_ADDRESS=0x9414eD4F6d9beF484484D72da3d8361989348AEf
```

The static website output is `taniin_flutter/build/web`. If your existing Vercel project root is `contracts`, build Flutter locally, copy the contents of `taniin_flutter/build/web` into `contracts/public`, then deploy the same Vercel project. The existing Vercel API rewrites keep `/game-actions`, `/health`, and `/wallet-connect` working. For the same Vercel project, omit `TANIIN_GAME_API_URL` so Web uses the deployed domain automatically. If the API is on a different domain, set `TANIIN_GAME_API_URL` to that origin and do not add `/api` to the URL.

For a repeatable Web smoke test, install the local Playwright test dependency in `taniin_flutter`, serve the static output, then run the E2E script:

```bash
cd taniin_flutter
npm install
python3 -m http.server 4174 --bind 127.0.0.1 --directory ../contracts/public
npm run e2e:web
```

On WSL without Linux browser system libraries, start Chrome on Windows with a remote debugging port and run the CDP variant instead:

```bash
powershell.exe -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList '--remote-debugging-port=9223','--user-data-dir=C:\Users\matsg\AppData\Local\Temp\taniin-e2e-chrome','--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check'"
cmd.exe /c "set TANIIN_E2E_BASE_URL=http://127.0.0.1:4174&& npm run e2e:web:cdp"
```

## Web3 Flow

1. Deploy the contracts from `contracts/`.
2. Put the deployed public addresses into the root `.env`.
3. Rebuild the Android app so Gradle writes the addresses into `BuildConfig`.
4. Optionally set `TANIIN_DEFAULT_WALLET_ADDRESS` to a public Sepolia wallet address before building. The app will auto-connect that wallet only until a player wallet is saved in-app; tapping the wallet button opens the wallet app connect/sync dialog.
5. The shop coin display uses the ERC-20 TANI balance when `TANIIN_COIN_CONTRACT_ADDRESS` is set. Otherwise it falls back to local prototype coins saved on the device.
6. Start the local backend signer with `cd contracts && npm run game-api`. It listens on port `8787` and signs `/game-actions` with the deployer wallet from the root `.env`. On a USB device, also run `adb reverse tcp:8787 tcp:8787`.
7. Gameplay actions are recorded in the local history. When `TANIIN_GAME_API_URL` is set, or when Web uses the same-origin fallback, the app posts each action to `/game-actions` for the backend signer to process. If the backend returns a transaction hash, the app saves it in the transaction history and opens Sepolia Etherscan when tapped. Without that signer URL, the history marks actions as not yet on-chain instead of leaving them pending forever.
8. The swap house can fund local Game Coin from Sepolia ETH through a signer receipt transaction, and can swap game coins to either TANI or native Sepolia ETH. ETH payout is sent from the backend signer wallet, so keep the signer funded, connect a player wallet that is different from the signer, and configure `TANIIN_ETH_WEI_PER_COIN` plus `TANIIN_MAX_ETH_PAYOUT_WEI` deliberately before using this on a public deployment. If the connected wallet equals the backend signer, the app marks it as a signer wallet and asks the player to change wallets before ETH payout.

For non-local testing, deploy the signer in `contracts/api/` to Vercel with the Vercel project root set to `contracts`. Set `TANIIN_GAME_API_URL=https://your-project.vercel.app` in the Android root `.env` and rebuild the APK. Flutter Web can omit `TANIIN_GAME_API_URL` when it is deployed to the same Vercel project as the API. The Vercel rewrites keep the endpoint as `/game-actions`, so do not add `/api` to the URL.

The Android app does not sign transactions with a private key. A production setup should use WalletConnect or a backend signer with strict server-side validation.

Land ownership is represented by `TaniinLand` ERC-721 on-chain, but the Android gameplay state remains local unless the backend signer maps each game action to the deployed contracts and returns confirmed transaction hashes.

The included development signer maps gameplay actions like this: land buy mints an ERC-721 land NFT to the player's wallet, land sell burns that plot NFT and mints a TANI reward, plant/harvest update the land contract, seed purchases mint ERC-1155 seed items, harvests mint ERC-1155 crop items, crop sales mint ERC-20 TANI rewards, ETH-to-coin funding mints a signer receipt, TANI swaps mint ERC-20 TANI, and ETH swaps pay native ETH from the signer wallet.

## Deploy Contracts

```bash
cd contracts
npm install
npm run compile
npm run deploy:sepolia
```

The deploy script prints:

```properties
TANIIN_COIN_CONTRACT_ADDRESS=...
TANIIN_LAND_CONTRACT_ADDRESS=...
TANIIN_ITEMS_CONTRACT_ADDRESS=...
```

Copy those public addresses into the root `.env`, then rebuild the Android app.

Mint test TANI to the default public wallet when the deployer is the coin owner:

```bash
cd contracts
npm run mint:tani
```

Set `TANIIN_MINT_AMOUNT=2500` in `.env` to override the default `1000` TANI amount.

Current Sepolia deployment:

```properties
TANIIN_COIN_CONTRACT_ADDRESS=0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8
TANIIN_LAND_CONTRACT_ADDRESS=0x55D768D736b66B842EE72Ff7fa143f03245F81cc
TANIIN_ITEMS_CONTRACT_ADDRESS=0x9414eD4F6d9beF484484D72da3d8361989348AEf
```

## License

This project is licensed under the MIT License. See `LICENSE` for details.
