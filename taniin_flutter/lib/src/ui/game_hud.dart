import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/taniin_game.dart';
import '../state/farm_state.dart';
import '../chain/multiplayer_client.dart';
import '../chain/platform_bridge.dart';
import 'physical_viewport.dart';
import 'web_input_capability.dart'
    if (dart.library.js_interop) 'web_input_capability_web.dart'
    as web_input;
import 'hud/status_strip.dart';
import 'kayu.dart';
import 'pixel_art.dart';
import 'wallet_panel.dart';

part 'hud/top_bar.dart';
part 'hud/minimap.dart';
part 'hud/joystick.dart';
part 'hud/interaction.dart';
part 'hud/swap.dart';
part 'hud/shop.dart';
part 'hud/chat.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    required this.game,
    required this.farmState,
    required this.activePanel,
    required this.onPanelSelected,
    this.onChatTypingChanged,
    super.key,
  });

  final TaniinGame game;
  final FarmStateController farmState;
  final GamePanel? activePanel;
  final ValueChanged<GamePanel> onPanelSelected;
  final ValueChanged<bool>? onChatTypingChanged;

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
                final portrait = PhysicalViewport.isPortrait(
                  constraints.biggest,
                );
                // Sideways phones: one row of buttons along the top instead of a column.
                final short = !portrait && constraints.maxHeight < 600;
                final compact = portrait || short || constraints.maxWidth < 980;
                // Portrait phones: HUD stacks down the edges instead of across the top.
                const edge = 16.0;
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
                final miniMapWidth = portrait
                    ? 150.0
                    : short
                    ? 190.0
                    : compact
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
                final joystickTop = showTouchJoystick && portrait
                    ? constraints.maxHeight - joystickSize - 120
                    : showTouchJoystick
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
                            _handleWorldTap(context, details.globalPosition),
                      ),
                    ),
                    if (showMiniMap)
                      Positioned(
                        left: portrait ? edge : 32,
                        top: portrait ? edge : 26,
                        child: _MiniMap(
                          game: game,
                          width: miniMapWidth,
                          height: miniMapWidth * game.miniMapAspectRatio,
                        ),
                      ),
                    if (short)
                      Positioned(
                        right: edge,
                        top: 10,
                        child: _TopRow(
                          farmState: farmState,
                          activePanel: activePanel,
                          onPanelSelected: onPanelSelected,
                          onWalletPressed: () => _showWalletDialog(context),
                        ),
                      )
                    else ...[
                      Positioned(
                        right: portrait ? edge : 20,
                        top: portrait ? edge : 10,
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
                        right: portrait ? edge : 20,
                        top: portrait ? edge + 112 : 122,
                        child: Column(
                          children: _panelButtons(
                            farmState,
                            activePanel,
                            onPanelSelected,
                            gap: 12,
                            axis: Axis.vertical,
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      top: portrait
                          ? edge + miniMapWidth * game.miniMapAspectRatio + 36
                          : short
                          ? 118
                          : 8,
                      left: portrait
                          ? edge
                          : short
                          ? 400
                          : miniMapWidth + 48,
                      right: portrait
                          ? 110
                          : short
                          ? edge
                          : compact
                          ? 300
                          : 420,
                      child: Align(
                        alignment: portrait
                            ? Alignment.topLeft
                            : short
                            ? Alignment.topRight
                            : Alignment.topCenter,
                        child: AnimatedBuilder(
                          animation: game.multiplayerClient,
                          builder: (context, _) => StatusStrip(
                            farmState: farmState,
                            multiplayerOnline: game.multiplayerClient.connected,
                            aiOnline:
                                game.multiplayerClient.connected &&
                                game.multiplayerClient.aiAgent != null,
                          ),
                        ),
                      ),
                    ),
                    if (showTouchJoystick)
                      Positioned(
                        left: joystickLeft,
                        top: joystickTop,
                        child: _Joystick(game: game, radius: joystickRadius),
                      ),
                    // Chat / AI Agent Panel (collapsible, anchored under minimap)
                    Positioned(
                      left: portrait ? edge : 32,
                      top: portrait
                          ? edge + miniMapWidth * game.miniMapAspectRatio + 96
                          : 26 + miniMapWidth * game.miniMapAspectRatio + 12,
                      child: _ChatHud(
                        multiplayerClient: game.multiplayerClient,
                        compact: compact,
                        onTypingChanged: onChatTypingChanged,
                      ),
                    ),
                    Positioned(
                      left: portrait
                          ? edge
                          : compact
                          ? 194
                          : 260,
                      right: portrait
                          ? edge
                          : compact
                          ? 330
                          : 320,
                      bottom: portrait
                          ? 28
                          : compact
                          ? 20
                          : 32,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
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
                      ),
                    ),
                    if (farmState.statusVisible)
                      Positioned(
                        left: portrait ? 40 : constraints.maxWidth * 0.31,
                        right: portrait ? 40 : constraints.maxWidth * 0.31,
                        top: portrait ? 300 : 80,
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
      _showPanelDialog(
        context,
        (onClose) => _SwapHousePanel(farmState: farmState, onClose: onClose),
      );
      return;
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

  void _showPanelDialog(
    BuildContext context,
    Widget Function(VoidCallback onClose) panel,
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
              child: panel(() => Navigator.of(dialogContext).maybePop()),
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
