# Taniin

Taniin is a landscape Android farming game prototype with Web3 hooks for Sepolia. The app renders a pixel farm map, lets the player buy seeds, plant, harvest, sell crops, and sync the in-game coin display with a connected wallet.

## Current Features

- Java Canvas game loop with TMX map rendering, collisions, foreground layers, minimap, joystick, and hardware key support.
- Fullscreen loading screen using `app/src/main/res/drawable/loadingscreen.jpg` with animated 1-100 progress before entering the game.
- Farming loop for land ownership, land selling, seed selection, quantity-based seed purchase, planting confirmation, harvest confirmation, success popups, and harvest effects.
- Separate seed shop and crop-selling house interactions.
- Local game state persistence for coins, seeds, harvest inventory, land ownership, and planted crops when the app is closed and reopened.
- Background music plus click/error/walking SFX from `res/raw`, with toggles in the hamburger menu's Audio tab.
- Wallet button that can auto-connect from a public `.env` wallet address, checks Sepolia RPC, reads ETH balance, and reads ERC-20 TANI balance when the deployed coin contract address is configured.
- Pending Web3 action queue for buy land, sell land, buy seed, plant, harvest, and sell crop actions. If `TANIIN_GAME_API_URL` is configured, actions are posted to that backend signer endpoint.
- In-game transaction history panel. Backend responses may return `txHash`, `transactionHash`, `hash`, or a nested `data`/`result` hash; rows with a hash open the Sepolia Etherscan transaction page.
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
TANIIN_DEFAULT_WALLET_ADDRESS=
DEPLOYER_PRIVATE_KEY=replace_with_new_private_key_do_not_commit
```

The Android build reads the public values into `BuildConfig`. `TANIIN_DEFAULT_WALLET_ADDRESS` is optional and lets the debug app auto-connect without typing a wallet address. The default local `.env` uses the public Sepolia RPC and leaves contract/API values blank, so the app runs in local prototype mode until deployed addresses are added. Only public values should be shipped in the APK. Never put a real private key in Android source, Gradle config, screenshots, commits, or APK assets. If a private key has been pasted into chat or git, treat it as compromised and move funds/assets to a new wallet.

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
4. Optionally set `TANIIN_DEFAULT_WALLET_ADDRESS` to a public Sepolia wallet address before building. The app will auto-connect that wallet and tapping the wallet button will sync balances.
5. The shop coin display uses the ERC-20 TANI balance when `TANIIN_COIN_CONTRACT_ADDRESS` is set. Otherwise it falls back to local prototype coins saved on the device.
6. Gameplay actions are queued locally. When `TANIIN_GAME_API_URL` is set, the app posts each action to `/game-actions` for a backend signer to process. If the backend returns a transaction hash, the app saves it in the transaction history and opens Sepolia Etherscan when tapped.

The Android app does not sign transactions with a private key. A production setup should use WalletConnect or a backend signer with strict server-side validation.

Land ownership is represented by `TaniinLand` ERC-721 on-chain, but the Android gameplay state remains local unless the backend signer maps each game action to the deployed contracts and returns confirmed transaction hashes.

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

Redeploy and replace these addresses after contract changes, including the `sellLand` function, before expecting land selling to execute on-chain.

```properties
TANIIN_COIN_CONTRACT_ADDRESS=0xc3F787EF326Cec3EFD9DC50258B7b4F0639F385e
TANIIN_LAND_CONTRACT_ADDRESS=0x5c612b1dE28Cc5bC63e51580b06b196EDB4f3f78
TANIIN_ITEMS_CONTRACT_ADDRESS=0xE3651A399FB1818880E5e90fd5d76a80DB2d76CF
```

## License

This project is licensed under the MIT License. See `LICENSE` for details.
