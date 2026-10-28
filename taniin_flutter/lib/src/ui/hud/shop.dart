part of '../game_hud.dart';

class _ShopPanel extends StatelessWidget {
  const _ShopPanel({required this.farmState, required this.onClose});

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return KayuPanel(
      title: 'Toko Benih',
      icon: Icons.storefront,
      subtitle: 'Satu paket berisi ${FarmStateController.seedBundleAmount} benih.',
      trailing: KayuWell(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: CoinAmount(amount: farmState.coins, size: narrow ? 20 : 24),
      ),
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShopQuantity(farmState: farmState),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 640 ? 1 : 2;
              final gap = 14.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < farmState.seeds.length; i++)
                    SizedBox(
                      width: cardWidth,
                      child: _ShopSeedCard(farmState: farmState, seedIndex: i),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            farmState.onChainMode
                ? 'Benih yang kamu beli dicatat sebagai item di Sepolia.'
                : 'Mode tamu: benih tersimpan di perangkat ini.',
            style: Kayu.teks(16, color: Kayu.kremRedup),
          ),
        ],
      ),
    );
  }
}

class _ShopQuantity extends StatelessWidget {
  const _ShopQuantity({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    final bundles = farmState.shopBundleQuantity;
    return KayuWell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Jumlah paket: $bundles (${farmState.seedTotalAmount()} benih)',
              style: Kayu.teks(19),
            ),
          ),
          _SmallStepperButton(
            label: '-',
            onTap: () => farmState.adjustShopBundleQuantity(-1),
          ),
          const SizedBox(width: 10),
          _SmallStepperButton(
            label: '+',
            onTap: () => farmState.adjustShopBundleQuantity(1),
          ),
        ],
      ),
    );
  }
}

class _ShopSeedCard extends StatelessWidget {
  const _ShopSeedCard({required this.farmState, required this.seedIndex});

  final FarmStateController farmState;
  final int seedIndex;

  @override
  Widget build(BuildContext context) {
    final seed = farmState.seeds[seedIndex];
    final selected = farmState.selectedSeedIndex == seedIndex;
    final price = farmState.seedTotalPrice(seedIndex);
    final canBuy = farmState.coins >= price;
    return GestureDetector(
      onTap: () => farmState.selectSeed(seedIndex),
      child: KayuWell(
        highlighted: selected,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CropSprite(cropRow: farmState.cropSpriteRow(seedIndex), height: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seed.name, style: Kayu.judul(26, color: Kayu.krem)),
                  const SizedBox(height: 2),
                  Text('Punya ${seed.quantity} benih', style: Kayu.teks(16, color: Kayu.kremRedup)),
                  const SizedBox(height: 6),
                  CoinAmount(amount: price, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 10),
            KayuButton(
              label: canBuy ? 'Beli' : 'Koin kurang',
              compact: true,
              onPressed: canBuy ? () => farmState.buySeeds(seedIndex) : null,
            ),
          ],
        ),
      ),
    );
  }
}
