import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _clickAsset = 'assets/assets/audio/klik.mp3';
const int _clickPoolSize = 4;

final List<web.HTMLAudioElement> _clickPool = <web.HTMLAudioElement>[];
int _nextClick = 0;
bool _sfxEnabled = true;
double _sfxVolume = 0.8;

bool startWebAudio({required double sfxVolume}) {
  _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
  _ensureClickPool();
  return true;
}

bool syncWebAudio({required bool sfxEnabled, required double sfxVolume}) {
  _sfxEnabled = sfxEnabled;
  _sfxVolume = sfxVolume.clamp(0, 1).toDouble();
  for (final audio in _clickPool) {
    audio.volume = _sfxVolume;
  }
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
  } on Object {
    // Browser audio failures should never block gameplay interaction.
  }
  return true;
}

bool stopWebWalk() => true;

bool pauseWebAudio() => true;

bool resumeWebAudio() => true;

bool releaseWebAudio() {
  for (final audio in _clickPool) {
    audio.pause();
  }
  _clickPool.clear();
  return true;
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

Future<void> _play(web.HTMLAudioElement audio) async {
  try {
    await audio.play().toDart;
  } on Object {
    // Autoplay policy can reject outside a user gesture; ignore and retry on
    // the next real tap/click.
  }
}
