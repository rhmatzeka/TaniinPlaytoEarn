# Taniin Business Model Plan

## Status Dokumen

- Status: Draft strategi produk dan bisnis
- Produk: Taniin
- Platform saat ini: Flutter/Flame Web dan Android
- Network saat ini: Ethereum Sepolia
- Dokumen pendamping: `docs/taniin-improvement-plan.md`
- Prinsip: gameplay harus menyenangkan tanpa pembayaran; monetisasi menjual identitas, ekspresi, koleksi, dan layanan, bukan kemenangan atau janji keuntungan.

## Ringkasan Eksekutif

Taniin saat ini adalah prototype social farming game dengan farming loop, inventory, toko benih, land, multiplayer, chat, Pak Tani AI, wallet, dan aset Sepolia. Produk belum memiliki sistem retensi jangka panjang atau sumber pendapatan komersial yang matang.

Model bisnis yang direkomendasikan:

> Free-to-play social farming game dengan pendapatan utama dari kosmetik, dekorasi, season pass, brand partnership, dan creator marketplace. Web3 menjadi lapisan kepemilikan opsional, bukan syarat utama bermain.

Urutan pembangunan yang benar:

```text
Economy safety
  -> Retention
  -> Player identity
  -> Cosmetic monetization
  -> Social visibility
  -> Seasons and live operations
  -> Creator economy
  -> Optional Web3 ownership
```

TANI dan ETH tidak boleh dijadikan sumber utama retensi atau janji pendapatan pemain. Ekonomi bernilai nyata baru boleh dibuka setelah ledger, auth, inventory, idempotency, replay protection, dan payout controls menjadi server-authoritative.

## Kondisi Produk Saat Ini

### Fitur Yang Sudah Ada

- Farming loop: beli benih, tanam, tunggu, panen, dan jual.
- Empat jenis tanaman: Kentang, Bawang, Stroberi, dan Bit.
- Lima plot dengan satu plot awal.
- Seed shop, crop-selling house, swap house, backpack, dan transaction history.
- Game Coin lokal, TANI Sepolia, dan ETH Sepolia.
- ERC-20 TANI, ERC-721 land, serta ERC-1155 seed/crop.
- Multiplayer presence, remote movement, dan public chat.
- Pak Tani AI dengan online dan offline fallback.
- Local persistence untuk sebagian besar state gameplay.

### Fitur Yang Belum Ada

- Player level, XP, reputation, atau skill progression.
- Daily quest, weekly quest, achievement, streak, atau order board.
- Player profile dan custom display name.
- Skin, wardrobe, pet, emote, profile frame, atau farm decoration.
- Season dan battle pass.
- Friends, visit farm, guestbook, gifting, cooperative order, atau guild.
- Marketplace, creator tools, dan creator revenue sharing.
- Subscription, conventional IAP, fiat checkout, dan entitlement service.
- Product analytics, experimentation, remote config, push notification, dan live-ops tooling.

### Kelemahan Loop Produk

- Progression utama selesai setelah membeli empat plot tambahan.
- Waktu tumbuh prototype sangat singkat dan tidak membentuk ritme retensi.
- Tidak ada tujuan jangka menengah atau jangka panjang.
- Tidak ada identitas visual yang dapat dipamerkan kepada pemain lain.
- Multiplayer belum memberi aktivitas sosial yang berarti.
- AI belum memiliki affinity, progression, atau recurring mission.
- Token conversion terlihat lebih dominan daripada fun dan collection loop.

## Gap Dari Plan Awal

Plan awal sudah mencakup cosmetics, season pass, subscription, creator marketplace, roadmap, dan KPI dasar. Bagian berikut perlu ditambahkan agar plan dapat dipakai untuk keputusan bisnis nyata.

### Segmentasi Pengguna

Harus dibedakan minimal empat kelompok:

1. Casual farmer: bermain untuk relaksasi dan koleksi.
2. Social decorator: bermain untuk membangun farm dan memamerkannya.
3. Collector: tertarik skin, pet, badge, dan limited seasonal item.
4. Web3 enthusiast: tertarik ownership dan marketplace, tetapi bukan target default onboarding.

Target awal yang direkomendasikan adalah casual farmer dan social decorator. Web3 enthusiast adalah segmen tambahan, bukan pusat desain.

### Positioning Dan Kompetitor

Taniin tidak boleh mencoba mengalahkan farming game besar hanya melalui fitur tanam-panen. Posisi yang lebih kuat:

> Farming sosial bernuansa Nusantara dengan AI companion dan kepemilikan digital opsional.

Pembeda utama:

- Visual dan event bertema Nusantara.
- Pak Tani AI sebagai companion, guide, dan quest giver.
- Social farm showcase.
- Creator-made local cosmetics dan decorations.
- Optional wallet ownership tanpa memaksa seluruh pemain memahami Web3.

Analisis kompetitor harus membandingkan Taniin dengan:

- Farming/cozy games untuk retention dan decoration loop.
- Social games untuk visit, gifting, dan showcase.
- Web3 games untuk wallet friction, economy failure, dan marketplace.
- AI games untuk companion utility dan operating cost.

### Distribution Dan Acquisition

Channel distribusi yang perlu diuji:

- Web playable tanpa instalasi untuk acquisition tercepat.
- Android APK atau Play Store setelah billing dan policy siap.
- Campus/community events.
- Farming, sustainability, dan local culture communities.
- TikTok, Instagram Reels, YouTube Shorts, dan Discord.
- Creator cosmetic collaborations.
- Brand-sponsored seasonal events.
- Referral setelah social profile dan fraud controls tersedia.

Konten pemasaran harus menunjukkan hasil visual, bukan proses wallet:

- Before/after farm decoration.
- Rare pet atau outfit reveal.
- Pak Tani AI membantu farming.
- Community harvest event.
- Farm showcase pemain.

### Funnel Produk

Funnel yang harus diukur:

```text
Visit landing page
  -> Start game
  -> Finish onboarding
  -> First plant
  -> First harvest
  -> First land expansion
  -> First social interaction
  -> First cosmetic shop view
  -> First purchase
  -> Repeat purchase or season renewal
```

Wallet connect sebaiknya tidak menjadi langkah pertama bagi pemain casual. Guest account dapat digunakan untuk mencoba game, lalu account linking/wallet ditawarkan ketika pemain membutuhkan cloud save, social identity, atau optional ownership.

### Unit Economics

Plan harus mengukur:

- Customer acquisition cost (CAC).
- Average revenue per daily active user (ARPDAU).
- Average revenue per paying user (ARPPU).
- Gross margin setelah payment fee, platform fee, creator share, gas subsidy, AI cost, RPC, hosting, dan support.
- Lifetime value (LTV).
- LTV/CAC.
- Payback period.
- Refund dan chargeback rate.

Rumus sederhana:

```text
Net Revenue
  = Gross Purchases
  - Store/Payment Fees
  - Creator Revenue Share
  - Refunds/Chargebacks
  - Gas Subsidy

Contribution Margin
  = Net Revenue
  - AI Cost
  - RPC/Hosting Cost
  - Customer Support Variable Cost
```

Target awal sebelum paid acquisition:

- LTV/CAC minimal 3 setelah data cukup.
- Contribution margin positif untuk cosmetic purchase.
- AI cost per monthly active user memiliki hard cap.
- Gas subsidy tidak boleh lebih besar dari margin item.

### Legal Dan Platform Compliance

Sebelum real-money launch, perlu review:

- Google Play dan Apple policy untuk digital goods dan external payment.
- Consumer protection, refund, pricing transparency, dan parental controls.
- Privacy policy, terms of service, cookie/local storage notice, dan data deletion.
- Chat moderation, reporting, blocking, dan child safety.
- Intellectual property untuk asset internal dan creator submissions.
- Tax dan creator payout obligations.
- KYC/AML jika token redemption, marketplace payout, atau fiat withdrawal diterapkan.
- Gambling/securities risk jika reward dipromosikan sebagai investasi atau keuntungan.
- Geographic restrictions untuk token dan marketplace jika diperlukan.

Dokumen ini bukan nasihat hukum. Launch komersial dengan token atau cash-out membutuhkan legal review yang sesuai yurisdiksi.

### Operating Model

Setiap live feature membutuhkan owner:

| Domain | Tanggung jawab |
|---|---|
| Product | Roadmap, scope, KPI, experiment decision |
| Economy | Sources/sinks, pricing, emission, treasury limits |
| Engineering | Reliability, security, ledger, release |
| Art/Content | Cosmetics, decorations, season content |
| LiveOps | Calendar, quests, events, offers |
| Community | Feedback, moderation, support |
| Data | Analytics schema, dashboard, experiment results |
| Legal/Finance | Policies, payment, tax, creator payout |

Jika tim masih kecil, satu orang dapat memegang beberapa domain, tetapi owner dan approval tetap harus eksplisit.

## Target Audience Dan Jobs To Be Done

### Primary Persona: Casual Farmer

- Ingin sesi santai selama 5-15 menit.
- Ingin progress terlihat tanpa memahami blockchain.
- Menyukai reward kecil, collection, dan visual improvement.
- Membutuhkan onboarding sederhana dan mobile-friendly.

Job to be done:

> Ketika punya waktu singkat, saya ingin merawat dan mempercantik farm agar merasa rileks dan melihat progress yang jelas.

### Primary Persona: Social Decorator

- Menikmati customization dan showcase.
- Ingin farm dikunjungi dan disukai pemain lain.
- Bersedia membeli kosmetik jika terlihat unik.

Job to be done:

> Saya ingin membangun farm yang mencerminkan identitas saya dan mendapat pengakuan dari komunitas.

### Secondary Persona: Collector

- Menyukai limited set, rarity, completion, badge, dan pet.
- Sensitif terhadap fairness dan transparansi availability.

Job to be done:

> Saya ingin mengoleksi item yang bermakna dan mengetahui cara mendapatkannya tanpa mekanik yang manipulatif.

### Secondary Persona: Web3 Enthusiast

- Menginginkan portable ownership dan marketplace.
- Bersedia menghubungkan wallet setelah memahami manfaatnya.

Job to be done:

> Saya ingin item tertentu benar-benar saya miliki dan dapat saya transfer tanpa merusak keseimbangan game.

## Product Positioning

### Value Proposition

Taniin menawarkan:

- Cozy farming loop yang mudah dipahami.
- Identitas visual bernuansa Nusantara.
- AI farmer companion yang membantu dan memberi misi.
- Multiplayer social presence dan farm showcase.
- Optional digital ownership untuk collectible tertentu.

### Product Narrative

Taniin bukan aplikasi swap yang diberi tampilan game. Taniin adalah farming game yang tetap bernilai tanpa token. AI dan Web3 harus memperkuat pengalaman tersebut:

- AI membantu, menjelaskan, dan membangun relationship.
- Web3 memberi ownership opsional untuk collectible tertentu.
- Gameplay tetap berjalan saat wallet, RPC, atau blockchain tidak tersedia.

## Business Model

### Revenue Mix Target

Target jangka menengah setelah seluruh channel tersedia:

| Sumber | Target kontribusi |
|---|---:|
| Cosmetics dan bundles | 40-50% |
| Season pass | 20-30% |
| Brand partnership | 10-20% |
| Subscription | 5-15% |
| Marketplace fee | 0-10% |

Komposisi aktual harus ditentukan dari data. Marketplace tidak boleh dipaksakan hanya untuk memenuhi narasi Web3.

### Monetization Guardrails

- Tidak menjual crop yield multiplier permanen.
- Tidak menjual payout rate yang lebih tinggi.
- Tidak menjual kemenangan leaderboard.
- Tidak memberikan TANI/ETH besar melalui paid pass.
- Tidak menggunakan loot box berbayar pada MVP.
- Tidak membuat false scarcity atau countdown palsu.
- Menampilkan harga final, isi bundle, dan availability secara jelas.
- Memberikan preview kosmetik sebelum pembelian.
- Menyediakan purchase history dan support/refund flow.
- Memisahkan soft currency, premium entitlement, dan token ownership.

## Currency And Asset Architecture

### Rekomendasi Tiga Lapisan

1. Game Coin
   - Soft currency server-authoritative.
   - Diperoleh melalui gameplay.
   - Digunakan untuk benih dasar, progression, crafting, dan convenience ringan.
   - Tidak dapat langsung diuangkan.

2. Premium entitlement atau premium currency
   - Dibeli melalui channel pembayaran yang sesuai platform.
   - Digunakan untuk cosmetics, pass, dan decoration.
   - Tidak dapat ditukar langsung ke ETH.
   - Jika memakai premium currency, pricing dan refund harus tetap transparan.

3. TANI/collectible ownership
   - Opsional dan tidak diperlukan untuk core gameplay.
   - Digunakan untuk mint collectible tertentu, creator settlement tertentu, atau community utility setelah legal/security review.
   - Tidak menjadi mirror 1:1 dari Game Coin.

### Economy Safety Gate

Real-value conversion tidak boleh production-ready sebelum:

- Wallet signature authentication wajib.
- PostgreSQL atau durable ledger tersedia.
- Inventory dan planted state server-authoritative.
- Durable idempotency dan replay protection.
- Seed burn dan harvest validation atomik.
- Land payment dan resale konsisten.
- Reward treasury memiliki budget, bukan unlimited mint.
- Per-wallet dan global daily caps aktif.
- Emergency pause tersedia.
- Monitoring dan alerting tersedia.
- Security test untuk malicious action sequence lulus.
- Legal review selesai.

## Cosmetics Strategy

### Cosmetic Slots

- Body/base character.
- Outfit.
- Headwear.
- Back item.
- Tool skin.
- Pet/companion.
- Footstep effect.
- Planting effect.
- Harvest effect.
- Emote.
- Profile frame.
- Player title.
- Farm theme.
- House skin.
- Fence, path, lamp, sign, scarecrow, dan plot border.

### Rarity

- Common.
- Rare.
- Epic.
- Legendary.
- Seasonal.
- Founder.

Rarity hanya memengaruhi presentasi, availability, dan collection status. Rarity tidak memberi economic advantage.

### Launch Collections

| Koleksi | Contoh isi | Tujuan |
|---|---|---|
| Petani Nusantara | Caping, batik, sarung, keranjang bambu | Identitas utama Taniin |
| Cyber Farmer | Neon outfit, drone pet, cyber tool | Kontras visual premium |
| Penjaga Hutan | Green cloak, owl pet, leaf effect | Sustainability theme |
| Panen Raya | Festive outfit, confetti harvest, lantern | Seasonal event |
| Founder Farmer | Skin, title, badge, profile frame | Early supporter reward |

### Pricing Hypothesis

Harga berikut adalah hipotesis yang harus diuji, bukan keputusan final:

| Produk | Kisaran awal |
|---|---:|
| Aksesori kecil | Rp5.000-Rp15.000 |
| Emote/effect kecil | Rp10.000-Rp25.000 |
| Character skin | Rp20.000-Rp50.000 |
| Pet | Rp25.000-Rp60.000 |
| Farm theme | Rp40.000-Rp80.000 |
| Collection bundle | Rp79.000-Rp149.000 |

Eksperimen harga harus membandingkan conversion, revenue per visitor, refund, dan satisfaction. Jangan hanya memilih harga dengan gross revenue tertinggi.

### Cosmetic Data Model

Catalog item:

```json
{
  "cosmeticId": "outfit_batik_farmer_01",
  "category": "outfit",
  "rarity": "epic",
  "price": 39000,
  "currency": "IDR",
  "tradeable": false,
  "season": "harvest_nusantara"
}
```

Player entitlement:

```json
{
  "playerId": "player_123",
  "cosmeticId": "outfit_batik_farmer_01",
  "source": "season_pass",
  "acquiredAt": "2026-07-25T12:00:00Z"
}
```

Equipped loadout:

```json
{
  "outfit": "outfit_batik_farmer_01",
  "headwear": "head_caping_01",
  "pet": "pet_chicken_gold_01",
  "harvestEffect": "effect_rice_confetti_01"
}
```

### Cosmetic MVP Acceptance Criteria

- Catalog diambil dari backend atau versioned configuration.
- Pemain dapat preview item sebelum membeli.
- Ownership tidak bergantung pada local storage.
- Pemain dapat equip dan unequip item.
- Loadout tersimpan di server.
- Remote player melihat loadout yang benar.
- Missing asset memakai safe fallback.
- Tidak ada cosmetic stat bonus.
- Purchase idempotent dan memiliki receipt/history.
- Restore purchase dan support flow tersedia sesuai payment channel.

## Retention Systems

### Player Level

Level membuka content dan expression, bukan payout multiplier.

Contoh unlock:

| Level | Unlock |
|---:|---|
| 2 | Bawang |
| 4 | Decoration mode |
| 6 | Stroberi |
| 8 | Pet slot |
| 10 | Farm theme |
| 15 | Visit farm |
| 20 | Creator showcase |

### Daily And Weekly Quests

Contoh daily quest:

- Tanam 5 Kentang.
- Panen 3 kali.
- Jual 10 hasil panen.
- Gunakan satu bantuan Pak Tani AI.
- Kunjungi satu farm pemain.

Contoh weekly quest:

- Selesaikan 15 daily quests.
- Panen 100 tanaman.
- Selesaikan cooperative order.
- Dapatkan 10 likes pada farm.

Reward:

- XP.
- Game Coin terbatas.
- Cosmetic crafting material.
- Season XP.
- Badge atau decoration tertentu.

Quest sederhana tidak memberikan ETH atau TANI yang dapat diuangkan.

### Achievement

- Panen Pertama.
- 100 Tanaman.
- Petani Kentang.
- Pemilik Lima Lahan.
- Sahabat Pak Tani AI.
- Kolektor Musim Pertama.
- Early Adopter Sepolia.

Achievement memberi badge, title, cosmetic material, atau decoration.

### Pak Tani AI Retention Loop

AI dapat berkembang dari utility menjadi companion:

- Daily advice.
- Contextual quest giver.
- Relationship/affinity level.
- Memory opt-in yang transparan.
- Unlockable AI outfit atau farm station.
- Weekly farm review.
- Strategy recommendation tanpa mengendalikan real-value transaction.

AI harus memiliki quota dan deterministic fallback agar biaya terkendali.

## Season Pass

### Format

- Durasi 6-8 minggu.
- 40-50 level setelah MVP tervalidasi.
- Free track dan premium track.
- Seasonal quests dan community goal.
- Catch-up mechanics yang fair pada akhir season.

### Season 1 Concept

Nama: Festival Panen Nusantara.

Reward gratis:

- Game Coin terbatas.
- Benih dasar.
- Emote.
- Profile badge.
- Dekorasi sederhana.

Reward premium:

- Skin eksklusif season.
- Pet.
- Farm theme.
- Harvest effect.
- Premium decorations.
- Extra cosmetic preset.

### Pricing Hypothesis

