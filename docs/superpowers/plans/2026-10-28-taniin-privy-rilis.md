# Taniin Privy, Ekonomi Server, Multiplayer, APK — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Taniin bisa dimainkan tamu di web, diunduh sebagai APK, login lewat Privy, aksi ekonomi divalidasi server dan tercatat di Sepolia, multiplayer + Pak Tani AI hidup dari srv.

**Architecture:** Backend Node yang ada (`contracts/`) tetap di Vercel, digabung jadi satu fungsi router, state bersama di Neon Postgres. Sesi Taniin diterbitkan setelah token Privy diverifikasi. Server menyimpan state pemain dan menjalankan aturan ekonomi murni (`lib/economy.cjs`), lalu signer mengirim transaksi dengan kunci advisory Postgres. Flutter menerima snapshot state dari server untuk pemain login, tetap lokal untuk tamu. Server Socket.IO yang sama dijalankan terpisah di srv.

**Tech Stack:** Node 20 CommonJS, ethers v6 (dari hardhat-toolbox), `pg`, `jose`, `@electric-sql/pglite` (tes), mocha/chai via `hardhat test`, React 18 + `@privy-io/react-auth` + esbuild, Flutter/Flame (Dart 3.12), GitHub Actions, Cloudflare Tunnel.

**Spec:** `docs/superpowers/specs/2026-10-28-taniin-privy-rilis-design.md`

## Global Constraints

- Tidak ada migrasi bahasa/framework; game Flutter, backend Node di Vercel.
- Kontrak tidak di-deploy ulang: coin `0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8`, land `0x55D768D736b66B842EE72Ff7fa143f03245F81cc`, items `0x9414eD4F6d9beF484484D72da3d8361989348AEf`.
- Tamu tidak pernah dipaksa login untuk bermain.
- Secret (private key signer, `PRIVY_APP_SECRET`, `DATABASE_URL`, `GROQ_API_KEY`) tidak boleh ada di repo, APK, build web, atau README. `PRIVY_APP_ID` publik.
- Commit hanya atas identitas git pemilik: tanpa `Co-Authored-By`, tanpa atribusi AI, tanpa commit bot CI ke branch.
- Bahasa UI Indonesia.
- Batas default (env bisa ubah): payout ETH 0,01 SepETH/wallet/hari (`TANIIN_DAILY_ETH_PAYOUT_WEI=10000000000000000`), mint TANI 2.000/wallet/hari (`TANIIN_DAILY_TANI_MINT=2000`), tolak payout bila saldo signer < 0,2 SepETH (`TANIIN_MIN_SIGNER_BALANCE_WEI=200000000000000000`), 30 aksi/menit/wallet, 60/menit/IP.
- Impor progres tamu: sekali per akun, koin maks 500.
- Saklar darurat: `TANIIN_ECONOMY_PAUSED=true` menolak semua aksi on-chain dengan 503.
- Sesi Taniin berumur 7 hari.
- Paket Vercel Hobby: maksimal 12 fungsi; pakai satu router.

## Review Focus

- Dua request dengan `Idempotency-Key` sama datang bersamaan (double tap): hanya satu yang diproses dan keduanya menerima hasil yang sama. Dites di Task 4.
- Panen dikirim sebelum 12 detik berlalu menurut jam server (jam klien dimajukan): ditolak 409 dan state tidak berubah. Dites di Task 2.
- Sesi kedaluwarsa atau dicabut di tengah permainan: Flutter kembali ke mode tamu dengan pesan "Sesi habis, masuk lagi", tidak macet dengan status pending. Dites di Task 7.
- Transaksi Sepolia gagal setelah state server diubah: state server dikembalikan (rollback transaksi DB) dan klien menerima snapshot lama. Dites di Task 4.
- Server multiplayer tidak terjangkau: game tetap jalan solo, indikator "Multiplayer offline", tanpa spam error. Dites di Task 9.

---

### Task 1: Lapisan database (Neon + PGlite untuk tes)

