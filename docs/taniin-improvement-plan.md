# Taniin Improvement Plan

Dokumen ini merangkum rencana peningkatan Taniin untuk kebutuhan pameran, kualitas produk, integrasi multi-wallet, keamanan Web3, AI agent, multiplayer, dan maintainability codebase.

## Tujuan Utama

- Membuat Taniin terlihat kuat sebagai game farming digital dengan AI agent, multiplayer, dan Web3, bukan hanya prototype wallet Sepolia.
- Menghapus kesan MetaMask-only dengan dukungan multi-wallet yang lebih modern.
- Membuat flow demo pameran stabil, mudah dijelaskan, dan tahan terhadap koneksi/wallet yang gagal.
- Memperbaiki risiko keamanan backend signer dan validasi gameplay.
- Merapikan struktur code agar fitur berikutnya lebih mudah dikembangkan.

## Kondisi Saat Ini

- Flutter/Flame menjadi app utama untuk Android dan Web.
- Wallet connect masih custom melalui halaman `/wallet-connect`.
- Halaman wallet connect hanya mengandalkan `window.ethereum` dan tombol `Open in MetaMask`.
- Flutter membaca ETH/TANI balance melalui custom JSON-RPC client di Dart.
- Transaksi on-chain tidak ditandatangani oleh wallet pemain dari Flutter.
- Gameplay action dikirim ke backend `/game-actions`, lalu backend signer mengirim transaksi ke Sepolia.
- Multiplayer dan AI agent memakai Socket.IO dari backend Node.js.
- State gameplay utama masih lokal di device melalui `shared_preferences`.
- File `taniin_game.dart` dan `farm_state.dart` sangat besar dan perlu dipisah bertahap.

## Kekurangan Dari Plan Awal Yang Perlu Ditambahkan

- Belum ada strategi demo pameran yang tahan gagal jaringan, wallet, RPC, atau backend.
- Belum ada observability untuk melihat error wallet/API/Socket.IO saat demo.
- Belum ada mode fallback yang jelas antara offline demo, local signer, dan deployed signer.
- Belum ada checklist presentasi teknis dan non-teknis.
- Belum ada plan untuk data privacy, abuse prevention, dan cleanup session wallet.
- Belum ada plan untuk UX error state seperti RPC down, wrong network, backend signer kehabisan ETH, atau wallet reject.
- Belum ada plan untuk mobile responsiveness halaman wallet connect.
- Belum ada plan untuk performance Flame rendering, asset loading, dan memory audio.
- Belum ada plan untuk CI/build reproducibility.
- Belum ada plan untuk memisahkan environment public dan secret.

## Roadmap Prioritas

### Phase -1: Scope Cutline And Decision Log

Target phase ini adalah mencegah roadmap terlalu besar dan tidak selesai sebelum pameran.

- Tentukan tanggal pameran dan waktu freeze fitur.
- Pisahkan item menjadi `Must Have`, `Should Have`, `Nice To Have`, dan `After Exhibition`.
- Buat decision log untuk pilihan besar: Reown vs RainbowKit, backend signer vs user-signed tx, local state vs server state, Vercel vs VPS.
- Tetapkan satu path demo utama dan satu path fallback.
- Hindari mengganti banyak arsitektur sekaligus menjelang pameran.
- Tetapkan definisi selesai untuk demo: wallet connect, AI terlihat, farming loop jalan, history tampil, backend health oke.
- Buat daftar fitur yang sengaja tidak dikerjakan untuk pameran agar ekspektasi jelas.

### Phase -0.5: Threat Model And Risk Register

Target phase ini adalah membuat risiko keamanan dan operasional terlihat sejak awal.

- Buat threat model singkat untuk wallet, backend signer, game action API, Socket.IO, AI chat, dan deployed Web.
- Identifikasi attacker utama: user iseng pameran, bot endpoint publik, wallet spoofing, replay request, spam chat, RPC abuse.
- Catat asset yang harus dilindungi: private key signer, session token, wallet identity, contract ownership, signer ETH, API quota.
- Catat risiko tertinggi: endpoint reward tanpa auth, manual wallet impersonation, backend signer abuse, chat spam, replay action.
- Buat risk register dengan severity, likelihood, mitigation, owner, dan status.
- Tambahkan emergency action: pause backend signer, rotate private key, revoke signer role, disable ETH payout, disable game actions.

