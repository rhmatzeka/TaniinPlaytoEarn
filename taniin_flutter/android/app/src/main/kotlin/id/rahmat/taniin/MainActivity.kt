package id.rahmat.taniin

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioBridge: AndroidAudioBridge? = null
    private var platformChannel: MethodChannel? = null
    private var splashOverlay: View? = null
    private var pendingWalletAddress = ""
    private val flutterUiDisplayListener = object : FlutterUiDisplayListener {
        override fun onFlutterUiDisplayed() {
            window.decorView.postDelayed({ removeNativeSplashOverlay() }, 120L)
        }

        override fun onFlutterUiNoLongerDisplayed() = Unit
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        configureFullscreenWindow()
        super.onCreate(savedInstanceState)
        installNativeSplashOverlay()
        handleWalletIntent(intent)
        scheduleHideSystemUi()
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
        scheduleHideSystemUi()
        audioBridge?.resume()
    }

    override fun onPause() {
        audioBridge?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        removeNativeSplashOverlay()
        audioBridge?.release()
        audioBridge = null
        platformChannel = null
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            scheduleHideSystemUi()
        }
    }

    private fun scheduleHideSystemUi() {
        hideSystemUi()
        window.decorView.post { hideSystemUi() }
        window.decorView.postDelayed({ hideSystemUi() }, 250L)
        window.decorView.postDelayed({ hideSystemUi() }, 900L)
    }

    private fun installNativeSplashOverlay() {
        if (splashOverlay != null) {
            return
        }
        val overlay = NativeLoadingSplashView(this)
        splashOverlay = overlay
        addContentView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        flutterEngine?.renderer?.addIsDisplayingFlutterUiListener(flutterUiDisplayListener)
    }

    private fun removeNativeSplashOverlay() {
        flutterEngine?.renderer?.removeIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        val overlay = splashOverlay ?: return
        splashOverlay = null
        (overlay.parent as? ViewGroup)?.removeView(overlay)
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

private class NativeLoadingSplashView(context: Context) : View(context) {
    private val image: Bitmap = BitmapFactory.decodeResource(resources, R.drawable.loadingscreen)
    private val imageSource = Rect(0, 0, image.width, image.height)
    private val imageTarget = RectF()
    private val startedAt = SystemClock.uptimeMillis()
    private val imagePaint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
        isDither = false
    }
    private val paint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
    }
    private val textPaint = Paint().apply {
        isAntiAlias = false
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private var keepAnimating = false

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        keepAnimating = true
        postInvalidateOnAnimation()
    }

    override fun onDetachedFromWindow() {
        keepAnimating = false
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        drawBackground(canvas)
        if (keepAnimating) {
            postInvalidateOnAnimation()
        }
    }

    private fun drawBackground(canvas: Canvas) {
        canvas.drawColor(Color.rgb(35, 74, 42))
        val canvasRatio = width.toFloat() / height.toFloat()
        val imageRatio = image.width.toFloat() / image.height.toFloat()
        if (canvasRatio > imageRatio) {
            val targetHeight = width / imageRatio
            val top = (height - targetHeight) * 0.5f
            imageTarget.set(0f, top, width.toFloat(), top + targetHeight)
        } else {
            val targetWidth = height * imageRatio
            val left = (width - targetWidth) * 0.5f
            imageTarget.set(left, 0f, left + targetWidth, height.toFloat())
        }
        canvas.drawBitmap(image, imageSource, imageTarget, imagePaint)
        canvas.drawColor(Color.argb(84, 16, 28, 20))
        drawLoadingChrome(canvas)
    }

    private fun drawLoadingChrome(canvas: Canvas) {
        if (width <= 0 || height <= 0) {
            return
        }
        val scale = (height / 414f).coerceIn(0.82f, 2.0f)
        val centerX = width * 0.5f
        val titleY = maxOf(58f * scale, height * 0.18f)
        drawOutlinedText(
            canvas,
            "Taniin",
            centerX,
            titleY,
            72f * scale,
            Color.rgb(255, 222, 82),
            Color.rgb(30, 71, 36),
            5f * scale,
        )
        drawOutlinedText(
            canvas,
            "GAME ONCHAIN BERTANI",
            centerX,
            titleY + 38f * scale,
            20f * scale,
            Color.rgb(250, 247, 208),
            Color.rgb(23, 55, 35),
            3f * scale,
        )
        drawLoadingPanel(canvas, scale)
    }

    private fun drawLoadingPanel(canvas: Canvas, scale: Float) {
        val panelWidth = minOf(width - 48f * scale, 650f * scale)
        val panelHeight = 108f * scale
        val left = (width - panelWidth) * 0.5f
        val bottom = height - maxOf(28f * scale, height * 0.10f)
        val panel = RectF(left, bottom - panelHeight, left + panelWidth, bottom)

        paint.color = Color.argb(150, 0, 0, 0)
        canvas.drawRect(panel.left + 6f * scale, panel.top + 7f * scale, panel.right + 6f * scale, panel.bottom + 7f * scale, paint)
        paint.color = Color.rgb(24, 48, 31)
        canvas.drawRect(panel, paint)
        paint.color = Color.rgb(255, 219, 87)
        canvas.drawRect(panel.left, panel.top, panel.right, panel.top + 5f * scale, paint)
        canvas.drawRect(panel.left, panel.bottom - 5f * scale, panel.right, panel.bottom, paint)
        canvas.drawRect(panel.left, panel.top, panel.left + 5f * scale, panel.bottom, paint)
        canvas.drawRect(panel.right - 5f * scale, panel.top, panel.right, panel.bottom, paint)
        paint.color = Color.rgb(54, 109, 58)
        canvas.drawRect(panel.left + 10f * scale, panel.top + 10f * scale, panel.right - 10f * scale, panel.bottom - 10f * scale, paint)

        val progress = loadingProgress()
        drawLabelText(canvas, "LOADING FARM", panel.left + 24f * scale, panel.top + 34f * scale, 19f * scale, Paint.Align.LEFT)
        drawLabelText(canvas, "${(progress * 100).toInt()}%", panel.right - 24f * scale, panel.top + 35f * scale, 22f * scale, Paint.Align.RIGHT)

        val bar = RectF(panel.left + 24f * scale, panel.top + 55f * scale, panel.right - 24f * scale, panel.top + 80f * scale)
        paint.color = Color.rgb(15, 32, 20)
        canvas.drawRect(bar, paint)
        paint.color = Color.rgb(115, 65, 32)
        canvas.drawRect(bar.left, bar.top, bar.right, bar.top + 4f * scale, paint)
        canvas.drawRect(bar.left, bar.bottom - 4f * scale, bar.right, bar.bottom, paint)
        val fillRight = bar.left + bar.width() * progress
        paint.color = Color.rgb(255, 215, 76)
        canvas.drawRect(bar.left + 4f * scale, bar.top + 5f * scale, fillRight - 4f * scale, bar.bottom - 5f * scale, paint)
        paint.color = Color.rgb(255, 239, 132)
        canvas.drawRect(bar.left + 4f * scale, bar.top + 5f * scale, fillRight - 4f * scale, bar.top + 10f * scale, paint)
    }

    private fun loadingProgress(): Float {
        val elapsed = (SystemClock.uptimeMillis() - startedAt).coerceAtLeast(0L)
        val loop = (elapsed % 1800L) / 1800f
        return (0.12f + loop * 0.82f).coerceIn(0.12f, 0.94f)
    }

    private fun drawOutlinedText(
        canvas: Canvas,
        text: String,
        x: Float,
        y: Float,
        size: Float,
        fillColor: Int,
        strokeColor: Int,
        strokeWidth: Float,
    ) {
        textPaint.textAlign = Paint.Align.CENTER
        textPaint.textSize = size
        textPaint.style = Paint.Style.STROKE
        textPaint.strokeWidth = strokeWidth
        textPaint.color = strokeColor
        canvas.drawText(text, x, y, textPaint)
        textPaint.style = Paint.Style.FILL
        textPaint.strokeWidth = 0f
        textPaint.color = fillColor
        canvas.drawText(text, x, y, textPaint)
    }

    private fun drawLabelText(
        canvas: Canvas,
        text: String,
        x: Float,
        y: Float,
        size: Float,
        align: Paint.Align,
    ) {
        textPaint.textAlign = align
        textPaint.textSize = size
        textPaint.style = Paint.Style.FILL
        textPaint.strokeWidth = 0f
        textPaint.color = Color.rgb(255, 243, 199)
        canvas.drawText(text, x, y, textPaint)
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
