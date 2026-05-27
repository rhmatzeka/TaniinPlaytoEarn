# Taniin

Taniin is an Android farming game prototype with early play-to-earn hooks. The app renders a pixel farm map, lets the player move with an on-screen joystick, buy and plant land, harvest crops, and queue game actions that can later be wired to Sepolia smart contracts.

## Current Features

- Landscape fullscreen Android game view built with Java Canvas.
- TMX map loading from `app/src/main/assets/game/map.tmx`, including tile rendering, collisions, foreground layers, and a minimap.
- Local farming loop for coins, seeds, crop growth, harvests, shop actions, inventory, and settings.
- Sepolia RPC health check and wallet address storage for the blockchain panel.
- Solidity prototype contracts for land, items, and token rewards in `contracts/`.

## Project Structure

- `app/src/main/java/id/rahmat/taniin/` - Android gameplay, TMX parser, and Sepolia RPC client.
- `app/src/main/assets/game/` - Tiled map files and tileset source images used by the runtime map renderer.
- `app/src/main/res/drawable/` - Sprite sheets loaded directly through `R.drawable`.
- `contracts/` - Smart contract prototypes and deploy notes for a separate Hardhat or Foundry workspace.
- `gradle/` and `*.gradle.kts` - Android Gradle project configuration.

## Requirements

- Android Studio or Android SDK command-line tools with Android Gradle Plugin 9.1.1 support.
- JDK 17 or newer.
- Android SDK platform 36.
- A device or emulator running Android 8.0/API 26 or newer.

## Build And Run

From the repository root:

```bash
./gradlew :app:assembleDebug
```

Install to a connected device or emulator:

```bash
./gradlew :app:installDebug
```

You can also open this directory in Android Studio and run the `app` configuration.

## Blockchain Notes

The Android app currently checks the public Sepolia RPC endpoint and stores a wallet address locally. Gameplay actions are queued in-app as pending chain actions, but transaction signing is not implemented yet.

Contract prototypes live in `contracts/TaniinGame.sol`. Use a separate Hardhat or Foundry project for deployment, and never commit private keys or wallet secrets.

## Generated Files

Root-level verification screenshots such as `taniin_*.png` and temporary scaled images are ignored. Runtime build outputs, Android Studio local state, and `local.properties` should stay out of git.
