import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chain/platform_bridge.dart';
import '../audio/game_audio.dart';
import '../game/taniin_game.dart';
import '../state/farm_state.dart';
import 'backpack_panel.dart';
import 'game_hud.dart';
import 'history_panel.dart';
import 'loading_overlay.dart';
import 'physical_viewport.dart';
import 'settings_panel.dart';
import 'wallet_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final FarmStateController _farmState;
  late final TaniinGame _game;
  late final GameAudioController _audio;
  final FocusNode _gameFocusNode = FocusNode(debugLabel: 'Taniin game input');
  final Set<LogicalKeyboardKey> _movementKeys = <LogicalKeyboardKey>{};
  GamePanel? _activePanel;
  bool _gameMounted = false;
  bool _loadingFinished = false;
  bool _audioStarted = false;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = GameAudioController();
    _farmState = FarmStateController(onSfx: () => _audio.playClick());
    _farmState.addListener(_syncAudio);
    PlatformBridge.setWalletAddressHandler(
      _farmState.connectWalletFromDeepLink,
    );
    _game = TaniinGame(_farmState);
    _game.walkingNotifier.addListener(_syncWalkAudio);
    _syncAudio();
    unawaited(_restoreStartupState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PlatformBridge.setWalletAddressHandler(null);
    _farmState.removeListener(_syncAudio);
    _game.walkingNotifier.removeListener(_syncWalkAudio);
    _game.loadingComplete.dispose();
    _game.walkingNotifier.dispose();
    _game.hudNotifier.dispose();
    _game.miniMapNotifier.dispose();
    _gameFocusNode.dispose();
    _audio.release();
    unawaited(_farmState.saveNow());
    _farmState.dispose();
    super.dispose();
  }

  Future<void> _restoreStartupState() async {
    await _farmState.loadSavedState();
    if (!mounted) {
      return;
    }
    setState(() => _gameMounted = true);
    unawaited(_loadChainConfig());
  }

  Future<void> _loadChainConfig() async {
    final config = await PlatformBridge.loadChainConfig();
    if (!mounted) {
      return;
    }
    _farmState.configureChain(config);
    final launchWalletAddress = PlatformBridge.launchWalletAddress();
    if (launchWalletAddress.isNotEmpty) {
      unawaited(_farmState.connectWalletFromDeepLink(launchWalletAddress));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      if (_audioStarted) {
        _audio.resume();
      } else {
        _startAudioIfReady();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appInForeground = false;
      _clearMovementInput();
      unawaited(_farmState.saveNow());
      if (_audioStarted) {
        _audio.stopWalk();
        _audio.pause();
      }
    }
  }

  void _togglePanel(GamePanel panel) {
    _farmState.playClick();
    final closing = _activePanel == panel;
    setState(() {
      _activePanel = closing ? null : panel;
    });
    _clearMovementInput();
    if (closing) {
      _requestGameFocus();
    }
  }

  void _closePanel() {
    _farmState.playClick();
    setState(() {
      _activePanel = null;
    });
    _clearMovementInput();
    _requestGameFocus();
  }

  void _syncAudio() {
    _audio.sync(
      musicEnabled: _farmState.musicEnabled,
      sfxEnabled: _farmState.sfxEnabled,
      musicVolume: _farmState.musicVolume,
      sfxVolume: _farmState.sfxVolume,
    );
    _syncWalkAudio();
    _requestGameFocus();
  }

  void _syncWalkAudio() {
    if (!_audioStarted || !_appInForeground || !_farmState.sfxEnabled) {
      _audio.stopWalk();
      return;
    }
    if (_game.walkingNotifier.value) {
      _audio.startWalk();
    } else {
      _audio.stopWalk();
    }
  }

  void _handleLoadingFinished() {
    setState(() => _loadingFinished = true);
    _startAudioIfReady();
    _requestGameFocus();
  }

  void _startAudioIfReady() {
    if (!_loadingFinished || !_appInForeground || _audioStarted) {
      return;
    }
    _audioStarted = true;
    _audio.start();
    _syncWalkAudio();
  }

  bool get _canUseKeyboardMovement =>
      _gameMounted &&
      _loadingFinished &&
      _appInForeground &&
      _farmState.walletConnected &&
      _activePanel == null;

  void _requestGameFocus() {
    if (!mounted || !_canUseKeyboardMovement) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canUseKeyboardMovement) {
        _gameFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleGameKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (!_isMovementKey(key)) {
      return KeyEventResult.ignored;
    }
    if (!_canUseKeyboardMovement) {
      _clearMovementInput();
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _movementKeys.add(key);
    } else if (event is KeyUpEvent) {
      _movementKeys.remove(key);
    }
    _syncKeyboardMovement();
    return KeyEventResult.handled;
  }

  void _syncKeyboardMovement() {
    if (!_canUseKeyboardMovement || _movementKeys.isEmpty) {
      _game.setInputVector(Offset.zero);
      return;
    }

    var dx = 0.0;
    var dy = 0.0;
    if (_movementKeys.any(_leftMovementKeys.contains)) {
      dx -= 1;
    }
    if (_movementKeys.any(_rightMovementKeys.contains)) {
      dx += 1;
    }
    if (_movementKeys.any(_upMovementKeys.contains)) {
      dy -= 1;
    }
    if (_movementKeys.any(_downMovementKeys.contains)) {
      dy += 1;
    }
    _game.setInputVector(Offset(dx, dy));
  }

  void _clearMovementInput() {
    _movementKeys.clear();
    _game.setInputVector(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _gameFocusNode,
        autofocus: true,
        onFocusChange: (focused) {
          if (!focused) {
            _clearMovementInput();
          }
        },
        onKeyEvent: _handleGameKeyEvent,
        child: Listener(
          onPointerDown: (_) => _requestGameFocus(),
          child: AnimatedBuilder(
            animation: _farmState,
            builder: (context, _) {
              final startupReady = _gameMounted && _loadingFinished;
              final needsWalletLogin =
                  startupReady && !_farmState.walletConnected;
              final canShowGameHud = startupReady && _farmState.walletConnected;
              return Stack(
                children: [
                  if (_gameMounted) ...[
                    Positioned.fill(child: GameWidget(game: _game)),
                    if (canShowGameHud) ...[
                      Positioned.fill(
                        child: GameHud(
                          game: _game,
                          farmState: _farmState,
                          activePanel: _activePanel,
                          onPanelSelected: _togglePanel,
                        ),
                      ),
                      Positioned.fill(
                        child: _activePanel == null
                            ? const SizedBox.shrink()
                            : ColoredBox(
                                color: const Color(0x66000000),
                                child: PhysicalViewport(
                                  alignment: Alignment.center,
                                  child: Center(child: _buildPanel()),
                                ),
                              ),
                      ),
                    ],
                    if (needsWalletLogin)
                      Positioned.fill(
                        child: _WalletLoginGate(farmState: _farmState),
                      ),
                  ] else
                    const Positioned.fill(child: _LoadingBackdrop()),
                  Positioned.fill(
                    child: PhysicalViewport(
                      child: LoadingOverlay(
                        loaded: _game.loadingComplete,
                        onFinished: _handleLoadingFinished,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return switch (_activePanel!) {
      GamePanel.backpack => BackpackPanel(
        farmState: _farmState,
        onClose: _closePanel,
      ),
      GamePanel.history => HistoryPanel(
        farmState: _farmState,
        onClose: _closePanel,
      ),
      GamePanel.settings => SettingsPanel(
        farmState: _farmState,
        onClose: _closePanel,
      ),
    };
  }
}

final Set<LogicalKeyboardKey> _leftMovementKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.arrowLeft,
};

final Set<LogicalKeyboardKey> _rightMovementKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.arrowRight,
};

final Set<LogicalKeyboardKey> _upMovementKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.arrowUp,
};

final Set<LogicalKeyboardKey> _downMovementKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.arrowDown,
};

bool _isMovementKey(LogicalKeyboardKey key) =>
    _leftMovementKeys.contains(key) ||
    _rightMovementKeys.contains(key) ||
    _upMovementKeys.contains(key) ||
    _downMovementKeys.contains(key);

class _WalletLoginGate extends StatelessWidget {
  const _WalletLoginGate({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _LoadingBackdrop(),
        const ColoredBox(color: Color(0x7A102015)),
        PhysicalViewport(
          alignment: Alignment.center,
          child: Center(
            child: WalletPanel(
              farmState: farmState,
              onClose: () {},
              showCloseButton: false,
              prominent: true,
              showFacts: false,
              title: 'Login Wallet',
              subtitle: 'Connect wallet dulu untuk mulai bermain',
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBackdrop extends StatelessWidget {
  const _LoadingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF275D35)),
        Image.asset(
          'assets/images/loadingscreen.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
        ),
      ],
    );
  }
}
