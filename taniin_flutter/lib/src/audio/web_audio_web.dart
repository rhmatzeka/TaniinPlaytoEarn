import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _musicAsset = 'assets/assets/audio/backsound.mp3';
const String _clickAsset = 'assets/assets/audio/klik.mp3';
const String _walkAsset = 'assets/assets/audio/soundjalan.mp3';
const int _clickPoolSize = 4;
const double _walkLoopStartSeconds = 0.015;
const double _walkLoopEndTrimSeconds = 0.08;
const double _walkVolumeRatio = 0.64;

final List<web.HTMLAudioElement> _clickPool = <web.HTMLAudioElement>[];
web.HTMLAudioElement? _musicAudio;
web.AudioContext? _audioContext;
web.AudioBuffer? _walkBuffer;
web.GainNode? _walkGain;
web.AudioBufferSourceNode? _walkSource;
Future<void>? _walkBufferLoad;
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
  _ensureAudioContext();
  unawaited(_loadWalkBuffer());
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
  final context = _ensureAudioContext();
  unawaited(_resumeAudioContext(context));
  _applyWalkVolume();
  _startBufferedWalkLoop();
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
  final context = _audioContext;
  if (context != null) {
    unawaited(_suspendAudioContext(context));
  }
  return true;
}

bool resumeWebAudio() {
  _paused = false;
  final context = _audioContext;
  if (context != null) {
    unawaited(_resumeAudioContext(context));
  }
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
  _stopWalkSource();
  for (final audio in _clickPool) {
    audio.pause();
  }
  final context = _audioContext;
  _musicAudio = null;
  _audioContext = null;
  _walkBuffer = null;
  _walkGain = null;
  _walkBufferLoad = null;
  _clickPool.clear();
  if (context != null) {
    unawaited(_closeAudioContext(context));
  }
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
  _stopWalkSource();
}

web.AudioContext _ensureAudioContext() {
  final existing = _audioContext;
  if (existing != null) {
    return existing;
  }
  final context = web.AudioContext();
  _audioContext = context;
  final gain = context.createGain();
  gain.gain.value = _walkVolume();
  gain.connect(context.destination);
  _walkGain = gain;
  return context;
}

Future<void> _loadWalkBuffer() {
  if (_walkBuffer != null) {
    return Future<void>.value();
  }
  final existing = _walkBufferLoad;
  if (existing != null) {
    return existing;
  }
  final context = _ensureAudioContext();
  final load = () async {
    try {
      final response = await web.window.fetch(_walkAsset.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;
      final decoded = await context.decodeAudioData(arrayBuffer).toDart;
      if (_audioContext != context) {
        return;
      }
      _walkBuffer = decoded;
      if (_walkRequested && _sfxEnabled && !_paused) {
        _startBufferedWalkLoop();
      }
    } on Object {
      _walkBufferLoad = null;
    }
  }();
  _walkBufferLoad = load;
  return load;
}

void _startBufferedWalkLoop() {
  if (!_walkRequested || !_sfxEnabled || _paused || _walkSource != null) {
    return;
  }
  final buffer = _walkBuffer;
  if (buffer == null) {
    unawaited(_loadWalkBuffer());
    return;
  }
  final context = _ensureAudioContext();
  final gain = _ensureWalkGain(context);
  final source = context.createBufferSource()
    ..buffer = buffer
    ..loop = true
    ..loopStart = _walkLoopStart(buffer)
    ..loopEnd = _walkLoopEnd(buffer);
  source.connect(gain);
  try {
    source.start();
    _walkSource = source;
  } on Object {
    try {
      source.disconnect();
    } on Object {
      // Failed source cleanup should not block gameplay.
    }
  }
}

web.GainNode _ensureWalkGain(web.AudioContext context) {
  final existing = _walkGain;
  if (existing != null) {
    return existing;
  }
  final gain = context.createGain();
  gain.gain.value = _walkVolume();
  gain.connect(context.destination);
  _walkGain = gain;
  return gain;
}

double _walkLoopStart(web.AudioBuffer buffer) {
  if (buffer.duration <= _walkLoopStartSeconds + _walkLoopEndTrimSeconds) {
    return 0;
  }
  return _walkLoopStartSeconds;
}

double _walkLoopEnd(web.AudioBuffer buffer) {
  final end = buffer.duration - _walkLoopEndTrimSeconds;
  return end > _walkLoopStart(buffer) ? end : buffer.duration;
}

void _stopWalkSource() {
  final source = _walkSource;
  _walkSource = null;
  if (source == null) {
    return;
  }
  try {
    source.stop();
  } on Object {
    // A source can throw if it has already stopped.
  }
  try {
    source.disconnect();
  } on Object {
    // Disconnect can throw during teardown; ignore it.
  }
}

Future<void> _resumeAudioContext(web.AudioContext context) async {
  try {
    await context.resume().toDart;
  } on Object {
    // Resume can fail if the page is closing or audio output is unavailable.
  }
}

Future<void> _suspendAudioContext(web.AudioContext context) async {
  try {
    await context.suspend().toDart;
  } on Object {
    // Audio suspension must not block lifecycle changes.
  }
}

Future<void> _closeAudioContext(web.AudioContext context) async {
  try {
    await context.close().toDart;
  } on Object {
    // Ignore close failures during teardown.
  }
}

void _applyWalkVolume() {
  final volume = _walkVolume();
  _walkGain?.gain.value = volume;
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