**Files:**
- Create: `contracts/lib/db.cjs`, `contracts/db/schema.sql`, `contracts/test/helpers/test-db.cjs`, `contracts/test/db.cjs`
- Modify: `contracts/package.json` (dependencies `pg`, `jose`; devDependencies `@electric-sql/pglite`; script `"test": "hardhat test"` tetap), `.env.example` (tambah `DATABASE_URL=`, `PRIVY_APP_ID=`, `PRIVY_APP_SECRET=`, batas di Global Constraints)

**Interfaces:**
- Produces: `getDb(): Db` (singleton dari `DATABASE_URL`, `pg.Pool` dengan `ssl: { rejectUnauthorized: true }`), `setDbForTests(db: Db)`, tipe `Db = { query(sql, params?) => Promise<{rows}>, transaction(fn: (tx: Db) => Promise<T>) => Promise<T> }`, `ensureSchema(db)` (jalankan `schema.sql` idempoten, `CREATE TABLE IF NOT EXISTS`).
- Produces: `createTestDb(): Promise<Db>` di helper, berbasis PGlite in-memory dengan skema terpasang.

Tabel di `schema.sql`: `sessions(token_hash text pk, privy_user_id text, wallet text, login_method text, created_at, expires_at, revoked_at)`, `rate_limits(key text pk, count int, reset_at timestamptz)`, `idempotency(scoped_key text pk, status text, response jsonb, expires_at)`, `players(wallet text pk, privy_user_id text unique, state jsonb, imported_guest bool default false, updated_at)`, `daily_usage(wallet text, day date, tani_minted numeric, eth_paid_wei numeric, pk(wallet, day))`, `funding_txs(tx_hash text pk, wallet text, used_at)`, `audit_log(id bigserial pk, wallet, action, amount, plot_id, tx_hashes jsonb, result text, error text, created_at)`. Token sesi disimpan sebagai SHA-256, bukan mentah.

- [ ] **Step 1: Tulis tes gagal** `test/db.cjs`: `ensureSchema` dua kali tidak error; `transaction` yang melempar error membatalkan insert ke `players`.
- [ ] **Step 2:** `cd contracts && npm install && npx hardhat test test/db.cjs` → FAIL (modul belum ada).
- [ ] **Step 3:** Implementasi `db.cjs`, `schema.sql`, helper.
- [ ] **Step 4:** Tes yang sama → PASS.
- [ ] **Step 5:** Commit `Add Postgres storage layer`.

### Task 2: Aturan ekonomi murni

**Files:**
- Create: `contracts/lib/economy.cjs`, `contracts/test/economy.cjs`

**Interfaces:**
- Produces: `CATALOG` (nilai dari `farm_state.dart`: `growMs: 12000`, `landBuyPrice: 1000`, `landSellPrice: 750`, `cropSellPrice: 50`, `seedBundleAmount: 3`, `seedBundlePrices: [100,140,220,180]` TANI, `harvestYields: [3,4,5,4]`, `plotCount: 5`, kuest `plant/3/30xp`, `harvest/2/40xp`, `sell/1/30xp`, level `1 + floor(xp/100)`, skin `farmer_classic@1`, `farmer_nusantara@2`, `forest_keeper@4`, achievement `Langkah Pertama` (xp≥30), `Petani Berkembang` (level≥2), `Juragan Lahan` (5 plot)).
- Produces: `newPlayerState(): PlayerState` (sama dengan default Flutter: coins 620, plot 1 dimiliki, benih awal seperti `seeds` di Dart).
- Produces: `applyAction(state, action, nowMs): { state, chainOps: ChainOp[], summary }`, melempar `httpError(409|400, pesan)` bila tidak valid. `action = { type, plotId, seedIndex?, cropIndex?, quantity?, amount? }`. `ChainOp = { kind: 'mintLand'|'sellLand'|'plant'|'harvest'|'mintCrop'|'burnCrop'|'mintSeed'|'spendTani'|'mintTani'|'payEth', ...args }`. Pemetaan per aksi mengikuti `switch` di `game-action-service.cjs` saat ini. Jumlah hadiah/harga dihitung dari `CATALOG`, `amount` klien hanya dipakai untuk swap dan dibatasi `maxOnChainSwapAmount = 10000`.
- Produces: `importGuestState(raw): PlayerState`. Hasilnya dipotong: plot ≤ 5 (plot 1 selalu dimiliki), stok benih/panen per jenis ≤ 30, xp ≤ 400, koin ≤ 500, tanaman yang sedang tumbuh direset ke kosong, skin hanya yang sesuai level.
- Produces: `publicState(state)`: bentuk JSON yang dikirim ke Flutter (kunci sama dengan `_toSaveJson` Dart untuk field ekonomi).

