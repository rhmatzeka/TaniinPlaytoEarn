# Taniin: Login Privy, Ekonomi Aman, Multiplayer Hidup, APK Unduhan

Tanggal: 2026-10-28
Status: draf, menunggu persetujuan pemilik

## Maksud

Taniin (game bertani pixel Flutter/Flame, Android + Web, Web3 Sepolia) berhenti dikerjakan sejak 2026-07-31 dalam keadaan setengah jadi. Pemilik ingin memasukkannya ke portfolio (rahmateka.my.id). Orang yang membuka porto (rekruter, juri) harus bisa:

1. langsung main di web `taniin.rahmateka.my.id` tanpa daftar apa pun,
2. mengunduh APK Android dari link publik (seperti Smart KTM: `/unduh/...apk`),
3. masuk dengan **Privy** (email/Google, wallet dibuat otomatis, tidak harus punya MetaMask) lalu melihat aksi game benar-benar tercatat di Sepolia,
4. melihat pemain lain dan Pak Tani AI bergerak (multiplayer).

Kondisi sekarang: backend sudah punya guard auth, tapi Flutter tidak pernah mengirim sesi, jadi hampir semua aksi on-chain sengaja dimatikan (`assertPhase0ActionEnabled`, fail closed). Sesi, rate limit, dan idempotency hanya di memori (tidak berlaku di Vercel serverless). Multiplayer memakai Socket.IO yang tidak bisa hidup di Vercel, jadi di versi online kemungkinan besar mati. Daftar lengkap kekurangan ada di `docs/taniin-improvement-plan.md` bagian "Remaining Gaps After Auth Guard".

## Keputusan pemilik

- **Tidak ada migrasi bahasa/framework.** Game tetap Flutter/Flame, backend tetap Node.js (`contracts/api`, `contracts/lib`), tetap di **Vercel**.
- **Login pakai Privy.**
- **Multiplayer + AI:** file Node yang sudah ada (`contracts/scripts/game-api.cjs` + `lib/multiplayer-service.cjs`) dijalankan juga di **srv PC HP-mats** lewat subdomain sendiri. Bagian lain tetap di Vercel.
- **APK bisa diunduh publik**, seperti Smart KTM.
- Lengkapi kekurangan yang tercatat di docs, dan perbagus hasilnya untuk porto.

## Tujuan

### T1. Login Privy (ganti wallet-connect + ConnectKit + nonce/sign)

- Satu halaman login web di domain yang sama, mis. `/masuk`, dibangun dengan React + Privy React SDK, memakai pipeline esbuild yang sekarang dipakai `wallet-connect/app.jsx` (bukan Astro, bukan framework baru).
- Metode login: email, Google, dan wallet eksternal. Embedded wallet Privy (Ethereum) dibuat otomatis saat login bila pengguna belum punya wallet.
- Flutter web dan APK sama-sama membuka halaman ini. Setelah login, halaman menukar token Privy ke backend lalu mengembalikan hasilnya ke game:
  - APK: deep link `taniin://auth#...` (Android intent filter `taniin://` sudah ada untuk `taniin://wallet`).
  - Web: redirect balik ke game dengan data di fragmen `#...` (tidak di query, supaya tidak masuk log server).
- Backend: endpoint baru `POST /auth/privy` memverifikasi access token Privy di server (library resmi `@privy-io/server-auth` atau verifikasi JWT ES256 + JWKS), mengambil alamat embedded wallet / wallet tertaut pengguna, lalu menerbitkan **sesi Taniin** sendiri (token acak, disimpan di database, umur 7 hari).
- Flutter menyimpan sesi (token, wallet, kedaluwarsa, metode login) dan mengirim `Authorization: Bearer <sesi>` + `Idempotency-Key` unik per aksi di setiap `submitGameAction`.
- Tombol keluar menghapus sesi lokal dan mencabut sesi di server.
- Endpoint lama `/auth/nonce`, `/auth/verify`, `/wallet-connect`, bundel ConnectKit, dan input alamat manual dihapus.

### T2. Penyimpanan bersama di Neon Postgres

