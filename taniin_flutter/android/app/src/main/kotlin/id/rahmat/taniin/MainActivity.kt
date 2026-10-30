package id.rahmat.taniin

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
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
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioBridge: AndroidAudioBridge? = null
    private var platformChannel: MethodChannel? = null
    private var splashOverlay: View? = null
    private var pendingAuthFragment = ""
    private val flutterUiDisplayListener = object : FlutterUiDisplayListener {
        // Dart hides the card via "hideSplash" once its loading screen is
        // ready; this only catches a Dart side that never asks.
        override fun onFlutterUiDisplayed() {
            window.decorView.postDelayed({ fadeOutNativeSplashOverlay() }, 8000L)
        }

        override fun onFlutterUiNoLongerDisplayed() = Unit
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        configureFullscreenWindow()
        super.onCreate(savedInstanceState)
        installNativeSplashOverlay()
        handleAuthIntent(intent)
        scheduleHideSystemUi()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthIntent(intent)
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
                "hideSplash" -> {
                    fadeOutNativeSplashOverlay()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        deliverPendingAuthFragment()
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

    private fun fadeOutNativeSplashOverlay() {
        val overlay = splashOverlay ?: return
        overlay.animate()
            .alpha(0f)
            .setDuration(280L)
            .withEndAction { removeNativeSplashOverlay() }
            .start()
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

    // The login page returns with taniin://auth#session=...; Dart validates the fragment.
    private fun handleAuthIntent(intent: Intent?) {
        val data: Uri = intent?.data ?: return
        if (data.scheme != "taniin" || data.host != "auth") {
            return
        }
        val fragment = data.encodedFragment?.trim().orEmpty()
        if (fragment.isEmpty()) {
            return
        }
        pendingAuthFragment = fragment
        deliverPendingAuthFragment()
    }

    private fun deliverPendingAuthFragment() {
        val fragment = pendingAuthFragment
        val channel = platformChannel
        if (fragment.isEmpty() || channel == null) {
            return
        }
        pendingAuthFragment = ""
        channel.invokeMethod("authCallback", fragment)
    }

    private fun chainConfig(): Map<String, String> = mapOf(
        "rpcUrl" to BuildConfig.SEPOLIA_RPC_URL,
        "coinContractAddress" to BuildConfig.TANIIN_COIN_CONTRACT_ADDRESS,
        "itemsContractAddress" to BuildConfig.TANIIN_ITEMS_CONTRACT_ADDRESS,
        "landContractAddress" to BuildConfig.TANIIN_LAND_CONTRACT_ADDRESS,
        "gameApiUrl" to BuildConfig.TANIIN_GAME_API_URL,
        "multiplayerUrl" to BuildConfig.TANIIN_MULTIPLAYER_URL,
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

/**
 * Native loading card shown while the Flutter engine starts. It mirrors the
 * Flutter loading screen (wood card, icon, Pixelify title, soil strip with
 * seeds, striped bar) and is laid out on the same design canvas as
 * PhysicalViewport, so the hand-over to Flutter is seamless. Images and the
 * font come from the Flutter assets in the APK.
 */
private class NativeLoadingSplashView(context: Context) : View(context) {
    private val background: Bitmap? = flutterAsset("assets/images/loadingscreen.jpg")
    private val icon: Bitmap? = flutterAsset("assets/images/iconaplikasi.png")
    private val crops: Bitmap? = flutterAsset("assets/images/spring_crops.png")
    private val pixelify: Typeface = runCatching {
        Typeface.createFromAsset(context.assets, assetKey("assets/fonts/PixelifySans.ttf"))
    }.getOrDefault(Typeface.DEFAULT_BOLD)
    private val startedAt = SystemClock.uptimeMillis()
    private val pixelPaint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
    }
    private val smoothPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()
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
        if (width <= 0 || height <= 0) {
            return
        }
        drawBackground(canvas)
        drawCard(canvas)
        if (keepAnimating) {
            postInvalidateOnAnimation()
        }
    }

    private fun drawBackground(canvas: Canvas) {
        canvas.drawColor(Color.rgb(0x27, 0x5D, 0x35))
        background?.let { image ->
            val scale = maxOf(width / image.width.toFloat(), height / image.height.toFloat())
            val w = image.width * scale
            val h = image.height * scale
            rect.set((width - w) / 2f, (height - h) / 2f, (width + w) / 2f, (height + h) / 2f)
            canvas.drawBitmap(image, null, rect, pixelPaint)
        }
        paint.shader = LinearGradient(
            0f, 0f, 0f, height.toFloat(),
            intArrayOf(Color.argb(0x40, 16, 28, 20), Color.argb(0x26, 16, 28, 20), Color.argb(0xC0, 16, 28, 20)),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        paint.shader = null
    }

    private fun drawCard(canvas: Canvas) {
        // Same design canvas as lib/src/ui/physical_viewport.dart.
        val density = resources.displayMetrics.density
        val logicalW = width / density
        val logicalH = height / density
        val canvasW = when {
            logicalH > logicalW * 1.1f -> 600f
            logicalH < 520f -> logicalW * 560f / logicalH
            else -> maxOf(logicalW, 1280f)
        }
        val u = width / canvasW
        val canvasH = height / u
        val short = canvasH < 600f
        val cardW = minOf(canvasW - 32f, 660f)
        val pad = 26f
        val padTop = if (short) 14f else pad
        val padBottom = if (short) 16f else pad
        val px = if (cardW - 2 * pad - 16f >= 560f && !short) 4f else 3f
        val soilH = 16f * px + 8f * px
        val kebunH = soilH + 13f * px
        val headerH = if (short) 40f * 1.1f + 4f + 24.3f else 54f * 1.1f + 4f + 24.3f
        val contentH = headerH + (if (short) 10f else 18f) + kebunH +
            (if (short) 10f else 16f) + 26f + 10f + 26.4f
        val cardH = contentH + padTop + padBottom + 16f
        val tipH = 76f
        val gap = if (short) 12f else 22f
        val left = (canvasW - cardW) / 2f
        var top = (canvasH - (cardH + gap + tipH)) / 2f

        canvas.save()
        canvas.scale(u, u)

        // Wood card: dark border, drop shadow, orange rim.
        paint.color = Color.rgb(0x4A, 0x1D, 0x08)
        rect.set(left, top + 10f, left + cardW, top + cardH + 10f)
        canvas.drawRoundRect(rect, 18f, 18f, paint)
        rect.set(left, top, left + cardW, top + cardH)
        canvas.drawRoundRect(rect, 18f, 18f, paint)
        paint.color = Color.rgb(0xE0, 0x7B, 0x20)
        rect.inset(5f, 5f)
        canvas.drawRoundRect(rect, 13f, 13f, paint)
        paint.color = Color.rgb(0xA3, 0x4A, 0x1C)
        rect.inset(3f, 3f)
        canvas.drawRoundRect(rect, 10f, 10f, paint)

        val x = left + 8f + pad
        val innerW = cardW - 16f - 2 * pad
        var y = top + 8f + padTop

        // Header: icon and title.
        val iconSize = if (short) 52f else 66f
        val iconTop = y + (headerH - iconSize - 6f) / 2f
        paint.color = Color.rgb(0x4A, 0x1D, 0x08)
        rect.set(x, iconTop, x + iconSize + 6f, iconTop + iconSize + 6f)
        canvas.drawRoundRect(rect, 14f, 14f, paint)
        icon?.let {
            rect.inset(3f, 3f)
            canvas.save()
            val clip = android.graphics.Path().apply { addRoundRect(rect, 11f, 11f, android.graphics.Path.Direction.CW) }
            canvas.clipPath(clip)
            canvas.drawBitmap(it, null, rect, smoothPaint)
            canvas.restore()
        }
        val textX = x + iconSize + 6f + 18f
        val titleSize = if (short) 40f else 54f
        textPaint.typeface = pixelify
        textPaint.isFakeBoldText = true
        textPaint.textSize = titleSize
        textPaint.textAlign = Paint.Align.LEFT
        val titleBase = y + titleSize * 0.9f
        textPaint.color = Color.rgb(0x4A, 0x1D, 0x08)
        canvas.drawText("Taniin", textX, titleBase + 4f, textPaint)
        textPaint.color = Color.rgb(0xFF, 0xDE, 0x19)
        canvas.drawText("Taniin", textX, titleBase, textPaint)
        textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textPaint.isFakeBoldText = false
        textPaint.textSize = 18f
        textPaint.color = Color.rgb(0xF3, 0xC9, 0x9A)
        canvas.drawText("Game bertani on-chain", textX, y + titleSize * 1.1f + 4f + 18f, textPaint)
        y += headerH + if (short) 10f else 18f

        // Soil strip with a seed in each of eight slots.
        val soilTop = y + kebunH - soilH
        paint.color = Color.rgb(0x4A, 0x1D, 0x08)
        rect.set(x, soilTop, x + innerW, soilTop + soilH)
        canvas.drawRoundRect(rect, 10f, 10f, paint)
        paint.color = Color.rgb(0x6B, 0x3A, 0x1E)
        rect.inset(3f, 3f)
        canvas.drawRoundRect(rect, 7f, 7f, paint)
        paint.color = Color.rgb(0x8A, 0x55, 0x30)
        canvas.drawRect(rect.left, rect.top, rect.right, rect.top + 2f * px, paint)
        paint.color = Color.rgb(0x55, 0x2C, 0x14)
        var furrow = rect.top + 6f * px
        while (furrow < rect.bottom - 2f * px) {
            canvas.drawRect(rect.left + 3f * px, furrow, rect.right - 3f * px, furrow + px, paint)
            furrow += 6f * px
        }
        crops?.let { sheet ->
            val slot = innerW / 8f
            val crop = 16f * px
            for (i in 0 until 8) {
                val sx = 0
                val sy = (i % 4) * 32 + 16
                val cx = x + slot * i + (slot - crop) / 2f
                val cy = soilTop + soilH - 5f * px - crop
                rect.set(cx, cy, cx + crop, cy + crop)
                canvas.drawBitmap(sheet, Rect(sx, sy, sx + 16, sy + 16), rect, pixelPaint)
            }
        }
        y += kebunH + if (short) 10f else 16f

        // Striped bar running back and forth while the engine starts.
        paint.color = Color.rgb(0x25, 0x14, 0x0A)
        rect.set(x, y, x + innerW, y + 26f)
        canvas.drawRoundRect(rect, 6f, 6f, paint)
        paint.color = Color.rgb(0x4A, 0x1D, 0x08)
        rect.inset(3f, 3f)
        canvas.drawRoundRect(rect, 3f, 3f, paint)
        val elapsed = SystemClock.uptimeMillis() - startedAt
        val track = rect.width()
        val block = track * 0.35f
        val travel = ((elapsed % 1200L) / 1200f) * (track + block) - block
        canvas.save()
        canvas.clipRect(rect)
        val fillLeft = rect.left + travel
        paint.color = Color.rgb(0x2F, 0x7D, 0x45)
        canvas.drawRect(fillLeft, rect.top, fillLeft + block, rect.bottom, paint)
        paint.color = Color.rgb(0x86, 0xE2, 0x76)
        var stripe = fillLeft
        while (stripe < fillLeft + block) {
            canvas.drawRect(stripe, rect.top, minOf(stripe + 10f, fillLeft + block), rect.bottom, paint)
            stripe += 14f
        }
        paint.color = Color.argb(0x55, 255, 255, 255)
        canvas.drawRect(fillLeft, rect.top, fillLeft + block, rect.top + 4f, paint)
        canvas.restore()
        y += 26f + 10f

        textPaint.textSize = 17f
        textPaint.color = Color.rgb(0xFF, 0xF0, 0xD4)
        canvas.drawText("Memuat game…", x, y + 19f, textPaint)

        // Tip strip under the card.
        top += cardH + gap
        paint.color = Color.rgb(0x7A, 0x2D, 0x0E)
        rect.set(left, top, left + cardW, top + tipH)
        canvas.drawRoundRect(rect, 12f, 12f, paint)
        paint.color = Color.argb(0xF2, 0x1A, 0x0E, 0x05)
        rect.inset(3f, 3f)
        canvas.drawRoundRect(rect, 9f, 9f, paint)
        textPaint.typeface = pixelify
        textPaint.isFakeBoldText = true
        textPaint.textSize = 18f
        textPaint.color = Color.rgb(0xFF, 0xDE, 0x19)
        canvas.drawText("TIPS", left + 21f, top + tipH / 2f + 6f, textPaint)
        textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textPaint.isFakeBoldText = false
        textPaint.textSize = 16f
        textPaint.color = Color.rgb(0xFF, 0xF0, 0xD4)
        canvas.drawText("Kebunmu sedang disiapkan…", left + 21f + 60f, top + tipH / 2f + 6f, textPaint)

        canvas.restore()
    }

    private fun assetKey(path: String): String =
        FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)

    private fun flutterAsset(path: String): Bitmap? = runCatching {
        context.assets.open(assetKey(path)).use { BitmapFactory.decodeStream(it) }
    }.getOrNull()
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