- [ ] **Step 1: Tulis tes gagal** di `test/economy.cjs`:
  - `BUY_LAND` dengan coins 620 → 409 "Coin belum cukup"; dengan 1000 → coins 0, plot dimiliki, chainOps `[mintLand]`.
  - `PLANT` tanpa benih → 409; dengan benih → stok −1, `plantedAtMs = now`, quest plant +1.
  - `HARVEST` pada `now − plantedAt = 11999` → 409 "belum siap"; pada `12000` → panen +`harvestYields[seed]`, chainOps `[harvest, mintCrop]`.
  - `SELL_CROP` jual semua stok → coins += qty×50, chainOps `[burnCrop]`.
  - `SELL_LAND` lahan terakhir → 409.
  - `importGuestState({coins: 99999, plots: 9 dimiliki, xp: 5000})` → coins 500, plot dimiliki ≤ 5, xp 400.
  - Level naik ke 2 membuka `farmer_nusantara` dan achievement `Petani Berkembang`.
- [ ] **Step 2:** `npx hardhat test test/economy.cjs` → FAIL.
- [ ] **Step 3:** Implementasi.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5:** Commit `Add server-side economy rules`.

### Task 3: Auth Privy + sesi + rate limit di database

**Files:**
- Create: `contracts/lib/privy.cjs`, `contracts/lib/session-service.cjs`, `contracts/test/session-service.cjs`
- Delete: `contracts/lib/auth-service.cjs`, `contracts/api/auth-nonce.js`, `contracts/api/auth-verify.js`, `contracts/scripts/test-auth.cjs`

**Interfaces:**
- Produces (`privy.cjs`): `verifyPrivyAccessToken(token): Promise<{ privyUserId }>` (jose `jwtVerify` dengan `createRemoteJWKSet('https://auth.privy.io/api/v1/apps/${PRIVY_APP_ID}/jwks.json')`, `issuer: 'privy.io'`, `audience: PRIVY_APP_ID`); `fetchPrivyWallet(privyUserId): Promise<{ wallet, loginMethod }>` (GET `https://auth.privy.io/api/v1/users/{id}`, Basic `appId:appSecret`, header `privy-app-id`; pilih akun `type: 'wallet'` dengan `wallet_client_type: 'privy'` dulu, lalu wallet eksternal; loginMethod dari akun `email`/`google_oauth`/`wallet`). Keduanya bisa diganti lewat `setPrivyForTests({verify, fetchWallet})`.
- Produces (`session-service.cjs`): `exchangePrivyToken(db, accessToken, ip): Promise<{ session, wallet, expiresAt, loginMethod }>`; `requireSession(db, req): Promise<{ wallet, privyUserId }>` (401 "Sesi habis, masuk lagi." bila tidak ada/kedaluwarsa/dicabut); `revokeSession(db, req)`; `checkRateLimit(db, key, limit, windowMs)` (429); `withIdempotency(db, wallet, key, run)` (400 bila key kosong / >128 karakter; baris `status='pending'` dikunci dengan `INSERT ... ON CONFLICT DO NOTHING`, request kedua menunggu polling ≤ 20 dtk lalu mengembalikan `response` yang sama; error menghapus baris).
- Produces: `sessionWalletForSocket(db, token): Promise<{ wallet } | null>` untuk Task 9.