Semua state yang sekarang ada di `Map` memori pindah ke Neon Postgres (paket gratis): sesi, rate limit (per wallet dan per IP), hasil idempotency, transaksi pendanaan ETH yang sudah dipakai, dan log audit setiap aksi (wallet, aksi, jumlah, plot, tx hash, hasil, error, waktu). Data kedaluwarsa dibersihkan otomatis (dibersihkan saat request, tanpa cron terpisah).

### T3. Ekonomi dijaga server

- Untuk pemain yang login, **server adalah pegangan** untuk koin game, benih, panen, kepemilikan plot, waktu tanam, XP/level, quest harian, achievement, dan skin.
- Setiap aksi divalidasi di server: saldo cukup, benih ada, tanaman sudah matang sesuai durasi tumbuh, panen ada di inventaris sebelum dijual, plot dimiliki. Jumlah hadiah dan harga dihitung server, `amount` dari klien tidak dipercaya.
- Flutter memuat state dari server setelah login dan memperbarui tampilan dari respons server.
- Mode tamu (belum login) tetap seperti sekarang: state lokal di perangkat, tanpa on-chain.
- **Progres tamu saat pertama login (keputusan pemilik: bawa tapi dibatasi).** Sekali per akun Privy, saat akun itu belum punya state di server, Flutter mengirim progres tamunya. Server menerima benih, panen, plot, dan level/XP setelah dipotong ke batas yang masuk akal (mis. maksimal 5 plot, stok benih/panen per jenis dibatasi, level dibatasi). Koin game dibatasi maksimal 500. Impor kedua untuk akun yang sama ditolak. Batas persisnya ditentukan builder dan dicatat di kode sebagai konstanta.

### T4. Aksi on-chain dibuka lagi

- Semua jenis aksi (`BUY_LAND`, `SELL_LAND`, `BUY_SEED`, `PLANT`, `HARVEST`, `SELL_CROP`, swap koin/TANI/ETH) aktif kembali, hanya untuk sesi Privy yang valid dan setelah lolos validasi T3.
- Pengaman: batas harian per wallet untuk mint/hadiah dan payout ETH, cek saldo signer sebelum payout ETH, saklar darurat lewat env (mis. `TANIIN_ECONOMY_PAUSED=true`) yang mematikan semua aksi on-chain tanpa deploy ulang.
- Antrean signer di memori (`actionQueue`) tidak berlaku lintas instance Vercel. Pengiriman transaksi signer harus diserialkan lewat database (mis. advisory lock Postgres) agar nonce tidak bentrok.
- Kontrak di Sepolia **tidak di-deploy ulang**. Alamat tetap: coin `0x8E1584fF95842C888F1FAaB29ed1e55d886A81F8`, land `0x55D768D736b66B842EE72Ff7fa143f03245F81cc`, items `0x9414eD4F6d9beF484484D72da3d8361989348AEf`.

### T5. Multiplayer + Pak Tani AI hidup

- `npm run game-api` (Socket.IO + AI Groq) jalan sebagai layanan tetap di srv PC HP-mats, dibuka lewat Cloudflare Tunnel di subdomain mis. `mp.taniin.rahmateka.my.id`.
- Flutter mendapat konfigurasi baru `TANIIN_MULTIPLAYER_URL` (dart-define + BuildConfig Android). Sekarang multiplayer memakai `gameApiUrl`, yang di web berarti domain Vercel dan pasti gagal.
- Join Socket.IO: pemain login mengirim sesi Taniin, yang divalidasi server multiplayer ke database yang sama, lalu nama profilnya ditampilkan. Tamu tetap boleh masuk dengan nama "Tamu-xxxx". Chat dibatasi frekuensi dan disanitasi di server.
- Kalau server multiplayer tidak terjangkau, game tetap jalan solo dan UI menunjukkan "Multiplayer offline".

### T6. APK unduhan + build ulang web

- GitHub Actions membangun APK Android, ditandatangani dengan **keystore tetap** dari secret repo (supaya update tidak perlu uninstall, belajar dari Smart KTM), lalu menaruhnya sebagai asset di GitHub Release tetap (mis. tag `apk-terbaru`). Repo publik, jadi asset bisa diunduh siapa saja.
- `taniin.rahmateka.my.id/unduh` (dan `/unduh/Taniin.apk`) mengarah ke asset itu.
- Web Flutter dibangun ulang dengan konfigurasi baru lalu di-deploy ke Vercel seperti alur sekarang (`taniin_flutter/build/web` disalin ke `contracts/public`).