### Phase -0.25: Data Storage And Session Design

Target phase ini adalah menentukan penyimpanan data sebelum menambah auth dan server-side validation.

- Putuskan apakah session disimpan stateless JWT atau server-side session store.
- Untuk Vercel/serverless, pilih storage yang realistis: Upstash Redis, Vercel KV, Supabase, Neon, atau database ringan lain.
- Simpan nonce login dengan expiry pendek.
- Simpan session dengan expiry dan wallet address.
- Simpan idempotency key untuk game action agar double submit aman.
- Simpan minimal game state server-side jika backend mulai memvalidasi economy.
- Simpan transaction audit log untuk debugging pameran.
- Tentukan retention policy: berapa lama session/log/demo data disimpan.
- Tambahkan cleanup job atau expiry otomatis untuk nonce/session/log demo.

### Phase 0: Stabilkan Demo Pameran

Target phase ini adalah membuat project aman dan nyaman untuk dipamerkan meskipun jaringan, wallet, atau backend bermasalah.

- Buat `docs/demo-guide.md` berisi cara menjalankan Android, Web, backend signer, dan contract config.
- Buat `docs/demo-script.md` berisi alur demo 3-5 menit untuk pengunjung.
- Tambahkan mode demo/offline yang jelas ketika backend signer tidak tersedia.
- Tambahkan indikator status di UI: Wallet, Sepolia RPC, Game API, Multiplayer, AI Agent.
- Tambahkan fallback jika `/health` gagal: game tetap bisa dimainkan lokal tanpa pending transaksi selamanya.
- Tambahkan pesan error yang ramah untuk wrong network, wallet rejected, RPC timeout, signer balance kurang, dan backend offline.
- Siapkan satu wallet Sepolia khusus demo dengan saldo kecil.
- Siapkan satu backend signer khusus demo dengan limit payout rendah.
- Pastikan private key demo tidak pernah masuk repo, screenshot, APK assets, atau Flutter web output.
- Buat checklist sebelum pameran: build APK, test wallet, test backend, test AI chat, test multiplayer, test QR, test Web.

### Phase 1: Multi-Wallet Connect

Target phase ini adalah menghilangkan ketergantungan pada MetaMask saja.

- Ganti halaman `/wallet-connect` menjadi connector page modern.
- Gunakan stack web yang familiar: `wagmi`, `viem`, dan Reown AppKit atau RainbowKit.
- Prioritaskan Reown AppKit jika ingin WalletConnect v2, mobile wallet support, dan QR yang lebih mudah.
- Dukung wallet berikut: MetaMask, WalletConnect, Coinbase Wallet, Trust Wallet, Rabby, OKX Wallet, dan injected provider lain.
- Tambahkan tombol `Pilih Wallet`, bukan `Open in MetaMask`.
- Tambahkan QR connect untuk desktop dan pameran.
- Tambahkan deep link mobile wallet untuk Android.
- Tambahkan provider detection untuk `window.ethereum.providers`.
- Tambahkan `wallet_addEthereumChain` jika Sepolia belum ada di wallet.
- Simpan metadata wallet di Flutter: wallet type, chain ID, connection method, dan verified status.
- Tetap sediakan manual address hanya sebagai demo fallback.
- Tandai manual address sebagai `Demo Mode`, bukan wallet verified.

### Phase 2: Wallet Signature Login

Target phase ini adalah memastikan pemain benar-benar memiliki wallet yang dipakai.

- Tambahkan message signing saat wallet connect.
- Gunakan format SIWE jika memungkinkan.
- Minimal message harus berisi domain, wallet address, nonce, timestamp, chain ID, dan purpose.
- Backend membuat nonce untuk wallet login.
- Wallet menandatangani nonce.
- Backend memverifikasi signature.
- Backend mengembalikan session token jangka pendek.
- Flutter menyimpan session token secara lokal.
- `/game-actions` wajib memakai `Authorization: Bearer <sessionToken>`.
- Backend memastikan session wallet sama dengan `body.wallet`.
- Manual address tidak boleh melakukan on-chain reward kecuali sudah diverifikasi signature.
- Tambahkan logout yang menghapus wallet address, session token, dan metadata koneksi.

### Phase 3: Backend Signer Security

Target phase ini adalah mencegah endpoint reward disalahgunakan.

