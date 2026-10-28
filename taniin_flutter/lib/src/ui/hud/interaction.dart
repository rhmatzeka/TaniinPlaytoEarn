part of '../game_hud.dart';

class _DialogSurface extends StatelessWidget {
  const _DialogSurface({required this.farmState, required this.child});

  final FarmStateController farmState;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: PhysicalViewport(
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final popupWidth = math
                .min(760.0, math.max(340.0, constraints.maxWidth - 56.0))
                .toDouble();
            return Stack(
              children: [
                Center(child: child),
                if (farmState.statusVisible)
                  Positioned(
                    left: (constraints.maxWidth - popupWidth) * 0.5,
                    top: 34,
                    width: popupWidth,
                    child: IgnorePointer(
                      child: _StatusPopup(farmState: farmState),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? const Color(0xD8221512) : const Color(0xB8171512),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFFFD75A) : const Color(0x886E5B37),
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x70000000),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontSize: 20,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractionPanel extends StatelessWidget {
  const _InteractionPanel({
    required this.farmState,
    required this.interaction,
    required this.plotIndex,
    required this.onClose,
    required this.onOpenShop,
  });

  final FarmStateController farmState;
  final GameInteraction interaction;
  final int? plotIndex;
  final VoidCallback onClose;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final wide = interaction == GameInteraction.swapToken;
    final tall = wide || interaction == GameInteraction.sellHarvest;
    final compact = media.height < 620 || media.width < 760;
    final compactSwap = wide && (media.height < 980 || media.width < 980);
    final availableWidth = math.max(300.0, media.width - (compact ? 28 : 44));
    final panelWidth = math.max(
      compact ? 320.0 : 360.0,
      math.min(availableWidth, wide ? 980.0 : 820.0),
    );
    final maxPanelHeight = math.min(
      math.max(280.0, media.height - (compact ? 24 : 44)),
      tall ? 760.0 : 560.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: panelWidth,
        maxHeight: maxPanelHeight,
      ),
      child: SizedBox(
        width: panelWidth,
        child: PixelPanel(
          color: const Color(0xFF9E4E20),
          borderColor: const Color(0xFF4D2A0E),
          padding: compact
              ? const EdgeInsets.fromLTRB(18, 16, 18, 18)
              : const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: SingleChildScrollView(
            physics: wide
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        farmState.interactionTitle(interaction),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFFFDE19),
                          fontSize: compact ? 30 : 38,
                          height: 1,
                        ),
                      ),
                    ),
                    PanelCloseButton(
                      onPressed: onClose,
                      dimension: compact ? 58 : 72,
                      iconSize: compact ? 42 : 52,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 18),
                _DialogBody(
                  text: farmState.interactionBody(
                    interaction,
                    plotIndex: plotIndex,
                  ),
                  compact: compact,
                ),
                if (interaction == GameInteraction.plant) ...[
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    'Pilih Benih',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFE054),
                      fontSize: compact ? 21 : null,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  _PlantSeedSelector(farmState: farmState, compact: compact),
                ],
                if (interaction == GameInteraction.sellHarvest &&
                    farmState.harvests > 0) ...[
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    'Pilih Panen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFE054),
                      fontSize: compact ? 21 : null,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  _SellHarvestSelector(farmState: farmState, compact: compact),
                ],
                if (interaction == GameInteraction.swapToken) ...[
                  SizedBox(height: compact ? 12 : 18),
                  _SwapControl(farmState: farmState, compact: compactSwap),
                ],
                SizedBox(height: compact ? 16 : 24),
                _InteractionButtons(
                  farmState: farmState,
                  interaction: interaction,
                  plotIndex: plotIndex,
                  onClose: onClose,
                  onOpenShop: onOpenShop,
                  compact: compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8E411B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5C2A0C), width: 4),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 12 : 20,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFFFF0D4),
            fontSize: compact ? 21 : 26,
            height: compact ? 1.08 : 1.12,
          ),
        ),
      ),
    );
  }
}

class _InteractionButtons extends StatelessWidget {
  const _InteractionButtons({
    required this.farmState,
    required this.interaction,
    required this.plotIndex,
    required this.onClose,
    required this.onOpenShop,
    required this.compact,
  });

