import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/taniin_game.dart';
import '../state/farm_state.dart';
import 'physical_viewport.dart';
import 'pixel_panel.dart';
import 'web_input_capability.dart'
    if (dart.library.js_interop) 'web_input_capability_web.dart'
    as web_input;
import 'wallet_panel.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    required this.game,
    required this.farmState,
    required this.activePanel,
    required this.onPanelSelected,
    super.key,
  });

  final TaniinGame game;
  final FarmStateController farmState;
  final GamePanel? activePanel;
  final ValueChanged<GamePanel> onPanelSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game.hudNotifier,
      builder: (context, _) {
        final logicalViewport = MediaQuery.sizeOf(context);
        final interaction = game.currentInteraction;
        final selectedPlot = game.selectedPlotIndex;
        final contextText = farmState.contextText(
          interaction,
          plotIndex: selectedPlot,
        );
        return SafeArea(
          child: PhysicalViewport(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final showTouchJoystick = shouldShowTouchJoystickForPlatform(
                  viewportSize: logicalViewport,
                );
                final viewportScale = logicalViewport.width <= 0
                    ? 1.0
                    : (constraints.maxWidth / logicalViewport.width)
                          .clamp(1.0, 4.0)
                          .toDouble();
                final mobileWebTouchLayout = kIsWeb && showTouchJoystick;
                const showMiniMap = true;
                final miniMapWidth = compact
                    ? (constraints.maxWidth * 0.28)
                          .clamp(112.0, 140.0)
                          .toDouble()
                    : (constraints.maxWidth * 0.112)
                          .clamp(236.0, 286.0)
                          .toDouble();
                final joystickRadius = showTouchJoystick
                    ? mobileWebTouchLayout
                          ? _mobileWebJoystickRadius(
                              logicalViewport,
                              viewportScale,
                            )
                          : _joystickRadius(compact)
                    : 0.0;
                final joystickSize = joystickRadius * 2.2;
                final joystickBaseX = showTouchJoystick
                    ? (constraints.maxWidth * 0.145)
                          .clamp(
                            compact ? 270.0 : 320.0,
                            compact ? 340.0 : 390.0,
                          )
                          .toDouble()
                    : 0.0;
                final joystickBaseY = showTouchJoystick
                    ? constraints.maxHeight -
                          (constraints.maxHeight * 0.31)
                              .clamp(
                                compact ? 270.0 : 300.0,
                                compact ? 320.0 : 350.0,
                              )
                              .toDouble()
                    : 0.0;
                final joystickMargin = mobileWebTouchLayout
                    ? 22.0 * viewportScale
                    : 16.0;
                final joystickLeft = showTouchJoystick
                    ? (mobileWebTouchLayout
                              ? joystickMargin
                              : joystickBaseX - joystickSize * 0.5)
                          .clamp(
                            16.0,
                            math.max(
                              16.0,
                              constraints.maxWidth - joystickSize - 16,
                            ),
                          )
                          .toDouble()
                    : 0.0;
                final joystickTop = showTouchJoystick
                    ? (mobileWebTouchLayout
                              ? constraints.maxHeight -
                                    joystickSize -
                                    joystickMargin
                              : joystickBaseY - joystickSize * 0.5)
                          .clamp(
                            16.0,
                            math.max(
                              16.0,
                              constraints.maxHeight - joystickSize - 16,
                            ),
                          )
                          .toDouble()
                    : 0.0;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) =>
                            _handleWorldTap(context, details.localPosition),
                      ),
                    ),
                    if (showMiniMap)
                      Positioned(
                        left: 32,
                        top: 26,
                        child: _MiniMap(
                          game: game,
                          width: miniMapWidth,
                          height: miniMapWidth * game.miniMapAspectRatio,
                        ),
                      ),
                    Positioned(
                      right: 20,
                      top: 10,
                      child: _TopCluster(
                        farmState: farmState,
                        compact: compact,
                        menuActive: activePanel == GamePanel.settings,
                        onMenuPressed: () =>
                            onPanelSelected(GamePanel.settings),
                        onWalletPressed: () => _showWalletDialog(context),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      top: compact ? 196 : 204,
                      child: Column(
                        children: [
                          _HudIconButton(
                            icon: Icons.history,
                            tooltip: 'Riwayat',
                            isActive: activePanel == GamePanel.history,
                            badge: '${farmState.history.length}',
                            onPressed: () => onPanelSelected(GamePanel.history),
                          ),
                          const SizedBox(height: 8),
                          _HudIconButton(
                            icon: Icons.backpack,
                            tooltip: 'Backpack',
                            isActive: activePanel == GamePanel.backpack,
                            badge: '${farmState.totalSeeds}',
                            onPressed: () =>
                                onPanelSelected(GamePanel.backpack),
                          ),
                        ],
                      ),
                    ),
                    if (showTouchJoystick)
                      Positioned(
                        left: joystickLeft,
                        top: joystickTop,
                        child: _Joystick(game: game, radius: joystickRadius),
                      ),
                    Positioned(
                      left: compact ? 194 : 260,
                      right: compact ? 330 : 320,
                      bottom: compact ? 20 : 32,
                      child: _ContextPill(
                        text: contextText,
                        enabled: interaction != GameInteraction.none,
                        onTap: () {
                          farmState.playClick();
                          _openContextDialog(
                            context,
                            interaction,
                            selectedPlot,
                          );
                        },
                      ),
                    ),
                    if (farmState.statusVisible)
                      Positioned(
                        left: constraints.maxWidth * 0.31,
                        right: constraints.maxWidth * 0.31,
                        top: 80,
                        child: _StatusPopup(farmState: farmState),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleWorldTap(BuildContext context, Offset position) {
    final target = game.interactionAtScreenPosition(position);
    if (target.interaction == GameInteraction.none) {
      return;
    }
    farmState.playClick();
    _openContextDialog(context, target.interaction, target.plotIndex);
  }

  void _openContextDialog(
    BuildContext context,
    GameInteraction interaction,
    int? plotIndex,
  ) {
    if (interaction == GameInteraction.none) {
      farmState.showMessage(
        'Dekati lahan, shop, rumah jual, atau rumah swap dulu.',
        success: false,
      );
      return;
    }
    if (interaction == GameInteraction.shop) {
      _showShopDialog(context);
      return;
    }
    if (interaction == GameInteraction.swapToken) {
      farmState.prepareSwapAmount();
    }
    _showInteractionDialog(context, interaction, plotIndex);
  }

  void _showInteractionDialog(
    BuildContext context,
    GameInteraction interaction,
    int? plotIndex,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: farmState,
          builder: (context, _) {
            return _DialogSurface(
              farmState: farmState,
              child: _InteractionPanel(
                farmState: farmState,
                interaction: interaction,
                plotIndex: plotIndex,
                onClose: () => Navigator.of(dialogContext).maybePop(),
                onOpenShop: () {
                  Navigator.of(dialogContext).maybePop();
                  _showShopDialog(context);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showShopDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: farmState,
          builder: (context, _) {
            return _DialogSurface(
              farmState: farmState,
              child: _ShopPanel(
                farmState: farmState,
                onClose: () => Navigator.of(dialogContext).maybePop(),
              ),
            );
          },
        );
      },
    );
  }

  void _showWalletDialog(BuildContext context) {
    farmState.playClick();
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: farmState,
          builder: (context, _) {
            return _DialogSurface(
              farmState: farmState,
              child: WalletPanel(
                farmState: farmState,
                onClose: () => Navigator.of(dialogContext).maybePop(),
              ),
            );
          },
        );
      },
    );
  }
}

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