- Tambahkan auth/session validation di `/game-actions`.
- Tambahkan rate limit per wallet dan per IP.
- Tambahkan allowlist action type.
- Tambahkan batas `plotId`, `amount`, dan action frequency.
- Tambahkan server-side validation untuk gameplay state.
- Jangan percaya `amount` langsung dari client.
- Simpan state minimal di server untuk plot ownership, planted status, harvest cooldown, seed purchase, crop inventory, dan last action.
- Tambahkan idempotency key agar action double-tap tidak mint dua kali.
- Tambahkan audit log untuk setiap action: wallet, action, amount, plotId, txHash, timestamp, result, error.
- Tambahkan limit harian mint/reward untuk demo.
- Tambahkan signer balance guard sebelum menerima action yang butuh ETH payout.
- Tambahkan CORS yang eksplisit untuk domain deploy, bukan wildcard untuk production.
- Tambahkan validasi JSON body size.

### Phase 4: Gameplay Economy Validation

Target phase ini adalah membuat ekonomi game lebih konsisten antara local state, backend, dan on-chain state.

- Definisikan sumber kebenaran untuk coin, TANI, seed, crop, dan land.
- Untuk prototype, tetapkan dengan jelas mana yang local-only dan mana yang on-chain.
- Buat mapping action economy: buy land, sell land, buy seed, plant, harvest, sell crop, swap coin, swap TANI, swap ETH.
- Validasi saldo coin sebelum beli seed/lahan.
- Validasi seed quantity sebelum plant.
- Validasi crop ready sebelum harvest.
- Validasi crop inventory sebelum sell crop.
- Validasi signer bukan wallet pemain saat ETH payout.
- Tambahkan anti-spam harvest berdasarkan grow duration server-side.
- Tambahkan reconciliation saat wallet connect: local state vs on-chain balance.
- Tambahkan pesan status jika on-chain state berbeda dari local state.

### Phase 5: AI Agent Experience

Target phase ini adalah membuat AI agent terlihat sebagai fitur utama saat pameran.

- Tambahkan panel `AI Farmer` di UI.
- Tampilkan status `AI Agent Online` atau `AI Agent Offline`.
- Tambahkan chat bubble di atas karakter AI.
- Tambahkan quick prompts: `Bantu tanam`, `Apa yang bisa dipanen?`, `Jelaskan Web3`, `Bantu beli bibit`, `Apa strategi farming terbaik?`.
- Tambahkan log aksi AI: AI moved, AI planted, AI harvested, AI suggested.
- Tambahkan animasi atau highlight ketika AI melakukan aksi.
- Tambahkan fallback local AI response jika backend AI offline.
- Tambahkan batas chat length dan rate limit chat.
- Sanitize chat text sebelum ditampilkan.
- Tambahkan narasi pameran yang menjelaskan AI sebagai farm assistant, bukan NPC biasa.

### Phase 6: Multiplayer Hardening

Target phase ini adalah membuat multiplayer tidak mudah spoof dan tetap stabil.

- Gunakan session token wallet untuk Socket.IO join.
- Jangan percaya wallet/name dari client tanpa session.
- Batasi panjang nama pemain.
- Batasi frekuensi update posisi.
- Clamp posisi pemain di server agar tidak keluar map.
- Tambahkan rate limit chat.
- Sanitize pesan chat.
- Tambahkan reconnect state yang jelas di UI.
- Tambahkan status jumlah pemain online.
- Tambahkan fallback jika Socket.IO gagal: game tetap single-player.
- Tambahkan e2e multiplayer test untuk join, move, chat, leave, dan AI event.

### Phase 7: Refactor Flutter State

Target phase ini adalah mengurangi risiko dari `farm_state.dart` yang terlalu besar.

- Pecah domain state secara bertahap tanpa mengubah behaviour besar sekaligus.
- Buat model untuk wallet: `wallet_state.dart`.
- Buat model untuk inventory: `inventory_state.dart`.
- Buat model untuk plots: `plot_state.dart`.
- Buat service history: `transaction_history.dart`.
- Buat service chain action queue: `chain_action_queue.dart`.
- Buat model swap: `swap_state.dart`.
- Kurangi mutable public fields.
- Tambahkan command method yang jelas: `buySeed`, `buyLand`, `plant`, `harvest`, `sellCrop`, `swapAsset`.
- Return action result dari command agar UI tidak membaca terlalu banyak internal state.
- Pertahankan backward compatibility hanya untuk saved local state `taniin.farmState.v1`.
- Tambahkan migration jika save schema berubah.