### T7. Perbagus untuk porto

- Halaman depan ringan di Vercel (HTML statis, bergaya pixel yang sama dengan game) untuk pengunjung yang datang dari porto: judul, 3-4 screenshot asli, tombol **Main di browser** dan **Unduh APK**, satu paragraf cara kerja Web3-nya, link GitHub. Game sendiri pindah ke path tetap (mis. `/main`) atau halaman depan muncul sebelum game dimuat. Pilihan bentuknya diserahkan ke builder, asal pengunjung baru tidak langsung disambut layar loading kanvas tanpa konteks.
- Di dalam game: indikator status kecil (Login, Sepolia, Server, Multiplayer, AI), pesan error ramah (RPC lambat, server offline, saldo signer kurang, sesi kedaluwarsa, aksi ditolak validasi), dan status transaksi yang jelas di riwayat (tersimpan lokal → dikirim → menunggu konfirmasi → terkonfirmasi / gagal).
- Kartu Taniin di porto Mapporto diperbarui dengan link main dan link unduh APK (repo porto mengikuti aturan push langsung Mapporto).
- README diperbarui: cara login, arsitektur (Vercel + Neon + srv), link unduh, dan screenshot.

## Bukan tujuan

- Migrasi ke Rust, Astro, atau framework lain.
- Deploy ulang atau mengubah kontrak.
- Pembayaran sungguhan, mainnet, marketplace, season/battle pass, aset seni baru.
- Memecah file besar (`game_hud.dart`, `farm_state.dart`) di luar bagian yang memang disentuh fitur di atas.
- Build iOS.

## Anti-tujuan (gagal walau jalan)

- Pengunjung porto **dipaksa login** sebelum bisa main.
- Private key signer atau secret (Privy app secret, Groq key, string koneksi Neon) masuk ke repo, APK, build web, screenshot, atau README.
- Endpoint publik bisa dipakai siapa pun untuk mint TANI / menarik ETH tanpa sesi Privy yang valid.
- Demo tampak rusak: tombol mati tanpa penjelasan, transaksi "pending" selamanya, multiplayer gagal diam-diam.
- Kontributor GitHub selain pemilik (tidak ada Co-Authored-By, tidak ada commit dari bot CI ke branch).

## Batasan

- Laptop: RAM 7 GB, Flutter dan Android SDK belum terpasang. Flutter dipasang lokal untuk `flutter analyze`, `flutter test`, dan build web. APK dibangun di GitHub Actions, bukan di laptop.
- Vercel Hobby: fungsi serverless berumur pendek. Aksi yang menunggu konfirmasi Sepolia tidak boleh melewati batas waktu fungsi. Kembalikan tx hash lalu biarkan klien memantau receipt (Flutter sudah punya `waitForTransaction`), atau naikkan `maxDuration` bila perlu.
- Vercel CLI belum terpasang di laptop. Env production di Vercel diisi pemilik lewat dashboard atau CLI dengan token pemilik.
- srv PC HP-mats diakses lewat `ssh pc` (Tailscale). Saat desain ini ditulis, host belum terjangkau dari laptop. Layanan bot lain di srv tidak boleh terganggu.
- Semua commit hanya atas identitas git pemilik.
- Bahasa UI game tetap Indonesia.

## Yang harus disiapkan pemilik

1. Akun Privy: buat app, aktifkan email + Google + wallet eksternal + embedded wallet Ethereum, daftarkan domain `taniin.rahmateka.my.id` (dan localhost untuk uji). Berikan **App ID**; **App Secret** diisi langsung ke env Vercel/srv, jangan ditempel di chat.
2. Neon Postgres: buat project atau login `neonctl`. String koneksi diisi ke env Vercel dan srv.
3. Akses Vercel untuk project Taniin yang sekarang (dashboard atau token).
4. srv PC HP-mats menyala dan terjangkau.

## Jawaban dari kode dan keputusan Claude

