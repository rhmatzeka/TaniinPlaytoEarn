package id.rahmat.taniin_flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.Window
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioBridge: AndroidAudioBridge? = null
    private var platformChannel: MethodChannel? = null
    private var pendingWalletAddress = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        configureFullscreenWindow()
        super.onCreate(savedInstanceState)
        handleWalletIntent(intent)
        hideSystemUi()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWalletIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = AndroidAudioBridge(this)
        audioBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taniin/audio")
            .setMethodCallHandler { call, result ->
                bridge.handle(call)
                result.success(null)
            }
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taniin/platform")
        platformChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getChainConfig" -> result.success(chainConfig())
                "openUrl" -> result.success(openUrl(call.argument<String>("url").orEmpty()))
                else -> result.notImplemented()
            }
        }
        deliverPendingWalletAddress()
    }

    override fun onResume() {
        super.onResume()
        hideSystemUi()
        audioBridge?.resume()
    }

    override fun onPause() {
        audioBridge?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        audioBridge?.release()
        audioBridge = null
        platformChannel = null
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUi()
        }
    }

    private fun configureFullscreenWindow() {
        val window = window
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attributes = window.attributes
            attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = attributes
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
    }

    private fun handleWalletIntent(intent: Intent?) {
        val data: Uri = intent?.data ?: return
        if (data.scheme != "taniin" || data.host != "wallet") {
            return
        }
        val address = data.getQueryParameter("address")?.trim().orEmpty()
        if (address.isEmpty()) {
            return
        }
        pendingWalletAddress = address
        deliverPendingWalletAddress()
    }

    private fun deliverPendingWalletAddress() {
        val address = pendingWalletAddress
        val channel = platformChannel
        if (address.isEmpty() || channel == null) {
            return
        }
        pendingWalletAddress = ""
        channel.invokeMethod("walletAddress", address)
    }

    private fun chainConfig(): Map<String, String> = mapOf(
        "rpcUrl" to BuildConfig.SEPOLIA_RPC_URL,
        "coinContractAddress" to BuildConfig.TANIIN_COIN_CONTRACT_ADDRESS,
        "itemsContractAddress" to BuildConfig.TANIIN_ITEMS_CONTRACT_ADDRESS,
        "landContractAddress" to BuildConfig.TANIIN_LAND_CONTRACT_ADDRESS,
        "gameApiUrl" to BuildConfig.TANIIN_GAME_API_URL,
        "defaultWalletAddress" to BuildConfig.TANIIN_DEFAULT_WALLET_ADDRESS,
    )

    private fun openUrl(url: String): Boolean {
        if (url.isBlank()) {
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        try {
            startActivity(intent)
            return true
        } catch (_: ActivityNotFoundException) {
            return false
        } catch (_: RuntimeException) {
            return false
        }
    }

    @Suppress("DEPRECATION")
    private fun hideSystemUi() {
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }
    }
}

private class AndroidAudioBridge(private val activity: MainActivity) {
    private companion object {
        const val WALK_VOLUME_RATIO = 0.64f
    }

    private val soundPool: SoundPool
    private val clickSoundId: Int
    private var walkSoundId = 0
    private var musicPlayer: MediaPlayer? = null
    private var walkStreamId = 0
    private var musicEnabled = true
    private var sfxEnabled = true
    private var musicVolume = 0.65f
    private var sfxVolume = 0.8f
    private var musicRequested = false
    private var walkRequested = false
    private var walkLoaded = false
    private var walkPrewarmed = false
    private var released = false

    init {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setAudioAttributes(attributes)
            .setMaxStreams(5)
            .build()
        soundPool.setOnLoadCompleteListener { _, sampleId, status ->
            if (sampleId == walkSoundId && status == 0) {
                walkLoaded = true
                if (walkRequested && walkStreamId == 0) {
                    startWalk()
                } else {
                    prewarmWalk()
                }
            }
        }
        clickSoundId = soundPool.load(activity, R.raw.klik, 1)
        walkSoundId = soundPool.load(activity, R.raw.soundjalan, 1)
    }

    fun handle(call: MethodCall) {
        if (released) {
            return
        }
        when (call.method) {
            "startMusic" -> requestMusicStart()
            "resumeMusic" -> resume()
            "pauseMusic" -> pause()
            "playClick" -> playClick()
            "startWalk" -> startWalk()
            "stopWalk" -> stopWalk()
            "release" -> release()
            "sync" -> sync(call.arguments)
        }
    }

    fun resume() {
        if (musicRequested && musicEnabled) {
            startMusic()
        }
    }

    fun pause() {
        stopWalk()
        pauseMusicOnly()
    }

    private fun pauseMusicOnly() {
        musicPlayer?.takeIf { it.isPlaying }?.pause()
    }

    fun release() {
        if (released) {
            return
        }
        released = true
        musicRequested = false
        stopWalk()
        musicPlayer?.release()
        musicPlayer = null
        soundPool.release()
    }

    private fun requestMusicStart() {
        musicRequested = true
        startMusic()
    }

    private fun startMusic() {
        if (!musicEnabled || released) {
            return
        }
        val player = musicPlayer ?: MediaPlayer.create(activity, R.raw.backsound)?.also {
            it.isLooping = true
            musicPlayer = it
        }
        player?.setVolume(musicVolume, musicVolume)
        if (player != null && !player.isPlaying) {
            player.start()
        }
    }

    private fun playClick() {
        if (!sfxEnabled || released) {
            return
        }
        soundPool.play(clickSoundId, sfxVolume, sfxVolume, 1, 0, 1f)
    }

    private fun startWalk() {
        walkRequested = true
        if (released || !sfxEnabled || walkSoundId == 0 || !walkLoaded) {
            return
        }
        if (walkStreamId != 0) {
            return
        }
        val volume = walkVolume()
        walkStreamId = soundPool.play(walkSoundId, volume, volume, 1, -1, 1f)
    }

    private fun stopWalk() {
        walkRequested = false
        if (walkStreamId == 0) {
            return
        }
        soundPool.stop(walkStreamId)
        walkStreamId = 0
    }

    private fun prewarmWalk() {
        if (released || walkPrewarmed || walkSoundId == 0 || !walkLoaded) {
            return
        }
        val streamId = soundPool.play(walkSoundId, 0f, 0f, 0, 0, 1f)
        if (streamId != 0) {
            soundPool.stop(streamId)
            walkPrewarmed = true
        }
    }

    private fun sync(arguments: Any?) {
        val map = arguments as? Map<*, *> ?: return
        musicEnabled = map["musicEnabled"] as? Boolean ?: musicEnabled
        sfxEnabled = map["sfxEnabled"] as? Boolean ?: sfxEnabled
        musicVolume = (map["musicVolume"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: musicVolume
        sfxVolume = (map["sfxVolume"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: sfxVolume
        musicPlayer?.setVolume(musicVolume, musicVolume)
        if (walkStreamId != 0) {
            val volume = walkVolume()
            soundPool.setVolume(walkStreamId, volume, volume)
        }
        if (!sfxEnabled) {
            stopWalk()
        }
        if (!musicRequested) {
            return
        }
        if (musicEnabled) {
            startMusic()
        } else {
            pauseMusicOnly()
        }
    }

    private fun walkVolume(): Float = (sfxVolume * WALK_VOLUME_RATIO).coerceIn(0f, 1f)
}
