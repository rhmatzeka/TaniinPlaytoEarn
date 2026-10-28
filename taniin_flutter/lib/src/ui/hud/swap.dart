part of '../game_hud.dart';

class _SwapControl extends StatelessWidget {
  const _SwapControl({required this.farmState, required this.compact});

  final FarmStateController farmState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sourceBalance = math.max(0, farmState.swapSourceBalance);
    final amount = farmState.selectedSwapAmount;
    final value = amount.toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF793A17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5E2C0D), width: 4),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 650;
            final rateHint = farmState.swapRateHintLabel;
            final fromCard = _SwapAssetCard(
              label: 'DARI',
              selectedAsset: farmState.swapFromAsset,
              amount: farmState.swapCardAmountLabel(
                farmState.swapFromAsset,
                amount,
                to: false,
              ),
              balance: farmState.swapBalanceLabel(farmState.swapFromAsset),
              icon: _swapAssetIcon(farmState.swapFromAsset),
              color: _swapAssetColor(farmState.swapFromAsset),
              onAssetChanged: farmState.setSwapFromAsset,
            );
            final toCard = _SwapAssetCard(
              label: 'KE',
              selectedAsset: farmState.swapToAsset,
              amount: farmState.swapCardAmountLabel(
                farmState.swapToAsset,
                amount,
                to: true,
              ),
              balance: farmState.swapBalanceLabel(farmState.swapToAsset),
              icon: _swapAssetIcon(farmState.swapToAsset),
              color: _swapAssetColor(farmState.swapToAsset),
              onAssetChanged: farmState.setSwapToAsset,
            );
            final arrow = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: vertical ? 0 : (compact ? 8 : 14),
                vertical: vertical ? (compact ? 5 : 10) : 0,
              ),
              child: _SwapArrow(
                vertical: vertical,
                onTap: farmState.reverseSwapAssets,
              ),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                vertical
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          fromCard,
                          Center(child: arrow),
                          toCard,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: fromCard),
                          arrow,
                          Expanded(child: toCard),
                        ],
                      ),
                SizedBox(height: compact ? 9 : 18),
                if (rateHint.isNotEmpty) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E2C0D),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0x99FFFF99),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: compact ? 6 : 9,
                      ),
                      child: Text(
                        rateHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFFF0D4),
                          fontSize: compact ? 13 : 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Jumlah ${farmState.swapAmountUnitLabel}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFFFF0D4),
                              fontSize: compact ? 17 : 22,
                            ),
                      ),
                    ),
                    Text(
                      farmState.swapAmountProgressLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFDE19),
                        fontSize: compact ? 17 : 22,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: compact ? 7 : 10,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: compact ? 11 : 15,
                    ),
                    activeTrackColor: const Color(0xFFFFD900),
                    inactiveTrackColor: const Color(0xFF5E2C0D),
                    thumbColor: const Color(0xFFFFF0D4),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: math.max(1, sourceBalance).toDouble(),
                    divisions: sourceBalance <= 1000
                        ? math.max(1, sourceBalance)
                        : null,
                    onChanged: sourceBalance == 0
                        ? null
                        : (newValue) =>
                              farmState.setSwapAmount(newValue.round()),
                  ),
                ),
                Wrap(
                  spacing: compact ? 7 : 10,
                  runSpacing: compact ? 7 : 10,
                  children: [
                    _SwapPresetButton(
                      label: '25%',
                      enabled: sourceBalance > 0,
                      onTap: () => farmState.setSwapAmount(
                        math.max(1, (sourceBalance * 0.25).round()),
                      ),
                    ),
                    _SwapPresetButton(
                      label: '50%',
                      enabled: sourceBalance > 0,
                      onTap: () => farmState.setSwapAmount(
                        math.max(1, (sourceBalance * 0.50).round()),
                      ),
                    ),
                    _SwapPresetButton(
                      label: 'MAX',
                      enabled: sourceBalance > 0,
                      onTap: () => farmState.setSwapAmount(sourceBalance),
                    ),
                    _SwapPresetButton(
                      label: farmState.isLoggedIn ? 'ON-CHAIN' : 'MODE TAMU',
                      enabled: true,
                      onTap: () => farmState.showMessage(
                        farmState.isLoggedIn
                            ? 'Swap tercatat di Sepolia: ${farmState.walletLabel}'
                            : 'Mode tamu: swap tersimpan lokal. Tap MASUK di kanan atas.',
                        success: farmState.isLoggedIn,
                      ),
                      highlighted: farmState.isLoggedIn,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

IconData _swapAssetIcon(SwapAsset asset) {
  return switch (asset) {
    SwapAsset.gameCoin => Icons.paid,
    SwapAsset.taniSepolia => Icons.token,
    SwapAsset.ethSepolia => Icons.bolt,
  };
}

Color _swapAssetColor(SwapAsset asset) {
  return switch (asset) {
    SwapAsset.gameCoin => const Color(0xFF6C3915),
    SwapAsset.taniSepolia => const Color(0xFF22543B),
    SwapAsset.ethSepolia => const Color(0xFF244D7A),
  };
}

class _SwapAssetCard extends StatelessWidget {
  const _SwapAssetCard({
    required this.label,
    required this.selectedAsset,
    required this.amount,
    required this.balance,
    required this.icon,
    required this.color,
    required this.onAssetChanged,
  });

  final String label;
  final SwapAsset selectedAsset;
  final String amount;
  final String balance;
  final IconData icon;
  final Color color;
  final ValueChanged<SwapAsset> onAssetChanged;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFFFFF0D4),
      fontSize: 20,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB23F), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE9C692),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 7),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x33241008),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x66FFF0D4), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SwapAsset>(
                    value: selectedAsset,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF5E2C0D),
                    iconEnabledColor: const Color(0xFFFFDE19),
                    style: titleStyle,
                    items: SwapAsset.values
                        .map(
                          (asset) => DropdownMenuItem<SwapAsset>(
                            value: asset,
                            child: Text(
                              asset.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (asset) {
                      if (asset != null) {
                        onAssetChanged(asset);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox.square(
                    dimension: 54,
                    child: Icon(icon, color: const Color(0xFFFFF0D4), size: 34),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFDDBF91),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amount,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFFDE19),
                        fontSize: 32,
                      ),
                    ),
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

class _SwapArrow extends StatelessWidget {
  const _SwapArrow({required this.vertical, required this.onTap});

  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Balik arah swap',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF5E2C0D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFD900), width: 3),
          ),
          child: SizedBox.square(
            dimension: 54,
            child: Icon(
              vertical ? Icons.swap_vert : Icons.swap_horiz,
              color: const Color(0xFFFFF0D4),
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwapPresetButton extends StatelessWidget {
  const _SwapPresetButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFF5F4A38)
              : highlighted
              ? const Color(0xFF246644)
              : const Color(0xFF6A3512),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF86E276)
                : const Color(0xFFFFB23F),
            width: 3,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFFFF0D4),
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