- [ ] **Step 1: Tulis tes gagal** (Privy di-stub, DB PGlite): tukar token valid → sesi tersimpan sebagai hash; token Privy invalid → 401; `requireSession` dengan sesi kedaluwarsa → 401; `revokeSession` lalu `requireSession` → 401; rate limit ke-31 dalam satu menit → 429; dua `withIdempotency` paralel dengan key sama → `run` dipanggil sekali, kedua hasil sama.
- [ ] **Step 2:** → FAIL. **Step 3:** implementasi. **Step 4:** → PASS. Hapus `test/game-action-policy.cjs` lama (Phase 0) di task ini atau Task 4.
- [ ] **Step 5:** Commit `Replace wallet signature auth with Privy sessions`.

### Task 4: Pipeline aksi game + router Vercel tunggal

**Files:**
- Create: `contracts/api/[...path].js` (router), `contracts/lib/http.cjs` (readJson ≤16 KB, CORS dari `TANIIN_ALLOWED_ORIGIN`, httpError, kirim JSON), `contracts/lib/player-service.cjs`, `contracts/test/game-actions.cjs`
- Modify: `contracts/lib/game-action-service.cjs` (hapus `assertPhase0ActionEnabled`, antrean memori, `usedFundingTransactions` → tabel `funding_txs`; ubah jadi `executeChainOps(service, wallet, chainOps, extra): Promise<{ txHash, txHashes }>`), `contracts/scripts/game-api.cjs` (server lokal memakai router yang sama), `contracts/vercel.json`
- Delete: `contracts/api/game-actions.js`, `contracts/api/health.js`, `contracts/api/wallet-connect.js`, `contracts/wallet-connect/`, `contracts/public/wallet-connect.*`

**Interfaces:**
- Consumes: Task 1–3.
- Produces route (path publik lewat rewrite di `vercel.json`, `functions["api/[...path].js"].maxDuration = 60`):
  - `GET /health` → seperti sekarang + `economyPaused`, `multiplayerUrl`.
  - `POST /auth/privy` `{ accessToken }` → `{ ok, session, wallet, expiresAt, loginMethod }`.
  - `POST /auth/logout` (Bearer) → `{ ok }`.
  - `GET /player` (Bearer) → `{ ok, state, importedGuest }` (buat `newPlayerState` bila belum ada).
  - `POST /player/import` (Bearer) `{ guestState }` → `{ ok, state }`; 409 bila sudah pernah impor atau state server sudah punya aksi.
  - `POST /game-actions` (Bearer + `Idempotency-Key`) `{ type, plotId, seedIndex?, cropIndex?, quantity?, amount?, paymentTxHash? }` → `{ ok, txHash, txHashes, state }`.
- Alur `/game-actions` di `player-service.cjs` `runGameAction(db, session, body, idemKey)`: kill switch → rate limit wallet+IP → idempotency → `db.transaction`: `SELECT state ... FOR UPDATE` → `applyAction` → cek & tambah `daily_usage` → `pg_advisory_xact_lock(7271)` → `executeChainOps` → simpan state + `audit_log` → commit. Error apa pun membatalkan transaksi DB (state lama), lalu ditulis ke `audit_log` di luar transaksi.
- `executeChainOps` mengembalikan tx hash tanpa menunggu konfirmasi, kecuali langkah yang sekarang memakai `sendConfirmedTransaction` (burn TANI sebelum memberi benih/ETH, panen).
- `/unduh` dan `/unduh/Taniin.apk` di `vercel.json`: redirect 302 ke `https://github.com/rhmatzeka/TaniinPlaytoEarn/releases/download/apk-terbaru/Taniin.apk`.

- [ ] **Step 1: Tulis tes gagal** `test/game-actions.cjs` (DB PGlite, Privy stub, `executeChainOps` stub yang mengembalikan hash palsu atau melempar):
  - tanpa Bearer → 401; tanpa `Idempotency-Key` → 400; `TANIIN_ECONOMY_PAUSED=true` → 503.
  - `HARVEST` valid → 200, `state` berisi panen baru, audit_log 1 baris `ok`.
  - stub chain melempar → status 502, `GET /player` mengembalikan state sebelum aksi.
  - `SWAP_COIN_ETH` melewati batas harian 0,01 ETH → 429 "Batas harian".
  - `POST /player/import` kedua → 409.
  - dua `/game-actions` paralel key sama → stub chain dipanggil sekali.
