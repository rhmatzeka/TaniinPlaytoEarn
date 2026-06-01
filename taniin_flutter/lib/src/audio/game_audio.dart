import 'package:flutter/services.dart';

class GameAudioController {
  static const MethodChannel _channel = MethodChannel('taniin/audio');

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.65;
  double _sfxVolume = 0.8;

  Future<void> start() async {
    await _invoke('startMusic');
    await sync(
      musicEnabled: _musicEnabled,
      sfxEnabled: _sfxEnabled,
      musicVolume: _musicVolume,
      sfxVolume: _sfxVolume,
    );
  }

  Future<void> sync({
    required bool musicEnabled,
    required bool sfxEnabled,
    required double musicVolume,
    required double sfxVolume,
  }) async {
    _musicEnabled = musicEnabled;
    _sfxEnabled = sfxEnabled;
    _musicVolume = musicVolume.clamp(0, 1).toDouble();
    _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
    await _invoke('sync', <String, Object>{
      'musicEnabled': _musicEnabled,
      'sfxEnabled': _sfxEnabled,
      'musicVolume': _musicVolume,
      'sfxVolume': _sfxVolume,
    });
  }

  Future<void> playClick() async {
    if (!_sfxEnabled) {
      return;
    }
    await _invoke('playClick');
  }

  Future<void> startWalk() async {
    if (!_sfxEnabled) {
      return;
    }
    await _invoke('startWalk');
  }

  Future<void> stopWalk() => _invoke('stopWalk');

  Future<void> pause() => _invoke('pauseMusic');

  Future<void> resume() => _invoke('resumeMusic');

  Future<void> release() => _invoke('release');

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Tests and non-Android targets run without the native audio bridge.
    } on PlatformException {
      // Audio failure must not block gameplay.
    }
  }
}