### Phase 8: Refactor Flame Game

Target phase ini adalah mengurangi risiko dari `taniin_game.dart` yang terlalu besar.

- Pisahkan player movement dan collision ke file sendiri.
- Pisahkan interaction detection untuk shop, sell house, swap house, dan plot.
- Pisahkan minimap renderer.
- Pisahkan remote player renderer.
- Pisahkan AI agent renderer.
- Pisahkan map loading dan asset loading.
- Tambahkan debug overlay opsional untuk collision dan interaction bounds.
- Hindari perubahan rendering besar dalam satu PR.
- Tambahkan golden/smoke test jika memungkinkan untuk widget utama.

### Phase 9: Web3 Client Cleanup

Target phase ini adalah membuat Web3 integration lebih mudah dipahami dan dites.

- Dokumentasikan bahwa Flutter memakai custom JSON-RPC untuk read-only Web3.
- Pertimbangkan memakai `web3dart` hanya jika benar-benar mengurangi custom encoding.
- Tetap pertahankan custom JSON-RPC jika lebih kecil dan stabil.
- Pisahkan ABI encoding ERC-20 ke helper sendiri.
- Tambahkan unit test untuk address validation, tx hash validation, ETH formatting, ERC-20 balance parsing, dan RPC error handling.
- Tambahkan timeout dan retry policy yang konsisten.
- Tambahkan fallback RPC URL khusus demo jika public RPC down.
- Tampilkan RPC provider yang sedang dipakai di debug/status panel.

### Phase 10: UI/UX Polish

Target phase ini adalah membuat game terasa siap demo, bukan hanya bekerja secara teknis.

- Tambahkan onboarding singkat: connect wallet, gerak, beli bibit, tanam, panen, jual.
- Tambahkan tooltip untuk shop, sell house, swap house, AI, wallet, history.
- Tambahkan status transaction lifecycle: local saved, sent to API, tx submitted, confirmed, failed.
- Tambahkan toast/error panel yang tidak menutup gameplay berlebihan.
- Tambahkan empty state untuk backpack/history.
- Tambahkan loading state untuk wallet balance dan chain action.
- Tambahkan copy bahasa Indonesia yang konsisten.
- Pastikan tampilan landscape Android aman untuk notch/cutout.
- Pastikan halaman wallet responsive di mobile.
- Tambahkan tombol `Coba Lagi` untuk wallet/RPC/API error.

### Phase 11: Performance And Stability

Target phase ini adalah menjaga game tetap lancar saat demo.

- Profiling Flame rendering di Android device target.
- Cek apakah minimap cache sudah cukup efisien.
- Pastikan asset besar tidak reload berulang.
- Pastikan audio release/pause/resume tidak leak.
- Pastikan Socket.IO reconnect tidak membuat multiple socket aktif.
- Tambahkan guard untuk disposed notifier/listener.
- Tambahkan frame-time debug mode untuk pameran internal.
- Optimalkan image assets jika APK terlalu besar.
- Pastikan build Web tidak membawa file yang tidak perlu.

### Phase 12: Testing And CI

Target phase ini adalah membuat perubahan lebih aman.

- Tambahkan unit test untuk farming economy.
- Tambahkan widget test untuk wallet panel, history panel, backpack panel, and AI panel.
- Tambahkan fake `ChainClient` test untuk sukses/gagal wallet load.
- Tambahkan backend test untuk `/health`, `/game-actions`, invalid wallet, invalid action, auth missing, rate limit.
- Tambahkan e2e test Web untuk loading, connect fallback, open wallet panel, basic farming action.
- Tambahkan e2e Socket.IO untuk multiplayer dan AI.
- Tambahkan CI minimal: Flutter analyze, Flutter test, Node test, Hardhat compile.
- Tambahkan build command documentation untuk Windows/WSL dan Linux.

### Phase 13: Documentation And Presentation

Target phase ini adalah membuat project mudah dijelaskan ke dosen, juri, atau pengunjung.

- Update `taniin_flutter/README.md` agar tidak lagi template Flutter default.
- Tambahkan `docs/architecture.md`.
- Tambahkan diagram arsitektur:

