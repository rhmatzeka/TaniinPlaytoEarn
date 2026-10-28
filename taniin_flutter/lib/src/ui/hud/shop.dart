part of '../game_hud.dart';

class _ShopPanel extends StatelessWidget {
  const _ShopPanel({required this.farmState, required this.onClose});

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(media.width - 44, 1180),
        maxHeight: math.min(media.height - 44, 700),
      ),
      child: PixelPanel(
        color: const Color(0xFF9C4B1E),
        borderColor: const Color(0xFF46270D),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  size: 48,
                  color: Color(0xFFFFDE19),
                ),
                const SizedBox(width: 14),
                Text(
                  'Shop',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFDE19),
                    fontSize: 44,
                  ),
                ),
                const Spacer(),
                PanelCloseButton(onPressed: onClose),
              ],
            ),
            const SizedBox(height: 16),
            _DialogBody(
              text: 'Pilih benih, atur jumlah paket, lalu tekan Beli di kartu.',
            ),
            const SizedBox(height: 16),
            _ShopSummary(farmState: farmState),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: farmState.seeds.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 4.5,
                ),
                itemBuilder: (context, index) {
                  return _ShopSeedCard(farmState: farmState, seedIndex: index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopSummary extends StatelessWidget {
  const _ShopSummary({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    final seed = farmState.selectedSeed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8B3F19),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5F2B0C), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'TANI Sepolia: ${farmState.tani} | ${seed.name} | Paket x${farmState.shopBundleQuantity} = ${farmState.seedTotalAmount()} benih | Total ${farmState.seedTotalPrice(farmState.selectedSeedIndex)} TANI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFFEED3),
                  fontSize: 20,
                ),
              ),
            ),
            _SmallStepperButton(
              label: '-',
              onTap: () => farmState.adjustShopBundleQuantity(-1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'x${farmState.shopBundleQuantity}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFEED3),
                  fontSize: 23,
                ),
              ),
            ),
            _SmallStepperButton(
              label: '+',
              onTap: () => farmState.adjustShopBundleQuantity(1),
            ),
          ],
        ),
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
    final canBuy =
        farmState.walletTaniBalanceAvailable && farmState.tani >= price;
    return GestureDetector(
      onTap: () => farmState.selectSeed(seedIndex),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFA7581E) : const Color(0xFF793A17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFFFFDA2E) : const Color(0xFF5E2C0D),
            width: selected ? 5 : 3,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SeedPacket(color: seed.color, size: 58),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      seed.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFF0D4),
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Isi ${FarmStateController.seedBundleAmount} - Stok x${seed.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFFDDA8),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DialogButton(
                label: canBuy ? 'Beli $price' : 'Kurang',
                color: canBuy
                    ? const Color(0xFF24703C)
                    : const Color(0xFF664B35),
                border: canBuy
                    ? const Color(0xFF86E276)
                    : const Color(0xFF8B6A53),
                onPressed: () => farmState.buySeeds(seedIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