double _joystickRadius(bool compact) => compact ? 72 : 82;

double _mobileWebJoystickRadius(Size viewportSize, double viewportScale) {
  final logicalSize = math
      .min(viewportSize.shortestSide * 0.34, 132.0)
      .clamp(112.0, 132.0)
      .toDouble();
  return logicalSize * viewportScale / 2.2;
}

@visibleForTesting
bool shouldShowTouchJoystickForPlatform({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  Size? viewportSize,
  bool? coarsePointer,
}) {
  if (!isWeb) {
    return true;
  }

  final size = viewportSize;
  if (size == null) {
    return false;
  }
  if (!_isPhoneSizedWebViewport(size)) {
    return false;
  }

  final effectivePlatform = platform ?? defaultTargetPlatform;
  if (effectivePlatform == TargetPlatform.android ||
      effectivePlatform == TargetPlatform.iOS) {
    return true;
  }

  return coarsePointer ?? web_input.hasCoarsePointer();
}

bool _isPhoneSizedWebViewport(Size size) {
  final shortestSide = math.min(size.width, size.height);
  final longestSide = math.max(size.width, size.height);
  return shortestSide <= 520 && longestSide <= 1100;
}

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
    final barWidth = compact ? 198.0 : 218.0;
    final walletWidth = compact ? 220.0 : 390.0;
    final walletHeight = compact ? 64.0 : 94.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CurrencyBar(farmState: farmState, width: barWidth),
            const SizedBox(width: 12),
            _HudIconButton(
              icon: Icons.menu,
              tooltip: 'Menu',
              isActive: menuActive,
              onPressed: onMenuPressed,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WalletButton(
          farmState: farmState,
          width: walletWidth,
          height: walletHeight,
          compact: compact,
          onPressed: onWalletPressed,
        ),
      ],
    );
  }
}