```text
Flutter/Flame Game
  -> PlatformBridge
  -> Wallet Connect Page
  -> Backend Session/Auth
  -> Game Action API
  -> Sepolia Contracts

Flutter/Flame Game
  -> Socket.IO
  -> Multiplayer Service
  -> AI Agent Service
```

- Tambahkan `docs/web3-flow.md`.
- Tambahkan `docs/ai-agent.md`.
- Tambahkan `docs/security-notes.md`.
- Tambahkan screenshot terbaik ke `docs/screenshots/`.
- Pindahkan screenshot debug `adb_*.png` dari root ke `docs/screenshots/debug/` atau ignore jika tidak perlu.
- Tambahkan pitch singkat 30 detik, 1 menit, dan 3 menit.
- Tambahkan FAQ: apakah ini mainnet, apakah pakai uang asli, apakah wallet harus MetaMask, apakah AI benar-benar agent.

### Phase 14: Release Packaging And Rollback

Target phase ini adalah memastikan build yang dipakai di pameran bisa direproduksi dan dikembalikan jika ada bug.

- Buat tag/release candidate untuk build pameran.
- Simpan APK final di folder release lokal atau GitHub Release jika digunakan.
- Catat commit hash, contract address, backend URL, dan env public untuk build pameran.
- Buat checklist build: clean, pub get, analyze, test, assembleDebug/release, install, smoke test.
- Buat rollback plan: APK lama, backend lama, env lama, dan contract address lama.
- Jangan deploy perubahan besar pada hari pameran tanpa smoke test.
- Tambahkan version display kecil di debug/status panel: app version, build number, API URL, commit hash jika tersedia.

### Phase 15: Asset Licensing And Credits

Target phase ini adalah menghindari masalah lisensi asset saat project dipamerkan atau dipublikasikan.

- Audit semua assets game, tileset, character, audio, image, dan font.
- Buat `docs/credits.md` berisi sumber asset dan lisensinya.
- Pastikan asset boleh dipakai untuk demo publik.
- Pastikan attribution sesuai lisensi.
- Pisahkan asset yang tidak jelas lisensinya dan ganti jika perlu.
- Tambahkan credit screen sederhana di settings/about panel.
- Pastikan screenshot/video pameran tidak menampilkan data sensitif.

### Phase 16: Privacy And Data Handling

Target phase ini adalah membuat penggunaan wallet dan chat lebih bertanggung jawab.

- Jelaskan bahwa wallet address adalah public identifier.
- Jangan menyimpan private key, seed phrase, atau signature mentah lebih lama dari yang dibutuhkan.
- Jangan log full session token.
- Masking wallet address di UI dan logs jika full address tidak dibutuhkan.
- Tambahkan tombol disconnect dan clear local data.
- Tambahkan policy singkat di wallet connect page: data apa yang dibaca dan untuk apa.
- Tambahkan moderasi dasar untuk chat jika dipakai publik.

### Phase 17: Cost, Quota, And Dependency Risk

Target phase ini adalah mencegah demo gagal karena layanan gratis terkena limit.

- Catat RPC provider yang dipakai dan limitnya.
- Siapkan fallback RPC Sepolia.
- Catat Vercel/serverless limits.
- Catat WalletConnect/Reown project ID dan limitnya.
- Siapkan koneksi internet cadangan.
- Siapkan local backend mode jika Vercel bermasalah.
- Siapkan browser/device cadangan untuk wallet connect.
- Pastikan signer wallet punya ETH Sepolia cukup untuk demo tapi tidak terlalu besar.
- Tambahkan warning ketika signer balance di bawah minimum demo.

### Phase 18: Accessibility And Device Compatibility

Target phase ini adalah memastikan demo bisa dipakai nyaman di perangkat pameran.

- Test di device Android fisik target.
- Test di emulator hanya sebagai backup, bukan patokan utama.
- Pastikan touch target cukup besar untuk landscape mobile.
- Pastikan teks penting terbaca di layar kecil.
- Pastikan warna status/error cukup kontras.
- Pastikan game bisa dimainkan tanpa keyboard.
- Pastikan keyboard movement tetap bekerja untuk Web/desktop.
- Pastikan sound bisa dimatikan cepat saat kondisi pameran ramai.
- Tambahkan volume preset atau mute all.

