import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/farm_state.dart';
import 'pixel_panel.dart';
import 'taniin_theme.dart';

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
        maxWidth: math.max(420.0, media.width - 86),
        maxHeight: math.max(340.0, media.height - 86),
      ),
      child: SizedBox(
        width: 1120,
        height: 640,
        child: PixelPanel(
          color: const Color(0xFF8B3D17),
          borderColor: const Color(0xFF4B230E),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PanelHeader(onClose: onClose),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                  child: Column(
                    children: [
                      _SummaryStrip(farmState: farmState),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _InventorySection(
                                icon: Icons.grass,
                                title: 'Seed Bag',
                                subtitle:
                                    '${farmState.selectedSeed.name} dipilih',
                                accent: TaniinColors.leaf,
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: farmState.seeds.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 3.55,
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
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: _InventorySection(
                                icon: Icons.inventory_2,
                                title: 'Harvest Crate',
                                subtitle: '${farmState.totalCrops} hasil panen',
                                accent: const Color(0xFFD08D28),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: farmState.crops.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
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
  const _PanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.fromLTRB(22, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFA94F1E),
        border: Border(bottom: BorderSide(color: Color(0xFF633010), width: 5)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF6C2F10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCE56), width: 4),
            ),
            child: SizedBox.square(
              dimension: 68,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/chest.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.backpack,
                    size: 42,
                    color: Color(0xFFFFF0CE),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BACKPACK',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFFDE19),
                        fontSize: 38,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'BENIH DAN HASIL PANEN',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFFFF0CE),
                        fontSize: 16,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PanelCloseButton(onPressed: onClose, dimension: 66, iconSize: 46),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.grass,
            label: 'Seed',
            value: '${farmState.totalSeeds}',
            accent: TaniinColors.leaf,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.eco,
            label: 'Harvest',
            value: '${farmState.totalCrops}',
            accent: const Color(0xFFD08D28),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.paid,
            label: 'Coin',
            value: '${farmState.coins}',
            accent: const Color(0xFF3B75BA),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8A8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5A2B10), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        height: 88,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3A1E0D), width: 3),
                ),
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(icon, size: 30, color: const Color(0xFFFFF4CF)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF6A3A15),
                                fontSize: 15,
                                height: 1.0,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF2E1B0B),
                                fontSize: 30,
                                height: 0.95,
                              ),
                        ),
                      ],
                    ),
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

class _InventorySection extends StatelessWidget {
  const _InventorySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0C8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5A2B10), width: 5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3A1E0D),
                      width: 3,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 42,
                    child: Icon(icon, size: 26, color: const Color(0xFFFFF4CF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF2E1B0B),
                              fontSize: 24,
                            ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF805323),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
    final available = seed.quantity > 0;
    final borderColor = selected
        ? const Color(0xFF2F7D45)
        : const Color(0xFFB6722D);
    final fillColor = selected
        ? const Color(0xFFFFF1A8)
        : available
        ? const Color(0xFFFFDFA3)
        : const Color(0xFFE4C99B);
    return Material(
      color: fillColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: selected ? 5 : 4),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _ItemIcon(color: seed.color, icon: Icons.eco, enabled: available),
              const SizedBox(width: 12),
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
                        color: available
                            ? const Color(0xFF2E1B0B)
                            : const Color(0xFF7D6543),
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _QuantityPill(
                          text: 'x${seed.quantity}',
                          color: available
                              ? const Color(0xFF2F7D45)
                              : const Color(0xFF8F7652),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${seed.price} coin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF805323),
                                  fontSize: 15,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  size: 26,
                  color: Color(0xFF2F7D45),
                ),
              ],
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
    final available = crop.quantity > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: available ? const Color(0xFFFFDFA3) : const Color(0xFFE4C99B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available ? const Color(0xFFB6722D) : const Color(0xFF9C7C50),
          width: 4,
        ),
      ),
      child: SizedBox(
        height: 74,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _ItemIcon(
                color: crop.color,
                icon: Icons.spa,
                enabled: available,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  crop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: available
                        ? const Color(0xFF2E1B0B)
                        : const Color(0xFF7D6543),
                    fontSize: 21,
                  ),
                ),
              ),
              _QuantityPill(
                text: 'x${crop.quantity}',
                color: available
                    ? const Color(0xFFD08D28)
                    : const Color(0xFF8F7652),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({
    required this.color,
    required this.icon,
    required this.enabled,
    this.size = 54,
  });

  final Color color;
  final IconData icon;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? color : Color.lerp(color, Colors.grey, 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4C230B), width: 4),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size * 0.52, color: const Color(0xFFFFF4CF)),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A1E0D), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFFFF4CF),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