Hal-hal ini sudah dijawab oleh kode, atau diputuskan Claude karena builder yang wajar bisa memutuskannya tanpa mengubah apa yang dibangun. Pemilik boleh membatalkan salah satunya.

- **Gas dan aset (dari kode):** signer backend adalah owner/minter kontrak dan membayar semua gas. Fungsi kontrak sudah menerima alamat pemain sebagai penerima (`mintLandFor(player, ...)`, `coin.mint(to, ...)`, `coin.gameSpend(from, ...)`, `items.mint(to, ...)`), jadi wallet Privy pemain tidak perlu menandatangani transaksi apa pun.
- **Katalog ekonomi (dari kode):** harga benih, durasi tumbuh, hadiah, dan definisi quest/XP/skin sekarang ada di `farm_state.dart` dan `game-action-service.cjs`. Katalog itu dipindah ke satu modul Node yang menjadi sumber kebenaran. Flutter tetap memakai salinan nilainya untuk mode tamu.
- **Angka batas (keputusan Claude, konservatif, bisa diubah lewat env):** payout ETH maks 0,01 SepETH per wallet per hari, mint TANI maks 2.000 per wallet per hari, payout ETH ditolak bila saldo signer < 0,2 SepETH, rate limit 30 aksi/menit per wallet dan 60/menit per IP.
- **Database saat pengembangan (keputusan Claude):** tes dan migrasi memakai branch `dev` di Neon (fitur branch tersedia di paket gratis). Production memakai branch utama.
- **Login di APK (keputusan Claude):** halaman `/masuk` dibuka di browser eksternal / Custom Tab, bukan WebView, karena login Google memblokir WebView. Hasil kembali lewat `taniin://auth#...`, ditangani bridge Android yang sudah dipakai untuk `taniin://wallet` (`PlatformBridge`).
- **Multiplayer membaca Neon dari srv (keputusan Claude):** server multiplayer memvalidasi sesi langsung ke Neon lewat internet dan menyimpan hasilnya di cache beberapa menit. String koneksi disimpan di env srv seperti secret bot lain di sana.
- **Pengguna lama (dari kode):** sesi lama hanya ada di memori, jadi tidak ada data pengguna nyata yang perlu dipertahankan saat peralihan.
- **Batas fungsi Vercel Hobby (keputusan Claude):** endpoint digabung menjadi sedikit fungsi (mis. satu router `api/[...path].js`) supaya tetap di bawah batas 12 fungsi. Path publik (`/game-actions`, `/health`, `/auth/privy`, dst.) tetap lewat rewrite.
- **Halaman depan (keputusan Claude):** halaman depan di `/`, game Flutter di `/main/` (`flutter build web --base-href /main/`). Service worker dan E2E Playwright disesuaikan. Link lama ke root tetap berguna karena halaman depan punya tombol Main.
- **Keystore APK (keputusan Claude):** keystore baru dibuat sekali di laptop, disimpan di `~/.config/taniin/` dan sebagai secret repo. CI hanya mengunggah asset ke GitHub Release, tanpa commit ke branch.

## Diserahkan ke builder

Bentuk skema tabel, library verifikasi Privy, cara serialisasi signer, urutan migrasi data, desain persis halaman depan dan halaman login (mengikuti gaya pixel yang ada), nama subdomain final, dan cara memasang layanan di srv (container `srv` atau systemd, mengikuti pola layanan lain di sana).

## Cara memeriksa selesai

- Pengunjung baru: buka domain, lihat halaman depan, main sebagai tamu, unduh dan pasang APK.
- Login Privy dengan email di web dan di APK, beli benih, tanam, panen, jual. Setiap aksi muncul di riwayat dengan tx hash yang terbuka di Sepolia Etherscan.
- Request `/game-actions` tanpa sesi, dengan sesi palsu, atau dengan jumlah yang tidak masuk akal ditolak. Request ganda dengan `Idempotency-Key` sama hanya diproses sekali.
- Dua browser login bersamaan saling terlihat di multiplayer. Pak Tani AI menjawab chat.
- `npm test` (kontrak + layanan), `flutter analyze`, `flutter test`, dan E2E web Playwright lulus.