### Phase 19: Product Narrative And Evaluation Metrics

Target phase ini adalah membuat project lebih mudah dinilai, bukan hanya terlihat ramai fitur.

- Tetapkan problem statement: game farming yang mengenalkan Web3 dengan bantuan AI agent.
- Tetapkan unique selling points: AI farmer assistant, multi-wallet Web3, asset ownership prototype, multiplayer farming.
- Tetapkan demo success metrics: connect wallet berhasil, AI response terlihat, transaksi tercatat, pemain memahami flow.
- Siapkan jawaban untuk pertanyaan juri: kenapa blockchain, kenapa AI, kenapa backend signer, kenapa Sepolia, apa risiko security.
- Buat perbandingan singkat dengan game farming biasa dan dApp biasa.
- Tambahkan slide arsitektur sederhana untuk menjelaskan backend signer dan AI service.

## Multi-Wallet Technical Plan

### Recommended Stack

- `wagmi` untuk wallet/account state di connector page.
- `viem` untuk chain config, public client, dan signature verification compatibility.
- Reown AppKit untuk WalletConnect v2 dan wallet discovery.
- Sepolia sebagai chain utama.

### Connector Page Flow

```text
Game opens /wallet-connect?return=taniin://wallet
User chooses wallet
Connector switches/adds Sepolia
Connector requests account
Connector requests message signature
Connector sends address/signature/nonce to backend
Backend verifies and creates session
Connector redirects to taniin://wallet?address=...&session=...&walletType=...
Flutter receives deep link and stores connection metadata
```

### Web Flutter Flow

```text
Flutter Web opens same-origin wallet connect
User connects wallet
Connector redirects back to current URL with address/session
PlatformBridge reads query params
FarmState connects verified wallet
```

### Android Flow

```text
Flutter Android calls PlatformBridge.openUrl
Android opens browser/wallet page
User connects wallet
Page redirects to taniin://wallet
MainActivity receives deep link
MethodChannel sends walletAddress/session to Flutter
FarmState connects verified wallet
```

### Data To Return To Flutter

- `address`
- `chainId`
- `session`
- `walletType`
- `connector`
- `verified=true|false`
- `expiresAt`

## Backend API Plan

### New Endpoints

- `GET /health`: current health, signer balance, chain ID, contract addresses.
- `POST /auth/nonce`: create login nonce for wallet.
- `POST /auth/verify`: verify wallet signature and return session token.
- `POST /game-actions`: authenticated gameplay action endpoint.
- `GET /game-state`: optional server-side state snapshot.
- `GET /transactions`: optional transaction history from server.

### Auth Requirements

- `/game-actions` must require bearer token.
- Token must map to verified wallet.
- Body wallet must equal token wallet.
- Token should expire.
- Logout should invalidate token if server stores sessions.

### Rate Limits

- Wallet login nonce: per IP and wallet.
- Verify signature: per IP and wallet.
- Game actions: per wallet/action type.
- Chat: per session.
- Multiplayer movement: throttle server-side.

## Smart Contract Plan

### Current Role

- `TaniinCoin`: ERC-20 reward token.
- `TaniinLand`: ERC-721 plot ownership.
- `TaniinItems`: ERC-1155 seeds and crops.

### Improvements

- Review access control for mint/burn/gameSpend functions.
- Ensure only authorized backend signer/game role can mint rewards.
- Add events for important game actions if not already enough.
- Consider pausable emergency switch for demo signer abuse.
- Consider per-wallet or per-plot constraints on-chain only if needed.
- Keep heavy gameplay validation off-chain for prototype simplicity.

## Demo Mode Policy

Demo mode harus jelas agar tidak menyesatkan pengunjung.

- Offline local play: no wallet, no on-chain reward.
- Manual wallet mode: wallet address only, no ownership proof.
- Verified wallet mode: wallet signature verified.
- On-chain mode: backend signer available and action submitted to Sepolia.
- Jika action gagal on-chain, gameplay lokal tetap bisa lanjut dengan status `local only`.

## Environment Plan

### Split Env Files

- `.env.public.example` untuk Flutter Android/Web public values.
- `.env.server.example` untuk backend signer.
- `.env.contracts.example` untuk deploy contracts.

### Public Values