- Premium Pass: Rp49.000-Rp79.000.
- Premium Plus: Rp99.000-Rp129.000.

Premium Plus dapat berisi level awal dan kosmetik tambahan, tetapi tidak memberi economic multiplier.

### Season Go/No-Go Gate

Season penuh hanya dibangun jika:

- D7 retention menunjukkan core loop cukup sehat.
- Quest completion dapat diukur.
- Content production pipeline mampu menghasilkan reward tepat waktu.
- Cosmetic entitlement stabil.
- Remote config dan analytics tersedia.
- Tim memiliki live-ops owner selama season berjalan.

## Subscription: Taniin Club

Subscription baru diluncurkan setelah monthly active user dan content cadence stabil.

Benefit yang disarankan:

- Satu kosmetik bulanan.
- Profile frame khusus.
- Tambahan preset outfit.
- Tambahan slot layout farm.
- Statistik farm lengkap.
- Daily cosmetic material.
- Diskon cosmetic 5-10%.
- No ads jika ads diterapkan.

Harga hipotesis:

- Rp29.000-Rp49.000 per bulan.

Subscription tidak memberi yield, payout, atau swap advantage.

## Social Farming

### Social Features

- Custom display name dan profile.
- Friends/following.
- Visit farm.
- Farm likes.
- Guestbook dengan moderation.
- Cosmetic gifting.
- Cooperative order.
- Community harvest goal.
- Weekly farm showcase.
- Guild/co-op pada tahap lanjut.

### Social Safety

- Report, mute, dan block.
- Rate limit chat dan guestbook.
- Profanity and abuse moderation.
- Privacy setting untuk visit dan messages.
- No direct wallet exposure by default.
- Child safety review sebelum public social launch.

## Creator Economy

### Creator Products

- Outfit dan headwear.
- Farm decorations.
- Floor/path pattern.
- Profile frame.
- Sticker dan emote.
- Farm template.
- House theme.

### Revenue Share Hypothesis

Pilihan awal:

```text
80% creator
20% platform
```

Pilihan dengan community treasury:

```text
70% creator
20% platform
10% community/season treasury
```

Pembagian final harus memperhitungkan store fee, tax, refund, moderation, hosting, dan payment cost. Persentase harus dijelaskan sebagai pembagian net revenue jika fee dipotong lebih dahulu.

### Creator Prerequisites

- Creator application dan identity verification sesuai kebutuhan payout.
- Submission format dan asset specification.
- Human moderation.
- Copyright declaration dan takedown process.
- Versioning dan safe asset fallback.
- Revenue dashboard.
- Refund allocation rules.
- Tax and payout handling.
- Ban and appeal process.

### Creator Go/No-Go Gate

- Internal cosmetic pipeline sudah stabil.
- Marketplace demand terbukti melalui first-party cosmetics.
- Moderation capacity tersedia.
- Legal dan creator agreement tersedia.
- Entitlement serta payment reconciliation stabil.

## Marketplace Dan Optional NFT

### Marketplace Candidates

- Limited cosmetic.
- Pet limited.
- Farm decoration limited.
- Event trophy.
- Special land cosmetic/history.

Tidak direkomendasikan untuk tahap awal:

- Tradable Game Coin.
- Tradable basic seed/crop.
- Item yang meningkatkan produksi.
- Cash-out untuk routine farming reward.

### Fee Hypothesis

- Marketplace fee: 2,5-5%.
- Creator royalty: 2,5-7,5%.
- Listing fee kecil hanya jika diperlukan untuk mengurangi spam.

### NFT Policy

- NFT bersifat opsional.
- Item game tidak wajib menjadi NFT untuk dimiliki pemain.
- Minting dapat menjadi pilihan tambahan untuk collectible terpilih.
- Gas, custody, recovery, bridge, dan transfer risk harus dijelaskan.
- Jangan menjanjikan appreciation atau investment return.

## Brand Partnership

### Target Partner

- Brand benih dan agrikultur.
- Produk makanan dan kopi lokal.
- UMKM.
- Kampus dan komunitas.
- Kementerian/dinas pertanian.
- Sustainability program dan NGO.
- Brand lokal bertema Nusantara.

### Product Format

- Sponsored seasonal crop.
- Branded farm decoration.
- Educational quest.
- Limited cosmetic collection.
- Community planting event.
- CSR campaign.
- Digital exhibition hasil pertanian daerah.

Brand content harus diberi label sponsor dan tidak boleh mengganggu core gameplay.

## Ads Policy

Ads bukan prioritas awal. Jika kelak digunakan:

- Rewarded ads hanya untuk convenience non-economic atau cosmetic material terbatas.
- Tidak ada forced interstitial di tengah farming action.
- Tidak ada iklan pada wallet/transaction flow.
- Subscription dapat menghapus ads.
- Consent dan age-appropriate policy wajib.
- Reward ads tidak boleh menghasilkan TANI/ETH.

## Analytics And Experimentation

### Core Events

- `game_started`
- `onboarding_started`
- `onboarding_completed`
- `first_seed_planted`
- `first_crop_harvested`
- `first_crop_sold`
- `land_purchased`
- `quest_started`
- `quest_completed`
- `profile_created`
- `farm_visited`
- `cosmetic_shop_viewed`
- `cosmetic_previewed`
- `checkout_started`
- `purchase_completed`
- `purchase_failed`
- `cosmetic_equipped`
- `season_pass_viewed`
- `season_pass_purchased`
- `wallet_connect_started`
- `wallet_connect_completed`
- `chain_action_failed`

Analytics tidak boleh mengirim private key, session token, signature, chat content sensitif, atau full wallet address jika tidak diperlukan.

### KPI

Retention:

- Tutorial completion.
- D1, D7, dan D30 retention.
- Sessions per active day.
- Average session duration.
- Quest completion rate.
- Weekly active days.

Engagement:

- First harvest completion.
- Plot expansion rate.
- Farm visit rate.
- Social interaction rate.
- AI interaction rate.
- Cosmetic equip rate.

Monetization:

- Shop view rate.
- Checkout conversion.
- Paying conversion.
- ARPDAU.
- ARPPU.
- Average order value.
- Season pass conversion.
- Subscription renewal.
- Refund/chargeback rate.

Reliability:

- Wallet connect completion.
- API error rate.
- Transaction failure rate.
- Purchase reconciliation failures.
- Crash-free sessions.
- P95 API latency.

### Initial Targets

Target berikut adalah hipotesis awal dan harus disesuaikan dengan cohort serta channel:

- Onboarding completion: 70%+.
- First harvest completion: 60%+.
- D1 retention: 30%+.
- D7 retention: 10-15%+.
- Paying conversion: 1-3% setelah cosmetic shop matang.
- Season pass completion: 25-40%.
- Purchase/transaction failure: di bawah 1%.
- Crash-free sessions: 99%+.

### Experiment Rules

- Satu experiment harus memiliki hypothesis, primary metric, guardrail metric, sample requirement, dan end date.
- Jangan menjalankan banyak perubahan ekonomi sekaligus.
- Jangan mengubah harga untuk pemain berbeda tanpa disclosure/policy review.
- Jangan mengoptimalkan revenue dengan mengorbankan retention, refund, atau trust.
- Catat hasil dan keputusan pada decision log.

## Roadmap Dan Dependency

### Phase 0: Economy Safety

Target: tidak ada aset bernilai yang dapat dibuat hanya dengan mengubah local storage atau memanggil API berulang.

- Durable player account dan PostgreSQL ledger.
- Wallet signature authentication.
- Persistent idempotency dan replay protection.
- Server-authoritative inventory dan planted state.
- Atomic seed consumption dan harvest reward.
- Consistent land payment/resale model.
- Reward treasury dan emission budget.
- Daily wallet/global payout cap.
- Emergency pause dan monitoring.
- Economy invariant and abuse tests.

Exit criteria:

- Malicious action sequence tests lulus.
- Semua balance mutation memiliki ledger entry.
- Reconciliation job tidak menemukan unexplained balance creation.
- Payout dapat dihentikan tanpa menghentikan core game.

### Phase 1: Retention Foundation

- Guest/player account.
- Profile dan custom name.
- XP dan farm level.
- Daily/weekly quest.
- Achievement dan badge.
- Crop unlock progression.
- Order board.
- Analytics dan remote config.

Exit criteria:

- Funnel first plant sampai first expansion dapat diukur.
- Quest dapat diubah tanpa build baru.
- D1/D7 baseline tersedia.

### Phase 2: Cosmetic MVP

- Catalog dan entitlement service.
- Wardrobe dan preview.
- Equip/loadout persistence.
- Multiplayer loadout sync.
- 6 skins, 4 headwear, 2 pets, 3 effects, dan 1 farm theme.
- Cosmetic shop dan purchase history.
- Payment sandbox sebelum real purchase.

Exit criteria:

- Entitlement tidak dapat dipalsukan melalui local storage.
- Purchase retry idempotent.
- Remote player melihat cosmetic yang benar.
- Cosmetic tidak memengaruhi stats.

### Phase 3: Mini Season

- 20 level untuk validation season pertama.
- Free dan premium track.
- 10 daily quest dan 5 weekly quest templates.
- Seasonal skin, pet, decorations, dan profile frame.
- Community harvest goal.
- Catch-up mechanics.

Exit criteria:

- Season XP dan claim idempotent.
- Content calendar selesai sebelum season dimulai.
- Support dan rollback procedure tersedia.

### Phase 4: Social Farming

- Friends/following.
- Visit farm.
- Likes dan guestbook.
- Cooperative order.
- Weekly showcase.
- Gifting.
- Moderation, block, mute, dan report.

