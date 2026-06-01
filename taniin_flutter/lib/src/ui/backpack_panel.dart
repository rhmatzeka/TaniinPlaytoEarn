import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/farm_state.dart';
import 'pixel_panel.dart';

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
    final media = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.max(360.0, media.width - 86),
        maxHeight: math.max(300.0, media.height - 86),
      ),
      child: SizedBox(
        width: 1160,
        height: 650,
        child: PixelPanel(
          color: const Color(0xFFA34A1C),
          borderColor: const Color(0xFF633010),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PanelHeader(
                icon: Icons.backpack,
                title: 'BACKPACK',
                onClose: onClose,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryTile(
                              icon: Icons.grass,
                              title: 'Seed',
                              value: '${farmState.totalSeeds}',
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _SummaryTile(
                              icon: Icons.eco,
                              title: 'Harvest',
                              value: '${farmState.totalCrops}',
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _SummaryTile(
                              icon: Icons.paid,
                              title: 'Coin',
                              value: '${farmState.coins}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _InventorySection(
                                title: 'Seeds',
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: farmState.seeds.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        childAspectRatio: 4.25,
                                      ),
                                  itemBuilder: (context, index) {
                                    final seed = farmState.seeds[index];
                                    return _SeedCard(
                                      seed: seed,
                                      selected:
                                          farmState.selectedSeedIndex == index,
                                      onTap: () => farmState.selectSeed(index),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: _InventorySection(
                                title: 'Harvest',
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: farmState.crops.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final crop = farmState.crops[index];
                                    return _CropRow(crop: crop);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(24, 18, 22, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFA94F1E),
        border: Border(bottom: BorderSide(color: Color(0xFF763513), width: 5)),
      ),
      child: Row(
        children: [
          const _YellowPixelDot(),
          const SizedBox(width: 24),
          Icon(icon, size: 50, color: const Color(0xFFFFF0CE)),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: 42,
              ),
            ),
          ),
          PanelCloseButton(onPressed: onClose),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF7A2D0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE07B20), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 44, color: const Color(0xFFFFD51C)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFE9C692),
                    fontSize: 16,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFFF0CE),
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventorySection extends StatelessWidget {
  const _InventorySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF7A2D0E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE07B20), width: 5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SeedCard extends StatelessWidget {
  const _SeedCard({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final SeedStack seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFA7581E) : const Color(0xFF8C3A14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFFFDA2E) : const Color(0xFF5D260E),
            width: selected ? 5 : 4,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: seed.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4C230B), width: 4),
                ),
                child: const SizedBox.square(dimension: 58),
              ),
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
                        color: const Color(0xFFFFF0CE),
                        fontSize: 25,
                      ),
                    ),
                    Text(
                      'x${seed.quantity}  -  ${seed.price} coin',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE9C692),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropRow extends StatelessWidget {
  const _CropRow({required this.crop});

  final CropStack crop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8C3A14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D260E), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: crop.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4C230B), width: 4),
              ),
              child: const SizedBox.square(dimension: 58),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                crop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFF0CE),
                  fontSize: 25,
                ),
              ),
            ),
            Text(
              'x${crop.quantity}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YellowPixelDot extends StatelessWidget {
  const _YellowPixelDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD51C),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const SizedBox.square(dimension: 20),
    );
  }
}
