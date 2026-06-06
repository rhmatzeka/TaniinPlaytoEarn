import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _musicAsset = 'assets/assets/audio/backsound.mp3';
const String _clickAsset = 'assets/assets/audio/klik.mp3';
const String _walkAsset = 'assets/assets/audio/soundjalan.mp3';
const int _clickPoolSize = 4;
const int _walkPoolSize = 2;
const double _walkLoopOverlapSeconds = 0.09;
const double _walkLoopFallbackSeconds = 0.82;
const double _walkVolumeRatio = 0.64;

final List<web.HTMLAudioElement> _clickPool = <web.HTMLAudioElement>[];
final List<web.HTMLAudioElement> _walkPool = <web.HTMLAudioElement>[];
web.HTMLAudioElement? _musicAudio;
int _nextClick = 0;
int _nextWalk = 0;
Timer? _walkLoopTimer;
bool _started = false;
bool _paused = false;
bool _musicEnabled = true;
bool _sfxEnabled = true;
bool _walkRequested = false;
bool _walkLoopActive = false;
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
  _ensureWalkPool();
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
  _ensureWalkPool();
  _applyWalkVolume();
  if (!_walkLoopActive) {
    _walkLoopActive = true;
    _nextWalk = 0;
    _playNextWalkSegment();
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
  _stopWalkPool(reset: true);
  for (final audio in _clickPool) {
    audio.pause();
  }
  _musicAudio = null;
  _walkPool.clear();
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
  _applyWalkVolume();
  for (final audio in _clickPool) {
    audio.volume = _sfxVolume;
  }
}

web.HTMLAudioElement _ensureMusicAudio() =>
    _musicAudio ??= _createLoopingAudio(_musicAsset, _musicVolume);

void _ensureWalkPool() {
  if (_walkPool.isNotEmpty) {
    return;
  }
  final volume = _walkVolume();
  for (var i = 0; i < _walkPoolSize; i += 1) {
    final audio = web.HTMLAudioElement()
      ..src = _walkAsset
      ..preload = 'auto'
      ..volume = volume;
    audio.load();
    _walkPool.add(audio);
  }
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
  _stopWalkPool(reset: reset);
}

void _playNextWalkSegment() {
  if (!_walkRequested || !_sfxEnabled || _paused || _walkPool.isEmpty) {
    _stopWalkPool(reset: true);
    return;
  }

  final audio = _walkPool[_nextWalk];
  _nextWalk = (_nextWalk + 1) % _walkPool.length;
  try {
    audio.pause();
    audio.currentTime = 0;
    audio.volume = _walkVolume();
    unawaited(_play(audio));
  } on Object {
    // Ignore media failures and retry on the next scheduled segment.
  }

  _walkLoopTimer?.cancel();
  _walkLoopTimer = Timer(_walkLoopDelay(audio), _playNextWalkSegment);
}

Duration _walkLoopDelay(web.HTMLAudioElement audio) {
  final duration = audio.duration;
  final seconds = duration.isFinite && duration > _walkLoopOverlapSeconds
      ? duration - _walkLoopOverlapSeconds
      : _walkLoopFallbackSeconds;
  final milliseconds = (seconds * 1000).round().clamp(120, 5000);
  return Duration(milliseconds: milliseconds);
}

void _stopWalkPool({required bool reset}) {
  _walkLoopTimer?.cancel();
  _walkLoopTimer = null;
  _walkLoopActive = false;
  for (final audio in _walkPool) {
    audio.pause();
    if (reset) {
      audio.currentTime = 0;
    }
  }
}

void _applyWalkVolume() {
  final volume = _walkVolume();
  for (final audio in _walkPool) {
    audio.volume = volume;
  }
}

double _walkVolume() => (_sfxVolume * _walkVolumeRatio).clamp(0, 1).toDouble();

Future<void> _play(web.HTMLAudioElement audio) async {
  try {
    await audio.play().toDart;
  } on Object {
    // Autoplay policy can reject outside a user gesture; ignore and retry on
    // the next real tap, click, or keyboard movement.
  }
}