Exit criteria:

- Abuse handling dan moderation dashboard tersedia.
- Privacy setting tersedia.
- Social features meningkatkan retention atau cosmetic engagement.

### Phase 5: Full Season And Subscription

- Season 6-8 minggu dengan 40-50 levels.
- Taniin Club.
- Monthly cosmetic cadence.
- Renewal, cancellation, dan restore purchase.

Exit criteria:

- Content cadence sustainable.
- Subscription support dan entitlement reconciliation stabil.
- Unit economics contribution-positive.

### Phase 6: Creator Economy

- Creator application.
- Asset submission dan moderation.
- Creator storefront.
- Revenue share dan payout.
- Creator analytics.
- Optional minting untuk approved collectibles.

Exit criteria:

- Legal agreement dan IP process tersedia.
- Moderation SLA tersedia.
- Creator payout reconciliation lulus.

## Prioritized Backlog

| Priority | Item | Reason |
|---:|---|---|
| P0 | Server-authoritative ledger | Fondasi seluruh ekonomi |
| P0 | Wallet/account auth | Mencegah impersonation |
| P0 | Economy abuse controls | Mencegah inflation dan treasury drain |
| P1 | Analytics dan remote config | Membuat keputusan berbasis data |
| P1 | Quest dan level | Retention sebelum monetization |
| P1 | Profile dan custom name | Identitas dasar |
| P1 | Cosmetic catalog/wardrobe | Monetisasi paling aman |
| P1 | Multiplayer cosmetic sync | Memberi nilai sosial pada cosmetic |
| P2 | Farm decoration mode | Collection dan expression loop |
| P2 | Mini season pass | Recurring content validation |
| P2 | Farm visit/showcase | Memperkuat social spending |
| P3 | Subscription | Setelah content cadence stabil |
| P3 | Creator marketplace | Setelah entitlement/moderation matang |
| P4 | Optional NFT marketplace | Setelah security dan demand terbukti |

## Explicit Non-Goals For MVP

- Mainnet token launch.
- Guaranteed play-to-earn income.
- Tradable basic crops dan seeds.
- Loot box berbayar.
- Guild system kompleks.
- Open creator uploads tanpa moderation.
- NFT untuk seluruh item.
- Cross-chain bridge.
- Cash-out dari routine farming.
- Paid yield multiplier.

## Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Local Game Coin dimanipulasi | Critical | Durable authoritative ledger |
| Unlimited/repeated token reward | Critical | Treasury budget, caps, auth, invariant tests |
| Signer ETH terkuras | Critical | Disable payout, daily/global cap, reserve guard |
| Monetisasi terasa pay-to-win | High | Cosmetic-only guardrails dan economy review |
| Wallet friction menurunkan onboarding | High | Guest-first onboarding dan optional wallet |
| Season content terlambat | High | Content freeze, templates, smaller mini season |
| Creator copyright violation | High | Moderation, declaration, takedown, creator agreement |
| Chat/social abuse | High | Report/block/mute, moderation, rate limit |
| AI operating cost meningkat | Medium | Quota, cache, small model, deterministic fallback |
| Gas lebih besar dari margin item | High | Off-chain entitlement default, optional batch mint |
| Platform store policy conflict | High | Policy/legal review dan platform-compliant billing |
| Token dianggap investasi | High | No return promises, optional utility, legal review |
| Low cosmetic demand | Medium | Preview tests, first-party collections, user research |
| Marketplace tidak likuid | Medium | Do not launch before demand; focus first-party store |

## Financial Scenario Template

Isi template ini setelah analytics dan payment sandbox tersedia.

| Metric | Conservative | Base | Upside |
|---|---:|---:|---:|
| Monthly active users | TBD | TBD | TBD |
| Paying conversion | TBD | TBD | TBD |
| Average order value | TBD | TBD | TBD |
| Gross monthly purchases | TBD | TBD | TBD |
| Store/payment fees | TBD | TBD | TBD |
| Creator share | TBD | TBD | TBD |
| Refunds | TBD | TBD | TBD |
| Hosting/RPC/AI variable cost | TBD | TBD | TBD |
| Contribution margin | TBD | TBD | TBD |

Jangan mengisi proyeksi dengan angka pengguna yang tidak memiliki dasar acquisition plan.

## Decision Gates

### Gate A: Boleh Membuka Real-Value Economy?

Jawaban hanya `ya` jika seluruh Economy Safety Gate terpenuhi, audit selesai, monitoring aktif, dan legal review menyetujui model.

### Gate B: Boleh Membangun Cosmetic Store?

Jawaban `ya` jika profile, entitlement, analytics, preview, dan payment sandbox tersedia. Cosmetic store dapat dibangun sebelum token marketplace.

### Gate C: Boleh Membuka Season Pass?

Jawaban `ya` jika quest/XP stabil, content pipeline siap, dan retention baseline cukup untuk diuji.

### Gate D: Boleh Membuka Creator Marketplace?

Jawaban `ya` jika first-party cosmetic demand terbukti, moderation/legal/payout siap, dan entitlement reconciliation stabil.

### Gate E: Boleh Menjadikan Item NFT?

Jawaban `ya` hanya untuk collectible yang mendapat manfaat nyata dari transferability dan setelah gas, custody, legal, recovery, serta marketplace risk dipahami.

## First 90-Day Execution Plan

### Days 1-30

- Freeze unsafe conversion untuk production real-value.
- Pilih database dan account model.
- Definisikan authoritative asset matrix.
- Tambahkan analytics schema dan funnel dashboard.
- Desain player profile, level, dan quest model.
- Buat cosmetic art direction dan modular sprite feasibility test.
- User interview minimal 5-10 target players.

### Days 31-60

- Implement profile, XP, daily quest, dan remote config.
- Implement cosmetic catalog, entitlement, wardrobe, dan preview.
- Buat first collection assets.
- Sync cosmetic loadout ke multiplayer.
- Jalankan usability test shop dan wardrobe.
- Siapkan payment sandbox dan purchase reconciliation.

### Days 61-90

- Launch closed Cosmetic MVP test.
- Ukur shop view, preview, equip, dan sandbox conversion.
- Implement 20-level mini season.
- Tambahkan farm visit prototype atau showcase sederhana.
- Review D1/D7, content cost, AI cost, dan cosmetic demand.
- Putuskan lanjut full season, iterate cosmetic, atau fokus retention.

## Immediate Next Actions

1. Buat authoritative asset matrix untuk Game Coin, TANI, ETH, seed, crop, land, cosmetic, dan entitlement.
2. Putuskan guest account versus wallet-first onboarding.
3. Pilih persistent storage dan ledger architecture.
4. Tambahkan analytics sebelum membuat banyak fitur baru.
5. Buat UX flow profile, quest, wardrobe, dan cosmetic shop.
6. Lakukan modular player sprite proof-of-concept.
7. Buat satu collection `Petani Nusantara` sebagai vertical slice.
8. Uji minat pemain dengan preview dan fake-door shop tanpa mengambil pembayaran.
9. Hitung content production cost per skin/pet/theme.
10. Review hasil sebelum membangun season, subscription, atau marketplace.

## Open Decisions

- Apakah core game dapat dimainkan tanpa wallet?
- Apakah Game Coin sepenuhnya off-chain dan non-redeemable?
- Apakah TANI tetap digunakan di produk komersial atau hanya prototype/community utility?
- Payment channel apa yang digunakan untuk Web dan Android?
- Apakah cosmetic menggunakan modular layered sprites atau full sprite sheets?
- Siapa yang memproduksi art secara berkelanjutan?
- Apakah farm decoration menggunakan grid placement atau preset layout?
- Berapa target usia pemain dan konsekuensi moderation/parental control?
- Wilayah launch pertama dan kewajiban legal apa yang berlaku?
- Siapa owner untuk economy, LiveOps, moderation, dan customer support?

## Definition Of Business-Ready Prototype

- Core farming dapat dimainkan tanpa transaksi blockchain.
- Game state bernilai tersimpan server-side.
- Wallet adalah opsi ownership, bukan blocker onboarding.
- Quest dan level memberi tujuan minimal tujuh hari.
- Cosmetic dapat dipreview, dimiliki, dipakai, dan terlihat di multiplayer.
- Tidak ada cosmetic yang memengaruhi hasil ekonomi.
- Funnel dan KPI dapat diukur.
- Purchase sandbox idempotent dan dapat direkonsiliasi.
- Economy exploit kritis ditutup.
- Privacy, terms, support, dan moderation plan tersedia.
- Tim memiliki keputusan go/no-go berdasarkan data, bukan hanya jumlah fitur.

## Product Principle Checklist

Sebelum menyetujui fitur baru, tanyakan:

- Apakah fitur ini membuat core game lebih menyenangkan?
- Apakah fitur ini menambah alasan pemain kembali?
- Apakah fitur ini memperkuat identitas atau hubungan sosial?
- Apakah pemain gratis tetap mendapat pengalaman utuh?
- Apakah fitur dapat menjadi pay-to-win?
- Apakah state dan reward dapat diverifikasi server?
- Apakah biaya operasional dan support dapat dikontrol?
- Apakah legal, privacy, dan platform policy sudah dipertimbangkan?
- Apakah keberhasilan fitur dapat diukur?
- Apakah ada kill switch atau rollback plan?

Jika beberapa jawaban belum jelas, fitur belum siap masuk production roadmap.

## Investor And Operator Readiness

