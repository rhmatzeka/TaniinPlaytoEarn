package id.rahmat.taniin;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.SoundPool;

final class GameAudio {
    private static final float BGM_VOLUME = 0.34f;
    private static final float SFX_VOLUME = 0.72f;
    private static final float WALK_VOLUME = 0.46f;

    private final Context context;
    private final int[] bgmResources = {R.raw.backsound, R.raw.backsound2};
    private final SoundPool soundPool;
    private final int clickSoundId;
    private final int errorSoundId;
    private int walkSoundId;

    private MediaPlayer bgmPlayer;
    private int walkStreamId;
    private int bgmIndex;
    private boolean bgmEnabled = true;
    private boolean sfxEnabled = true;
    private boolean bgmRequested;
    private boolean walkRequested;
    private boolean walkLoaded;
    private boolean walkPrewarmed;
    private boolean released;

    GameAudio(Context context) {
        this.context = context.getApplicationContext();
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();
        soundPool = new SoundPool.Builder()
                .setAudioAttributes(attributes)
                .setMaxStreams(5)
                .build();
        soundPool.setOnLoadCompleteListener((pool, sampleId, status) -> {
            if (sampleId == walkSoundId && status == 0) {
                walkLoaded = true;
                if (walkRequested && walkStreamId == 0) {
                    startWalk();
                } else {
                    prewarmWalk();
                }
            }
        });
        clickSoundId = soundPool.load(this.context, R.raw.klik, 1);
        errorSoundId = soundPool.load(this.context, R.raw.gagalerror, 1);
        walkSoundId = soundPool.load(this.context, R.raw.soundjalan, 1);
    }

    void resumeBgm() {
        if (released) {
            return;
        }
        bgmRequested = true;
        if (!bgmEnabled) {
            return;
        }
        ensureBgmPlayer();
        if (bgmPlayer != null && !bgmPlayer.isPlaying()) {
            bgmPlayer.start();
        }
    }

    void pauseBgm() {
        bgmRequested = false;
        if (bgmPlayer != null && bgmPlayer.isPlaying()) {
            bgmPlayer.pause();
        }
    }

    void playClick() {
        play(clickSoundId, SFX_VOLUME);
    }

    void playError() {
        play(errorSoundId, SFX_VOLUME);
    }

    void startWalk() {
        walkRequested = true;
        if (released || !sfxEnabled || walkSoundId == 0 || !walkLoaded) {
            return;
        }
        if (walkStreamId != 0) {
            return;
        }
        walkStreamId = soundPool.play(walkSoundId, WALK_VOLUME, WALK_VOLUME, 1, -1, 1f);
    }

    void stopWalk() {
        walkRequested = false;
        if (walkStreamId == 0) {
            return;
        }
        soundPool.stop(walkStreamId);
        walkStreamId = 0;
    }

    void setBgmEnabled(boolean enabled) {
        bgmEnabled = enabled;
        if (!enabled) {
            if (bgmPlayer != null && bgmPlayer.isPlaying()) {
                bgmPlayer.pause();
            }
            return;
        }
        if (bgmRequested) {
            resumeBgm();
        }
    }

    void setSfxEnabled(boolean enabled) {
        sfxEnabled = enabled;
        if (!enabled) {
            stopWalk();
        }
    }

    void setBgmIndex(int index) {
        if (bgmResources.length == 0) {
            bgmIndex = 0;
            return;
        }
        bgmIndex = Math.max(0, Math.min(index, bgmResources.length - 1));
    }

    int getBgmIndex() {
        return bgmIndex;
    }

    int getBgmCount() {
        return bgmResources.length;
    }

    void nextBgm() {
        if (bgmResources.length <= 1) {
            return;
        }
        boolean shouldRestart = bgmRequested && bgmEnabled;
        releaseBgmPlayer();
        bgmIndex = (bgmIndex + 1) % bgmResources.length;
        if (shouldRestart) {
            resumeBgm();
        }
    }

    void release() {
        stopWalk();
        released = true;
        bgmRequested = false;
        releaseBgmPlayer();
        soundPool.release();
    }

    private void play(int soundId, float volume) {
        if (released || !sfxEnabled || soundId == 0) {
            return;
        }
        soundPool.play(soundId, volume, volume, 1, 0, 1f);
    }

    private void prewarmWalk() {
        if (released || walkPrewarmed || walkSoundId == 0 || !walkLoaded) {
            return;
        }
        int streamId = soundPool.play(walkSoundId, 0f, 0f, 0, 0, 1f);
        if (streamId != 0) {
            soundPool.stop(streamId);
            walkPrewarmed = true;
        }
    }

    private void ensureBgmPlayer() {
        if (bgmPlayer != null || bgmResources.length == 0) {
            return;
        }
        bgmPlayer = MediaPlayer.create(context, bgmResources[bgmIndex]);
        if (bgmPlayer == null) {
            return;
        }
        bgmPlayer.setVolume(BGM_VOLUME, BGM_VOLUME);
        bgmPlayer.setLooping(bgmResources.length == 1);
        bgmPlayer.setOnCompletionListener(player -> {
            releaseBgmPlayer();
            bgmIndex = (bgmIndex + 1) % bgmResources.length;
            if (bgmRequested) {
                resumeBgm();
            }
        });
    }

    private void releaseBgmPlayer() {
        if (bgmPlayer == null) {
            return;
        }
        bgmPlayer.setOnCompletionListener(null);
        bgmPlayer.release();
        bgmPlayer = null;
    }
}