class _CurrencyBar extends StatelessWidget {
  const _CurrencyBar({required this.farmState, required this.width});

  final FarmStateController farmState;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _HudFrame(
      width: width,
      height: 76,
      color: const Color(0xFF704110),
      border: const Color(0xFF56300C),
      child: Row(
        children: [
          _CoinIcon(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: _AmountBlock(label: 'COIN', value: '${farmState.coins}'),
          ),
        ],
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFF0DEB3),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFF0DEB3),
            fontSize: 26,
            height: 0.92,
          ),
        ),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.farmState,
    required this.width,
    required this.height,
    required this.compact,
    required this.onPressed,
  });

  final FarmStateController farmState;
  final double width;
  final double height;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final connected = farmState.walletConnected;
    return Tooltip(
      message: connected ? 'Wallet tersambung' : 'Connect wallet',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: _HudFrame(
          width: width,
          height: height,
          color: connected ? const Color(0xFF246644) : const Color(0xFF2A573E),
          border: connected ? const Color(0xFF69C487) : const Color(0xFF5B8F68),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 18,
            vertical: compact ? 6 : 12,
          ),
          child: Row(
            children: [
              _WalletIcon(connected: connected),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmState.walletLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFECF8E2),
                        fontSize: compact ? 16 : (connected ? 22 : 23),
                        height: 1.0,
                      ),
                    ),
                    Text(
                      connected ? 'tap untuk ganti/sync' : 'mode lokal aktif',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: connected
                            ? const Color(0xFFB1EEB9)
                            : const Color(0xFFD9EBCB),
                        fontSize: compact ? 12 : 16,
                        height: 1.05,
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

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.game,
    required this.width,
    required this.height,
  });

  final TaniinGame game;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mapWidth = width.clamp(236.0, 286.0).toDouble();
    final mapHeight = height.clamp(194.0, 264.0).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x62000000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 5),
          child: SizedBox(
            width: mapWidth,
            height: mapHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF5A3F1F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2D2110), width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF77B858),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFFB18845),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        isComplex: true,
                        willChange: false,
                        painter: _MiniMapPainter(game),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.game) : super(repaint: game.miniMapNotifier);

  final TaniinGame game;

  @override
  void paint(Canvas canvas, Size size) {
    game.drawMiniMapPreview(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.game != game;
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

class _Joystick extends StatefulWidget {
  const _Joystick({required this.game, required this.radius});

  final TaniinGame game;
  final double radius;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  bool _dragging = false;

  double get _radius => widget.radius;

  double get _knobRadius => _radius * 0.42;

  @override
  Widget build(BuildContext context) {
    final size = _radius * 2.2;
    final center = Offset(size * 0.5, size * 0.5);
    final knobCenter = _dragging ? center + _knob : center;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _update(details.localPosition, center),
      onPanUpdate: (details) => _update(details.localPosition, center),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _JoystickPainter(
            knobCenter: knobCenter,
            center: center,
            radius: _radius,
            knobRadius: _knobRadius,
          ),
        ),
      ),
    );
  }

  void _update(Offset position, Offset center) {
    final raw = position - center;
    final distance = raw.distance;
    final travel = _radius * 0.92;
    final clamped = distance > travel ? raw / distance * travel : raw;
    widget.game.setInputVector(clamped / travel);
    setState(() {
      _dragging = true;
      _knob = clamped;
    });
  }

  void _release() {
    widget.game.setInputVector(Offset.zero);
    setState(() {
      _dragging = false;
      _knob = Offset.zero;
    });
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({
    required this.knobCenter,
    required this.center,
    required this.radius,
    required this.knobRadius,
  });

  final Offset knobCenter;
  final Offset center;
  final double radius;
  final double knobRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    paint.color = const Color(0x66141414);
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0x99FFFFFF);
    canvas.drawCircle(knobCenter, knobRadius, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x55FFFFFF);
    canvas.drawCircle(center, radius - 6, paint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knobCenter != knobCenter;
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
            physics: const ClampingScrollPhysics(),
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
                  _SwapControl(farmState: farmState),
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

  void _performPrimary(BuildContext context) {
    switch (interaction) {
      case GameInteraction.sellHarvest:
        if (farmState.sellHarvest()) {
          onClose();
        }
        return;
      case GameInteraction.swapToken:
        if (farmState.swapSelectedAssets()) {
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

class _SwapControl extends StatelessWidget {
  const _SwapControl({required this.farmState});

  final FarmStateController farmState;

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
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 760;
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
                horizontal: vertical ? 0 : 14,
                vertical: vertical ? 10 : 0,
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
                const SizedBox(height: 18),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Text(
                        rateHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFFF0D4),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Jumlah ${farmState.swapAmountUnitLabel}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFFFF0D4),
                              fontSize: 22,
                            ),
                      ),
                    ),
                    Text(
                      farmState.swapAmountProgressLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFDE19),
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 15,
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
                  spacing: 10,
                  runSpacing: 10,
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
                      label: farmState.walletConnected
                          ? 'WALLET AKTIF'
                          : 'MODE LOKAL',
                      enabled: true,
                      onTap: () => farmState.showMessage(
                        farmState.walletConnected
                            ? 'Wallet aktif: ${farmState.walletLabel}'
                            : 'Buka tombol Connect Wallet di kanan atas.',
                        success: farmState.walletConnected,
                      ),
                      highlighted: farmState.walletConnected,
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
                'Game Coin: ${farmState.coins} | ${seed.name} | Paket x${farmState.shopBundleQuantity} = ${farmState.seedTotalAmount()} benih | Total ${farmState.seedTotalPrice(farmState.selectedSeedIndex)} Coin',
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
    final canBuy = farmState.coins >= price;
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

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _HudFrame(
              width: 76,
              height: 76,
              color: isActive
                  ? const Color(0xFF8D5218)
                  : const Color(0xFF7A4818),
              border: const Color(0xFF5B3510),
              padding: EdgeInsets.zero,
              child: Icon(icon, size: 42, color: const Color(0xFFF5E7CB)),
            ),
            if (badge != null)
              Positioned(
                right: -8,
                top: -8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDB5F),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2C1F0F),
                      width: 3,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Center(
                      child: Text(
                        badge!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF2C1F0F),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HudFrame extends StatelessWidget {
  const _HudFrame({
    required this.child,
    required this.width,
    required this.height,
    required this.color,
    required this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  final Widget child;
  final double width;
  final double height;
  final Color color;
  final Color border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x5A000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 5),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 4),
            ),
            child: Padding(padding: padding, child: child),
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

class _CoinIcon extends StatelessWidget {
  const _CoinIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _WalletIcon extends StatelessWidget {
  const _WalletIcon({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 60,
      child: CustomPaint(painter: _WalletPainter(connected)),
    );
  }
}

class _SeedPacket extends StatelessWidget {
  const _SeedPacket({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SeedPacketPainter(color)),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final center = size.center(Offset.zero);
    paint.color = const Color(0xFFF8F2D7);
    canvas.drawCircle(center, size.width * 0.50, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..color = const Color(0xFF362A12);
    canvas.drawCircle(center, size.width * 0.40, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFEEC530);
    canvas.drawCircle(center, size.width * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletPainter extends CustomPainter {
  const _WalletPainter(this.connected);

  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final center = size.center(Offset.zero);
    paint.color = connected ? const Color(0xFF70E084) : const Color(0xFFF4D057);
    canvas.drawCircle(center, size.width * 0.45, paint);
    paint.color = const Color(0xFF212F20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.62,
          height: size.height * 0.44,
        ),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.color = const Color(0xFFF0F6E4);
    canvas.drawRect(
      Rect.fromCenter(
        center: center.translate(0, -2),
        width: size.width * 0.42,
        height: 4,
      ),
      paint,
    );
    paint.color = connected ? const Color(0xFF45AA53) : const Color(0xFFC18A24);
    canvas.drawCircle(
      center.translate(size.width * 0.30, -size.height * 0.30),
      size.width * 0.11,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WalletPainter oldDelegate) =>
      oldDelegate.connected != connected;
}

class _SeedPacketPainter extends CustomPainter {
  const _SeedPacketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final scale = size.width / 44;
    final center = size.center(Offset.zero);
    paint.color = const Color(0xFFFFF6D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 32 * scale, height: 38 * scale),
        Radius.circular(4 * scale),
      ),
      paint,
    );
    paint.color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 12 * scale,
        center.dy - 12 * scale,
        24 * scale,
        19 * scale,
      ),
      paint,
    );
    paint.color = const Color(0xFF472C1F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - 8 * scale,
          center.dy + 3 * scale,
          16 * scale,
          11 * scale,
        ),
        Radius.circular(3 * scale),
      ),
      paint,
    );
    paint.color = const Color(0xFF60D25C);
    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - 10 * scale,
        center.dy - 4 * scale,
        12 * scale,
        9 * scale,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(center.dx, center.dy - 7 * scale, 11 * scale, 10 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeedPacketPainter oldDelegate) =>
      oldDelegate.color != color;
}