Bagian ini melengkapi product strategy dengan kerangka pembuktian pasar, finansial, organisasi, dan keputusan investasi. Semua angka yang belum didukung data ditulis `TBD`. Angka baru boleh digunakan dalam forecast setelah sumber, tanggal, dan asumsi tercatat.

### Primary Business Decision: 18 Bulan

Fokus yang direkomendasikan:

> Taniin adalah consumer social farming game Indonesia-first dengan monetisasi cosmetic dan mini-season. AI adalah fitur pendukung yang harus membuktikan uplift. Web3, creator marketplace, subscription, dan brand platform tetap sebagai option, bukan core scope 18 bulan pertama.

Prioritas model:

| Model | Status 18 bulan | Buyer | Revenue unit |
|---|---|---|---|
| Consumer farming game | Primary | Pemain | Cosmetic dan season purchase |
| Brand-sponsored event | Experiment | Brand/partner | Paid pilot atau campaign |
| AI companion product | Supporting feature | Pemain | Tidak berdiri sendiri |
| Creator marketplace | Deferred | Pemain dan creator | Marketplace fee |
| Web3 collectible ecosystem | Deferred/optional | Collector | Optional mint/market fee |
| Educational/agriculture platform | Opportunity test | Institusi | Project/pilot fee |

Perubahan primary business membutuhkan decision memo yang menjelaskan bukti, dampak roadmap, kebutuhan tim, margin, dan risiko legal.

## Market Sizing

### Launch Scope Decision

Sebelum menghitung pasar, tetapkan:

- Geography awal: Indonesia atau wilayah lain (`TBD`).
- Platform awal: Web, Play Store Android, direct APK, atau kombinasi (`TBD`).
- Target umur: `TBD` setelah legal dan user research.
- Device tier minimum: `TBD` berdasarkan performance test.
- Bahasa launch: Bahasa Indonesia; kebutuhan localization tambahan `TBD`.
- Business outcome: sustainable indie studio, regional publisher opportunity, atau venture-scale company (`TBD`).

### TAM, SAM, SOM Framework

TAM tidak boleh memakai seluruh pengguna internet sebagai pasar. Gunakan spending dan pemain pada genre/platform/geography yang relevan.

| Layer | Definisi Taniin | Nilai | Sumber dan tanggal |
|---|---|---:|---|
| TAM | Consumer spending farming, cozy, social simulation pada market relevan | TBD | TBD |
| SAM | Spending target umur, geography, platform, dan price band yang dapat dilayani | TBD | TBD |
| SOM 24 bulan | Revenue yang dapat diraih berdasarkan channel budget dan kapasitas tim | TBD | Bottom-up model |
| SOM 36 bulan | Revenue setelah channel/product expansion yang sudah dibuktikan | TBD | Bottom-up model |

### Bottom-Up Market Model

```text
Reachable Impressions
  x Click-Through Rate
  x Game Start Rate
  x Onboarding Completion
  x Retained MAU Rate
  x Paying Conversion
  x Purchase Frequency
  x Average Order Value
  = Gross Bookings
```

Sediakan conservative, base, dan upside case. Setiap variable harus berasal dari test Taniin atau benchmark yang benar-benar sebanding berdasarkan genre, platform, geography, dan acquisition channel.

### Outcome Range

Model harus menjawab:

- Berapa MAU agar studio mencapai operating break-even?
- Berapa retained-user CAC maksimum?
- Berapa payer dan ARPPU yang dibutuhkan untuk mendanai satu season?
- Apakah hasil base case cukup untuk venture return atau lebih cocok sebagai profitable indie studio?
- Apa perubahan strategi jika market size tidak mendukung venture-scale outcome?

## Competitive Evidence

### Named Competitor Set

Competitor research minimal mencakup:

- Direct farming/social: Hay Day, FarmVille, Township, Family Farm, dan produk regional yang relevan.
- Cozy/decorative: Stardew Valley, Animal Crossing, Palia, Disney Dreamlight Valley, dan mobile adjacent titles.
- Social expression/UGC: Roblox, ZEPETO, Highrise, dan produk avatar/decorating lain.
- Web3 farming/social: produk aktif dan produk gagal untuk mempelajari token collapse, wallet friction, dan marketplace liquidity.

### Competitor Matrix Template

| Product | Platform/market | Core loop | Retention systems | Social visibility | Monetization | Price ladder | Content cadence | Team scale | Player complaints | Source/date |
|---|---|---|---|---|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Untuk setiap competitor, kumpulkan:

- Download dan revenue estimate dengan sumber dan tanggal.
- Session pattern dan target demographic.
- Monetization mechanics dan SKU.
- Social dan cosmetic visibility.
- Update cadence serta volume content.
- Review mining dari store, community, Reddit/Discord, dan creator coverage.
- Bukti traction di Indonesia atau target geography.
- Estimated studio/team scale.
- Alasan pemain bertahan dan churn.

### Why Taniin

Hipotesis diferensiasi harus diuji terpisah:

| Hypothesis | Test | Primary metric | Scale threshold | Kill threshold |
|---|---|---|---|---|
| Nusantara meningkatkan daya tarik | Creative/landing A/B | Qualified start conversion | TBD | Tidak ada uplift setelah sample valid |
| Pak Tani AI meningkatkan retention | Scripted vs generative test | D7/return sessions | TBD | Uplift tidak menutup cost/risk |
| Social showcase meningkatkan cosmetic value | Farm visibility test | Equip/shop/purchase intent | TBD | Participation terlalu rendah |
| Optional ownership menambah demand | Transferable vs cheaper entitlement | Paid conversion/WTP | TBD | Friction/cost lebih besar dari uplift |

Defensible advantage tidak boleh hanya berupa daftar fitur. Bukti yang dicari dapat berupa distribution partnership, local creator supply, recognizable IP, community density, proprietary content pipeline, atau content cost advantage.

## Customer Discovery Program

### Research Streams

1. Qualitative discovery
   - Target 20-30 participants lintas segment hypothesis.
   - Rekrut pengguna farming/cozy aktif, lapsed players, payer, non-payer, decorator, dan Web3-aware/non-Web3 users.
2. Observed concept/usability sessions
   - Target 50-100 sessions bertahap.
   - Ukur perilaku, bukan hanya opini.
3. Quantitative validation
   - Dilakukan setelah istilah dan trade-off dipahami dari qualitative research.
4. Behavioral monetization test
   - Fake-door shop, payment sandbox, refundable reservation, atau founder pack yang legal.
5. Churn research
   - Wawancarai pengguna yang berhenti dan yang gagal onboarding.

### Recruitment Controls

- Jangan mengandalkan teman founder, tim, kampus sendiri, komunitas crypto, atau peserta pameran saja.
- Catat geography, umur, device, game yang dimainkan, spending history, dan acquisition source.
- Pisahkan organic, incentivized, event, dan paid cohorts.
- Hindari memasukkan tim/test account dalam KPI produk.

### Required Questions And Evidence

- Game farming/cozy apa yang dimainkan dan mengapa?
- Apa alasan mulai, bertahan, membayar, dan churn?
- Tiga pembelian game terakhir dan nominal aktual.
- Preferred payment methods.
- Reaksi terhadap guest account, login, wallet, public chat, AI, NFT, dan resale.
- Forced trade-off: crops vs decoration, AI vs handcrafted NPC, multiplayer vs farm visits, transferable vs cheaper non-transferable cosmetic.
- Apakah tema Nusantara mengubah perilaku atau hanya menghasilkan feedback positif?

### Research Repository

Simpan secara terstruktur:

- Research question.
- Recruitment criteria.
- Consent status.
- Interview/session date.
- Raw notes yang sudah menghapus data sensitif.
- Insight.
- Confidence.
- Product decision.
- Follow-up experiment.

## Core Product Hypothesis

Primary hypothesis:

> Target player kembali secara sukarela untuk mengembangkan dan mempercantik farm karena perubahan visual, collection progress, dan social recognition terasa memuaskan.

Minimum testable loop:

```text
Plant
  -> Return after meaningful elapsed time
  -> Harvest
  -> Choose/craft an improvement
  -> Display it
  -> Receive or seek social feedback
```

Core enjoyment harus diuji tanpa:

- Token reward.
- Cash-out promise.
- Mandatory event attendance.
- Test compensation.
- Excessive streak pressure.
- Konten season dalam jumlah besar.

Cohort rules:

- New independent users.
- Consistent time zone dan retention definition.
- Minimum onboarding exposure.
- Organic dan incentivized cohorts dilaporkan terpisah.
- Minimum sample dan confidence interval ditetapkan sebelum keputusan.
- Churn interview menjadi bagian evaluasi.

## Go-To-Market Plan

### Beachhead Cohort

Hipotesis awal:

> Pemain Android/Web Indonesia usia `TBD` yang sudah memainkan farming, cozy, decorating, atau social simulation games dan tertarik pada visual customization.

Hipotesis ini harus diganti jika customer research menunjukkan segment lain memiliki activation, retention, dan willingness to pay lebih tinggi.

### Channel Experiment Template

| Channel | Audience | Creative proposition | Budget | CPM/CPC | Start conversion | D7 retained CAC | Payer CAC | Duration | Owner | Stop rule |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| TikTok/Reels | TBD | Farm before/after | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Micro creator | TBD | Cosmetic/farm makeover | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Campus/event | TBD | Pak Tani and social demo | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Community | TBD | Nusantara collection | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Partner | TBD | Sponsored event | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Acquisition messages harus diuji secara independen:

- Relaxing farming.
- Nusantara identity.
- Farm decoration/showcase.
- Pak Tani AI.
- Community event.
- Optional digital ownership.

