import 'package:flutter/material.dart';

import '../state/farm_state.dart';
import 'kayu.dart';
import 'pixel_art.dart';

/// The bag: what the farmer is carrying, drawn with the game's own sprites.
class BackpackPanel extends StatelessWidget {
  const BackpackPanel({
    required this.farmState,
    required this.onClose,
    super.key,
  });

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: farmState,
      builder: (context, _) {
        final harvestValue = farmState.crops.fold<int>(
          0,
          (sum, crop) =>
              sum + crop.quantity * FarmStateController.harvestSellPrice,
        );
        // Sideways phones are short but wide: seeds and harvest side by side.
        final short = MediaQuery.sizeOf(context).height < 600;
        final seedSection = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Benih', style: Kayu.judul(short ? 20 : 26)),
            const SizedBox(height: 10),
            _BagGrid(
              children: [
                for (var i = 0; i < farmState.seeds.length; i++)
                  _BagItem(
                    cropRow: farmState.cropSpriteRow(i),
                    frame: CropFrame.benih,
                    name: farmState.seeds[i].name,
                    detail: '${farmState.seeds[i].quantity} benih',
                    empty: farmState.seeds[i].quantity == 0,
                    selected: farmState.selectedSeedIndex == i,
                    onTap: () => farmState.selectSeed(i),
                  ),
              ],
            ),
          ],
        );
        final harvestSection = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hasil panen',
                    style: Kayu.judul(short ? 20 : 26),
                  ),
                ),
                if (harvestValue > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Laku ',
                        style: Kayu.teks(17, color: Kayu.kremRedup),
                      ),
                      CoinAmount(amount: harvestValue, size: 20),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _BagGrid(
              children: [
                for (var i = 0; i < farmState.crops.length; i++)
                  _BagItem(
                    cropRow: farmState.cropSpriteRow(i),
                    frame: CropFrame.panen,
                    name: farmState.crops[i].name,
                    detail: '${farmState.crops[i].quantity} buah',
                    empty: farmState.crops[i].quantity == 0,
                    selected: false,
                    onTap: null,
                  ),
              ],
            ),
          ],
        );
        return KayuPanel(
          title: 'Tas',
          leading: const PixelIcon('tas', size: 52),
          subtitle: 'Benih dan hasil panen yang kamu bawa.',
          trailing: KayuWell(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: CoinAmount(amount: farmState.coins, size: 22),
          ),
          onClose: onClose,
          maxWidth: short ? 1180 : 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (short)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: seedSection),
                    const SizedBox(width: 18),
                    Expanded(child: harvestSection),
                  ],
                )
              else ...[
                seedSection,
                const SizedBox(height: 22),
                harvestSection,
              ],
              const SizedBox(height: 16),
              Text(
                'Tanam benih di lahanmu, lalu jual hasil panen di rumah pengepul.',
                style: Kayu.teks(17, color: Kayu.kremRedup),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BagGrid extends StatelessWidget {
  const _BagGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _BagItem extends StatelessWidget {
  const _BagItem({
    required this.cropRow,
    required this.frame,
    required this.name,
    required this.detail,
    required this.empty,
    required this.selected,
    required this.onTap,
  });

  final int cropRow;
  final CropFrame frame;
  final String name;
  final String detail;
  final bool empty;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final item = Opacity(
      opacity: empty ? 0.5 : 1,
      child: KayuWell(
        highlighted: selected,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CropSprite(cropRow: cropRow, frame: frame, height: 56),
            const SizedBox(height: 8),
            Text(name, style: Kayu.judul(21, color: Kayu.krem)),
            Text(detail, style: Kayu.teks(15, color: Kayu.kremRedup)),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$name, $detail',
      child: onTap == null ? item : GestureDetector(onTap: onTap, child: item),
    );
  }
}