- [ ] **Step 2:** → FAIL. **Step 3:** implementasi. **Step 4:** `npx hardhat test` (semua) → PASS; `node scripts/game-api.cjs` lokal lalu `curl localhost:8787/health` → `{"ok":true,...}`.
- [ ] **Step 5:** Commit `Serve server-validated game actions from one router`.

### Task 5: Halaman login Privy `/masuk`

**Files:**
- Create: `contracts/masuk/app.jsx`, `contracts/masuk/masuk.css`, `contracts/public/masuk/index.html`
- Modify: `contracts/package.json` (deps `@privy-io/react-auth`; hapus `connectkit`, `wagmi`, `@tanstack/react-query` bila tidak dipakai Privy; script `build:masuk` esbuild → `public/masuk/masuk.js` dengan `--define:process.env.PRIVY_APP_ID` dari env saat build)

**Interfaces:**
- Consumes: `POST /auth/privy`, `GET /health` (alamat signer untuk isi ETH).
- Query: `return` (wajib salah satu dari `taniin://auth` atau path same-origin yang diawali `/main/`; nilai lain → pakai `/main/`), `aksi` (`masuk` default | `isi-eth`), `jumlah` (koin, untuk isi-eth).
- Mode `masuk`: Privy login (email, Google, wallet), `embeddedWallets.ethereum.createOnLogin: 'users-without-wallets'`, chain Sepolia. Lalu `getAccessToken()` → `POST /auth/privy` → redirect ke `return#session=...&wallet=...&expires=...&method=...`.
- Mode `isi-eth`: kirim `jumlah × ethWeiPerCoin` wei dari wallet Privy ke signer (`useSendTransaction`), lalu redirect ke `return#fundTx=<hash>&jumlah=<n>`.
- Tampilan bergaya pixel game (font dan palet dari `taniin_theme.dart`), satu kartu, teks Indonesia, terbaca di lebar 360 px.

- [ ] **Step 1:** `npm run build:masuk` menghasilkan bundel tanpa error. Uji manual di browser lokal (`python3 -m http.server` di `public/` + `game-api` lokal): halaman tampil, tombol Masuk membuka modal Privy (butuh `PRIVY_APP_ID` asli; bila belum ada, cek modal error yang ramah "Login belum dikonfigurasi").
- [ ] **Step 2:** Tes Playwright `taniin_flutter/e2e/masuk.spec.*` (ikuti gaya e2e yang ada): `return=https://jahat.example` diganti ke `/main/`; tanpa App ID → pesan ramah.
- [ ] **Step 3:** Commit `Add Privy login page`.

### Task 6: Flutter — sesi Privy dan bridge

**Files:**
- Create: `taniin_flutter/lib/src/chain/auth_session.dart`, `taniin_flutter/test/auth_session_test.dart`
- Modify: `lib/src/chain/platform_bridge.dart` (ganti `walletConnectUrl`/`launchWalletAddress`/browser wallet dengan `loginUrl(config, {aksi, jumlah})` dan `launchAuthFragment()`), `lib/src/chain/chain_client.dart` (`ChainConfig` tambah `multiplayerUrl` dari `TANIIN_MULTIPLAYER_URL`; hapus `walletConnectUrl`), `android/app/src/main/AndroidManifest.xml` (intent filter `taniin://auth`), `MainActivity.kt` (teruskan fragmen `taniin://auth#...` lewat method `authCallback`, buka URL di browser eksternal / Custom Tab), `android/app/build.gradle.kts` (`TANIIN_MULTIPLAYER_URL` BuildConfig)
- Delete: `lib/src/chain/browser_wallet_web.dart` dan stub-nya bila tidak dipakai lagi

**Interfaces:**
- Produces: `class AuthSession { final String token, wallet, loginMethod; final DateTime expiresAt; bool get isExpired; Map toJson(); static AuthSession? fromJson(Map); static AuthSession? fromFragment(String fragment, DateTime now) }` (null bila wallet invalid / kedaluwarsa / token kosong).
- Produces: `class FundCallback { final String txHash; final int amount; static FundCallback? fromFragment(String) }`.
- Produces: `PlatformBridge.setAuthCallbackHandler(void Function(String fragment)?)`, `PlatformBridge.launchAuthFragment(): String` (web: baca `Uri.base.fragment` lalu bersihkan), `PlatformBridge.loginUrl(ChainConfig, {String aksi = 'masuk', int? jumlah}): String`.

