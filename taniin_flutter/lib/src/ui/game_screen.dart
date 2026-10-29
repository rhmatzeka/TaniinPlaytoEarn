import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_update.dart';
import '../chain/platform_bridge.dart';
import '../chain/multiplayer_client.dart';
import '../audio/game_audio.dart';
import '../game/taniin_game.dart';
import '../state/farm_state.dart';
import 'backpack_panel.dart';
import 'game_hud.dart';
import 'history_panel.dart';
import 'kayu.dart';
import 'loading_overlay.dart';
import 'physical_viewport.dart';
import 'profile_panel.dart';
import 'settings_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final FarmStateController _farmState;
  late final MultiplayerClient _multiplayerClient;
  late final TaniinGame _game;
  late final GameAudioController _audio;
  final FocusNode _gameFocusNode = FocusNode(debugLabel: 'Taniin game input');
  final Set<LogicalKeyboardKey> _movementKeys = <LogicalKeyboardKey>{};
  GamePanel? _activePanel;
  bool _gameMounted = false;
  bool _loadingFinished = false;
  bool _audioStarted = false;
  bool _appInForeground = true;
  bool _chatTyping = false;
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = GameAudioController();
    _audio.preload();
    _farmState = FarmStateController(onSfx: () => _audio.playClick());
    _farmState.addListener(_syncAudio);
    _multiplayerClient = MultiplayerClient(_farmState);
    PlatformBridge.setAuthCallbackHandler(
      (fragment) => unawaited(_farmState.handleAuthFragment(fragment)),
    );
    _game = TaniinGame(_farmState, _multiplayerClient);
    _game.walkingNotifier.addListener(_syncWalkAudio);
    _syncAudio();
    unawaited(_restoreStartupState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PlatformBridge.setAuthCallbackHandler(null);
    _farmState.removeListener(_syncAudio);
    _game.walkingNotifier.removeListener(_syncWalkAudio);
    _game.loadingComplete.dispose();
    _game.walkingNotifier.dispose();
    _game.hudNotifier.dispose();
    _game.miniMapNotifier.dispose();
    _gameFocusNode.dispose();
    _audio.release();
    unawaited(_farmState.saveNow());
    _multiplayerClient.dispose();
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
    _multiplayerClient.start();
    final launchFragment = PlatformBridge.launchAuthFragment();
    if (launchFragment.isNotEmpty) {
      unawaited(_farmState.handleAuthFragment(launchFragment));
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
    unawaited(
      checkForAppUpdate().then((update) {
        if (mounted && update != null) {
          setState(() => _update = update);
        }
      }),
    );
  }

  Future<void> _downloadUpdate() async {
    _farmState.playClick();
    await PlatformBridge.openUrl(apkDownloadUrl);
  }

  void _dismissUpdate() {
    _farmState.playClick();
    setState(() => _update = null);
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
      _activePanel == null &&
      !_chatTyping;

  void _requestGameFocus() {
    if (!mounted || !_canUseKeyboardMovement) {
      return;
    }
    // Do not steal focus away from the chat text field while the player types.
    if (_chatTyping) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canUseKeyboardMovement && !_chatTyping) {
        _gameFocusNode.requestFocus();
      }
    });
  }

  void _handleChatTypingChanged(bool typing) {
    if (_chatTyping == typing) {
      return;
    }
    setState(() => _chatTyping = typing);
    if (typing) {
      // Stop any in-progress movement and release the game focus node.
      _clearMovementInput();
    } else {
      _requestGameFocus();
    }
  }

  KeyEventResult _handleGameKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (!_isMovementKey(key)) {
      return KeyEventResult.ignored;
    }
    if (!_canUseKeyboardMovement || _chatTyping) {
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
          onPointerDown: (_) {
            if (!_chatTyping) {
              _requestGameFocus();
            }
          },
          child: AnimatedBuilder(
            animation: _farmState,
            builder: (context, _) {
              // Guests play right away; logging in is optional (wallet button).
              final canShowGameHud = _gameMounted && _loadingFinished;
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
                          onChatTypingChanged: _handleChatTypingChanged,
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
                      if (_update != null && _activePanel == null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: const Color(0x66000000),
                            child: PhysicalViewport(
                              alignment: Alignment.center,
                              child: Center(
                                child: _UpdateCard(
                                  update: _update!,
                                  onDownload: _downloadUpdate,
                                  onLater: _dismissUpdate,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
      GamePanel.profile => ProfilePanel(
        farmState: _farmState,
        onClose: _closePanel,
      ),
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

/// Shown once per launch when the apk-terbaru release has a newer build.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.onDownload,
    required this.onLater,
  });

  final AppUpdate update;
  final VoidCallback onDownload;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return KayuPanel(
      title: 'Ada versi baru!',
      subtitle: 'Taniin ${update.versionName}',
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/iconaplikasi.png',
          width: 56,
          height: 56,
          filterQuality: FilterQuality.medium,
        ),
      ),
      maxWidth: 560,
      onClose: onLater,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unduh APK terbaru untuk tampilan dan fitur terbaru. '
            'Pasang di atas versi ini, kebunmu tetap aman.',
            style: Kayu.teks(17),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: KayuButton(
                  label: 'Nanti',
                  tone: KayuTone.kedua,
                  expand: true,
                  onPressed: onLater,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KayuButton(
                  label: 'Unduh',
                  icon: Icons.download,
                  expand: true,
                  onPressed: onDownload,
                ),
              ),
            ],
          ),
        ],
      ),
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
