part of '../game_hud.dart';

/// Coins, account and menu in the top-right corner (landscape and portrait).
class _TopCluster extends StatelessWidget {
  const _TopCluster({
    required this.farmState,
    required this.compact,
    required this.menuActive,
    required this.onMenuPressed,
    required this.onWalletPressed,
  });

  final FarmStateController farmState;
  final bool compact;
  final bool menuActive;
  final VoidCallback onMenuPressed;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrencyBar(farmState: farmState),
        const SizedBox(width: 10),
        _AccountButton(farmState: farmState, onPressed: onWalletPressed),
        const SizedBox(width: 10),
        _HudIconButton(
          ikon: 'menu',
          label: 'Menu',
          isActive: menuActive,
          onPressed: onMenuPressed,
        ),
      ],
    );
  }
}

/// Single top row for short landscape screens: coins, account, panels, menu.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.farmState,
    required this.activePanel,
    required this.onPanelSelected,
    required this.onWalletPressed,
  });

  final FarmStateController farmState;
  final GamePanel? activePanel;
  final ValueChanged<GamePanel> onPanelSelected;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrencyBar(farmState: farmState),
        const SizedBox(width: 8),
        _AccountButton(farmState: farmState, onPressed: onWalletPressed),
        const SizedBox(width: 8),
        ..._panelButtons(farmState, activePanel, onPanelSelected, gap: 8, axis: Axis.horizontal),
        const SizedBox(width: 8),
        _HudIconButton(
          ikon: 'menu',
          label: 'Menu',
          isActive: activePanel == GamePanel.settings,
          onPressed: () => onPanelSelected(GamePanel.settings),
        ),
      ],
    );
  }
}

/// Profile, bag and history buttons, shared by the column and the top row.
List<Widget> _panelButtons(
  FarmStateController farmState,
  GamePanel? activePanel,
  ValueChanged<GamePanel> onPanelSelected, {
  required double gap,
  required Axis axis,
}) {
  final spacer = axis == Axis.horizontal ? SizedBox(width: gap) : SizedBox(height: gap);
  return [
    _HudIconButton(
      ikon: 'petani',
      label: 'Profil',
      badge: 'Lv${farmState.playerLevel}',
      isActive: activePanel == GamePanel.profile,
      onPressed: () => onPanelSelected(GamePanel.profile),
    ),
    spacer,
    _HudIconButton(
      ikon: 'tas',
      label: 'Tas',
      badge: farmState.totalSeeds > 0 ? '${farmState.totalSeeds}' : null,
      isActive: activePanel == GamePanel.backpack,
      onPressed: () => onPanelSelected(GamePanel.backpack),
    ),
    spacer,
    _HudIconButton(
      ikon: 'riwayat',
      label: 'Riwayat',
      isActive: activePanel == GamePanel.history,
      onPressed: () => onPanelSelected(GamePanel.history),
    ),
  ];
}

class _CurrencyBar extends StatelessWidget {
  const _CurrencyBar({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Game Coin ${farmState.coins}',
      child: PixelFrame(
        height: 92,
        padding: const EdgeInsets.fromLTRB(14, 10, 22, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelIcon('koin', size: 48),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: Text('${farmState.coins}', style: Kayu.judul(38, color: Kayu.krem)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small account button: a key to sign in, the farmer once signed in.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.farmState, required this.onPressed});

  final FarmStateController farmState;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final loggedIn = farmState.isLoggedIn;
    return _HudIconButton(
      ikon: loggedIn ? 'bintang' : 'kunci',
      label: loggedIn ? 'Akun' : 'Masuk',
      isActive: false,
      highlight: !loggedIn,
      onPressed: onPressed,
    );
  }
}

/// Square HUD button: pixel icon over a short label, in a wood frame.
class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.ikon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.highlight = false,
    this.badge,
  });

  final String ikon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final bool highlight;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: badge == null ? label : '$label, $badge',
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PixelFrame(
                width: 100,
                height: 96,
                tone: isActive || highlight ? PixelFrameTone.aktif : PixelFrameTone.kayu,
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PixelIcon(ikon, size: 44),
                    const SizedBox(height: 2),
                    ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: Kayu.judul(17, color: Kayu.krem),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -6,
                  top: -8,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Kayu.emas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Kayu.kayuGelap, width: 3),
                      ),
                      child: Text(badge!, style: Kayu.judul(15, color: Kayu.kayuGelap)),
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
