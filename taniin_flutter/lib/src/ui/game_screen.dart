import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final FarmStateController _farmState;
  late final TaniinGame _game;
  late final GameAudioController _audio;
  GamePanel? _activePanel;
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
    _loadChainConfig();
    _game = TaniinGame(_farmState);
    _game.walkingNotifier.addListener(_syncWalkAudio);
    _syncAudio();
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
    _audio.release();
    _farmState.dispose();
    super.dispose();
  }

  Future<void> _loadChainConfig() async {
    final config = await PlatformBridge.loadChainConfig();
    if (!mounted) {
      return;
    }
    _farmState.configureChain(config);
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
      if (_audioStarted) {
        _audio.stopWalk();
        _audio.pause();
      }
    }
  }

  void _togglePanel(GamePanel panel) {
    _farmState.playClick();
    setState(() {
      _activePanel = _activePanel == panel ? null : panel;
    });
  }

  void _closePanel() {
    _farmState.playClick();
    setState(() {
      _activePanel = null;
    });
  }

  void _syncAudio() {
    _audio.sync(
      musicEnabled: _farmState.musicEnabled,
      sfxEnabled: _farmState.sfxEnabled,
      musicVolume: _farmState.musicVolume,
      sfxVolume: _farmState.sfxVolume,
    );
    _syncWalkAudio();
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
    _loadingFinished = true;
    _startAudioIfReady();
  }

  void _startAudioIfReady() {
    if (!_loadingFinished || !_appInForeground || _audioStarted) {
      return;
    }
    _audioStarted = true;
    _audio.start();
    _syncWalkAudio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _farmState,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
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
