bool startWebAudio({
  required bool musicEnabled,
  required bool sfxEnabled,
  required double musicVolume,
  required double sfxVolume,
}) => false;

bool syncWebAudio({
  required bool musicEnabled,
  required bool sfxEnabled,
  required double musicVolume,
  required double sfxVolume,
}) => false;

bool playWebClick({required double sfxVolume}) => false;

bool startWebWalk({required double sfxVolume}) => false;

bool stopWebWalk() => false;

bool pauseWebAudio() => false;

bool resumeWebAudio() => false;

bool releaseWebAudio() => false;
