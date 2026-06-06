import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _musicAsset = 'assets/assets/audio/backsound.mp3';
const String _clickAsset = 'assets/assets/audio/klik.mp3';
const String _walkAsset = 'assets/assets/audio/soundjalan.mp3';
const int _clickPoolSize = 4;
const double _walkVolumeRatio = 0.64;

final List<web.HTMLAudioElement> _clickPool = <web.HTMLAudioElement>[];
web.HTMLAudioElement? _musicAudio;
web.HTMLAudioElement? _walkAudio;
int _nextClick = 0;
bool _started = false;
bool _paused = false;
bool _musicEnabled = true;
bool _sfxEnabled = true;
bool _walkRequested = false;
double _musicVolume = 0.65;
double _sfxVolume = 0.8;

bool startWebAudio({
  required bool musicEnabled,
  required bool sfxEnabled,
  required double musicVolume,
  required double sfxVolume,
}) {
  _started = true;
  _paused = false;
  _ensureMusicAudio();
  _ensureWalkAudio();
  _ensureClickPool();
  syncWebAudio(
    musicEnabled: musicEnabled,
    sfxEnabled: sfxEnabled,
    musicVolume: musicVolume,
    sfxVolume: sfxVolume,
  );
  return true;
}

bool syncWebAudio({
  required bool musicEnabled,
  required bool sfxEnabled,
  required double musicVolume,
  required double sfxVolume,
}) {
  _musicEnabled = musicEnabled;
  _sfxEnabled = sfxEnabled;
  _musicVolume = musicVolume.clamp(0, 1).toDouble();
  _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
  _applyVolumes();
  if (!_sfxEnabled) {
    _pauseWalk(reset: true);
  }
  _syncMusicPlayback();
  return true;
}

bool playWebClick({required double sfxVolume}) {
  _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
  if (!_sfxEnabled) {
    return true;
  }
  _ensureClickPool();
  final audio = _clickPool[_nextClick];
  _nextClick = (_nextClick + 1) % _clickPool.length;
  try {
    audio.pause();
    audio.currentTime = 0;
    audio.volume = _sfxVolume;
    unawaited(_play(audio));
    _syncMusicPlayback();
  } on Object {
    // Browser audio failures should never block gameplay interaction.
  }
  return true;
}

bool startWebWalk({required double sfxVolume}) {
  _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
  _walkRequested = true;
  if (!_sfxEnabled || _paused) {
    return true;
  }
  _ensureWalkAudio();
  final audio = _walkAudio;
  if (audio == null) {
    return true;
  }
  audio.volume = (_sfxVolume * _walkVolumeRatio).clamp(0, 1).toDouble();
  if (audio.paused) {
    unawaited(_play(audio));
  }
  _syncMusicPlayback();
  return true;
}

bool stopWebWalk() {
  _walkRequested = false;
  _pauseWalk(reset: true);
  return true;
}

bool pauseWebAudio() {
  _paused = true;
  _musicAudio?.pause();
  _pauseWalk(reset: false);
  return true;
}

bool resumeWebAudio() {
  _paused = false;
  _syncMusicPlayback();
  if (_walkRequested && _sfxEnabled) {
    startWebWalk(sfxVolume: _sfxVolume);
  }
  return true;
}

bool releaseWebAudio() {
  _started = false;
  _paused = false;
  _walkRequested = false;
  _musicAudio?.pause();
  _walkAudio?.pause();
  for (final audio in _clickPool) {
    audio.pause();
  }
  _musicAudio = null;
  _walkAudio = null;
  _clickPool.clear();
  return true;
}

void _syncMusicPlayback() {
  if (!_started || _paused) {
    return;
  }
  final audio = _ensureMusicAudio();
  audio.volume = _musicVolume;
  if (_musicEnabled) {
    unawaited(_play(audio));
  } else {
    audio.pause();
  }
}

void _applyVolumes() {
  _musicAudio?.volume = _musicVolume;
  _walkAudio?.volume = (_sfxVolume * _walkVolumeRatio).clamp(0, 1).toDouble();
  for (final audio in _clickPool) {
    audio.volume = _sfxVolume;
  }
}

web.HTMLAudioElement _ensureMusicAudio() =>
    _musicAudio ??= _createLoopingAudio(_musicAsset, _musicVolume);

void _ensureWalkAudio() {
  _walkAudio ??= _createLoopingAudio(
    _walkAsset,
    (_sfxVolume * _walkVolumeRatio).clamp(0, 1).toDouble(),
  );
}

void _ensureClickPool() {
  if (_clickPool.isNotEmpty) {
    return;
  }
  for (var i = 0; i < _clickPoolSize; i += 1) {
    final audio = web.HTMLAudioElement()
      ..src = _clickAsset
      ..preload = 'auto'
      ..volume = _sfxVolume;
    audio.load();
    _clickPool.add(audio);
  }
}

web.HTMLAudioElement _createLoopingAudio(String src, double volume) {
  final audio = web.HTMLAudioElement()
    ..src = src
    ..loop = true
    ..preload = 'auto'
    ..volume = volume;
  audio.load();
  return audio;
}

void _pauseWalk({required bool reset}) {
  final audio = _walkAudio;
  if (audio == null) {
    return;
  }
  audio.pause();
  if (reset) {
    audio.currentTime = 0;
  }
}

Future<void> _play(web.HTMLAudioElement audio) async {
  try {
    await audio.play().toDart;
  } on Object {
    // Autoplay policy can reject outside a user gesture; ignore and retry on
    // the next real tap, click, or keyboard movement.
  }
}