Jangan scale paid acquisition sebelum retained-user CAC dan monetization dapat diukur. Creative production cost dan creative fatigue harus masuk channel economics.

Community platform dipilih dari riset. Jangan mengasumsikan Discord; bandingkan WhatsApp, TikTok, Instagram, Facebook groups, Discord, dan in-game channels.

## Pricing And SKU Architecture

### Required Benchmarking

- Harga competitor di Indonesia dan target geography.
- Play/App Store price tiers jika digunakan.
- Local purchasing power dan payment preference.
- VAT, platform fee, gateway fee, refund, dan chargeback.
- Direct IDR versus premium currency.
- Regional pricing dan exchange-rate policy.

### Proposed SKU Ladder

| Tier | Product | Price hypothesis | Purpose | Evidence status |
|---|---|---:|---|---|
| Entry | Small accessory/emote | Rp5.000-Rp15.000 | First purchase | Unvalidated |
| Core | Character skin/pet | Rp20.000-Rp60.000 | Main cosmetic spend | Unvalidated |
| Bundle | Collection | Rp79.000-Rp149.000 | Higher AOV | Unvalidated |
| Pass | Mini/full season | Rp49.000-Rp129.000 | Recurring content | Unvalidated |
| Subscription | Taniin Club | Rp29.000-Rp49.000/month | Recurring service | Deferred |
| Founder | Limited supporter pack | TBD | Early validation | Requires legal/payment review |

Jika premium currency digunakan, definisikan pack, exact conversion, residual balance, expiry prohibition, refund handling, breakage accounting, dan price transparency. Direct IDR lebih sederhana untuk validation awal.

Price test mengukur conversion, revenue per eligible user, repeat purchase, refund/regret, dan fairness, bukan gross revenue saja. Manipulative reference price dan false discount dilarang.

## Payment Channel Architecture

| Channel | Billing provider | Fee/tax | Receipt validation | Refund authority | Restore entitlement | Cross-platform rule | NFT/token restriction |
|---|---|---|---|---|---|---|---|
| Play Store Android | TBD sesuai policy | TBD | Required | Platform/TBD | Required | TBD | Policy/legal review |
| Direct APK | TBD | TBD | Required | Merchant/TBD | Account-based | TBD | Legal review |
| Mobile Web | Licensed payment provider/TBD | TBD | Webhook + ledger | Merchant/provider | Account-based | TBD | Legal review |
| Desktop Web | Licensed payment provider/TBD | TBD | Webhook + ledger | Merchant/provider | Account-based | TBD | Legal review |
| Future iOS | Apple IAP/TBD | TBD | Required | Platform/TBD | Required | TBD | Policy/legal review |

Evaluate cards, bank transfer, e-wallet, dan QRIS melalui provider berlisensi. Taniin tidak boleh bertindak sebagai payment intermediary tanpa kewenangan.

Payment reconciliation harus menghubungkan:

```text
Store/Payment Receipt
  -> Payment Event
  -> Internal Order
  -> Entitlement Ledger
  -> Optional Blockchain Mint
  -> Refund/Chargeback Reversal Policy
```

Tentukan perilaku ownership setelah refund, chargeback, account deletion, atau NFT transfer sebelum menerima pembayaran nyata.

## 36-Month Financial Model

Model dibuat per bulan dan memiliki conservative, base, serta upside scenario.

### Revenue Drivers

- New users per channel.
- DAU, WAU, MAU, dan cohort retention.
- Active days per user.
- Payer conversion.
- Purchase frequency.
- AOV per SKU category.
- Season pass attach, completion, dan renewal.
- Subscription start, renewal, churn, serta involuntary churn.
- Partner deal value, probability, delivery period, dan recognition.

### Cost Drivers

- Platform/payment fee.
- VAT/tax.
- Refund, fraud, dan chargeback.
- Creator/partner share.
- AI usage.
- Hosting, database, RPC, storage, dan CDN.
- Moderation dan support.
- Art, animation, UI, QA, dan localization.
- Salary dan contractor.
- Legal, audit, insurance, dan software.
- User acquisition dan marketing content.
- Contingency dan shutdown reserve.

### Monthly Model Template

| Month | New users | MAU | Payers | Gross bookings | Net revenue | Variable cost | Contribution profit | Fixed cost | Operating profit/loss | Ending cash |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| M1 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Sensitivity Analysis

- D30 retention.
- Payer conversion.
- ARPPU.
- Purchase frequency.
- CPI dan retained-user CAC.
- Content production cost.
- Platform fee.
- Refund rate.
- AI interactions per MAU.
- Season cadence.

### Revenue Quality

Revenue mix target lama tetap hipotesis. Model setiap source secara terpisah:

| Source | Margin | Predictability | Sales cycle | Service effort | Concentration risk | Validation evidence |
|---|---|---|---|---|---|---|
| Cosmetics | TBD | TBD | Immediate consumer | Content-heavy | SKU/payer | Real purchases |
| Season pass | TBD | Seasonal | Seasonal | LiveOps-heavy | Season | Renewal |
| Subscription | TBD | Recurring | Immediate consumer | Monthly liability | Benefit/content | Renewal/churn |
| Partnership | TBD | Lumpy | Long/negotiated | High | Partner | Paid pilot/LOI |
| Marketplace | TBD | Volume dependent | Two-sided | Moderation/support | Liquidity | First-party + curated creator demand |

Consumer bookings, sponsorship, dan custom-development/service revenue dilaporkan terpisah.

## Budget, Runway, And Fundraising

### Current Position

| Item | Value | As of date |
|---|---:|---|
| Cash available | TBD | TBD |
| Monthly burn | TBD | TBD |
| Liabilities | TBD | TBD |
| Founder funding | TBD | TBD |
| Grants/partner funding | TBD | TBD |
| Runway | TBD months | TBD |

### Financing Ask

- Amount: `TBD`.
- Instrument: `TBD`.
- Target runway: `TBD` months.
- Milestone financed: evidence milestone, bukan hanya feature list.
- Follow-on requirement: `TBD`.
- Downside plan jika follow-on tidak tersedia: `TBD`.

### Use Of Funds Template

| Category | Amount | Percentage | Evidence delivered |
|---|---:|---:|---|
| Engineering/data/security | TBD | TBD | Authoritative state and reliable vertical slice |
| Art/content | TBD | TBD | Cosmetic collection and content pipeline evidence |
| User research/acquisition | TBD | TBD | Retention, CAC, and demand evidence |
| Infrastructure/AI | TBD | TBD | Cost and reliability evidence |
| Legal/security | TBD | TBD | Launch feasibility and risk reduction |
| Community/support | TBD | TBD | Safe closed/soft launch operation |
| Contingency | TBD | TBD | Runway protection |

Non-dilutive options seperti grants, publisher funding, paid pilots, dan platform programs dinilai bersama restriction, revenue share, IP rights, dan delivery obligation.

## Team And Execution Capacity

### Team Inventory

| Person/role | Full/part-time | Weekly availability | Relevant shipped experience | Current responsibility | Key gap |
|---|---|---:|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD |

Required capabilities:

- Product and game design.
- Flutter/Flame engineering.
- Backend/data/security.
- Economy design.
- Art and animation.
- UI/UX.
- QA and release.
- Analytics/growth.
- LiveOps.
- Community, moderation, and support.
- Payment/legal/finance.

Tidak semua harus menjadi employee, tetapi person-week, availability, contractor lead time, cost, dan review owner harus masuk roadmap dan financial model.

### RACI Decisions

Tetapkan Responsible, Accountable, Consulted, dan Informed untuk:

- Product scope.
- Economy/pricing change.
- Content approval.
- Payment/refund policy.
- Token treasury.
- Security incident.
- Moderation escalation.
- Production deployment.
- Spending dan hiring.
- Partnership approval.

### Operating Cadence

- Weekly product and KPI review.
- Biweekly experiment review.
- Monthly business and cash review.
- Per-release risk review.
- Per-season postmortem.
- Quarterly roadmap and runway decision.

## Content Economics

### Asset Bill Of Materials

| Content type | Concept hours | Production/animation | Integration | QA | Marketing art | Localization | Contractor cost | Expected life | Reuse rate |
|---|---:|---:|---:|---:|---:|---:|---:|---|---:|
| Character skin | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Headwear | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Pet | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Harvest effect | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Farm theme | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Fully loaded cost termasuk revision, multiplayer compatibility, device QA, file-size impact, support, dan future rig compatibility.

```text
Break-Even Purchases
  = Fully Loaded Content Cost
  / Contribution Margin Per Purchase
```

Content KPI:

- Revenue per art-hour.
- Revenue per content set.
- Sell-through.
- Preview-to-purchase conversion.
- Equip rate.
- Repeat-use days.
- Catalog tail revenue.
- Cannibalization.
- Subscriber content liability.
- Pass reward cost per purchaser.
- Cost of free-track content.

Sebelum full season, buktikan modularity: berapa item berkualitas yang dapat dihasilkan satu base rig/theme dan berapa biaya maintenance-nya.

## Live Operations Capacity

### Two-Season Capacity Test

Jangan menyatakan cadence sustainable sebelum tim menyelesaikan dua mini-season berurutan.