- [ ] **Step 1: Tes gagal** `auth_session_test.dart`: fragmen valid → objek; wallet `0x123` → null; `expires` lampau → null; round-trip `toJson/fromJson`; fragmen `fundTx=0xabc..&jumlah=200` → `FundCallback`.
- [ ] **Step 2:** `cd taniin_flutter && flutter test test/auth_session_test.dart` → FAIL. **Step 3:** implementasi. **Step 4:** → PASS; `flutter analyze` bersih.
- [ ] **Step 5:** Commit `Add Privy session model and callbacks`.

### Task 7: Flutter — state dari server untuk pemain login

**Files:**
- Modify: `lib/src/state/farm_state.dart`, `lib/src/chain/chain_client.dart`, `test/widget_test.dart` (atau buat `test/server_state_test.dart`)

**Interfaces:**
- Consumes: Task 4 routes, Task 6 `AuthSession`.
- Produces di `ChainClient`: `exchange` tidak perlu (dilakukan halaman `/masuk`); `fetchPlayer(AuthSession) → ServerPlayerResult`, `importGuest(AuthSession, Map guestState) → ServerPlayerResult`, `submitGameAction(AuthSession, ChainAction, String idempotencyKey) → ChainResult` (header `Authorization: Bearer`, `Idempotency-Key`; `ChainResult` membawa `state` bila ada dan `unauthorized` bila 401), `logout(AuthSession)`.
- Produces di `FarmStateController`: `AuthSession? session`, `bool get isLoggedIn`, `Future<void> applyAuthSession(AuthSession)` (simpan, `fetchPlayer`, bila `importedGuest == false` dan state server masih baru → `importGuest(_toSaveJson())`, lalu terapkan snapshot), `void applyServerState(Map)` (menimpa field ekonomi; field non-ekonomi seperti audio dan nama tampilan tetap lokal), `Future<void> logout()` (kembali ke state tamu lokal yang tersimpan terpisah, kunci simpan `taniin.farmState.v1` untuk tamu dan sesi di `taniin.session.v1`).
- Perilaku aksi saat login: update optimis lokal tetap boleh untuk responsif, lalu respons server **selalu** menimpa dengan `state`. Saat 401 → `logout()` + pesan "Sesi habis, masuk lagi." Kunci idempotency: UUID v4 per aksi, dibuat sekali dan dipakai ulang saat retry.
- Mode tamu: tidak ada request `/game-actions`, riwayat bertanda "lokal".
- `FundCallback` dari halaman `/masuk?aksi=isi-eth` → kirim `SWAP_ETH_COIN` dengan `paymentTxHash` dan `amount` dari callback (menggantikan alur pendanaan ETH lama `_swapEthToGameCoin`).
- `ChainAction.toGameApiJson` mengirim `seedIndex`/`cropIndex`/`quantity` eksplisit, bukan `amount` campur `plotId`.

- [ ] **Step 1: Tes gagal** (ChainClient palsu lewat `chainClientFactory`): login → `importGuest` dipanggil sekali dengan state tamu; respons `/game-actions` dengan coins 999 → `controller.coins == 999`; respons 401 → `isLoggedIn == false` dan pesan sesi habis; tamu menanam → tidak ada panggilan jaringan.
- [ ] **Step 2:** → FAIL. **Step 3:** implementasi. **Step 4:** `flutter test` (semua, termasuk tes progression/wardrobe yang sudah ada) → PASS; `flutter analyze` bersih.
- [ ] **Step 5:** Commit `Use server state for signed-in players`.

### Task 8: Flutter — UI login, status, error, riwayat

