# Taniin

Taniin is a landscape Android farming game prototype with Web3 hooks for Sepolia. The app renders a pixel farm map, lets the player buy seeds, plant, harvest, sell crops, and sync the in-game coin display with a connected wallet.

## Current Features

- Java Canvas game loop with TMX map rendering, collisions, foreground layers, minimap, joystick, and hardware key support.
- Farming loop for land ownership, seed selection, quantity-based seed purchase, planting confirmation, harvest confirmation, success popups, and harvest effects.
- Separate seed shop and crop-selling house interactions.
- Local game state persistence for coins, seeds, harvest inventory, land ownership, and planted crops when the app is closed and reopened.
- Wallet button that stores a public wallet address, checks Sepolia RPC, reads ETH balance, and reads ERC-20 TANI balance when the deployed coin contract address is configured.
- Pending Web3 action queue for buy land, buy seed, plant, harvest, and sell crop actions. If `TANIIN_GAME_API_URL` is configured, actions are posted to that backend signer endpoint.
- Solidity contracts and Hardhat deploy scaffold in `contracts/`.

## Project Structure

- `app/src/main/java/id/rahmat/taniin/` - Android gameplay, TMX parser, wallet/RPC client, and blockchain action queue.
- `app/src/main/assets/game/` - Tiled map files and tileset source images used by the runtime map renderer.
- `app/src/main/res/drawable/` - Sprite sheets loaded directly through `R.drawable`.
- `app/src/main/res/raw/` - Put background music or short audio files here, for example `farm_backsound.mp3`. Android resource filenames must use lowercase letters, numbers, and underscores.
- `contracts/` - Solidity contracts and Hardhat deploy helper.
- `.env.example` - Local configuration template. Real `.env` files are ignored by git.

## Requirements

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
TANIIN_GAME_API_URL=
DEPLOYER_PRIVATE_KEY=replace_with_new_private_key_do_not_commit
```

The Android build reads these values into `BuildConfig`. The default local `.env` uses the public Sepolia RPC and leaves contract/API values blank, so the app runs in local prototype mode until deployed addresses are added. Only public values should be shipped in the APK. Never put a real private key in Android source, Gradle config, screenshots, commits, or APK assets. If a private key has been pasted into chat or git, treat it as compromised and move funds/assets to a new wallet.

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

## Web3 Flow

1. Deploy the contracts from `contracts/`.
2. Put the deployed public addresses into the root `.env`.
3. Rebuild the Android app so Gradle writes the addresses into `BuildConfig`.
4. In the app, tap `CONNECT WALLET` and enter the public wallet address.
5. The shop coin display uses the ERC-20 TANI balance when `TANIIN_COIN_CONTRACT_ADDRESS` is set. Otherwise it falls back to local prototype coins saved on the device.
6. Gameplay actions are queued locally. When `TANIIN_GAME_API_URL` is set, the app posts each action to `/game-actions` for a backend signer to process.

The Android app does not sign transactions with a private key. A production setup should use WalletConnect or a backend signer with strict server-side validation.

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

## License

This project is licensed under the MIT License. See `LICENSE` for details.