  final FarmStateController farmState;
  final GameInteraction interaction;
  final int? plotIndex;
  final VoidCallback onClose;
  final VoidCallback onOpenShop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: compact ? 10 : 14,
      spacing: compact ? 12 : 18,
      children: [
        _DialogButton(
          label: _primaryLabel(),
          color: const Color(0xFF61320C),
          border: const Color(0xFFFFD900),
          compact: compact,
          onPressed: () => _performPrimary(context),
        ),
        if (interaction == GameInteraction.plant) ...[
          _DialogButton(
            label: 'Jual lahan',
            color: const Color(0xFF724718),
            border: const Color(0xFFFFB23F),
            compact: compact,
            onPressed: () {
              final index = plotIndex;
              if (index != null) {
                farmState.sellLand(index);
              }
              onClose();
            },
          ),
        ],
        _DialogButton(
          label: 'Batal',
          color: const Color(0xFFA00500),
          border: const Color(0xFF5C0000),
          compact: compact,
          onPressed: onClose,
        ),
      ],
    );
  }

  String _primaryLabel() {
    return switch (interaction) {
      GameInteraction.sellHarvest =>
        farmState.harvests > 0 && farmState.selectedSellCrop.quantity > 0
            ? 'Jual ${farmState.selectedSellCrop.name}'
            : 'Pilih panen',
      GameInteraction.swapToken =>
        farmState.selectedSwapAmount > 0
            ? '${farmState.swapVerb} ${farmState.selectedSwapAmount}'
            : 'Oke',
      GameInteraction.buyLand => 'Ya, beli lahan',
      GameInteraction.plant =>
        farmState.selectedSeed.quantity > 0
            ? 'Ya, tanam ${farmState.selectedSeed.name}'
            : 'Buka toko',
      GameInteraction.waitCrop => 'Oke',
      GameInteraction.harvest => 'Panen',
      _ => 'Lanjut',
    };
  }

  Future<void> _performPrimary(BuildContext context) async {
    switch (interaction) {
      case GameInteraction.sellHarvest:
        if (farmState.sellHarvest()) {
          onClose();
        }
        return;
      case GameInteraction.swapToken:
        if (await farmState.swapSelectedAssets()) {
          onClose();
        }
        return;
      case GameInteraction.waitCrop:
        onClose();
        return;
      case GameInteraction.buyLand:
      case GameInteraction.plant:
      case GameInteraction.harvest:
        final index = plotIndex;
        if (index == null) {
          farmState.showMessage('Dekati lahan dulu.', success: false);
          onClose();
          return;
        }
        if (interaction == GameInteraction.plant &&
            farmState.selectedSeed.quantity <= 0) {
          onOpenShop();
          return;
        }
        farmState.performPlotAction(index);
        onClose();
        return;
      default:
        onClose();
    }
  }
}

class _PlantSeedSelector extends StatelessWidget {
  const _PlantSeedSelector({required this.farmState, required this.compact});

  final FarmStateController farmState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < farmState.seeds.length; i++) ...[
          Expanded(
            child: _SeedOption(
              seed: farmState.seeds[i],
              selected: farmState.selectedSeedIndex == i,
              compact: compact,
              onTap: () => farmState.selectSeed(i),
            ),
          ),
          if (i != farmState.seeds.length - 1)
            SizedBox(width: compact ? 8 : 12),
        ],
      ],
    );
  }
}

class _SeedOption extends StatelessWidget {
  const _SeedOption({
    required this.seed,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final SeedStack seed;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = seed.quantity > 0;
    return GestureDetector(
      onTap: onTap,
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
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SeedPacket(
                color: available ? seed.color : const Color(0xFF6B594D),
                size: compact ? 34 : 44,
              ),
              SizedBox(height: compact ? 5 : 8),
              Text(
                seed.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: available
                      ? const Color(0xFFFFF0D4)
                      : const Color(0xFFBE977C),
                  fontSize: compact ? 17 : 20,
                ),
              ),
              Text(
                'Stok x${seed.quantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: available
                      ? const Color(0xFFFFF0D4)
                      : const Color(0xFFBE977C),
                  fontSize: compact ? 14 : 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellHarvestSelector extends StatelessWidget {
  const _SellHarvestSelector({required this.farmState, required this.compact});

  final FarmStateController farmState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < farmState.crops.length; i++) ...[
          Expanded(
            child: _CropOption(
              crop: farmState.crops[i],
              selected: farmState.selectedSellCropIndex == i,
              price: FarmStateController.harvestSellPrice,
              compact: compact,
              onTap: () => farmState.selectSellCrop(i),
            ),
          ),
          if (i != farmState.crops.length - 1)
            SizedBox(width: compact ? 8 : 12),
        ],
      ],
    );
  }
}

class _CropOption extends StatelessWidget {
  const _CropOption({
    required this.crop,
    required this.selected,
    required this.price,
    required this.compact,
    required this.onTap,
  });

  final CropStack crop;
  final bool selected;
  final int price;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = crop.quantity > 0;
    final value = crop.quantity * price;
    return GestureDetector(
      onTap: onTap,
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
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SeedPacket(
                color: available ? crop.color : const Color(0xFF6B594D),
                size: compact ? 34 : 44,
              ),
              SizedBox(height: compact ? 5 : 8),
              Text(
                crop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: available
                      ? const Color(0xFFFFF0D4)
                      : const Color(0xFFBE977C),
                  fontSize: compact ? 17 : 20,
                ),
              ),
              Text(
                available ? 'x${crop.quantity} -> $value coin' : 'Stok kosong',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: available
                      ? const Color(0xFFFFF0D4)
                      : const Color(0xFFBE977C),
                  fontSize: compact ? 13 : 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.border,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color border;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              offset: Offset(4, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? 132 : 150,
            minHeight: compact ? 52 : 62,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 20,
              vertical: compact ? 9 : 12,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFEDCD),
                  fontSize: compact ? 20 : 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallStepperButton extends StatelessWidget {
  const _SmallStepperButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF68330E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD64E), width: 3),
        ),
        child: SizedBox.square(
          dimension: 54,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFEED3),
                fontSize: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPopup extends StatelessWidget {
  const _StatusPopup({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF22723E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7DE282), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(6, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFD3FFCB), size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                farmState.statusMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