**Files:**
- Modify: `lib/src/ui/wallet_panel.dart` (tombol **Masuk dengan Privy**, info akun: alamat singkat + metode login, tombol Keluar, tombol Isi koin dari ETH → `loginUrl(aksi: 'isi-eth')`; hapus input alamat manual dan pilihan wallet), `lib/src/ui/game_hud.dart` (baris indikator kecil: Akun, Sepolia, Server, Multiplayer, AI — hijau/abu/merah dengan label teks, bukan warna saja), `lib/src/ui/history_panel.dart` (status: Lokal, Dikirim, Menunggu konfirmasi, Terkonfirmasi, Gagal), `lib/src/state/farm_state.dart` (`_conciseChainError` memetakan: 401 → "Sesi habis, masuk lagi.", 409 → pesan server, 429 → "Pelan-pelan, coba lagi sebentar.", 503 → "Ekonomi on-chain sedang dijeda.", timeout → "Server lambat, aksi disimpan lokal.", saldo signer → "Hadiah ETH sedang habis, coba nanti.")
- Test: `test/widget_test.dart`

- [ ] **Step 1: Tes widget gagal:** panel wallet tamu menampilkan "Masuk dengan Privy" dan tidak ada field alamat; setelah `applyAuthSession` panel menampilkan alamat singkat dan "Keluar"; indikator HUD punya 5 label.
- [ ] **Step 2:** → FAIL. **Step 3:** implementasi (gaya `pixel_panel.dart`/`taniin_theme.dart`). **Step 4:** `flutter test` → PASS.
- [ ] **Step 5:** Commit `Polish login, status and history UI`.

### Task 9: Multiplayer dengan sesi + URL terpisah

**Files:**
- Modify: `contracts/lib/multiplayer-service.cjs` (join: `{ session? , name, skinId }` → bila sesi valid via `sessionWalletForSocket` (cache 5 menit) pakai wallet + nama profil; tanpa sesi → `Tamu-xxxx`; chat maks 1 pesan/2 dtk per socket, panjang ≤ 300, buang karakter kontrol; CORS `TANIIN_ALLOWED_ORIGIN`), `contracts/test/multiplayer-cosmetics.cjs` (tambah kasus), `taniin_flutter/lib/src/chain/multiplayer_client.dart` (host dari `chainConfig.multiplayerUrl`; kosong → tidak konek dan status "Multiplayer offline"; kirim `session` saat join; backoff reconnect maks 30 dtk tanpa spam log/pesan)
- Create: `contracts/Dockerfile.multiplayer` atau unit systemd `deploy/taniin-mp.service` (ikuti pola layanan di srv saat Task 11)

**Interfaces:**
- Consumes: `sessionWalletForSocket` (Task 3).
- Produces: event Socket.IO tidak berubah (`init`, `player_joined`, `player_moved`, `player_left`, `ai_*`, `chat_message`), payload `join` menambah `session`.

- [ ] **Step 1: Tes gagal:** join tanpa sesi → nama diawali `Tamu-`; join dengan sesi valid → wallet dari sesi, bukan dari payload; chat kedua dalam 1 dtk dibuang; pesan berisi `\u0000` dibersihkan. Flutter: `multiplayerUrl` kosong → `connected == false`, tidak ada percobaan koneksi.
- [ ] **Step 2:** → FAIL. **Step 3:** implementasi. **Step 4:** `npx hardhat test` + `node scripts/e2e-multiplayer.cjs` + `flutter test` → PASS.
- [ ] **Step 5:** Commit `Authenticate multiplayer joins and split its URL`.

### Task 10: Halaman depan, game di `/main/`, CI APK

**Files:**
- Create: `contracts/public/index.html` + `contracts/public/landing.css` (halaman depan: judul, 3–4 screenshot asli di `contracts/public/img/`, tombol **Main di browser** → `/main/`, **Unduh APK** → `/unduh`, paragraf singkat cara kerja Web3, link GitHub; gaya pixel; lebar 360 px tanpa scroll horizontal), `scripts/build-web.sh` (build Flutter `--release --base-href /main/` + dart-define publik → salin ke `contracts/public/main/`, lalu `npm run build:masuk`), `.github/workflows/android.yml`
- Modify: `contracts/vercel.json` (header no-store untuk `/main/index.html`, `/main/flutter_bootstrap.js`, `/main/main.dart.js`, `/main/flutter_service_worker.js`; hapus entri root lama), `taniin_flutter/android/app/build.gradle.kts` (`signingConfigs.tetap` membaca `android/app/taniin.keystore` + env `TANIIN_KEYSTORE_PASSWORD` bila file ada, fallback debug), `.gitignore` (`*.keystore`), e2e web yang ada (URL ke `/main/`)
- Delete: build Flutter lama di root `contracts/public/` (`main.dart.js`, `flutter*.js`, `canvaskit/`, `assets/` milik Flutter, `manifest.json`, `version.json`)