- `SEPOLIA_RPC_URL`
- `TANIIN_COIN_CONTRACT_ADDRESS`
- `TANIIN_ITEMS_CONTRACT_ADDRESS`
- `TANIIN_LAND_CONTRACT_ADDRESS`
- `TANIIN_GAME_API_URL`
- `TANIIN_DEFAULT_WALLET_ADDRESS`

### Secret Values

- `DEPLOYER_PRIVATE_KEY`
- Any session secret/JWT secret.
- Any WalletConnect/Reown secret that must not ship to client.

## Observability Plan

- Add backend structured logs for auth, game actions, transaction submissions, transaction failures, and Socket.IO connections.
- Add request IDs for `/game-actions`.
- Show debug code/error ID in game UI for easier troubleshooting during pameran.
- Add `/health` details: signer address, signer balance, RPC chain, contract addresses, multiplayer status, AI status.
- Add optional in-game debug panel hidden behind long press or settings toggle.
- Log wallet connector type and failure reason without logging private data or signatures unnecessarily.

## UX Error States

### Wallet Error

- User rejects connection: show `Koneksi wallet dibatalkan.`
- Wallet not installed: show multi-wallet options and QR.
- Wrong network: show `Ganti ke Sepolia` with retry.
- Sepolia missing: add chain automatically if wallet supports it.
- Signature rejected: connect address but mark as unverified/demo only.

### Backend Error

- API offline: `Mode lokal aktif. Aksi belum dikirim on-chain.`
- Signer ETH low: `Signer demo kehabisan ETH Sepolia. Reward lokal tetap tersimpan.`
- Rate limited: `Tunggu sebentar sebelum aksi berikutnya.`
- Invalid session: ask reconnect wallet.

### RPC Error

- RPC timeout: retry once, then show local fallback.
- Wrong chain ID: show Sepolia required.
- Contract address missing: show token balance unavailable but game playable.

## File Cleanup Plan

- Move `adb_*.png` screenshots from repo root to `docs/screenshots/debug/` if still useful.
- Add `.gitignore` rule for new ad-hoc screenshots if they are only debug artifacts.
- Keep curated images for README under `docs/screenshots/`.
- Replace `taniin_flutter/README.md` template content.
- Add architecture docs.
- Keep root README as main entry point.

## Acceptance Criteria

### Pameran Ready

- Android APK builds successfully.
- Web build runs successfully.
- Wallet connect supports more than MetaMask.
- WalletConnect QR works on desktop.
- Manual demo fallback exists and is clearly labeled.
- AI Agent visibly appears and can respond or perform at least one demo interaction.
- Multiplayer can connect or gracefully fallback.
- Backend signer health can be checked.
- Transaction history shows local and on-chain status clearly.
- No private key appears in source, screenshots, APK assets, or web bundle.

### Security Ready For Prototype

- `/game-actions` requires verified session.
- Manual wallet cannot claim on-chain reward.
- Rate limit is active.
- Backend validates action type and amount.
- Signer payout limits are configured.
- Error messages do not leak private key or sensitive environment values.

### Code Quality Ready

- `flutter analyze` passes.
- `flutter test` passes.
- `npm run compile` or `hardhat compile` passes for contracts.
- Wallet connect page has basic tests or manual checklist.
- Major state/game files have started being split or have documented refactor tickets.

## Suggested Implementation Order

1. Add docs and demo checklist.
2. Clean wallet connect copy to remove MetaMask-only wording.
3. Add multi-wallet connector page with Reown AppKit/wagmi/viem.
4. Add callback metadata to Flutter bridge.
5. Add wallet signature login and backend session.
6. Protect `/game-actions` with session token.
7. Add rate limit and server-side validation basics.
8. Improve AI Agent UI visibility.
9. Add status indicators for Wallet/API/RPC/AI/Multiplayer.
10. Add tests for wallet, chain client, backend validation, and economy.
11. Refactor `farm_state.dart` gradually.
12. Refactor `taniin_game.dart` gradually.
13. Polish presentation docs and screenshots.

## Short Pitch After Improvements

Taniin adalah game pertanian digital berbasis Flutter/Flame yang menggabungkan gameplay farming, AI farmer assistant, multiplayer, dan integrasi Web3. Pemain bisa bertani, berinteraksi dengan AI agent, terhubung dengan berbagai wallet, dan mencatat progress tertentu ke Sepolia melalui backend signer yang aman untuk prototype.
