# Taniin

Taniin is a pixel farming game for the browser and Android, built with Flutter and Flame. Players buy seeds, plant, harvest, and sell crops, play alongside other farmers and the Pak Tani AI assistant, and can record their farm on Ethereum Sepolia after signing in with Privy.

- **Play:** https://taniin.rahmateka.my.id
- **Android APK:** https://taniin.rahmateka.my.id/unduh/Taniin.apk (Android 8.0+)

Guests can play right away; progress is saved on the device. Signing in is optional.

## Features

- Farming loop: buy land, buy seeds (potato, onion, strawberry, beet), plant, wait, harvest, sell.
- Daily quests, XP and levels, achievements, and unlockable farmer outfits visible to other players.
- Multiplayer presence and chat over Socket.IO, plus Pak Tani AI, which plants and harvests on request (Groq LLM with a rule-based fallback).
- Privy login with email, Google, or an existing wallet. An embedded Sepolia wallet is created for new players, and guest progress is carried over once (capped).
- Server-validated economy: prices, grow time, and inventory are checked on the server before any transaction is sent.
- On-chain records on Sepolia: land as ERC-721, seeds and crops as ERC-1155, and the TANI ERC-20 token. Game Coin can be swapped to TANI or Sepolia ETH, within daily limits.
- In-game status strip (account, Sepolia, server, multiplayer, AI) and a transaction history that links to Etherscan.

## Architecture

```
Flutter web / APK ──► Vercel (contracts/)
   │                    ├─ static: landing page, /main/ game, /masuk/ Privy login
   │                    └─ api/[...path].js: /auth/privy, /player, /game-actions, /health
   │                         │
   │                         ├─ Neon Postgres: sessions, player state, rate limits,
   │                         │  idempotency keys, daily limits, audit log
   │                         └─ backend signer ──► Sepolia contracts
   │
   └─────────────────► srv (always on): Socket.IO multiplayer + Pak Tani AI
```

- The game never holds a private key. The signer runs on the server, and the advisory lock in Postgres serializes its transactions across serverless instances.
- `TANIIN_ECONOMY_PAUSED=true` stops all on-chain actions without a redeploy.

### Sepolia contracts

| Contract | Address |
| --- | --- |
| TaniinCoin (TANI, ERC-20) | `0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8` |
| TaniinLand (ERC-721) | `0x55D768D736b66B842EE72Ff7fa143f03245F81cc` |
| TaniinItems (ERC-1155) | `0x9414eD4F6d9beF484484D72da3d8361989348AEf` |

## Repository layout

- `taniin_flutter/` — Flutter app (game, HUD, state, Privy session handling, Android host).
- `contracts/lib/` — backend: economy rules, Privy sessions, player service, chain executor, multiplayer.
- `contracts/api/` — single Vercel function that routes every API path.
- `contracts/masuk/` — Privy login page (React, bundled with esbuild at deploy time).
- `contracts/public/` — landing page and static assets; the Flutter web build goes to `public/main/`.
- `contracts/contracts/` — Solidity contracts and Hardhat config.
- `docs/` — product plans and the design and implementation plan for this release.

## Running locally

Requirements: Node.js 20+, Flutter stable, and (for Android) JDK 17 with the Android SDK.

```bash
cp .env.example .env        # fill in DATABASE_URL, PRIVY_*, DEPLOYER_PRIVATE_KEY
cd contracts
npm install
npx hardhat test            # backend and contract tests (uses in-memory Postgres)
npm run game-api            # API + multiplayer on http://127.0.0.1:8787
```

Flutter web against the local server:

```bash
cd taniin_flutter
flutter run -d chrome \
  --dart-define=TANIIN_GAME_API_URL=http://127.0.0.1:8787 \
  --dart-define=TANIIN_MULTIPLAYER_URL=http://127.0.0.1:8787
```

## Deployment

- **Vercel** (project root `contracts/`): set `DATABASE_URL`, `PRIVY_APP_ID`, `PRIVY_APP_SECRET`, `DEPLOYER_PRIVATE_KEY`, `SEPOLIA_RPC_URL`, the contract addresses, `TANIIN_ALLOWED_ORIGIN`, and `TANIIN_MULTIPLAYER_URL`. The build command bundles the login page.
- **Web game:** CI builds `taniin_flutter` with `--base-href /main/`; the artifact is copied to `contracts/public/main/`.
- **APK:** the `Android APK` workflow builds a release APK signed with a fixed key (repo secrets `TANIIN_KEYSTORE_B64` and `TANIIN_KEYSTORE_PASSWORD`) and uploads it to the `apk-terbaru` release. `/unduh` redirects there.
- **Multiplayer:** run `npm run game-api` as a service on an always-on host behind a Cloudflare Tunnel, with `DATABASE_URL`, `GROQ_API_KEY`, and `TANIIN_ALLOWED_ORIGIN`.

Taniin runs on the Sepolia testnet. Its tokens and ETH have no real-world value.

## License

MIT. See `LICENSE`.