Workflow `android.yml`: trigger `push` ke `main` pada path `taniin_flutter/**` + `workflow_dispatch`; Java 17, Flutter stable; tulis `.env` publik dari `vars` repo; decode secret `TANIIN_KEYSTORE_B64`; `flutter build apk --release`; salin ke `Taniin.apk`; `gh release upload apk-terbaru Taniin.apk --clobber` (buat release bila belum ada). Tidak ada commit dari CI.

- [ ] **Step 1:** Buat keystore sekali: `keytool -genkeypair -keystore ~/.config/taniin/taniin.keystore -alias taniin -keyalg RSA -keysize 2048 -validity 10000` (pasang JDK headless bila belum ada). Simpan secret `TANIIN_KEYSTORE_B64`, `TANIIN_KEYSTORE_PASSWORD` dengan `gh secret set`, variabel publik dengan `gh variable set`.
- [ ] **Step 2:** `./scripts/build-web.sh` sukses; `python3 -m http.server 4174 -d contracts/public` → `/` halaman depan, `/main/` game jalan; e2e web (`npm run e2e:web` dengan base `/main/`) → PASS.
- [ ] **Step 3:** Push branch, jalankan workflow manual → release `apk-terbaru` berisi `Taniin.apk`; `apksigner verify --print-certs` sertifikat sama di dua build berturut-turut.
- [ ] **Step 4:** Commit `Add landing page, /main game path and APK release workflow`.

### Task 11: Deploy, porto, README

**Files:**
- Modify: `README.md`, `docs/taniin-improvement-plan.md` (tandai gap yang selesai), memory/vault catatan Taniin, repo porto Mapporto (kartu Taniin: link main `https://taniin.rahmateka.my.id`, link unduh `/unduh`)

- [ ] **Step 1: Akun pemilik** (pandu dengan bahasa sederhana, satu langkah sekali jalan): Privy app (App ID ke `.env` lokal + env Vercel; App Secret langsung ke env Vercel/srv), Neon (project + branch `dev`; `DATABASE_URL` ke env), akses Vercel.
- [ ] **Step 2:** `ensureSchema` ke Neon production; isi env Vercel (`DATABASE_URL`, `PRIVY_APP_ID`, `PRIVY_APP_SECRET`, `DEPLOYER_PRIVATE_KEY` yang sudah ada, batas, `TANIIN_ALLOWED_ORIGIN=https://taniin.rahmateka.my.id`, `TANIIN_MULTIPLAYER_URL`); deploy; `curl https://taniin.rahmateka.my.id/health` → `ok: true, economyPaused: false`.
- [ ] **Step 3:** srv: pasang layanan multiplayer (pola container/systemd yang ada di srv), Cloudflare Tunnel `mp.taniin.rahmateka.my.id`, env `DATABASE_URL`, `GROQ_API_KEY`, `TANIIN_ALLOWED_ORIGIN`. Cek dua browser saling terlihat.
- [ ] **Step 4: Verifikasi akhir sesuai spec "Cara memeriksa selesai":** tamu main + unduh APK; login email di web & APK, beli benih → tanam → panen → jual, tx hash terbuka di Etherscan; request tanpa sesi/sesi palsu/jumlah aneh ditolak; Pak Tani AI menjawab chat. Screenshot ke `contracts/public/img/` dan README.
- [ ] **Step 5:** Kartu porto Mapporto diperbarui (push langsung sesuai aturan Mapporto). PR `feat/privy-rilis` → `main` di repo Taniin, merge setelah verifikasi.