| Deliverable | Season A | Season B | Owner | Person-hours | Content lock | QA start |
|---|---:|---:|---|---:|---|---|
| New quests | TBD | TBD | TBD | TBD | TBD | TBD |
| Reused quest templates | TBD | TBD | TBD | TBD | TBD | TBD |
| Cosmetics | TBD | TBD | TBD | TBD | TBD | TBD |
| Decorations | TBD | TBD | TBD | TBD | TBD | TBD |
| Dialogue/localization | TBD | TBD | TBD | TBD | TBD | TBD |
| Marketing assets | TBD | TBD | TBD | TBD | TBD | TBD |

LiveOps juga membutuhkan:

- Offer, quest, event, dan reward configuration tanpa build baru.
- Compensation dan item grant tools.
- Ban/moderation tools.
- Payment/economy incident response.
- On-call and escalation schedule.
- Weekend/holiday coverage.
- Support SLA.
- Rollback dan postmortem.

## AI Value And Cost Validation

Pisahkan deterministic/scripted interaction dari generative AI.

| Use case | Scripted possible? | Generative value hypothesis | Safety risk | Cost cap | Fallback |
|---|---|---|---|---:|---|
| Tutorial/help | Yes | Natural clarification | Hallucination | TBD | Scripted FAQ |
| Daily advice | Yes | Personalized context | Bad advice | TBD | Rule engine |
| Quest dialogue | Yes | Variety | Inappropriate text | TBD | Templates |
| Farm strategy | Partial | Contextual recommendation | Economic/financial claims | TBD | Deterministic calculator |

AI test membandingkan scripted dan generative variants pada retention, quest completion, satisfaction, latency, safety incidents, dan cost per retained user.

Model biaya memasukkan prompt, output, memory, moderation, storage, embeddings jika ada, retry, dan provider failure. Tetapkan per-user daily quota dan global monthly budget.

Tambahkan safety policy untuk minors, sexual content, harassment, self-harm, financial advice, agricultural claims, dan transaction request. Definisikan retention/deletion AI conversations dan provider migration plan.

## Social Density And Moderation Economics

### Social Density Metrics

- Users dengan minimal satu active friend.
- Probability melihat pemain lain.
- Farm visits sent/received.
- Likes dan guestbook activity per farm.
- Cooperative-order matchmaking time.
- Social feature participation.

Low-density fallback:

- Curated featured farms.
- Asynchronous discovery.
- NPC/community farms.
- Seeded showcase yang dilabeli jelas.
- AI-assisted community prompts tanpa fake player claims.

### Moderation Capacity

| Surface | Daily volume | Report rate | Moderator hours | Language coverage | SLA | Escalation owner |
|---|---:|---:|---:|---|---|---|
| Public chat | TBD | TBD | TBD | TBD | TBD | TBD |
| Guestbook | TBD | TBD | TBD | TBD | TBD | TBD |
| Profile/name | TBD | TBD | TBD | TBD | TBD | TBD |
| Creator upload | TBD | TBD | TBD | TBD | TBD | TBD |

Controls:

- Filtering, report, mute, block, appeal, dan timely response.
- Fraud controls untuk gifting, account theft, coercion, dan real-money trading.
- Evidence retention sesuai privacy policy.
- Indonesian language, slang, evasion, dan cultural context.
- Public chat dapat ditunda/ditutup jika safety burden tidak sebanding dengan value.

## Token Decision Memo

Default production decision:

> Commercial cosmetics dan progression tetap off-chain. TANI tidak masuk core consumer economy sampai transferability terbukti memberi incremental demand yang lebih besar daripada legal, security, support, gas, treasury, dan UX burden.

Sebelum mainnet atau real-value token, memo wajib menjawab:

- Mengapa token diperlukan dibanding entitlement database?
- Supply cap, mint authority, dan allocation.
- Team/investor/advisor vesting dan lockup.
- Utility dan explicit non-rights.
- Emission schedule, sinks, velocity, dan concentration.
- Treasury denomination dan exposure limit.
- Custody dan signer separation.
- Liquidity/market-making policy.
- Accounting dan tax.
- Jurisdiction, sanctions, KYC/AML trigger, dan transfer restriction.
- Upgradeability/admin rights.
- Lost wallet dan recovery.
- Exploit, chain fork, bridge, deprecation, dan end-of-game policy.
- Governance rights jika ada.

### Community Treasury Definition

Istilah `community treasury` tidak digunakan secara publik sebelum ditentukan apakah itu:

- Company-controlled marketing budget.
- Contractual creator pool.
- On-chain treasury.
- Separate entity/foundation.

Definisikan beneficial owner, legal controller, eligible spending, annual/per-transaction limit, signer separation, approval, conflict policy, tax, audit, reporting, dan apakah community memiliki enforceable rights atau hanya advisory input.

## Jurisdiction-Specific Legal Plan

Dokumen ini bukan nasihat hukum. Launch komersial memerlukan counsel sesuai jurisdiction.

### Legal Foundation

- Operating entity dan IP owner: `TBD`.
- Governing law: `TBD`.
- Launch jurisdictions: `TBD`.
- Data controller/processors: `TBD`.
- Merchant of record: `TBD`.
- Target age dan rating: `TBD`.

### Required Legal Work Products

- Terms of Service.
- Privacy Policy dan data deletion process.
- Refund Policy.
- Community Guidelines.
- AI Policy.
- Creator Agreement.
- Marketplace Terms jika relevan.
- Payment, virtual currency, token/NFT, custody, KYC/AML, sanctions, dan tax memo.
- Child-directed-service analysis.
- Data transfer, processor agreement, retention, dan breach response.
- Trademark clearance untuk Taniin, logo, character, dan collection.
- Cultural-rights/appropriation review untuk motif dan tradisi Nusantara.

Legal matrix dibuat per geography untuk consumer protection, digital goods, virtual currency, token classification, creator payout, VAT/withholding, ads/sponsor disclosure, contest/prize, privacy, dan child safety.

## Creator Marketplace Operating Model

Revenue share selalu menjelaskan basis:

```text
Consumer Price
  - Indirect Tax
  - Store/Payment Fee
  - Refund/Chargeback Reserve
  = Net Receipts

Creator Payout
  = Creator Share x Net Receipts
```

Tentukan:

- Payout minimum, timing, currency, FX, dan failed payout.
- Refund/chargeback reserve sebelum creator payout.
- Tax documentation dan withholding.
- License, exclusivity, derivative rights, moral rights, takedown, dan indemnity.
- Repeat-infringer dan appeal policy.
- AI-generated asset disclosure dan provenance.
- Cultural sensitivity dan age-rating standards.
- File security, performance, size, animation, dan compatibility requirements.
- Moderator throughput serta cost per submission.

Mulai dengan curated paid creator program 3-5 creator. Self-service marketplace hanya dibangun setelah demand, sell-through, moderation cost, dan buyer liquidity terbukti.

## Partnership Sales Model

Pilih satu initial buyer category. Contoh hypothesis:

> Brand makanan/minuman lokal yang ingin youth engagement melalui seasonal campaign bertema Nusantara atau sustainability.

### Package Template

| Package | Deliverables | Duration | Approval rounds | Price | Fully loaded cost | Gross margin | Reporting |
|---|---|---:|---:|---:|---:|---:|---|
| Sponsored cosmetic | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Seasonal quest | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Community event | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Tetapkan minimum deal size agar custom work tidak merugi, custom-engineering limit, sponsorship labeling, claims review, political neutrality, dan partner concentration limit.

### Pipeline

| Target | Buyer persona | Contact | Stage | Estimated value | Probability | Decision date | Procurement requirement | Owner |
|---|---|---|---|---:|---:|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Hanya paid pilot atau signed LOI dengan buyer yang memiliki budget authority boleh masuk weighted forecast.

## Metric Dictionary

Setiap KPI memiliki formula, denominator, time window, cohort eligibility, exclusions, source of truth, dan owner.

| Metric | Definition | Eligibility | Exclusions | Window | Source | Owner |
|---|---|---|---|---|---|---|
| Onboarding completion | Completed onboarding / onboarding starters | New users | Team/test/fraud | Session | Analytics | TBD |
| D1 retention | Eligible new users active on defined D1 / eligible D0 users | New qualified users | Team/test/fraud | Defined timezone | Analytics | TBD |
| D7 retention | Eligible new users active on defined D7 / eligible D0 users | New qualified users | Team/test/fraud | Defined timezone | Analytics | TBD |
| Paying conversion | Unique payers / purchase-eligible active users | Eligible users | Sandbox/test/refunded-only | Cohort/month | Payment + analytics | TBD |
| ARPDAU | Net recognized consumer revenue / DAU | Active users | Tax/refunds per policy | Daily/monthly | Finance + analytics | TBD |
| ARPPU | Net recognized consumer revenue / unique payers | Payers | Test/refunded-only | Monthly | Finance | TBD |
| Retained-user CAC | Acquisition spend / new users retained to target day | Attributed users | Organic/test | Channel cohort | Attribution | TBD |

Tambahkan definitions untuk rolling retention, resurrection, DAU/MAU, purchase frequency, AOV, refund, crash-free sessions, AI cost/user, content margin, social participation, dan creator sell-through.

Experiment harus memiliki hypothesis, primary metric, guardrail, sample-size/power, minimum detectable effect, end date, owner, dan precommitted decision rule.

## Economy Simulation

Buat spreadsheet atau simulation untuk:

- Game Coin issuance dan sinks.
- Seed/crop accumulation.
- Plot dan progression completion.
- Quest dan season rewards.
- Cosmetic crafting materials.
- Inventory saturation.
- Currency velocity dan distribution.

Model cohorts:

- New/free casual.
- Median retained.
- Highly engaged.
- Payer.
- Bot/exploit behavior.

Outputs:

- Time-to-unlock.
- Time-to-content exhaustion.
- Source/sink ratio.
- Balance percentiles.
- Sink exhaustion.
- New-player catch-up burden.
- Effect dari economy adjustment.

Off-chain economy dan token economy tetap dipisahkan kecuali bridge telah dibenarkan oleh legal dan product evidence. Economy change membutuhkan approval authority, communication plan, dan compensation policy.

## Company-Value Milestones

Setiap phase memiliki lima kategori evidence:

| Stage | Product | Customer | Commercial | Operational | Financial |
|---|---|---|---|---|---|
| Concept validation | Testable proposition | Target users choose/understand concept | WTP signal | Research repeatable | Research cost known |
| Core-loop alpha | Minimum loop shipped | Qualified D1/D7 evidence | No token incentive dependency | Stable test operation | Cost per tester known |
| Cosmetic MVP | Entitlement and wardrobe | Preview/equip demand | Real or valid sandbox conversion | Purchase reconciliation | Content unit economics |
| Mini-season | Quest/pass shipped | Retention uplift | Pass demand | On-time cycle | Incremental margin |
| Soft launch | Reliable product | Repeatable cohorts | Paying conversion | Support/moderation SLA | LTV/CAC hypothesis |
| Scale gate | Multi-cohort reproducibility | Stable retention | Repeat purchase | Sustainable LiveOps | Contribution-positive growth |
| Web3 gate | Optional ownership path | Transferability demand | Incremental net value | Security/legal readiness | Burden lower than uplift |

## Kill, Pivot, And Scale Criteria

Threshold numerik ditetapkan sebelum experiment setelah baseline dan sample plan tersedia. Tidak boleh diubah setelah hasil diketahui tanpa decision-log explanation.

### Core Product

- Stop atau redesign core loop jika dua iterasi material pada independently recruited cohorts gagal mencapai onboarding dan D1/D7 thresholds.
- `Kurang content` hanya diterima jika churn evidence secara spesifik mendukungnya.
- Jangan menambah season, marketplace, atau token untuk menutupi core retention yang lemah.

### Positioning

- Hapus Nusantara, AI, social, atau Web3 dari primary acquisition message jika tidak meningkatkan qualified start atau retention dalam controlled tests.
- Fitur dapat tetap ada hanya jika value terukur sebanding dengan biaya.

### Cosmetics

- Redesign/stop kategori jika shop exposure dan preview memadai tetapi real conversion tetap di bawah threshold pada beberapa collection/price tests.
- Stop produksi asset class jika fully loaded cost tidak kembali dalam target payback period.
- Scale hanya jika repeat purchase dan contribution margin sehat, bukan karena satu whale.

### Seasons

- Jangan naik dari mini-season ke full season jika retention/revenue uplift net of content and operations tidak bermakna.
- Stop cadence jika cycle kedua tidak dapat dikirim tepat waktu tanpa overtime atau contractor spending yang tidak sustainable.

### Subscription

- Jangan launch sebelum monthly content cadence stabil.
- Stop/redesign jika renewal, margin, atau benefit usage gagal setelah cohort matang.

### AI

- Default ke scripted Pak Tani jika generative AI tidak memberi uplift yang menutup cost, latency, safety, dan privacy burden.

### Social

- Simplify atau remove feature dengan participation dan retention uplift rendah.
- Tutup public chat jika moderation/safety burden melebihi kapasitas.

### Creator Marketplace

- Jangan bangun self-service sebelum first-party cosmetics dan curated creators membuktikan buyer demand dan supply quality.
- Stop submissions jika moderation/support cost melampaui platform margin.

### Web3

- Jangan mainnet jika transferability demand tidak terbukti.
- Hapus token dari commercial roadmap jika legal/security/support cost lebih besar daripada incremental revenue atau retention.
- Jangan menggunakan token price atau speculative volume sebagai core product KPI.

### Partnerships

- Jangan menambah custom scope tanpa minimum margin dan reusable product value.
- Hentikan pipeline category jika sales cycle dan delivery cost tidak mendukung target margin setelah sejumlah test yang ditetapkan.

### Company-Level

- Tetapkan minimum runway buffer sebelum hiring atau feature expansion.
- Freeze hiring jika evidence milestone terlambat dan runway jatuh di bawah threshold.
- Pivot ke profitable indie, B2B branded experience, educational product, atau wind-down berdasarkan precommitted runway dan traction gates.
- Jangan menggalang dana hanya untuk memperpanjang eksperimen yang telah gagal tanpa thesis baru yang dapat diuji.

## Shutdown And Asset Continuity

Sebelum menerima pembayaran, definisikan:

- Minimum service-support period setelah purchase.
- Shutdown notice period.
- Refund untuk unused pass/subscription/premium balance.
- Settlement creator balance.
- Treatment purchased cosmetics.
- Account data export/deletion.
- TANI dan collectible treatment.
- Durability NFT metadata/assets.
- Apa utility yang hilang ketika server berhenti.
- Reserve untuk refund, creator payout, dan closure operation.

Terms harus menjelaskan virtual-item license, service changes, ban, shutdown, transfer limitation, dan dispute process tanpa membuat ownership claim yang menyesatkan.

## Revised Evidence-First 90-Day Plan

Plan ini menggantikan asumsi bahwa seluruh profile, quest, cosmetic, payment, season, dan social system harus production-ready dalam 90 hari.

### Days 1-30: Evidence And Safety

- Putuskan primary business dan launch scope.
- Disable/isolate unsafe real-value economy.
- Pasang minimum analytics dan metric dictionary.
- Jalankan 20-30 qualitative interviews bertahap.
- Ukur baseline onboarding dan core loop pada independent testers.
- Buat named competitor matrix.
- Buat modular sprite/cosmetic technical proof.
- Estimasi team capacity, content BOM, cash, burn, dan runway.

Gate:

- Core hypothesis dipahami target users.
- Tidak ada critical economy exposure.
- Vertical slice scope dan evidence target disetujui.

### Days 31-60: Commercial Vertical Slice

- Implement minimum account/profile dan entitlement source of truth.
- Buat satu `Petani Nusantara` collection, wardrobe, preview, dan equip.
- Sync loadout ke multiplayer hanya jika biaya integrasi masuk scope.
- Jalankan fake-door/payment sandbox test.
- Uji Nusantara, AI, dan Web3 acquisition messages terpisah.
- Isi first version content economics dan channel test table.

Gate:

- Cosmetic desirability dan technical feasibility memiliki evidence.
- Cost per SKU diketahui.
- Tidak ada entitlement yang bergantung pada local storage.

### Days 61-90: Retention And Monetization Decision

- Closed test vertical slice pada qualified cohort.
- Ukur core retention, preview, equip, purchase intent/valid transaction, dan satisfaction.
- Tambahkan quest track kecil hanya jika dibutuhkan untuk menguji return loop.
- Uji farm showcase sederhana jika social recognition adalah primary hypothesis.
- Isi conservative/base/upside financial model awal.
- Buat go/redesign/stop decision untuk cosmetic MVP, AI, social, dan mini-season.

Gate:

- Keputusan berikutnya didasarkan pada cohort, unit economics, team capacity, dan runway.
- Full season, subscription, creator marketplace, serta mainnet tetap deferred sampai gate masing-masing terpenuhi.

## Execution Log

### 2026-07-25: Phase 0 Economy Safety, Fail-Closed Baseline

Status: implemented in code, pending persistent auth/ledger infrastructure.

Changes delivered:

- Public `/game-actions` now requires production wallet authentication to be enabled and a verified wallet session.
- Economy requests require an `Idempotency-Key`.
- Concurrent duplicate idempotency keys share one in-flight result in the supported single-process runtime.
- The legacy unsafe-economy flag can no longer reopen blocked value flows.
- Phase 0 backend allowlist contains only burn-only actions: `SELL_CROP` and `SWAP_TANI_COIN`.
- The following actions fail closed before RPC/signer initialization: `BUY_LAND`, `SELL_LAND`, `PLANT`, `HARVEST`, `BUY_SEED`, `SWAP_CROP`, `SWAP_COIN`, `SWAP_ETH_COIN`, and `SWAP_COIN_ETH`.
- Regression tests cover blocked actions, legacy-flag bypass, missing idempotency keys, and concurrent duplicate execution.

Business impact:

- Local Game Coin can no longer be converted through the public API into newly minted TANI or signer ETH.
- Free land mint/resale and rapid plant/harvest value loops are blocked at the signer boundary.
- ETH funding replay cannot mint additional value because the funding action is disabled.
- Existing local farming remains prototype gameplay and is not authoritative economic proof.
- Production on-chain actions remain unavailable until wallet signature sessions work end-to-end.

Known limitations:

- Nonce, session, rate-limit, and idempotency state remain in process memory.
- Flutter/ConnectKit does not yet request a nonce, sign it, return session metadata, or send bearer/idempotency headers.
- No durable Game Coin/inventory/plot ledger exists.
- Existing Solidity contracts do not atomically consume seeds, enforce maturity, issue harvest rewards, or settle land economics.
- Burn-only actions are intentionally unreachable from the current public client until authentication is complete.

Next required milestone:

1. Choose a persistent store for nonce, session, rate limit, and idempotency records.
2. Implement ConnectKit nonce request, wallet signature, and verification.
3. Transport verified session metadata to Flutter Web and Android.
4. Send bearer and stable idempotency headers from `ChainClient`.
5. Keep manual-address connections read-only.
6. Add an authoritative database ledger before re-enabling any mint, reward, land, funding, or payout action.
