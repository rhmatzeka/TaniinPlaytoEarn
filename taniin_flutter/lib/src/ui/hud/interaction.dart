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
    return KayuPanel(
      title: farmState.interactionTitle(interaction),
      icon: _icon,
      onClose: onClose,
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogBody(
            text: farmState.interactionBody(interaction, plotIndex: plotIndex),
          ),
          if (interaction == GameInteraction.plant) ...[
            const SizedBox(height: 18),
            Text('Pilih benih', style: Kayu.judul(24)),
            const SizedBox(height: 10),
            _PlantSeedSelector(farmState: farmState),
          ],
          if (interaction == GameInteraction.sellHarvest &&
              farmState.harvests > 0) ...[
            const SizedBox(height: 18),
            Text('Pilih panen', style: Kayu.judul(24)),
            const SizedBox(height: 10),
            _SellHarvestSelector(farmState: farmState),
          ],
          const SizedBox(height: 22),
          _InteractionButtons(
            farmState: farmState,
            interaction: interaction,
            plotIndex: plotIndex,
            onClose: onClose,
            onOpenShop: onOpenShop,
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (interaction) {
    GameInteraction.buyLand => Icons.landscape,
    GameInteraction.plant => Icons.grass,
    GameInteraction.harvest => Icons.agriculture,
    GameInteraction.waitCrop => Icons.hourglass_bottom,
    GameInteraction.sellHarvest => Icons.sell,
    _ => Icons.info_outline,
  };
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return KayuWell(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(text, style: Kayu.teks(21)),
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
  });

  final FarmStateController farmState;
  final GameInteraction interaction;
  final int? plotIndex;
  final VoidCallback onClose;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      runSpacing: 12,
      spacing: 12,
      children: [
        if (interaction == GameInteraction.plant)
          KayuButton(
            label: 'Jual lahan',
            tone: KayuTone.bahaya,
            compact: true,
            onPressed: () {
              final index = plotIndex;
              if (index != null) {
                farmState.sellLand(index);
              }
              onClose();
            },
          ),
        KayuButton(
          label: 'Batal',
          tone: KayuTone.kedua,
          compact: true,
          onPressed: onClose,
        ),
        KayuButton(
          label: _cannotAfford ? 'Koin kurang' : _primaryLabel(),
          compact: true,
          onPressed: _cannotAfford ? null : () => _performPrimary(context),
        ),
      ],
    );
  }

  bool get _cannotAfford =>
      interaction == GameInteraction.buyLand &&
      farmState.coins < FarmStateController.landBuyPrice;

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
  const _PlantSeedSelector({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return _ItemGrid(
      children: [
        for (var i = 0; i < farmState.seeds.length; i++)
          _ItemOption(
            cropRow: farmState.cropSpriteRow(i),
            frame: CropFrame.benih,
            name: farmState.seeds[i].name,
            detail: farmState.seeds[i].quantity > 0
                ? 'Punya ${farmState.seeds[i].quantity}'
                : 'Habis',
            available: farmState.seeds[i].quantity > 0,
            selected: farmState.selectedSeedIndex == i,
            onTap: () => farmState.selectSeed(i),
          ),
      ],
    );
  }
}

class _SellHarvestSelector extends StatelessWidget {
  const _SellHarvestSelector({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return _ItemGrid(
      children: [
        for (var i = 0; i < farmState.crops.length; i++)
          _ItemOption(
            cropRow: farmState.cropSpriteRow(i),
            frame: CropFrame.panen,
            name: farmState.crops[i].name,
            detail: farmState.crops[i].quantity > 0
                ? '${farmState.crops[i].quantity} = ${farmState.crops[i].quantity * FarmStateController.harvestSellPrice} koin'
                : 'Belum ada',
            available: farmState.crops[i].quantity > 0,
            selected: farmState.selectedSellCropIndex == i,
            onTap: () => farmState.selectSellCrop(i),
          ),
      ],
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.children});

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
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _ItemOption extends StatelessWidget {
  const _ItemOption({
    required this.cropRow,
    required this.frame,
    required this.name,
    required this.detail,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  final int cropRow;
  final CropFrame frame;
  final String name;
  final String detail;
  final bool available;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $detail',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: KayuWell(
            highlighted: selected,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CropSprite(cropRow: cropRow, frame: frame, height: 56),
                const SizedBox(height: 8),
                Text(name, style: Kayu.judul(21, color: Kayu.krem)),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: Kayu.teks(15, color: Kayu.kremRedup),
                ),
              ],
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
