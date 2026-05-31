package id.rahmat.taniin;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.net.Uri;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.InputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

final class FarmGameView extends CanvasGameView {
    private static final int TILE = 128;
    private static final int WORLD_COLS = 72;
    private static final int WORLD_ROWS = 52;
    private static final float PLAYER_SPEED = TILE * 3.9f;
    private static final long GROW_TIME_MS = 12_000L;
    private static final int CROP_READY_STAGE_COLUMN = 5;
    private static final int CROP_FIRST_VISIBLE_STAGE_COLUMN = 2;
    private static final int DIR_RIGHT = 0;
    private static final int DIR_UP = 1;
    private static final int DIR_DOWN = 2;
    private static final int DIR_LEFT = 3;
    private static final long WALK_FRAME_MS = 48L;
    private static final long WALK_SOUND_GRACE_MS = 80L;
    private static final float HORIZONTAL_FACING_BIAS = 0.70f;
    private static final float JOYSTICK_RADIUS = 82f;
    private static final float JOYSTICK_KNOB_RADIUS = 34f;
    private static final float JOYSTICK_TRAVEL = 76f;
    private static final float SHOP_LEFT_TILE = 13.8f;
    private static final float SHOP_RIGHT_TILE = 26.4f;
    private static final float SHOP_TOP_TILE = 16.6f;
    private static final float SHOP_BOTTOM_TILE = 31.2f;
    private static final float SHOP_SIGN_X_TILE = 18.5f;
    private static final float SHOP_SIGN_Y_TILE = 22.35f;
    private static final float SHOP_NPC_X_TILE = 19.18f;
    private static final float SHOP_NPC_Y_TILE = 25.88f;
    private static final float SHOP_NPC_SIZE = TILE * 1.16f;
    private static final float SHOP_NPC_FOOT_ANCHOR = 25f / 32f;
    private static final float SELL_HOUSE_LEFT_TILE = 27.0f;
    private static final float SELL_HOUSE_RIGHT_TILE = 35.4f;
    private static final float SELL_HOUSE_TOP_TILE = 8.7f;
    private static final float SELL_HOUSE_BOTTOM_TILE = 17.1f;
    private static final float SELL_SIGN_X_TILE = 31.0f;
    private static final float SELL_SIGN_Y_TILE = 13.35f;
    private static final float SWAP_HOUSE_LEFT_TILE = 8.2f;
    private static final float SWAP_HOUSE_RIGHT_TILE = 14.0f;
    private static final float SWAP_HOUSE_TOP_TILE = 8.4f;
    private static final float SWAP_HOUSE_BOTTOM_TILE = 16.5f;
    private static final float SWAP_SIGN_X_TILE = 10.85f;
    private static final float SWAP_SIGN_Y_TILE = 13.15f;
    private static final int LAND_BUY_PRICE = 250;
    private static final int LAND_SELL_PRICE = 175;
    private static final int HARVEST_SELL_PRICE = 35;
    private static final int COIN_SWAP_RATE = 1;
    private static final int SWAP_TARGET_TANI = 0;
    private static final int SWAP_TARGET_ETH = 1;
    static final int SWAP_ASSET_COIN = 0;
    private static final int SWAP_ASSET_TANI = 1;
    static final int SWAP_ASSET_ETH = 2;
    private static final String DEFAULT_ETH_WEI_PER_COIN = "10000000000";
    private static final BigDecimal WEI_PER_ETH = new BigDecimal("1000000000000000000");
    private static final int SEED_BUNDLE_AMOUNT = 3;
    private static final int MAX_SHOP_BUNDLE_QUANTITY = 9;
    private static final long HARVEST_EFFECT_MS = 1450L;
    private static final long SHOP_NPC_BUBBLE_MS = 4200L;
    private static final String[] SEED_NAMES = {"Kentang", "Bawang", "Stroberi", "Bit"};
    private static final String[] SEED_SHOP_NAMES = {"Potato Seed", "Leek Seed", "Strawberry Seed", "Beetroot Seed"};
    private static final int[] SEED_PRICES = {60, 75, 110, 90};
    private static final int[] SEED_HARVEST_YIELDS = {3, 4, 5, 4};
    private static final int[] SEED_CROP_ROWS = {5, 3, 1, 7};
    private static final int[] SEED_CARD_COLORS = {
            Color.rgb(169, 75, 31),
            Color.rgb(74, 113, 159),
            Color.rgb(170, 60, 36),
            Color.rgb(169, 77, 27)
    };
    private static final int[] SEED_ICON_COLORS = {
            Color.rgb(174, 97, 222),
            Color.rgb(122, 205, 126),
            Color.rgb(236, 70, 103),
            Color.rgb(247, 156, 88)
    };
    private static final int MENU_TAB_SETTINGS = 0;
    private static final int MENU_TAB_ABOUT = 1;
    private static final int CHAIN_HISTORY_LIMIT = 8;
    private static final float OVERLAY_CLOSE_SIZE = 64f;
    private static final float OVERLAY_CLOSE_RIGHT_MARGIN = 34f;
    private static final float DEFAULT_MASTER_VOLUME = 0.82f;
    private static final float DEFAULT_MUSIC_VOLUME = 0.70f;
    private static final float DEFAULT_SFX_VOLUME = 0.90f;
    private static final String PREF_CHAIN_HISTORY = "game_chain_history";
    private static final String PREF_COIN_AUTOFILL_MIGRATION = "game_coin_wallet_autofill_migrated";
    private static final String PREF_WALLET_ADDRESS = "wallet_address";
    private static final String PREF_DEFAULT_WALLET_DISABLED = "wallet_default_disabled";

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Rect src = new Rect();
    private final RectF dst = new RectF();
    private final RectF miniMapInnerBounds = new RectF();
    private final GameState gameState = new GameState();
    private final FarmingSystem farmingSystem = new FarmingSystem(
            LAND_BUY_PRICE,
            LAND_SELL_PRICE,
            GROW_TIME_MS,
            SEED_HARVEST_YIELDS,
            SEED_NAMES);
    private final ShopSystem shopSystem = new ShopSystem(SEED_BUNDLE_AMOUNT, SEED_PRICES, SEED_NAMES);
    private final List<RectF> collisionRects = new ArrayList<>();
    private final List<ChainAction> pendingChainActions = new ArrayList<>();
    private final List<ChainHistoryEntry> chainHistory = new ArrayList<>();
    private final List<HarvestEffect> harvestEffects = new ArrayList<>();
    private final BlockchainClient blockchainClient = new BlockchainClient();
    private final BigDecimal ethWeiPerCoin = resolveEthWeiPerCoin();
    private final GameAudio gameAudio;
    private final SharedPreferences preferences;
    private final GameStateStore gameStateStore;
    private final ChainHistoryStore chainHistoryStore;
    private final WorldRenderer worldRenderer = new WorldRenderer(TILE, WORLD_COLS, WORLD_ROWS, paint, pixelPaint, src, dst);
    private final HudRenderer hudRenderer = new HudRenderer(paint);
    private final ChainHistoryRenderer chainHistoryRenderer = new ChainHistoryRenderer(paint, CHAIN_HISTORY_LIMIT);
    private final WalletDialogController walletDialogController = new WalletDialogController(this);
    private final SwapAmountDialogController swapAmountDialogController = new SwapAmountDialogController(this);
    private MapDecorationRenderer mapDecorationRenderer;
    private TmxMap tmxMap;
    private Bitmap miniMapBitmap;
    private int miniMapBitmapWidth;
    private int miniMapBitmapHeight;

    private final Bitmap idleSheet;
    private final Bitmap walkSheet;
    private final Bitmap cropSheet;
    private final Bitmap chest;
    private final Bitmap chicken;
    private final Bitmap babyChicken;
    private final Bitmap cow;
    private final Bitmap maleCow;
    private final Bitmap chickenRed;
    private final Bitmap shopNpcSheet;
    private final Bitmap outdoorDecorSheet;
    private final Bitmap appIcon;

    private float playerX = 18.5f * TILE;
    private float playerY = 28.5f * TILE;
    private float cameraX;
    private float cameraY;
    private float joyBaseX;
    private float joyBaseY;
    private float joyX;
    private float joyY;
    private boolean joystickActive;
    private int joystickPointerId = -1;
    private long messageUntilMs;
    private long statusPopupUntilMs;
    private long shopUntilMs;
    private long chainPanelUntilMs;
    private long shopNpcBubbleUntilMs;
    private String message = "Dekati lahan atau toko, lalu tekan tombol aksi.";
    private String statusPopupTitle = "";
    private String statusPopupMessage = "";
    private String walletAddress = "";
    private String chainSignerAddress = "";
    private String chainStatus = "Mode lokal. Sepolia belum dicek.";
    private String walletNativeBalance = "";
    private int walletTaniBalance;
    private boolean walletTaniBalanceAvailable;
    private boolean checkingChain;
    private String mapStatus = "";

    private int selectedPlot = -1;
    private int activeInteractionPlot = -1;
    private boolean moving;
    private boolean menuOpen;
    private boolean backpackOpen;
    private boolean interactionDialogOpen;
    private boolean shopCatalogOpen;
    private boolean shopPurchaseConfirmOpen;
    private boolean chainHistoryOpen;
    private boolean swapAssetMenuOpen;
    private boolean swapAssetMenuFrom;
    private boolean audioBgmEnabled = true;
    private boolean audioSfxEnabled = true;
    private float masterVolume = DEFAULT_MASTER_VOLUME;
    private float musicVolume = DEFAULT_MUSIC_VOLUME;
    private float sfxVolume = DEFAULT_SFX_VOLUME;
    private int menuTab = MENU_TAB_SETTINGS;
    private InteractionKind activeInteractionKind = InteractionKind.NONE;
    private int shopPurchaseSeedIndex = -1;
    private int audioTrackIndex;
    private int activeAudioSlider = -1;
    private int activeAudioSliderPointerId = -1;
    private int facingDirection = DIR_DOWN;
    private int walkFrame;
    private long walkTickMs;
    private long lastPlayerMoveMs;
    private long swapSwitchAnimStartMs;
    private int worldWidthPixels = WORLD_COLS * TILE;
    private int worldHeightPixels = WORLD_ROWS * TILE;

    FarmGameView(Context context) {
        super(context);
        setFocusable(true);
        setFocusableInTouchMode(true);
        requestFocus();
        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        gameAudio = new GameAudio(context);
        preferences = context.getSharedPreferences("taniin_chain", Context.MODE_PRIVATE);
        gameStateStore = new GameStateStore(preferences, SEED_NAMES.length, MAX_SHOP_BUNDLE_QUANTITY, GROW_TIME_MS);
        chainHistoryStore = new ChainHistoryStore(preferences, PREF_CHAIN_HISTORY, CHAIN_HISTORY_LIMIT);
        walletAddress = resolveInitialWalletAddress();
        loadAudioSettings();
        idleSheet = decodePixelResource(R.drawable.idle);
        walkSheet = decodePixelResource(R.drawable.walk);
        Bitmap defaultCropSheet = decodePixelResource(R.drawable.spring_crops);
        cropSheet = decodePixelAsset(context, "game/Tileset/Spring Crops.png", defaultCropSheet);
        chest = decodePixelResource(R.drawable.chest);
        chicken = decodePixelResource(R.drawable.chicken_blonde_green);
        babyChicken = decodePixelResource(R.drawable.baby_chicken_yellow);
        cow = decodePixelResource(R.drawable.female_cow_brown);
        maleCow = decodePixelResource(R.drawable.male_cow_brown);
        chickenRed = decodePixelResource(R.drawable.chicken_red);
        appIcon = decodePixelResource(R.drawable.iconaplikasi);
        shopNpcSheet = decodePixelAsset(context, "game/Tileset/Cute_Fantasy_Free/Player/Player.png", idleSheet);
        outdoorDecorSheet = decodePixelAsset(context, "game/Tileset/Cute_Fantasy_Free/Outdoor decoration/Outdoor_Decor_Free.png", null);
        mapDecorationRenderer = new MapDecorationRenderer(TILE, worldRenderer, chicken, babyChicken, cow, maleCow, chickenRed);
        loadTmxMap(context);
        createWorld();
        loadGameState();
        chainHistoryStore.load(chainHistory);
        if (!walletAddress.isEmpty()) {
            refreshWalletState(false);
        }
    }

    private String resolveInitialWalletAddress() {
        String defaultWalletAddress = blockchainClient.defaultWalletAddress();
        String savedWalletAddress = preferences.getString(PREF_WALLET_ADDRESS, "");
        if (isValidAddress(savedWalletAddress)) {
            chainStatus = "Wallet pemain tersimpan: " + shortAddress(savedWalletAddress);
            return savedWalletAddress;
        }
        if (savedWalletAddress != null && !savedWalletAddress.trim().isEmpty()) {
            preferences.edit().remove(PREF_WALLET_ADDRESS).apply();
        }
        if (!preferences.getBoolean(PREF_DEFAULT_WALLET_DISABLED, false) && isValidAddress(defaultWalletAddress)) {
            chainStatus = "Wallet default dari .env: " + shortAddress(defaultWalletAddress)
                    + ". Tap panel wallet untuk ganti wallet pemain.";
            return defaultWalletAddress;
        }
        return "";
    }

    void resumeAudio() {
        gameAudio.resumeBgm();
    }

    void pauseAudio() {
        stopWalkSound();
        gameAudio.pauseBgm();
    }

    void releaseAudio() {
        gameAudio.release();
    }

    private void loadAudioSettings() {
        audioBgmEnabled = preferences.getBoolean("audio_bgm_enabled", true);
        audioSfxEnabled = preferences.getBoolean("audio_sfx_enabled", true);
        masterVolume = clamp(preferences.getFloat("audio_master_volume", DEFAULT_MASTER_VOLUME), 0f, 1f);
        musicVolume = clamp(preferences.getFloat("audio_music_volume", DEFAULT_MUSIC_VOLUME), 0f, 1f);
        sfxVolume = clamp(preferences.getFloat("audio_sfx_volume", DEFAULT_SFX_VOLUME), 0f, 1f);
        audioTrackIndex = clampInt(preferences.getInt("audio_track_index", 0), 0, Math.max(0, gameAudio.getBgmCount() - 1));
        gameAudio.setBgmIndex(audioTrackIndex);
        applyAudioSettings();
    }

    private void saveAudioSettings() {
        preferences.edit()
                .putBoolean("audio_bgm_enabled", audioBgmEnabled)
                .putBoolean("audio_sfx_enabled", audioSfxEnabled)
                .putFloat("audio_master_volume", masterVolume)
                .putFloat("audio_music_volume", musicVolume)
                .putFloat("audio_sfx_volume", sfxVolume)
                .putInt("audio_track_index", audioTrackIndex)
                .apply();
    }

    private void applyAudioSettings() {
        gameAudio.setVolumes(masterVolume, musicVolume, sfxVolume);
        gameAudio.setBgmEnabled(audioBgmEnabled);
        gameAudio.setSfxEnabled(audioSfxEnabled);
    }

    private Bitmap decodePixelResource(int resId) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inScaled = false;
        return BitmapFactory.decodeResource(getResources(), resId, options);
    }

    private Bitmap decodePixelAsset(Context context, String assetPath, Bitmap fallback) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inScaled = false;
        try (InputStream inputStream = context.getAssets().open(assetPath)) {
            Bitmap bitmap = BitmapFactory.decodeStream(inputStream, null, options);
            return bitmap == null ? fallback : bitmap;
        } catch (Exception exception) {
            return fallback;
        }
    }

    private void loadTmxMap(Context context) {
        try {
            tmxMap = TmxMap.load(context, "game/map.tmx");
            worldWidthPixels = tmxMap.getWorldWidthPixels(TILE);
            worldHeightPixels = tmxMap.getWorldHeightPixels(TILE);
            collisionRects.clear();
            tmxMap.appendCollisionRects(collisionRects, TILE);
            mapStatus = "TMX map loaded: " + collisionRects.size() + " colliders";
        } catch (Exception exception) {
            tmxMap = null;
            collisionRects.clear();
            createFallbackCollisionRects();
            mapStatus = "TMX gagal: " + exception.getMessage();
        }
    }

    private void createWorld() {
        int farmY = 19;
        int[] farmColumns = {4, 6, 8, 10, 12};
        for (int i = 0; i < farmColumns.length; i++) {
            Plot plot = new Plot(farmColumns[i] * TILE, farmY * TILE, 2 * TILE, 4 * TILE);
            plot.owned = i == 0;
            gameState.plots.add(plot);
        }
    }

    private void createFallbackCollisionRects() {
        worldRenderer.appendFallbackCollisionRects(collisionRects);
    }

    @Override
    protected void updateFrame(float dt, long now) {
        update(dt, now);
    }

    @Override
    protected void renderFrame(Canvas canvas, long now) {
        drawGame(canvas, now);
    }

    private void update(float dt, long now) {
        float dx = joyX - joyBaseX;
        float dy = joyY - joyBaseY;
        float distance = (float) Math.hypot(dx, dy);
        moving = joystickActive && distance > 8f;
        boolean playerMoved = false;
        if (moving) {
            float nx = dx / Math.max(distance, 1f);
            float ny = dy / Math.max(distance, 1f);
            updateFacingDirection(nx, ny);
            playerMoved = movePlayer(
                    playerX + nx * PLAYER_SPEED * dt,
                    playerY + ny * PLAYER_SPEED * dt);
            if (playerMoved) {
                startWalkSound(now);
            }
            if (now - walkTickMs > WALK_FRAME_MS) {
                walkFrame = (walkFrame + 1) % 6;
                walkTickMs = now;
            }
        }
        if (!playerMoved && now - lastPlayerMoveMs > WALK_SOUND_GRACE_MS) {
            stopWalkSound();
        }

        selectedPlot = findNearbyPlot();
        for (Plot plot : gameState.plots) {
            if (plot.state == PlotState.GROWING && now - plot.plantedAtMs >= GROW_TIME_MS) {
                plot.state = PlotState.READY;
            }
        }
        for (int i = harvestEffects.size() - 1; i >= 0; i--) {
            if (now - harvestEffects.get(i).startedAtMs > HARVEST_EFFECT_MS) {
                harvestEffects.remove(i);
            }
        }
    }

    private void updateFacingDirection(float nx, float ny) {
        float absX = Math.abs(nx);
        float absY = Math.abs(ny);
        if (absX >= 0.30f && absX >= absY * HORIZONTAL_FACING_BIAS) {
            facingDirection = nx < 0f ? DIR_LEFT : DIR_RIGHT;
        } else if (absY >= 0.30f) {
            facingDirection = ny < 0f ? DIR_UP : DIR_DOWN;
        }
    }

    private boolean movePlayer(float targetX, float targetY) {
        float oldX = playerX;
        float oldY = playerY;
        float nextX = clamp(targetX, 1.2f * TILE, worldWidthPixels - 1.2f * TILE);
        float nextY = clamp(targetY, 1.2f * TILE, worldHeightPixels - 1.2f * TILE);
        if (!collidesAt(nextX, playerY)) {
            playerX = nextX;
        }
        if (!collidesAt(playerX, nextY)) {
            playerY = nextY;
        }
        return Math.abs(playerX - oldX) > 0.5f || Math.abs(playerY - oldY) > 0.5f;
    }

    private boolean collidesAt(float x, float y) {
        RectF hitbox = playerHitbox(x, y);
        for (RectF obstacle : collisionRects) {
            if (RectF.intersects(hitbox, obstacle)) {
                return true;
            }
        }
        return false;
    }

    private RectF playerHitbox(float x, float y) {
        float halfW = TILE * 0.22f;
        float top = y - TILE * 0.18f;
        float bottom = y + TILE * 0.16f;
        return new RectF(x - halfW, top, x + halfW, bottom);
    }

    private void drawGame(Canvas canvas, long now) {
        int width = getWidth();
        int height = getHeight();
        cameraX = Math.round(clamp(playerX - width * 0.5f, 0, Math.max(0, worldWidthPixels - width)));
        cameraY = Math.round(clamp(playerY - height * 0.56f, 0, Math.max(0, worldHeightPixels - height)));
        worldRenderer.setCamera(cameraX, cameraY);

        drawWorld(canvas);
        drawMapDecorations(canvas, false, now);
        drawPlots(canvas, now);
        drawHarvestEffects(canvas, now);
        if (tmxMap == null) {
            drawDecorations(canvas);
        }
        drawPlayer(canvas, now);
        if (tmxMap != null) {
            tmxMap.drawForeground(canvas, cameraX, cameraY, TILE);
        }
        drawMapDecorations(canvas, true, now);
        drawPlotActionSigns(canvas, now);
        drawHud(canvas, now);
    }

    private void drawWorld(Canvas canvas) {
        if (tmxMap != null) {
            canvas.drawColor(Color.rgb(113, 181, 82));
            tmxMap.drawBackground(canvas, cameraX, cameraY, TILE);
            return;
        }

        worldRenderer.drawFallbackWorld(canvas, getWidth(), getHeight());
    }

    private void drawPlots(Canvas canvas, long now) {
        for (int i = 0; i < gameState.plots.size(); i++) {
            Plot plot = gameState.plots.get(i);
            boolean selected = i == selectedPlot;
            if (tmxMap == null) {
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(plot.owned ? Color.rgb(232, 148, 69) : Color.rgb(88, 64, 40));
                drawWorldRoundRect(canvas, plot.x, plot.y, plot.w, plot.h, 8);
            }

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(selected ? 5f : 2f);
            paint.setColor(selected ? Color.rgb(255, 230, 82) : Color.argb(tmxMap == null ? 255 : 75, 31, 111, 62));
            drawWorldRoundRect(canvas, plot.x, plot.y, plot.w, plot.h, 8);

            paint.setStrokeWidth(1f);
            paint.setColor(Color.argb(70, 95, 67, 34));
            if (tmxMap == null) {
                for (int gx = 1; gx < 3; gx++) {
                    drawWorldLine(canvas, plot.x + gx * TILE, plot.y, plot.x + gx * TILE, plot.y + plot.h);
                }
                for (int gy = 1; gy < 7; gy++) {
                    drawWorldLine(canvas, plot.x, plot.y + gy * TILE, plot.x + plot.w, plot.y + gy * TILE);
                }
            }

            if (plot.state != PlotState.EMPTY) {
                drawCrops(canvas, plot, now);
            }

            if (!plot.owned) {
                drawLock(canvas, plot);
            }
        }
    }

    private void drawCrops(Canvas canvas, Plot plot, long now) {
        int cell = 16;
        int cropRow = SEED_CROP_ROWS[plot.seedIndex];
        int cols = Math.max(1, Math.round(plot.w / TILE));
        int rows = Math.max(1, Math.round(plot.h / TILE));
        float cropSize = TILE * 0.74f;
        float progress = cropGrowthProgress(plot, now);
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                float delay = ((row * cols + col) % 5) * 0.035f;
                float localProgress = plot.state == PlotState.READY
                        ? 1f
                        : clamp((progress - delay) / Math.max(0.01f, 1f - delay), 0f, 1f);
                float centerX = plot.x + col * TILE + TILE * 0.5f - cameraX;
                float baseY = plot.y + row * TILE + TILE * 0.92f - cameraY;
                drawGrowingCropSprite(canvas, cropRow, localProgress, centerX, baseY, cropSize, now, row, col);
            }
        }
    }

    private float cropGrowthProgress(Plot plot, long now) {
        if (plot.state == PlotState.READY) {
            return 1f;
        }
        long elapsed = Math.max(0L, now - plot.plantedAtMs);
        return clamp(elapsed / (float) GROW_TIME_MS, 0f, 1f);
    }

    private void drawGrowingCropSprite(Canvas canvas, int cropRow, float progress, float centerX,
            float baseY, float baseSize, long now, int row, int col) {
        float eased = smoothStep(progress);
        float stageFloat = CROP_FIRST_VISIBLE_STAGE_COLUMN
                + eased * (CROP_READY_STAGE_COLUMN - CROP_FIRST_VISIBLE_STAGE_COLUMN);
        int stage = Math.min(CROP_READY_STAGE_COLUMN, (int) stageFloat);
        int nextStage = Math.min(CROP_READY_STAGE_COLUMN, stage + 1);
        float blend = clamp(stageFloat - stage, 0f, 1f);
        float pulse = progress >= 1f ? 0f : (float) Math.sin(now / 360.0 + row * 0.9 + col * 1.3) * 0.025f;
        float scale = 0.72f + 0.28f * eased + pulse;
        float sway = progress >= 1f ? 0f : (float) Math.sin(now / 420.0 + row * 0.9 + col * 1.3) * TILE * 0.018f * (0.35f + progress * 0.65f);
        float size = baseSize * scale;

        drawCropGroundShadow(canvas, centerX + sway, baseY, size);
        drawCropFrame(canvas, cropRow, stage, centerX + sway, baseY, size, (int) (255f * (1f - blend * 0.55f)));
        if (nextStage != stage && blend > 0.03f) {
            float nextSize = baseSize * (scale + 0.08f * smoothStep(blend));
            drawCropFrame(canvas, cropRow, nextStage, centerX + sway, baseY, nextSize, (int) (255f * smoothStep(blend)));
        }
    }

    private void drawCropGroundShadow(Canvas canvas, float centerX, float baseY, float size) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(38, 74, 44, 20));
        canvas.drawOval(
                centerX - size * 0.36f,
                baseY - size * 0.16f,
                centerX + size * 0.36f,
                baseY - size * 0.03f,
                paint);
    }

    private void drawCropFrame(Canvas canvas, int cropRow, int stage, float centerX, float baseY, float size, int alpha) {
        int cell = 16;
        src.set(stage * cell, cropRow * cell, stage * cell + cell, cropRow * cell + cell);
        dst.set(centerX - size * 0.5f, baseY - size, centerX + size * 0.5f, baseY);
        pixelPaint.setAlpha(clampInt(alpha, 0, 255));
        canvas.drawBitmap(cropSheet, src, dst, pixelPaint);
        pixelPaint.setAlpha(255);
    }

    private void drawHarvestEffects(Canvas canvas, long now) {
        for (HarvestEffect effect : harvestEffects) {
            float progress = clamp((now - effect.startedAtMs) / (float) HARVEST_EFFECT_MS, 0f, 1f);
            int alpha = (int) (255f * (1f - progress));
            float lift = TILE * 0.82f * progress;
            int cell = 16;
            int cropRow = SEED_CROP_ROWS[effect.seedIndex];
            src.set(CROP_READY_STAGE_COLUMN * cell, cropRow * cell,
                    CROP_READY_STAGE_COLUMN * cell + cell, cropRow * cell + cell);

            for (int i = 0; i < 8; i++) {
                float angle = (float) (i * Math.PI * 0.25f + effect.phase);
                float radius = TILE * (0.16f + progress * 0.42f);
                float x = effect.centerX + (float) Math.cos(angle) * radius - cameraX;
                float y = effect.centerY + (float) Math.sin(angle) * radius * 0.45f - lift - cameraY;

                paint.setStyle(Paint.Style.FILL);
                paint.setColor(Color.argb(alpha, 255, 223, 77));
                canvas.drawCircle(x, y, 8f + 7f * (1f - progress), paint);
            }

            pixelPaint.setAlpha(alpha);
            for (int i = 0; i < 5; i++) {
                float x = effect.centerX - TILE * 0.58f + i * TILE * 0.29f - cameraX;
                float y = effect.centerY - TILE * 0.12f - lift - (i % 2) * TILE * 0.16f - cameraY;
                float size = TILE * (0.34f - progress * 0.07f);
                dst.set(x, y, x + size, y + size);
                canvas.drawBitmap(cropSheet, src, dst, pixelPaint);
            }
            pixelPaint.setAlpha(255);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(alpha, 255, 247, 204));
            paint.setTextSize(28f + progress * 10f);
            paint.setFakeBoldText(true);
            drawCenteredText(canvas, "+" + effect.amount, effect.centerX - cameraX, effect.centerY - TILE * 0.75f - lift - cameraY);
            paint.setFakeBoldText(false);
        }
    }

    private void drawLock(Canvas canvas, Plot plot) {
        float cx = plot.x + plot.w / 2f - cameraX;
        float cy = plot.y + plot.h / 2f - cameraY;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(84, 0, 0, 0));
        canvas.drawOval(cx - 26f, cy + 15f, cx + 26f, cy + 26f, paint);
        paint.setColor(Color.rgb(118, 71, 26));
        canvas.drawRoundRect(cx - 25f, cy - 22f, cx + 25f, cy + 22f, 7f, 7f, paint);
        paint.setColor(Color.rgb(77, 45, 16));
        canvas.drawRoundRect(cx - 20f, cy - 17f, cx + 20f, cy + 17f, 5f, 5f, paint);
        paint.setColor(Color.rgb(255, 214, 74));
        canvas.drawRoundRect(cx - 13f, cy - 2f, cx + 13f, cy + 14f, 3f, 3f, paint);
        paint.setColor(Color.rgb(255, 230, 112));
        canvas.drawRect(cx - 9f, cy - 1f, cx + 9f, cy + 3f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(255, 214, 74));
        canvas.drawArc(cx - 12f, cy - 16f, cx + 12f, cy + 8f, 180f, -180f, false, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawDecorations(Canvas canvas) {
        worldRenderer.drawFallbackDecorations(canvas, chest, chicken, cow);
    }

    private void drawMapDecorations(Canvas canvas, boolean foreground, long now) {
        if (tmxMap == null) {
            return;
        }
        if (foreground) {
            drawShopHouseSign(canvas);
            drawSellHouseSign(canvas);
            drawSwapHouseSign(canvas);
            return;
        }
        mapDecorationRenderer.drawBackgroundDecorations(canvas, now);
    }

    private void drawShopHouseSign(Canvas canvas) {
        RectF sign = shopSignBounds();
        if (isOffscreen(sign)) {
            return;
        }

        drawWoodSignBoard(canvas, sign, "SHOP", 36f, true);
    }

    private void drawSellHouseSign(Canvas canvas) {
        RectF sign = sellSignBounds();
        if (isOffscreen(sign)) {
            return;
        }

        drawSignPosts(canvas, sign, 22f);
        drawWoodSignBoard(canvas, sign, "JUAL PANEN", 28f, true);
        drawSellSignBadge(canvas, sign);
    }

    private void drawSwapHouseSign(Canvas canvas) {
        RectF sign = swapSignBounds();
        if (isOffscreen(sign)) {
            return;
        }

        drawSignPosts(canvas, sign, 22f);
        drawWoodSignBoard(canvas, sign, "SWAP TANI", 31f, true);
        drawSwapSignBadge(canvas, sign);
    }

    private void drawSellSignBadge(Canvas canvas, RectF sign) {
        float cx = sign.right - 8f;
        float cy = sign.top - 6f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(115, 0, 0, 0));
        canvas.drawCircle(cx + 3f, cy + 4f, 21f, paint);
        paint.setColor(Color.rgb(255, 216, 76));
        canvas.drawCircle(cx, cy, 20f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(115, 69, 20));
        canvas.drawCircle(cx, cy, 13f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(115, 69, 20));
        paint.setTextSize(21f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, "$", cx, cy + 7f);
        paint.setFakeBoldText(false);
    }

    private void drawSwapSignBadge(Canvas canvas, RectF sign) {
        float cx = sign.right - 8f;
        float cy = sign.top - 6f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(115, 0, 0, 0));
        canvas.drawCircle(cx + 3f, cy + 4f, 21f, paint);
        paint.setColor(Color.rgb(78, 222, 119));
        canvas.drawCircle(cx, cy, 20f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.rgb(23, 70, 41));
        RectF arc = new RectF(cx - 11f, cy - 11f, cx + 11f, cy + 11f);
        canvas.drawArc(arc, -205f, 145f, false, paint);
        canvas.drawArc(arc, -25f, 145f, false, paint);
        canvas.drawLine(cx - 12f, cy + 3f, cx - 12f, cy + 11f, paint);
        canvas.drawLine(cx - 12f, cy + 3f, cx - 4f, cy + 3f, paint);
        canvas.drawLine(cx + 12f, cy - 3f, cx + 12f, cy - 11f, paint);
        canvas.drawLine(cx + 12f, cy - 3f, cx + 4f, cy - 3f, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawShopNpc(Canvas canvas, long now) {
        RectF body = shopNpcBodyBounds();
        if (isOffscreen(body)) {
            return;
        }

        float footWorldX = SHOP_NPC_X_TILE * TILE;
        float footWorldY = SHOP_NPC_Y_TILE * TILE;
        float footX = footWorldX - cameraX;
        float footY = footWorldY - cameraY;
        float sway = (float) Math.sin(now / 620.0) * 1.2f;
        float worldX = footWorldX - SHOP_NPC_SIZE * 0.5f + sway;
        float worldY = footWorldY - SHOP_NPC_SIZE * SHOP_NPC_FOOT_ANCHOR;
        int frame = (int) ((now / 340L) % 6L);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(82, 0, 0, 0));
        canvas.drawOval(
                footX - SHOP_NPC_SIZE * 0.18f,
                footY - SHOP_NPC_SIZE * 0.045f,
                footX + SHOP_NPC_SIZE * 0.18f,
                footY + SHOP_NPC_SIZE * 0.055f,
                paint);
        drawSpriteWorld(canvas, shopNpcSheet, frame, 32, 32, 6, worldX, worldY, SHOP_NPC_SIZE, SHOP_NPC_SIZE);

        if (shopNpcBubbleUntilMs <= now && isNearShop()) {
            drawNpcHintIcon(canvas, footX, footY - SHOP_NPC_SIZE * 0.82f, now);
        }
    }

    private void drawNpcHintIcon(Canvas canvas, float x, float y, long now) {
        float bob = (float) Math.sin(now / 180.0) * 3f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 223, 82));
        canvas.drawCircle(x, y + bob, 18f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(91, 52, 16));
        canvas.drawCircle(x, y + bob, 18f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(91, 52, 16));
        paint.setTextSize(26f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, "!", x, y + bob + 9f);
        paint.setFakeBoldText(false);
    }

    private void drawShopNpcBubble(Canvas canvas, long now) {
        if (shopNpcBubbleUntilMs <= now) {
            return;
        }

        float npcX = SHOP_NPC_X_TILE * TILE - cameraX;
        float npcY = SHOP_NPC_Y_TILE * TILE - cameraY - SHOP_NPC_SIZE * 0.82f;
        RectF bubble = new RectF(npcX - 205f, npcY - 128f, npcX + 205f, npcY - 28f);
        float shift = 0f;
        if (bubble.left < 18f) {
            shift = 18f - bubble.left;
        } else if (bubble.right > getWidth() - 18f) {
            shift = getWidth() - 18f - bubble.right;
        }
        bubble.offset(shift, 0f);
        if (bubble.top < 18f) {
            bubble.offset(0f, 18f - bubble.top);
        }

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(115, 0, 0, 0));
        canvas.drawRoundRect(bubble.left + 5f, bubble.top + 7f, bubble.right + 5f, bubble.bottom + 7f, 16, 16, paint);
        paint.setColor(Color.rgb(56, 37, 23));
        canvas.drawRoundRect(bubble, 16, 16, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(245, 176, 74));
        canvas.drawRoundRect(bubble, 16, 16, paint);

        Path tail = new Path();
        tail.moveTo(npcX - 18f, bubble.bottom - 2f);
        tail.lineTo(npcX + 18f, bubble.bottom - 2f);
        tail.lineTo(npcX, bubble.bottom + 28f);
        tail.close();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(56, 37, 23));
        canvas.drawPath(tail, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(245, 176, 74));
        canvas.drawLine(npcX - 18f, bubble.bottom - 2f, npcX, bubble.bottom + 28f, paint);
        canvas.drawLine(npcX + 18f, bubble.bottom - 2f, npcX, bubble.bottom + 28f, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 226, 121));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        canvas.drawText("Penjual Benih", bubble.left + 24f, bubble.top + 35f, paint);
        paint.setColor(Color.WHITE);
        paint.setTextSize(fitTextSize("SHOP: tap aku atau tekan A untuk beli benih.", 21f, bubble.width() - 48f));
        paint.setFakeBoldText(false);
        canvas.drawText("SHOP: tap aku atau tekan A untuk beli benih.", bubble.left + 24f, bubble.top + 72f, paint);
    }

    private void drawPlotActionSigns(Canvas canvas, long now) {
        for (int i = 0; i < gameState.plots.size(); i++) {
            if (i != selectedPlot) {
                continue;
            }
            Plot plot = gameState.plots.get(i);
            InteractionKind kind = plotInteractionKind(plot, now);
            RectF sign = plotActionSignBounds(plot);
            keepPlotSignOnScreen(sign);
            if (isOffscreen(sign)) {
                continue;
            }

            boolean selected = i == selectedPlot;
            drawSignPosts(canvas, sign, 26f);
            drawWoodSignBoard(canvas, sign, signLabel(kind), selected ? 24f : 21f, selected);
        }
    }

    private void drawSignPosts(Canvas canvas, RectF sign, float height) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(83, 49, 19));
        float postW = 9f;
        canvas.drawRect(sign.left + sign.width() * 0.26f - postW * 0.5f, sign.bottom - 2f,
                sign.left + sign.width() * 0.26f + postW * 0.5f, sign.bottom + height, paint);
        canvas.drawRect(sign.right - sign.width() * 0.26f - postW * 0.5f, sign.bottom - 2f,
                sign.right - sign.width() * 0.26f + postW * 0.5f, sign.bottom + height, paint);
    }

    private void drawWoodSignBoard(Canvas canvas, RectF sign, String label, float textSize, boolean highlighted) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(highlighted ? 140 : 105, 0, 0, 0));
        canvas.drawRoundRect(sign.left + 8f, sign.top + 9f, sign.right + 8f, sign.bottom + 9f, 8, 8, paint);
        paint.setColor(highlighted ? Color.rgb(137, 78, 28) : Color.rgb(113, 65, 24));
        canvas.drawRoundRect(sign, 8, 8, paint);
        paint.setColor(Color.argb(120, 177, 105, 41));
        canvas.drawRect(sign.left + 10f, sign.top + 9f, sign.right - 10f, sign.top + 18f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(highlighted ? 5f : 4f);
        paint.setColor(highlighted ? Color.rgb(255, 221, 121) : Color.rgb(79, 45, 17));
        canvas.drawRoundRect(sign, 8, 8, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setTextSize(fitTextSize(label, textSize, sign.width() - 22f));
        paint.setFakeBoldText(true);
        float baseline = sign.centerY() + paint.getTextSize() * 0.35f;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(63, 36, 16));
        drawCenteredText(canvas, label, sign.centerX(), baseline);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 239, 204));
        drawCenteredText(canvas, label, sign.centerX(), baseline);
        paint.setFakeBoldText(false);
    }

    private void keepPlotSignOnScreen(RectF sign) {
        float padding = 10f;
        if (sign.top < padding) {
            sign.offset(0f, padding - sign.top);
        }
        float bottomLimit = getHeight() - padding;
        if (sign.bottom > bottomLimit) {
            sign.offset(0f, bottomLimit - sign.bottom);
        }
    }

    private float fitTextSize(String text, float preferredSize, float maxWidth) {
        paint.setTextSize(preferredSize);
        float width = paint.measureText(text);
        if (width <= maxWidth) {
            return preferredSize;
        }
        return Math.max(15f, preferredSize * maxWidth / Math.max(1f, width));
    }

    private String signLabel(InteractionKind kind) {
        switch (kind) {
            case BUY_LAND:
                return "BELI LAHAN";
            case PLANT:
                return "TANAM/JUAL";
            case SELL_LAND:
                return "JUAL LAHAN";
            case WAIT_CROP:
                return "TUNGGU";
            case HARVEST:
                return "PANEN";
            default:
                return "AKSI";
        }
    }

    private RectF plotActionSignBounds(Plot plot) {
        float centerX = plot.x + plot.w * 0.5f - cameraX;
        float bottom = plot.y - cameraY - 16f;
        float width = 166f;
        float height = 48f;
        return new RectF(
                centerX - width * 0.5f,
                bottom - height,
                centerX + width * 0.5f,
                bottom);
    }

    private RectF plotActionSignTapBounds(Plot plot) {
        RectF bounds = new RectF(plotActionSignBounds(plot));
        keepPlotSignOnScreen(bounds);
        bounds.inset(-18f, -18f);
        return bounds;
    }

    private RectF shopSignBounds() {
        float centerX = SHOP_SIGN_X_TILE * TILE - cameraX;
        float centerY = SHOP_SIGN_Y_TILE * TILE - cameraY;
        float width = 190f;
        float height = 68f;
        return new RectF(
                centerX - width * 0.5f,
                centerY - height * 0.5f,
                centerX + width * 0.5f,
                centerY + height * 0.5f);
    }

    private RectF sellSignBounds() {
        float centerX = SELL_SIGN_X_TILE * TILE - cameraX;
        float centerY = SELL_SIGN_Y_TILE * TILE - cameraY;
        float width = 230f;
        float height = 64f;
        return new RectF(
                centerX - width * 0.5f,
                centerY - height * 0.5f,
                centerX + width * 0.5f,
                centerY + height * 0.5f);
    }

    private RectF swapSignBounds() {
        float centerX = SWAP_SIGN_X_TILE * TILE - cameraX;
        float centerY = SWAP_SIGN_Y_TILE * TILE - cameraY;
        float width = 230f;
        float height = 64f;
        return new RectF(
                centerX - width * 0.5f,
                centerY - height * 0.5f,
                centerX + width * 0.5f,
                centerY + height * 0.5f);
    }

    private RectF shopSignTapBounds() {
        RectF bounds = new RectF(shopSignBounds());
        bounds.inset(-24f, -22f);
        return bounds;
    }

    private RectF shopNpcBodyBounds() {
        float footX = SHOP_NPC_X_TILE * TILE - cameraX;
        float footY = SHOP_NPC_Y_TILE * TILE - cameraY;
        return new RectF(
                footX - SHOP_NPC_SIZE * 0.32f,
                footY - SHOP_NPC_SIZE * 0.82f,
                footX + SHOP_NPC_SIZE * 0.32f,
                footY + SHOP_NPC_SIZE * 0.10f);
    }

    private RectF shopNpcTapBounds() {
        RectF bounds = new RectF(shopNpcBodyBounds());
        bounds.inset(-26f, -22f);
        return bounds;
    }

    private RectF sellSignTapBounds() {
        RectF bounds = new RectF(sellSignBounds());
        bounds.inset(-26f, -24f);
        return bounds;
    }

    private RectF swapSignTapBounds() {
        RectF bounds = new RectF(swapSignBounds());
        bounds.inset(-26f, -24f);
        return bounds;
    }

    private boolean isOffscreen(RectF bounds) {
        return bounds.right < 0f
                || bounds.left > getWidth()
                || bounds.bottom < 0f
                || bounds.top > getHeight();
    }

    private void drawPlayer(Canvas canvas, long now) {
        Bitmap sheet = moving ? walkSheet : idleSheet;
        int frameW = 32;
        int frameH = 32;
        int columns = Math.max(1, sheet.getWidth() / frameW);
        int frame = moving ? walkFrame : (int) ((now / 240L) % 6L);
        int frameIndex = frame % columns;
        int row = spriteRowForDirection();
        src.set(frameIndex * frameW, row * frameH, frameIndex * frameW + frameW, row * frameH + frameH);

        float playerSize = TILE * 1.35f;
        float screenX = playerX - cameraX - playerSize * 0.5f;
        float screenY = playerY - cameraY - playerSize * 0.78f;
        float footX = playerX - cameraX;
        float footY = playerY - cameraY + TILE * 0.05f;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(80, 0, 0, 0));
        canvas.drawOval(
                footX - TILE * 0.22f,
                footY - TILE * 0.06f,
                footX + TILE * 0.22f,
                footY + TILE * 0.07f,
                paint);

        dst.set(screenX, screenY, screenX + playerSize, screenY + playerSize);
        if (facingDirection == DIR_LEFT) {
            canvas.save();
            canvas.scale(-1f, 1f, screenX + playerSize * 0.5f, screenY + playerSize * 0.5f);
            canvas.drawBitmap(sheet, src, dst, pixelPaint);
            canvas.restore();
        } else {
            canvas.drawBitmap(sheet, src, dst, pixelPaint);
        }
    }

    private int spriteRowForDirection() {
        if (facingDirection == DIR_UP) {
            return 1;
        }
        if (facingDirection == DIR_DOWN) {
            return 0;
        }
        return 2;
    }

    private void drawHud(Canvas canvas, long now) {
        drawMiniMap(canvas);
        drawTopMenu(canvas);
        drawJoystick(canvas);
        hudRenderer.drawActionButton(canvas, getWidth(), getHeight());
        drawWalletButton(canvas);
        drawChainHistoryButton(canvas);
        drawBackpackButton(canvas);
        hudRenderer.drawContextMessage(canvas, getWidth(), getHeight(), contextText(now));
        if (shopUntilMs > now) {
            drawShopPanel(canvas);
        }
        if (chainPanelUntilMs > now) {
            drawChainPanel(canvas, now);
        }
        if (menuOpen) {
            drawMenuPanel(canvas);
        }
        if (backpackOpen) {
            drawBackpackPanel(canvas);
        }
        if (interactionDialogOpen) {
            drawInteractionDialog(canvas, now);
        }
        if (shopCatalogOpen) {
            drawShopCatalog(canvas);
        }
        if (shopPurchaseConfirmOpen) {
            drawShopPurchaseConfirm(canvas);
        }
        if (chainHistoryOpen) {
            drawChainHistoryDialog(canvas);
        }
        drawStatusPopup(canvas, now);
    }

    private void drawStatusPopup(Canvas canvas, long now) {
        if (!isStatusPopupVisible(now)) {
            return;
        }

        RectF bounds = statusPopupBounds();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(135, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 7f, bounds.top + 8f, bounds.right + 7f, bounds.bottom + 8f, 16, 16, paint);
        paint.setColor(Color.rgb(34, 114, 62));
        canvas.drawRoundRect(bounds, 16, 16, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(125, 226, 130));
        canvas.drawRoundRect(bounds, 16, 16, paint);

        float iconCx = bounds.left + 58f;
        float iconCy = bounds.centerY();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(211, 255, 203));
        canvas.drawCircle(iconCx, iconCy, 26f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(7f);
        paint.setColor(Color.rgb(32, 120, 62));
        canvas.drawLine(iconCx - 12f, iconCy + 1f, iconCx - 2f, iconCy + 12f, paint);
        canvas.drawLine(iconCx - 2f, iconCy + 12f, iconCx + 15f, iconCy - 13f, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(226, 255, 214));
        paint.setTextSize(20f);
        paint.setFakeBoldText(true);
        canvas.drawText(statusPopupTitle, bounds.left + 102f, bounds.top + 39f, paint);
        paint.setColor(Color.WHITE);
        paint.setTextSize(fitTextSize(statusPopupMessage, 25f, bounds.width() - 128f));
        canvas.drawText(statusPopupMessage, bounds.left + 102f, bounds.top + 76f, paint);
        paint.setFakeBoldText(false);
    }

    private boolean isStatusPopupVisible(long now) {
        return statusPopupUntilMs > now && !statusPopupMessage.isEmpty();
    }

    private RectF statusPopupBounds() {
        float w = Math.min(getWidth() - 44f, clamp(getWidth() * 0.34f, 430f, 680f));
        float h = 112f;
        float left = (getWidth() - w) * 0.5f;
        float top = Math.max(76f, getHeight() * 0.12f);
        return new RectF(left, top, left + w, top + h);
    }

    private void drawInventory(Canvas canvas) {
        float left = miniMapLeft() + miniMapWidth() + 18f;
        float top = 14f;
        float right = Math.min(left + 382f, getWidth() - 410f);
        if (right - left < 300f) {
            right = left + 300f;
        }
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(210, 82, 49, 21));
        canvas.drawRoundRect(left, top, right, top + 52f, 10, 10, paint);
        paint.setColor(Color.rgb(255, 226, 88));
        paint.setTextSize(21f);
        paint.setFakeBoldText(true);
        canvas.drawText("Coin " + gameState.coins, left + 16f, top + 34f, paint);
        paint.setColor(Color.WHITE);
        canvas.drawText("Bibit " + totalSeeds(), left + 122f, top + 34f, paint);
        canvas.drawText("Panen " + gameState.harvests, left + 220f, top + 34f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawChainBar(Canvas canvas) {
        float left = miniMapLeft() + miniMapWidth() + 414f;
        float top = 14;
        float right = Math.min(getWidth() - 192f, left + 470f);
        if (right <= left + 80) {
            return;
        }
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(210, 34, 55, 45));
        canvas.drawRoundRect(left, top, right, 66, 12, 12, paint);
        paint.setTextSize(18f);
        paint.setFakeBoldText(true);
        paint.setColor(Color.rgb(152, 239, 176));
        canvas.drawText(walletTaniBalanceAvailable ? "Sepolia TANI" : "Sepolia", left + 16, 47, paint);
        paint.setColor(Color.WHITE);
        String wallet = walletAddress.isEmpty() ? "wallet belum connect" : shortAddress(walletAddress);
        canvas.drawText(wallet, left + 132, 47, paint);
        paint.setColor(pendingChainActions.isEmpty() ? Color.rgb(190, 214, 190) : Color.rgb(255, 219, 95));
        canvas.drawText("pending " + pendingChainActions.size(), right - 112, 47, paint);
        paint.setFakeBoldText(false);
    }

    private void drawMiniMap(Canvas canvas) {
        float mapW = miniMapWidth();
        float mapH = miniMapHeight();
        float left = miniMapLeft();
        float top = miniMapTop();
        float inset = 8f;
        miniMapInnerBounds.set(left + inset, top + inset, left + mapW - inset, top + mapH - inset);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(left + 4f, top + 5f, left + mapW + 4f, top + mapH + 5f, 8, 8, paint);
        paint.setColor(Color.rgb(78, 63, 30));
        canvas.drawRoundRect(left, top, left + mapW, top + mapH, 8, 8, paint);
        paint.setColor(Color.rgb(147, 108, 45));
        canvas.drawRoundRect(left + 3f, top + 3f, left + mapW - 3f, top + mapH - 3f, 6, 6, paint);

        canvas.save();
        canvas.clipRect(miniMapInnerBounds);
        if (tmxMap != null) {
            drawCachedMiniMap(canvas, miniMapInnerBounds);
        } else {
            paint.setColor(Color.rgb(105, 184, 78));
            canvas.drawRect(miniMapInnerBounds, paint);
        }

        float x = miniMapInnerBounds.left + playerX / worldWidthPixels * miniMapInnerBounds.width();
        float y = miniMapInnerBounds.top + playerY / worldHeightPixels * miniMapInnerBounds.height();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.WHITE);
        canvas.drawCircle(x, y, 4.4f, paint);
        paint.setColor(Color.rgb(225, 38, 34));
        canvas.drawCircle(x, y, 3.2f, paint);
        canvas.restore();

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2f);
        paint.setColor(Color.argb(170, 255, 241, 166));
        canvas.drawRoundRect(left + 6f, top + 6f, left + mapW - 6f, top + mapH - 6f, 4, 4, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawCachedMiniMap(Canvas canvas, RectF bounds) {
        int width = Math.max(1, Math.round(bounds.width()));
        int height = Math.max(1, Math.round(bounds.height()));
        if (miniMapBitmap == null || miniMapBitmapWidth != width || miniMapBitmapHeight != height) {
            miniMapBitmap = tmxMap.createMiniMapBitmap(width, height, TILE);
            miniMapBitmapWidth = width;
            miniMapBitmapHeight = height;
        }
        canvas.drawBitmap(miniMapBitmap, null, bounds, pixelPaint);
    }

    private void drawTopMenu(Canvas canvas) {
        float top = topMenuTop();
        float buttonSize = topMenuButtonSize();
        float buttonRight = getWidth() - 20f;
        float buttonLeft = buttonRight - buttonSize;
        float barRight = buttonLeft - 14f;
        float barLeft = barRight - topMenuBarWidth();
        float bottom = top + buttonSize;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(barLeft + 4f, top + 5f, barRight + 4f, bottom + 5f, 12, 12, paint);
        paint.setColor(Color.rgb(112, 65, 16));
        canvas.drawRoundRect(barLeft, top, barRight, bottom, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(86, 48, 12));
        canvas.drawRoundRect(barLeft, top, barRight, bottom, 12, 12, paint);

        paint.setStyle(Paint.Style.FILL);
        drawCoinHudIcon(canvas, barLeft + 36f, top + buttonSize * 0.5f);
        paint.setColor(Color.rgb(240, 222, 179));
        paint.setTextSize(26f);
        paint.setFakeBoldText(true);
        canvas.drawText(String.valueOf(gameState.coins), barLeft + 76f, top + 48f, paint);

        paint.setColor(Color.rgb(76, 42, 12));
        canvas.drawRect(barLeft + topMenuBarWidth() * 0.52f, top + 13f, barLeft + topMenuBarWidth() * 0.52f + 4f, bottom - 13f, paint);

        drawHarvestHudIcon(canvas, barLeft + topMenuBarWidth() * 0.67f, top + buttonSize * 0.5f);
        paint.setColor(Color.rgb(240, 222, 179));
        canvas.drawText(String.valueOf(gameState.harvests), barLeft + topMenuBarWidth() * 0.67f + 39f, top + 48f, paint);
        paint.setFakeBoldText(false);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(buttonLeft + 4f, top + 5f, buttonRight + 4f, bottom + 5f, 10, 10, paint);
        paint.setColor(menuOpen ? Color.rgb(141, 82, 24) : Color.rgb(122, 72, 24));
        canvas.drawRoundRect(buttonLeft, top, buttonRight, bottom, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(91, 53, 16));
        canvas.drawRoundRect(buttonLeft, top, buttonRight, bottom, 10, 10, paint);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(245, 231, 203));
        float cx = (buttonLeft + buttonRight) * 0.5f;
        for (int i = -1; i <= 1; i++) {
            float y = top + buttonSize * 0.5f + i * 15f;
            canvas.drawLine(cx - 21f, y, cx + 21f, y, paint);
        }
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawCoinHudIcon(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(248, 242, 215));
        canvas.drawCircle(cx, cy, 23f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(54, 42, 18));
        canvas.drawCircle(cx, cy, 19f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(238, 197, 48));
        canvas.drawCircle(cx, cy, 10f, paint);
    }

    private void drawHarvestHudIcon(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(36, 116, 216));
        canvas.drawCircle(cx, cy, 23f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(209, 238, 255));
        canvas.drawCircle(cx, cy, 17f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.WHITE);
        paint.setTextSize(25f);
        paint.setFakeBoldText(true);
        canvas.drawText("X", cx - 9f, cy + 9f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawMenuPanel(Canvas canvas) {
        canvas.drawColor(Color.argb(155, 0, 0, 0));

        RectF panel = settingsPanelBounds();
        float headerH = 118f;
        float sidebarW = 190f;
        float bodyTop = panel.top + headerH;
        float bodyLeft = panel.left + sidebarW;

        drawOverlayPanelFrame(canvas, panel, bodyTop);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(DialogUi.PANEL_INNER_FILL);
        canvas.drawRect(bodyLeft, bodyTop, panel.right - 4f, panel.bottom - 4f, paint);
        paint.setColor(Color.rgb(112, 52, 20));
        canvas.drawRect(panel.left + 4f, bodyTop, bodyLeft, panel.bottom - 4f, paint);

        drawMenuTitle(canvas, panel.left + 58f, panel.top + 61f);
        drawPanelCloseButton(canvas, menuCloseButtonBounds());

        drawBackpackSideTab(canvas, settingsAudioTabBounds(), menuTab == MENU_TAB_SETTINGS, "AUDIO", Color.rgb(105, 196, 250));
        drawBackpackSideTab(canvas, settingsAboutTabBounds(), menuTab == MENU_TAB_ABOUT, "ABOUT", Color.rgb(255, 151, 83));

        if (menuTab == MENU_TAB_ABOUT) {
            drawAboutPanel(canvas, panel, bodyLeft, bodyTop);
            return;
        }
        drawAudioSettingsPanel(canvas, panel, bodyLeft, bodyTop);
    }

    private void drawBackpackPanel(Canvas canvas) {
        canvas.drawColor(Color.argb(155, 0, 0, 0));

        RectF panel = backpackPanelBounds();
        float headerH = 108f;
        float bodyTop = panel.top + headerH;

        drawOverlayPanelFrame(canvas, panel, bodyTop);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(DialogUi.PANEL_INNER_FILL);
        canvas.drawRect(panel.left + 4f, bodyTop, panel.right - 4f, panel.bottom - 4f, paint);

        drawBackpackTitle(canvas, panel.left + 58f, panel.top + 56f);
        drawBackpackCloseButton(canvas);
        drawBackpackInventoryContent(canvas, panel, bodyTop);
    }

    private void drawOverlayPanelFrame(Canvas canvas, RectF panel, float bodyTop) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(120, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 8f, panel.top + 10f, panel.right + 8f, panel.bottom + 10f, 26, 26, paint);
        paint.setColor(DialogUi.PANEL_FILL);
        canvas.drawRoundRect(panel, 26, 26, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(6f);
        paint.setColor(DialogUi.PANEL_STROKE);
        canvas.drawRoundRect(panel, 26, 26, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(DialogUi.PANEL_FILL);
        canvas.drawRoundRect(panel.left + 4f, panel.top + 4f, panel.right - 4f, bodyTop, 24, 24, paint);
        paint.setColor(Color.rgb(95, 43, 16));
        canvas.drawRect(panel.left + 4f, bodyTop - 4f, panel.right - 4f, bodyTop + 2f, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(DialogUi.PANEL_INNER_STROKE);
        canvas.drawRoundRect(panel.left + 10f, panel.top + 10f, panel.right - 10f, panel.bottom - 10f, 19, 19, paint);

        drawPanelCorner(canvas, panel.left + 24f, panel.top + 24f, true, true);
        drawPanelCorner(canvas, panel.right - 24f, panel.top + 24f, false, true);
        drawPanelCorner(canvas, panel.left + 24f, panel.bottom - 24f, true, false);
        drawPanelCorner(canvas, panel.right - 24f, panel.bottom - 24f, false, false);
    }

    private void drawBackpackInventoryContent(Canvas canvas, RectF panel, float bodyTop) {
        RectF content = new RectF(panel.left + 40f, bodyTop + 24f, panel.right - 40f, panel.bottom - 34f);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(126, 58, 20));
        canvas.drawRoundRect(content.left, content.top, content.right, content.top + 58f, 14, 14, paint);
        paint.setColor(DialogUi.TITLE);
        paint.setTextSize(24f);
        paint.setFakeBoldText(true);
        canvas.drawText("SEEDS", content.left + 22f, content.top + 38f, paint);
        paint.setFakeBoldText(false);

        drawBackpackStatChip(canvas, content.right - 334f, content.top + 7f, 152f, true, gameState.coins);
        drawBackpackStatChip(canvas, content.right - 166f, content.top + 7f, 146f, false, gameState.harvests);

        float cardW = 122f;
        float cardH = 126f;
        float gap = 28f;
        int columns = SEED_NAMES.length;
        float gridW = columns * cardW + (columns - 1) * gap;
        if (gridW > content.width()) {
            columns = 2;
            gap = 24f;
            gridW = columns * cardW + (columns - 1) * gap;
        }
        float startX = content.left + Math.max(0f, (content.width() - gridW) * 0.5f);
        float startY = content.top + 86f;
        for (int i = 0; i < SEED_NAMES.length; i++) {
            int col = i % columns;
            int row = i / columns;
            drawInventoryItemCard(canvas,
                    startX + col * (cardW + gap),
                    startY + row * (cardH + 22f),
                    cardW,
                    cardH,
                    SEED_CARD_COLORS[i],
                    SEED_ICON_COLORS[i],
                    i == 1 ? "Benih Daun" : "Benih",
                    SEED_NAMES[i],
                    gameState.seedCounts[i]);
        }
    }

    private void drawBackpackStatChip(Canvas canvas, float left, float top, float width, boolean coin, int value) {
        RectF chip = new RectF(left, top, left + width, top + 44f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(96, 43, 13));
        canvas.drawRoundRect(chip, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(170, 89, 28));
        canvas.drawRoundRect(chip, 12, 12, paint);
        if (coin) {
            drawCoinHudIcon(canvas, chip.left + 27f, chip.centerY());
        } else {
            drawHarvestHudIcon(canvas, chip.left + 27f, chip.centerY());
        }
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 241, 212));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        canvas.drawText(String.valueOf(value), chip.left + 62f, chip.top + 30f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawMenuTitle(Canvas canvas, float left, float centerY) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(255, 236, 190));
        for (int i = -1; i <= 1; i++) {
            float y = centerY + i * 12f;
            canvas.drawLine(left + 2f, y, left + 34f, y, paint);
        }

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 222, 35));
        paint.setTextSize(35f);
        paint.setFakeBoldText(false);
        canvas.drawText("MENU", left + 58f, centerY + 13f, paint);
    }

    private void drawBackpackTitle(Canvas canvas, float left, float centerY) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 84, 122));
        canvas.drawRoundRect(left, centerY - 18f, left + 25f, centerY + 18f, 8, 8, paint);
        paint.setColor(Color.rgb(255, 181, 78));
        canvas.drawRect(left + 5f, centerY - 9f, left + 20f, centerY - 3f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(255, 138, 170));
        canvas.drawArc(left + 5f, centerY - 25f, left + 20f, centerY - 6f, 200, 140, false, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 222, 35));
        paint.setTextSize(35f);
        paint.setFakeBoldText(false);
        canvas.drawText("BACKPACK", left + 48f, centerY + 13f, paint);
    }

    private void drawBackpackCloseButton(Canvas canvas) {
        drawPanelCloseButton(canvas, backpackCloseButtonBounds());
    }

    private void drawPanelCloseButton(Canvas canvas, RectF close) {
        float radius = close.width() * 0.22f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(92, 0, 0, 0));
        canvas.drawRoundRect(close.left + 4f, close.top + 5f, close.right + 4f, close.bottom + 5f, radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(130, 57, 18));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setColor(Color.rgb(177, 88, 28));
        canvas.drawRoundRect(close.left + 6f, close.top + 6f, close.right - 6f, close.top + close.height() * 0.40f,
                radius * 0.74f, radius * 0.74f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(216, 126, 42));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setStrokeWidth(7f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.rgb(255, 236, 190));
        float pad = close.width() * 0.32f;
        canvas.drawLine(close.left + pad, close.top + pad, close.right - pad, close.bottom - pad, paint);
        canvas.drawLine(close.right - pad, close.top + pad, close.left + pad, close.bottom - pad, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawBackpackSideTab(Canvas canvas, RectF tab, boolean active, String label, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(active ? Color.rgb(255, 200, 15) : Color.rgb(106, 48, 13));
        canvas.drawRoundRect(tab, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(active ? 4f : 3f);
        paint.setColor(active ? Color.rgb(255, 226, 34) : Color.rgb(166, 85, 26));
        canvas.drawRoundRect(tab, 12, 12, paint);

        float cx = (tab.left + tab.right) * 0.5f;
        float iconY = tab.top + tab.height() * 0.37f;
        if ("SEEDS".equals(label)) {
            drawSeedSproutIcon(canvas, cx, iconY, active ? Color.rgb(80, 210, 83) : Color.rgb(235, 185, 70));
        } else if ("AUDIO".equals(label)) {
            drawSpeakerIcon(canvas, cx, iconY, active ? Color.rgb(64, 180, 240) : Color.rgb(235, 185, 70));
        } else if ("ABOUT".equals(label)) {
            drawAboutIcon(canvas, cx, iconY, active ? Color.rgb(255, 151, 83) : Color.rgb(235, 185, 70));
        } else {
            drawHarvestIcon(canvas, cx, iconY, accent);
        }
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(active ? Color.rgb(48, 29, 11) : Color.rgb(242, 228, 198));
        paint.setTextSize(19f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, label, cx, tab.bottom - 18f);
        paint.setFakeBoldText(false);
    }

    private void drawAboutPanel(Canvas canvas, RectF panel, float bodyLeft, float bodyTop) {
        float left = bodyLeft + 58f;
        float top = bodyTop + 48f;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 235, 171));
        paint.setTextSize(30f);
        paint.setFakeBoldText(true);
        canvas.drawText("About", left, top, paint);
        paint.setFakeBoldText(false);

        RectF chip = new RectF(left + 116f, top - 27f, left + 304f, top + 4f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(120, 58, 22));
        canvas.drawRoundRect(chip, 15, 15, paint);
        paint.setColor(Color.rgb(255, 218, 93));
        paint.setTextSize(15f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, "TANIIN", chip.centerX(), chip.top + 21f);
        paint.setFakeBoldText(false);

        RectF card = new RectF(left, top + 58f, panel.right - 58f, top + 318f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(76, 0, 0, 0));
        canvas.drawRoundRect(card.left + 5f, card.top + 6f, card.right + 5f, card.bottom + 6f, 18, 18, paint);
        paint.setColor(Color.rgb(104, 47, 15));
        canvas.drawRoundRect(card, 18, 18, paint);
        paint.setColor(Color.rgb(124, 58, 21));
        canvas.drawRoundRect(card.left + 8f, card.top + 8f, card.right - 8f, card.top + 34f, 11, 11, paint);
        paint.setColor(Color.rgb(255, 151, 83));
        canvas.drawRoundRect(card.left, card.top, card.left + 10f, card.bottom, 8, 8, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(164, 85, 31));
        canvas.drawRoundRect(card, 14, 14, paint);

        RectF icon = new RectF(card.left + 42f, card.top + 42f, card.left + 154f, card.top + 154f);
        drawAboutAppIcon(canvas, icon);

        float textLeft = icon.right + 34f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 241, 212));
        paint.setTextSize(fitTextSize("Rahmat Eka Satria", 30f, card.right - textLeft - 30f));
        paint.setFakeBoldText(true);
        canvas.drawText("Rahmat Eka Satria", textLeft, card.top + 82f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.rgb(232, 202, 164));
        paint.setTextSize(18f);
        canvas.drawText("Creator", textLeft, card.top + 116f, paint);

        RectF github = aboutGithubButtonBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(41, 92, 68));
        canvas.drawRoundRect(github, 13, 13, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(118, 218, 140));
        canvas.drawRoundRect(github, 13, 13, paint);
        drawExternalLinkIcon(canvas, github.left + 34f, github.centerY());
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.WHITE);
        paint.setTextSize(fitTextSize("github.com/rhmatzeka", 21f, github.width() - 78f));
        paint.setFakeBoldText(true);
        canvas.drawText("github.com/rhmatzeka", github.left + 62f, github.top + 31f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawAudioSettingsPanel(Canvas canvas, RectF panel, float bodyLeft, float bodyTop) {
        RectF content = audioSettingsCardBounds();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(78, 0, 0, 0));
        canvas.drawRoundRect(content.left + 5f, content.top + 6f, content.right + 5f, content.bottom + 6f, 18, 18, paint);
        paint.setColor(Color.rgb(146, 65, 22));
        canvas.drawRoundRect(content, 18, 18, paint);
        paint.setColor(Color.rgb(118, 52, 16));
        canvas.drawRoundRect(content.left + 10f, content.top + 10f, content.right - 10f, content.top + 86f, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(202, 104, 36));
        canvas.drawRoundRect(content, 18, 18, paint);

        drawSpeakerIcon(canvas, content.left + 48f, content.top + 48f, Color.rgb(93, 202, 250));

        paint.setStyle(Paint.Style.FILL);
        paint.setTypeface(android.graphics.Typeface.create(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD));
        paint.setFakeBoldText(true);
        paint.setTextSize(fitTextSize("SETTINGS", 39f, content.width() - 172f));
        paint.setColor(Color.rgb(255, 224, 21));
        canvas.drawText("SETTINGS", content.left + 132f, content.top + 60f, paint);

        paint.setTypeface(null);
        paint.setFakeBoldText(false);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(96, 43, 11));
        canvas.drawRect(content.left + 28f, content.top + 100f, content.right - 28f, content.top + 105f, paint);

        drawVolumeSlider(canvas, "MASTER VOLUME", masterVolume, 0);
        drawVolumeSlider(canvas, "MUSIC VOLUME", musicVolume, 1);
        drawVolumeSlider(canvas, "SFX VOLUME", sfxVolume, 2);
    }

    private void drawVolumeSlider(Canvas canvas, String label, float value, int index) {
        RectF card = audioSettingsCardBounds();
        RectF slider = audioSliderBounds(index);
        float labelY = slider.top - 28f;

        paint.setStyle(Paint.Style.FILL);
        paint.setTypeface(android.graphics.Typeface.create(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD));
        paint.setFakeBoldText(true);
        paint.setColor(Color.rgb(255, 241, 212));
        paint.setTextSize(fitTextSize(label, 27f, card.width() * 0.58f));
        canvas.drawText(label, slider.left, labelY, paint);

        String percent = Math.round(value * 100f) + "%";
        paint.setTextSize(27f);
        paint.setTextAlign(Paint.Align.RIGHT);
        canvas.drawText(percent, slider.right, labelY, paint);
        paint.setTextAlign(Paint.Align.LEFT);

        paint.setTypeface(null);
        paint.setFakeBoldText(false);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(96, 43, 11));
        canvas.drawRoundRect(slider, 8, 8, paint);

        float knobX = slider.left + slider.width() * clamp(value, 0f, 1f);
        paint.setColor(Color.rgb(255, 141, 9));
        canvas.drawCircle(knobX, slider.centerY(), 12f, paint);
        paint.setColor(Color.rgb(255, 186, 55));
        canvas.drawCircle(knobX - 3f, slider.centerY() - 4f, 4f, paint);
    }

    private void drawAudioSettingRow(Canvas canvas, RectF row, RectF toggle, String label,
            String detail, boolean enabled, int accent, int iconType) {
        drawAudioRowBackground(canvas, row, accent);
        drawAudioRowIcon(canvas, row.left + 46f, row.centerY(), accent, iconType);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 241, 212));
        paint.setTextSize(21f);
        paint.setFakeBoldText(true);
        canvas.drawText(label, row.left + 86f, row.top + 31f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.rgb(232, 202, 164));
        paint.setTextSize(16f);
        canvas.drawText(detail, row.left + 86f, row.top + 56f, paint);

        RectF state = new RectF(toggle.left - 76f, toggle.top + 7f, toggle.left - 16f, toggle.bottom - 7f);
        paint.setColor(enabled ? Color.rgb(51, 129, 72) : Color.rgb(122, 55, 48));
        canvas.drawRoundRect(state, 14, 14, paint);
        paint.setColor(enabled ? Color.rgb(181, 246, 164) : Color.rgb(244, 171, 155));
        paint.setTextSize(14f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, enabled ? "ON" : "OFF", state.centerX(), state.top + 22f);
        paint.setFakeBoldText(false);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(enabled ? Color.rgb(38, 139, 78) : Color.rgb(122, 51, 45));
        canvas.drawRoundRect(toggle, 24, 24, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(enabled ? Color.rgb(128, 237, 143) : Color.rgb(225, 105, 91));
        canvas.drawRoundRect(toggle, 24, 24, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(249, 240, 218));
        float knobRadius = 20f;
        float knobX = enabled ? toggle.right - 28f : toggle.left + 28f;
        canvas.drawCircle(knobX, toggle.centerY(), knobRadius, paint);
    }

    private void drawAudioTrackRow(Canvas canvas, RectF row, RectF button) {
        drawAudioRowBackground(canvas, row, Color.rgb(255, 152, 71));
        drawAudioRowIcon(canvas, row.left + 46f, row.centerY(), Color.rgb(255, 152, 71), 2);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 241, 212));
        paint.setTextSize(21f);
        paint.setFakeBoldText(true);
        canvas.drawText("Track backsound", row.left + 86f, row.top + 31f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.rgb(232, 202, 164));
        paint.setTextSize(16f);
        canvas.drawText("Track " + (audioTrackIndex + 1) + " / " + gameAudio.getBgmCount(), row.left + 86f, row.top + 56f, paint);

        drawMenuActionButton(canvas, button, "Ganti");
    }

    private void drawAudioRowBackground(Canvas canvas, RectF row, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(68, 0, 0, 0));
        canvas.drawRoundRect(row.left + 4f, row.top + 5f, row.right + 4f, row.bottom + 5f, 16, 16, paint);
        paint.setColor(Color.rgb(104, 47, 15));
        canvas.drawRoundRect(row, 16, 16, paint);
        paint.setColor(Color.rgb(124, 58, 21));
        canvas.drawRoundRect(row.left + 8f, row.top + 8f, row.right - 8f, row.top + 27f, 9, 9, paint);
        paint.setColor(accent);
        canvas.drawRoundRect(row.left, row.top, row.left + 10f, row.bottom, 8, 8, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(164, 85, 31));
        canvas.drawRoundRect(row, 12, 12, paint);
    }

    private void drawAudioRowIcon(Canvas canvas, float cx, float cy, int accent, int type) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(64, 31, 13));
        canvas.drawCircle(cx, cy, 27f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(accent);
        canvas.drawCircle(cx, cy, 23f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(accent);
        if (type == 0) {
            canvas.drawRect(cx - 8f, cy - 16f, cx - 3f, cy + 12f, paint);
            canvas.drawRect(cx + 8f, cy - 19f, cx + 13f, cy + 9f, paint);
            canvas.drawOval(cx - 22f, cy + 8f, cx - 2f, cy + 22f, paint);
            canvas.drawOval(cx + 0f, cy + 5f, cx + 20f, cy + 19f, paint);
            paint.setStrokeWidth(4f);
            canvas.drawLine(cx - 5f, cy - 16f, cx + 13f, cy - 20f, paint);
        } else if (type == 1) {
            canvas.drawRoundRect(cx - 18f, cy - 9f, cx - 4f, cy + 9f, 4, 4, paint);
            float[] points = {cx - 4f, cy - 14f, cx + 11f, cy - 23f, cx + 11f, cy + 23f, cx - 4f, cy + 14f};
            android.graphics.Path path = new android.graphics.Path();
            path.moveTo(points[0], points[1]);
            path.lineTo(points[2], points[3]);
            path.lineTo(points[4], points[5]);
            path.lineTo(points[6], points[7]);
            path.close();
            canvas.drawPath(path, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(4f);
            paint.setColor(Color.rgb(255, 238, 190));
            canvas.drawArc(cx + 9f, cy - 17f, cx + 31f, cy + 17f, -35, 70, false, paint);
            paint.setStyle(Paint.Style.FILL);
        } else {
            canvas.drawRoundRect(cx - 17f, cy - 15f, cx + 7f, cy + 3f, 6, 6, paint);
            canvas.drawRoundRect(cx - 3f, cy + 4f, cx + 19f, cy + 20f, 6, 6, paint);
            paint.setColor(Color.rgb(255, 226, 129));
            canvas.drawCircle(cx - 7f, cy - 6f, 3f, paint);
            canvas.drawCircle(cx + 8f, cy + 12f, 3f, paint);
        }
    }

    private void drawSpeakerIcon(Canvas canvas, float cx, float cy, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(accent);
        canvas.drawRoundRect(cx - 34f, cy - 13f, cx - 17f, cy + 13f, 5, 5, paint);
        float[] points = {
                cx - 16f, cy - 18f,
                cx + 5f, cy - 30f,
                cx + 5f, cy + 30f,
                cx - 16f, cy + 18f
        };
        android.graphics.Path path = new android.graphics.Path();
        path.moveTo(points[0], points[1]);
        path.lineTo(points[2], points[3]);
        path.lineTo(points[4], points[5]);
        path.lineTo(points[6], points[7]);
        path.close();
        canvas.drawPath(path, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(255, 236, 190));
        canvas.drawArc(cx + 8f, cy - 23f, cx + 40f, cy + 23f, -38, 76, false, paint);
        canvas.drawArc(cx + 19f, cy - 36f, cx + 60f, cy + 36f, -38, 76, false, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawAboutIcon(Canvas canvas, float cx, float cy, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(accent);
        canvas.drawCircle(cx, cy, 28f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(255, 236, 190));
        canvas.drawCircle(cx, cy, 21f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(64, 31, 13));
        canvas.drawCircle(cx, cy - 11f, 4f, paint);
        canvas.drawRoundRect(cx - 4f, cy - 2f, cx + 4f, cy + 18f, 4, 4, paint);
    }

    private void drawAboutAppIcon(Canvas canvas, RectF icon) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(67, 31, 12));
        canvas.drawRoundRect(icon.left - 7f, icon.top - 7f, icon.right + 7f, icon.bottom + 7f, 24, 24, paint);
        Path clip = new Path();
        clip.addRoundRect(icon, 20f, 20f, Path.Direction.CW);
        canvas.save();
        canvas.clipPath(clip);
        canvas.drawBitmap(appIcon, null, icon, pixelPaint);
        canvas.restore();
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(255, 205, 87));
        canvas.drawRoundRect(icon, 20, 20, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawExternalLinkIcon(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(232, 255, 224));
        canvas.drawRoundRect(cx - 12f, cy - 10f, cx + 9f, cy + 12f, 4, 4, paint);
        canvas.drawLine(cx - 2f, cy + 3f, cx + 14f, cy - 13f, paint);
        canvas.drawLine(cx + 5f, cy - 14f, cx + 15f, cy - 14f, paint);
        canvas.drawLine(cx + 15f, cy - 14f, cx + 15f, cy - 4f, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawInventoryItemCard(
            Canvas canvas,
            float left,
            float top,
            float width,
            float height,
            int cardColor,
            int iconColor,
            String labelTop,
            String labelBottom,
            int count) {
        RectF card = new RectF(left, top, left + width, top + height);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(85, 0, 0, 0));
        canvas.drawRoundRect(card.left + 4f, card.top + 5f, card.right + 4f, card.bottom + 5f, 9, 9, paint);
        paint.setColor(cardColor);
        canvas.drawRoundRect(card, 9, 9, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(120, 55, 18));
        canvas.drawRoundRect(card, 9, 9, paint);

        drawSeedPacketIcon(canvas, left + width * 0.5f, top + 34f, iconColor);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 205));
        paint.setTextSize(14f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, labelTop, left + width * 0.5f, top + 72f);
        drawCenteredText(canvas, labelBottom, left + width * 0.5f, top + 88f);
        paint.setColor(Color.rgb(255, 220, 28));
        paint.setTextSize(15f);
        drawCenteredText(canvas, "x" + count, left + width * 0.5f, top + 106f);
        paint.setFakeBoldText(false);
    }

    private void drawSeedPacketIcon(Canvas canvas, float cx, float cy, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 246, 216));
        canvas.drawRoundRect(cx - 16f, cy - 19f, cx + 16f, cy + 17f, 4, 4, paint);
        paint.setColor(accent);
        canvas.drawRect(cx - 12f, cy - 12f, cx + 12f, cy + 7f, paint);
        paint.setColor(Color.rgb(71, 44, 31));
        canvas.drawRoundRect(cx - 8f, cy + 3f, cx + 8f, cy + 14f, 3, 3, paint);
        paint.setColor(Color.rgb(96, 210, 92));
        canvas.drawOval(cx - 10f, cy - 4f, cx + 2f, cy + 5f, paint);
        canvas.drawOval(cx, cy - 7f, cx + 11f, cy + 3f, paint);
    }

    private void drawSeedSproutIcon(Canvas canvas, float cx, float cy, int leafColor) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(124, 72, 37));
        canvas.drawRect(cx - 5f, cy + 2f, cx + 5f, cy + 27f, paint);
        paint.setColor(leafColor);
        canvas.drawOval(cx - 26f, cy - 16f, cx - 2f, cy + 1f, paint);
        canvas.drawOval(cx + 2f, cy - 20f, cx + 27f, cy - 2f, paint);
        paint.setColor(Color.rgb(236, 171, 61));
        canvas.drawOval(cx - 15f, cy + 21f, cx + 15f, cy + 32f, paint);
    }

    private void drawHarvestIcon(Canvas canvas, float cx, float cy, int accent) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(accent);
        canvas.drawRect(cx - 5f, cy - 24f, cx + 5f, cy + 28f, paint);
        paint.setColor(Color.rgb(243, 200, 70));
        canvas.drawOval(cx - 25f, cy - 18f, cx - 2f, cy + 0f, paint);
        canvas.drawOval(cx + 2f, cy - 5f, cx + 25f, cy + 14f, paint);
        paint.setColor(Color.rgb(81, 156, 95));
        canvas.drawRect(cx - 18f, cy + 16f, cx - 11f, cy + 33f, paint);
        canvas.drawRect(cx + 11f, cy + 16f, cx + 18f, cy + 33f, paint);
    }

    private void drawCenteredText(Canvas canvas, String text, float centerX, float baselineY) {
        canvas.drawText(text, centerX - paint.measureText(text) * 0.5f, baselineY, paint);
    }

    private void drawMenuTab(Canvas canvas, float left, float top, float width, String label, boolean active) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(active ? Color.rgb(134, 83, 29) : Color.rgb(74, 54, 31));
        canvas.drawRoundRect(left, top, left + width, top + 42f, 8, 8, paint);
        paint.setColor(active ? Color.rgb(255, 231, 166) : Color.rgb(203, 185, 151));
        paint.setTextSize(18f);
        paint.setFakeBoldText(true);
        float textW = paint.measureText(label);
        canvas.drawText(label, left + (width - textW) * 0.5f, top + 28f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawInventoryMenu(Canvas canvas, RectF panel) {
        float x = panel.left + 24f;
        float y = panel.top + 88f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 232, 170));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        canvas.drawText("Inventory Aset", x, y, paint);
        paint.setFakeBoldText(false);

        int growing = 0;
        int ready = 0;
        for (Plot plot : gameState.plots) {
            if (plot.state == PlotState.GROWING) {
                growing++;
            } else if (plot.state == PlotState.READY) {
                ready++;
            }
        }

        drawInventoryRow(canvas, x, y + 45f, Color.rgb(255, 209, 84), "Game Coin", gameState.coins);
        drawInventoryRow(canvas, x, y + 90f, Color.rgb(116, 209, 85), "Bibit tanaman", totalSeeds());
        drawInventoryRow(canvas, x, y + 135f, Color.rgb(235, 150, 63), "Hasil panen", gameState.harvests);
        drawInventoryRow(canvas, x, y + 180f, Color.rgb(123, 188, 91), "Lahan dimiliki", gameState.ownedLand);
        drawInventoryRow(canvas, x, y + 225f, Color.rgb(96, 176, 220), "Tanaman tumbuh", growing);
        drawInventoryRow(canvas, x, y + 270f, Color.rgb(255, 230, 92), "Siap panen", ready);
    }

    private void drawInventoryRow(Canvas canvas, float x, float y, int iconColor, String label, int value) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(66, 52, 34));
        canvas.drawRoundRect(x, y - 28f, x + menuPanelBounds().width() - 48f, y + 8f, 8, 8, paint);
        paint.setColor(iconColor);
        canvas.drawCircle(x + 19f, y - 10f, 11f, paint);
        paint.setColor(Color.rgb(239, 226, 201));
        paint.setTextSize(18f);
        canvas.drawText(label, x + 44f, y - 3f, paint);
        paint.setFakeBoldText(true);
        String text = String.valueOf(value);
        canvas.drawText(text, x + menuPanelBounds().width() - 76f - paint.measureText(text), y - 3f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawSettingsMenu(Canvas canvas, RectF panel) {
        float x = panel.left + 24f;
        float y = panel.top + 88f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 232, 170));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        canvas.drawText("Setting", x, y, paint);
        paint.setFakeBoldText(false);

        paint.setColor(Color.rgb(226, 213, 187));
        paint.setTextSize(18f);
        canvas.drawText("Kontrol: Analog default", x, y + 40f, paint);
        canvas.drawText("Wallet: " + (walletAddress.isEmpty() ? "belum connect" : shortAddress(walletAddress)), x, y + 74f, paint);
        String balance = walletNativeBalance.isEmpty() ? chainStatus : "ETH " + walletNativeBalance + " | " + chainStatus;
        canvas.drawText(balance, x, y + 108f, paint);
        drawMenuActionButton(canvas, settingsRpcButtonBounds(), "Cek RPC");
        drawMenuActionButton(canvas, settingsWalletButtonBounds(), "Wallet");
        drawMenuActionButton(canvas, settingsCloseButtonBounds(), "Tutup");
    }

    private void drawMenuActionButton(Canvas canvas, RectF bounds, String label) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(119, 72, 28));
        canvas.drawRoundRect(bounds, 8, 8, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2f);
        paint.setColor(Color.rgb(162, 105, 41));
        canvas.drawRoundRect(bounds, 8, 8, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.WHITE);
        paint.setTextSize(18f);
        paint.setFakeBoldText(true);
        float textW = paint.measureText(label);
        canvas.drawText(label, bounds.left + (bounds.width() - textW) * 0.5f, bounds.top + 28f, paint);
        paint.setFakeBoldText(false);
    }

    private float miniMapLeft() {
        return 32f;
    }

    private float miniMapTop() {
        return 26f;
    }

    private float miniMapWidth() {
        return clamp(getWidth() * 0.112f, 236f, 286f);
    }

    private float miniMapHeight() {
        float mapRatio = worldHeightPixels / Math.max(1f, worldWidthPixels);
        return miniMapWidth() * clamp(mapRatio, 0.82f, 0.92f);
    }

    private float topMenuTop() {
        return 10f;
    }

    private float topMenuButtonSize() {
        return 76f;
    }

    private float topMenuBarWidth() {
        return 305f;
    }

    private RectF topMenuButtonBounds() {
        float right = getWidth() - 20f;
        float top = topMenuTop();
        float size = topMenuButtonSize();
        return new RectF(right - size, top, right, top + size);
    }

    private RectF menuPanelBounds() {
        float w = clamp(getWidth() * 0.28f, 430f, 540f);
        float h = 410f;
        float right = getWidth() - 20f;
        float top = topMenuTop() + topMenuButtonSize() + 14f;
        return new RectF(right - w, top, right, top + h);
    }

    private RectF backpackPanelBounds() {
        float maxW = Math.max(320f, getWidth() - 44f);
        float maxH = Math.max(300f, getHeight() - 44f);
        float w = Math.min(maxW, clamp(getWidth() * 0.64f, 720f, 940f));
        float h = Math.min(maxH, clamp(getHeight() * 0.52f, 380f, 460f));
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF settingsPanelBounds() {
        float maxW = Math.max(360f, getWidth() - 44f);
        float maxH = Math.max(380f, getHeight() - 44f);
        float w = Math.min(maxW, clamp(getWidth() * 0.72f, 820f, 1040f));
        float h = Math.min(maxH, clamp(getHeight() * 0.74f, 500f, 580f));
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF backpackCloseButtonBounds() {
        RectF panel = backpackPanelBounds();
        return overlayCloseButtonBounds(panel, 108f);
    }

    private RectF menuCloseButtonBounds() {
        RectF panel = settingsPanelBounds();
        return overlayCloseButtonBounds(panel, 118f);
    }

    private RectF overlayCloseButtonBounds(RectF panel, float headerHeight) {
        float top = panel.top + (headerHeight - OVERLAY_CLOSE_SIZE) * 0.5f;
        float right = panel.right - OVERLAY_CLOSE_RIGHT_MARGIN;
        return new RectF(right - OVERLAY_CLOSE_SIZE, top, right, top + OVERLAY_CLOSE_SIZE);
    }

    private RectF settingsAudioTabBounds() {
        RectF panel = settingsPanelBounds();
        float bodyTop = panel.top + 118f;
        return new RectF(panel.left + 34f, bodyTop + 30f, panel.left + 170f, bodyTop + 138f);
    }

    private RectF settingsAboutTabBounds() {
        RectF panel = settingsPanelBounds();
        float bodyTop = panel.top + 118f;
        return new RectF(panel.left + 34f, bodyTop + 160f, panel.left + 170f, bodyTop + 268f);
    }

    private RectF aboutGithubButtonBounds() {
        RectF panel = settingsPanelBounds();
        float bodyTop = panel.top + 118f;
        float bodyLeft = panel.left + 190f;
        float left = bodyLeft + 252f;
        float top = bodyTop + 252f;
        return new RectF(left, top, Math.min(panel.right - 86f, left + 326f), top + 50f);
    }

    private RectF audioSettingsCardBounds() {
        RectF panel = settingsPanelBounds();
        float bodyLeft = panel.left + 190f;
        float bodyTop = panel.top + 118f;
        float bodyRight = panel.right - 4f;
        float bodyBottom = panel.bottom - 4f;
        return new RectF(bodyLeft + 42f, bodyTop + 30f, bodyRight - 42f, bodyBottom - 36f);
    }

    private RectF audioSliderBounds(int index) {
        RectF content = audioSettingsCardBounds();
        float left = content.left + 38f;
        float right = content.right - 38f;
        float firstCenter = content.top + Math.max(154f, Math.min(172f, content.height() * 0.38f));
        float lastCenter = Math.max(firstCenter + 172f, content.bottom - 48f);
        float centerY = firstCenter + index * ((lastCenter - firstCenter) * 0.5f);
        return new RectF(left, centerY - 6f, right, centerY + 6f);
    }

    private RectF audioSliderTouchBounds(int index) {
        RectF slider = audioSliderBounds(index);
        return new RectF(slider.left - 14f, slider.top - 34f, slider.right + 14f, slider.bottom + 26f);
    }

    private RectF audioBgmRowBounds() {
        RectF panel = settingsPanelBounds();
        float bodyTop = panel.top + 118f;
        float bodyLeft = panel.left + 190f;
        return new RectF(bodyLeft + 58f, bodyTop + 94f, panel.right - 58f, bodyTop + 166f);
    }

    private RectF audioSfxRowBounds() {
        RectF bgm = audioBgmRowBounds();
        return new RectF(bgm.left, bgm.top + 86f, bgm.right, bgm.bottom + 86f);
    }

    private RectF audioTrackRowBounds() {
        RectF sfx = audioSfxRowBounds();
        return new RectF(sfx.left, sfx.top + 86f, sfx.right, sfx.bottom + 86f);
    }

    private RectF audioBgmToggleBounds() {
        RectF row = audioBgmRowBounds();
        return new RectF(row.right - 112f, row.top + 15f, row.right - 24f, row.bottom - 15f);
    }

    private RectF audioSfxToggleBounds() {
        RectF row = audioSfxRowBounds();
        return new RectF(row.right - 112f, row.top + 15f, row.right - 24f, row.bottom - 15f);
    }

    private RectF audioTrackButtonBounds() {
        RectF row = audioTrackRowBounds();
        return new RectF(row.right - 128f, row.top + 14f, row.right - 22f, row.bottom - 14f);
    }

    private RectF settingsRpcButtonBounds() {
        RectF panel = menuPanelBounds();
        return new RectF(panel.left + 24f, panel.bottom - 126f, panel.left + 154f, panel.bottom - 84f);
    }

    private RectF settingsWalletButtonBounds() {
        RectF panel = menuPanelBounds();
        return new RectF(panel.left + 168f, panel.bottom - 126f, panel.left + 298f, panel.bottom - 84f);
    }

    private RectF settingsCloseButtonBounds() {
        RectF panel = menuPanelBounds();
        return new RectF(panel.right - 150f, panel.bottom - 62f, panel.right - 24f, panel.bottom - 20f);
    }

    private float joystickBaseX() {
        return clamp(getWidth() * 0.145f, 320f, 390f);
    }

    private float joystickBaseY() {
        return getHeight() - clamp(getHeight() * 0.31f, 300f, 350f);
    }

    private void drawJoystick(Canvas canvas) {
        float baseX = joystickActive ? joyBaseX : joystickBaseX();
        float baseY = joystickActive ? joyBaseY : joystickBaseY();
        float knobX = joystickActive ? joyX : baseX;
        float knobY = joystickActive ? joyY : baseY;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 20, 20, 20));
        canvas.drawCircle(baseX, baseY, JOYSTICK_RADIUS, paint);
        paint.setColor(Color.argb(160, 255, 255, 255));
        canvas.drawCircle(knobX, knobY, JOYSTICK_KNOB_RADIUS, paint);
    }

    private void drawWalletButton(Canvas canvas) {
        boolean connected = !walletAddress.isEmpty();
        boolean signerWallet = connected && isConnectedWalletBackendSigner();
        String label = connected ? shortAddress(walletAddress) : "CONNECT WALLET";
        String compactNativeEth = walletNativeBalance.isEmpty() ? "" : compactEth(walletNativeBalance);
        hudRenderer.drawWalletButton(canvas, walletButtonBounds(), connected, checkingChain, signerWallet, label, compactNativeEth);
    }

    private void drawChainHistoryButton(Canvas canvas) {
        chainHistoryRenderer.drawButton(canvas, walletButtonBounds(), chainHistory);
    }

    private void drawBackpackButton(Canvas canvas) {
        RectF bounds = backpackButtonBounds();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 14, 14, paint);
        paint.setColor(backpackOpen ? Color.rgb(145, 81, 26) : Color.rgb(112, 65, 16));
        canvas.drawRoundRect(bounds, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(backpackOpen ? Color.rgb(255, 224, 38) : Color.rgb(184, 105, 35));
        canvas.drawRoundRect(bounds, 14, 14, paint);

        drawBackpackHudIcon(canvas, bounds.centerX(), bounds.centerY());

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(totalSeeds() > 0 ? Color.rgb(255, 219, 95) : Color.rgb(111, 82, 48));
        canvas.drawCircle(bounds.right - 10f, bounds.top + 12f, 17f, paint);
        paint.setColor(Color.rgb(44, 31, 15));
        paint.setTextSize(16f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, String.valueOf(totalSeeds()), bounds.right - 10f, bounds.top + 18f);
        paint.setFakeBoldText(false);
    }

    private void drawBackpackHudIcon(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 213, 71));
        canvas.drawRoundRect(cx - 27f, cy - 12f, cx + 27f, cy + 26f, 8, 8, paint);
        paint.setColor(Color.rgb(241, 99, 130));
        canvas.drawRoundRect(cx - 21f, cy - 21f, cx + 21f, cy + 20f, 8, 8, paint);
        paint.setColor(Color.rgb(255, 181, 78));
        canvas.drawRect(cx - 13f, cy - 3f, cx + 13f, cy + 4f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(255, 231, 172));
        canvas.drawArc(cx - 13f, cy - 35f, cx + 13f, cy - 9f, 200, 140, false, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawChainHistoryDialog(Canvas canvas) {
        chainHistoryRenderer.drawDialog(canvas, getWidth(), getHeight(), chainHistory, blockchainClient.hasGameApi());
    }

    private RectF chainHistoryButtonBounds() {
        return chainHistoryRenderer.buttonBounds(walletButtonBounds());
    }

    private RectF backpackButtonBounds() {
        RectF history = chainHistoryButtonBounds();
        float top = history.bottom + 8f;
        return new RectF(history.left, top, history.right, top + history.height());
    }

    private RectF chainHistoryDialogBounds() {
        return chainHistoryRenderer.dialogBounds(getWidth(), getHeight(), chainHistory.size());
    }

    private RectF chainHistoryDialogCloseBounds() {
        return chainHistoryRenderer.dialogCloseBounds(getWidth(), getHeight(), chainHistory.size());
    }

    private RectF chainHistoryDialogClearAllBounds() {
        return chainHistoryRenderer.dialogClearAllBounds(getWidth(), getHeight(), chainHistory.size());
    }

    private RectF chainHistoryDialogRowBounds(int rowIndex) {
        return chainHistoryRenderer.dialogRowBounds(rowIndex, getWidth(), getHeight(), chainHistory.size());
    }

    private RectF chainHistoryRowDeleteBounds(int rowIndex) {
        return chainHistoryRenderer.rowDeleteBounds(rowIndex, getWidth(), getHeight(), chainHistory.size());
    }

    private int visibleChainHistoryDialogRows() {
        return chainHistoryRenderer.visibleDialogRows(getWidth(), getHeight(), chainHistory.size());
    }

    private String contextText(long now) {
        if (messageUntilMs > now) {
            return message;
        }
        InteractionKind kind = currentInteractionKind(now);
        switch (kind) {
            case SHOP:
                return "";
            case SELL_HARVEST:
                return gameState.harvests > 0
                        ? "A: jual " + gameState.harvests + " panen jadi Game Coin."
                        : "Rumah jual: belum ada hasil panen.";
            case SWAP_TOKEN:
                if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
                    int maxCoins = maxEthFundingCoins();
                    return maxCoins > 0
                            ? "A: isi Game Coin dari Sepolia ETH. Maks " + maxCoins + " coin."
                            : "Rumah swap: sync saldo ETH Sepolia dulu.";
                }
                return gameState.coins > 0
                        ? "A: pilih output, lalu swap " + gameState.coins + " coin ke Sepolia."
                        : "Rumah swap: coin belum ada.";
            case BUY_LAND:
                return "A: beli lahan " + LAND_BUY_PRICE + " coin.";
            case PLANT:
                return "A: tanam atau jual lahan kosong.";
            case SELL_LAND:
                return "A: jual lahan kosong +" + LAND_SELL_PRICE + " coin.";
            case WAIT_CROP:
                return "Tanaman masih tumbuh.";
            case HARVEST:
                return "A: panen tanaman.";
            default:
                return "Dekati lahan atau toko.";
        }
    }

    private InteractionKind currentInteractionKind(long now) {
        if (selectedPlot >= 0) {
            return plotInteractionKind(gameState.plots.get(selectedPlot), now);
        }
        if (isNearShop()) {
            return InteractionKind.SHOP;
        }
        if (isNearSellHouse()) {
            return InteractionKind.SELL_HARVEST;
        }
        if (isNearSwapHouse()) {
            return InteractionKind.SWAP_TOKEN;
        }
        return InteractionKind.NONE;
    }

    private InteractionKind plotInteractionKind(Plot plot, long now) {
        return farmingSystem.interactionKind(plot, now);
    }

    private void drawShopPanel(Canvas canvas) {
        hudRenderer.drawShopPanel(canvas, getWidth(), LAND_BUY_PRICE, LAND_SELL_PRICE, HARVEST_SELL_PRICE);
    }

    private void drawChainPanel(Canvas canvas, long now) {
        boolean signerWallet = isConnectedWalletBackendSigner();
        String walletLine = "Wallet: " + (walletAddress.isEmpty() ? "belum diset" : shortAddress(walletAddress))
                + (signerWallet ? " (signer backend)" : "");
        String balanceLine = "Game Coin " + gameState.coins
                + (walletNativeBalance.isEmpty() ? "" : " | Sepolia ETH " + compactEth(walletNativeBalance))
                + (walletTaniBalanceAvailable ? " | TANI " + walletTaniBalance : "");
        String nextAction = signerWallet
                ? "Payout ETH diblokir. Tap wallet untuk ganti wallet pemain."
                : pendingChainActions.isEmpty()
                ? "Tidak ada sync chain berjalan."
                : "Sync berikutnya: " + pendingChainActions.get(0).label();
        String footnote = signerWallet
                ? "Gunakan public wallet pemain, bukan wallet deployer/backend."
                : "Gameplay tetap tersimpan lokal saat signer tidak reachable.";
        hudRenderer.drawChainPanel(
                canvas,
                getWidth(),
                getHeight(),
                isStatusPopupVisible(now),
                statusPopupBounds(),
                signerWallet,
                chainStatus,
                walletLine,
                balanceLine,
                blockchainClient.hasCoinContract(),
                blockchainClient.hasGameApi(),
                nextAction,
                footnote);
    }

    private void drawInteractionDialog(Canvas canvas, long now) {
        canvas.drawColor(Color.argb(170, 0, 0, 0));
        RectF panel = interactionDialogPanelBounds();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(130, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 8f, panel.top + 10f, panel.right + 8f, panel.bottom + 10f, 24, 24, paint);
        paint.setColor(Color.rgb(158, 78, 32));
        canvas.drawRoundRect(panel, 24, 24, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(7f);
        paint.setColor(Color.rgb(77, 42, 14));
        canvas.drawRoundRect(panel, 24, 24, paint);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(185, 92, 40));
        canvas.drawRoundRect(panel.left + 12f, panel.top + 12f, panel.right - 12f, panel.bottom - 12f, 18, 18, paint);

        drawPanelCorner(canvas, panel.left + 24f, panel.top + 24f, true, true);
        drawPanelCorner(canvas, panel.right - 24f, panel.top + 24f, false, true);
        drawPanelCorner(canvas, panel.left + 24f, panel.bottom - 24f, true, false);
        drawPanelCorner(canvas, panel.right - 24f, panel.bottom - 24f, false, false);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 222, 25));
        paint.setTextSize(40f);
        paint.setFakeBoldText(true);
        canvas.drawText(interactionTitle(), panel.left + 58f, panel.top + 75f, paint);
        paint.setFakeBoldText(false);

        paint.setColor(Color.rgb(89, 42, 13));
        canvas.drawRect(panel.left + 58f, panel.top + 112f, panel.right - 58f, panel.top + 117f, paint);

        RectF textBox = interactionBodyBoxBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(142, 65, 27));
        canvas.drawRoundRect(textBox, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(92, 42, 12));
        canvas.drawRoundRect(textBox, 14, 14, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 240, 212));
        String body = interactionBody(now);
        paint.setTextSize(fitTextSize(body, activeInteractionKind == InteractionKind.SWAP_TOKEN ? 27f : 28f, textBox.width() - 56f));
        paint.setFakeBoldText(false);
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            drawCenteredText(canvas, body, textBox.centerX(), textBox.centerY() + 10f);
        } else {
            canvas.drawText(body, textBox.left + 28f, textBox.top + 60f, paint);
        }

        if (activeInteractionKind == InteractionKind.PLANT) {
            drawPlantSeedSelector(canvas);
            drawDialogButton(canvas, interactionSellLandButtonBounds(), "Jual lahan",
                    Color.rgb(114, 71, 24), Color.rgb(255, 178, 63), Color.rgb(255, 237, 205));
        }
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            drawSwapRouteCard(canvas, now);
        }

        drawDialogButton(canvas, interactionPrimaryButtonBounds(), interactionPrimaryText(),
                Color.rgb(97, 50, 12), Color.rgb(255, 217, 0), Color.rgb(255, 237, 205));
        drawDialogButton(canvas, interactionSecondaryButtonBounds(), interactionSecondaryText(),
                Color.rgb(160, 5, 0), Color.rgb(92, 0, 0), Color.WHITE);
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN && swapAssetMenuOpen) {
            drawSwapAssetDropdown(canvas);
        }
    }

    private void drawShopCatalog(Canvas canvas) {
        canvas.drawColor(Color.argb(175, 0, 0, 0));
        RectF panel = shopCatalogPanelBounds();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(130, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 8f, panel.top + 10f, panel.right + 8f, panel.bottom + 10f, 22, 22, paint);
        paint.setColor(Color.rgb(156, 75, 30));
        canvas.drawRoundRect(panel, 22, 22, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(6f);
        paint.setColor(Color.rgb(70, 39, 13));
        canvas.drawRoundRect(panel, 22, 22, paint);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(184, 89, 38));
        canvas.drawRoundRect(panel.left + 10f, panel.top + 10f, panel.right - 10f, panel.bottom - 10f, 17, 17, paint);

        drawPanelCorner(canvas, panel.left + 24f, panel.top + 24f, true, true);
        drawPanelCorner(canvas, panel.right - 24f, panel.top + 24f, false, true);
        drawPanelCorner(canvas, panel.left + 24f, panel.bottom - 24f, true, false);
        drawPanelCorner(canvas, panel.right - 24f, panel.bottom - 24f, false, false);

        drawCartIcon(canvas, panel.left + 74f, panel.top + 74f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 222, 25));
        paint.setTextSize(48f);
        paint.setFakeBoldText(true);
        canvas.drawText("Shop", panel.left + 118f, panel.top + 93f, paint);
        paint.setFakeBoldText(false);
        drawShopCloseButton(canvas);

        paint.setColor(Color.rgb(89, 42, 13));
        canvas.drawRect(panel.left + 52f, panel.top + 132f, panel.right - 52f, panel.top + 137f, paint);

        RectF refresh = new RectF(panel.left + 52f, panel.top + 190f, panel.right - 52f, panel.top + 252f);
        drawInfoStrip(canvas, refresh, "Pilih benih, lalu tekan Beli di kartu.");
        drawShopPurchaseSummary(canvas);

        for (int i = 0; i < SEED_NAMES.length; i++) {
            drawShopCard(canvas, shopCardBounds(i), i);
        }
    }

    private void drawShopPurchaseConfirm(Canvas canvas) {
        canvas.drawColor(Color.argb(105, 0, 0, 0));
        RectF panel = shopPurchaseConfirmPanelBounds();
        int seedIndex = validShopPurchaseSeedIndex();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(140, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 7f, panel.top + 9f, panel.right + 7f, panel.bottom + 9f, 20, 20, paint);
        paint.setColor(Color.rgb(150, 72, 27));
        canvas.drawRoundRect(panel, 20, 20, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(6f);
        paint.setColor(Color.rgb(67, 37, 13));
        canvas.drawRoundRect(panel, 20, 20, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 222, 25));
        paint.setTextSize(34f);
        paint.setFakeBoldText(true);
        canvas.drawText("Konfirmasi Beli", panel.left + 38f, panel.top + 58f, paint);
        paint.setFakeBoldText(false);

        paint.setColor(Color.rgb(97, 45, 14));
        canvas.drawRect(panel.left + 38f, panel.top + 86f, panel.right - 38f, panel.top + 91f, paint);

        RectF detail = new RectF(panel.left + 38f, panel.top + 122f, panel.right - 38f, panel.top + 222f);
        paint.setColor(Color.rgb(124, 57, 22));
        canvas.drawRoundRect(detail, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(88, 40, 12));
        canvas.drawRoundRect(detail, 12, 12, paint);

        String line1 = String.format(Locale.US,
                "Beli %d paket %s?",
                gameState.shopBundleQuantity,
                SEED_NAMES[seedIndex]);
        String line2 = String.format(Locale.US,
                "Total %d benih - %d Coin. Game Coin kamu %d.",
                selectedSeedTotalAmount(),
                selectedSeedTotalPrice(),
                gameState.coins);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 240, 212));
        paint.setTextSize(fitTextSize(line1, 27f, detail.width() - 56f));
        paint.setFakeBoldText(true);
        canvas.drawText(line1, detail.left + 28f, detail.top + 42f, paint);
        paint.setTextSize(fitTextSize(line2, 22f, detail.width() - 56f));
        paint.setFakeBoldText(false);
        canvas.drawText(line2, detail.left + 28f, detail.top + 76f, paint);

        drawDialogButton(canvas, shopPurchaseConfirmPrimaryBounds(), "Ya, beli",
                Color.rgb(36, 112, 60), Color.rgb(134, 226, 118), Color.WHITE);
        drawDialogButton(canvas, shopPurchaseConfirmSecondaryBounds(), "Batal",
                Color.rgb(151, 47, 29), Color.rgb(93, 23, 16), Color.WHITE);
    }

    private void drawPanelCorner(Canvas canvas, float x, float y, boolean left, boolean top) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 211, 0));
        float cornerLeft = left ? x : x - 20f;
        float cornerTop = top ? y : y - 20f;
        canvas.drawRoundRect(cornerLeft, cornerTop, cornerLeft + 20f, cornerTop + 20f, 5, 5, paint);
    }

    private void drawDialogButton(Canvas canvas, RectF bounds, String label, int fill, int stroke, int textColor) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(85, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 4f, bounds.top + 5f, bounds.right + 4f, bounds.bottom + 5f, 12, 12, paint);
        paint.setColor(fill);
        canvas.drawRoundRect(bounds, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(stroke);
        canvas.drawRoundRect(bounds, 12, 12, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(textColor);
        float preferredTextSize = activeInteractionKind == InteractionKind.SWAP_TOKEN ? 29f : 23f;
        float horizontalPadding = activeInteractionKind == InteractionKind.SWAP_TOKEN ? 42f : 24f;
        paint.setTextSize(fitTextSize(label, preferredTextSize, bounds.width() - horizontalPadding));
        paint.setFakeBoldText(true);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        float baseline = bounds.centerY() - (metrics.ascent + metrics.descent) * 0.5f;
        drawCenteredText(canvas, label, bounds.centerX(), baseline);
        paint.setFakeBoldText(false);
    }

    private void drawShopPurchaseSummary(Canvas canvas) {
        RectF panel = shopCatalogPanelBounds();
        RectF bounds = new RectF(panel.left + 52f, panel.top + 312f, panel.right - 52f, panel.top + 386f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(139, 63, 25));
        canvas.drawRoundRect(bounds, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(95, 43, 12));
        canvas.drawRoundRect(bounds, 12, 12, paint);

        String selected = SEED_NAMES[gameState.selectedSeedIndex];
        String summary = String.format(Locale.US,
                "%s: %d | %s | Paket x%d = %d benih | Total %d Coin",
                "Game Coin",
                gameState.coins,
                selected,
                gameState.shopBundleQuantity,
                selectedSeedTotalAmount(),
                selectedSeedTotalPrice());
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 211));
        paint.setTextSize(fitTextSize(summary, 24f, bounds.width() - 190f));
        paint.setFakeBoldText(true);
        canvas.drawText(summary, bounds.left + 28f, bounds.top + 46f, paint);
        paint.setFakeBoldText(false);

        drawQuantityButton(canvas, shopQuantityMinusBounds(), "-");
        drawQuantityValue(canvas, shopQuantityValueBounds());
        drawQuantityButton(canvas, shopQuantityPlusBounds(), "+");
    }

    private void drawQuantityButton(Canvas canvas, RectF bounds, String label) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(104, 51, 14));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(255, 214, 78));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 211));
        paint.setTextSize(31f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, label, bounds.centerX(), bounds.top + 37f);
        paint.setFakeBoldText(false);
    }

    private void drawQuantityValue(Canvas canvas, RectF bounds) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(94, 44, 13));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(74, 34, 10));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 211));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, "x" + gameState.shopBundleQuantity, bounds.centerX(), bounds.top + 34f);
        paint.setFakeBoldText(false);
    }

    private void drawPlantSeedSelector(Canvas canvas) {
        RectF panel = interactionDialogPanelBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 224, 84));
        paint.setTextSize(21f);
        paint.setFakeBoldText(true);
        canvas.drawText("Pilih Benih", panel.left + 58f, panel.top + 314f, paint);
        paint.setFakeBoldText(false);

        for (int i = 0; i < SEED_NAMES.length; i++) {
            drawPlantSeedOption(canvas, plantSeedOptionBounds(i), i);
        }
    }

    private void drawPlantSeedOption(Canvas canvas, RectF bounds, int seedIndex) {
        boolean selected = seedIndex == gameState.selectedSeedIndex;
        boolean available = gameState.seedCounts[seedIndex] > 0;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(selected ? Color.rgb(167, 88, 30) : Color.rgb(121, 58, 23));
        canvas.drawRoundRect(bounds, 11, 11, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(selected ? 5f : 3f);
        paint.setColor(selected ? Color.rgb(255, 218, 46) : Color.rgb(94, 44, 13));
        canvas.drawRoundRect(bounds, 11, 11, paint);

        float iconCx = bounds.left + 34f;
        float iconCy = bounds.centerY() - 1f;
        drawSeedPacketIcon(canvas, iconCx, iconCy, available ? SEED_ICON_COLORS[seedIndex] : Color.rgb(107, 89, 77));

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(available ? Color.rgb(255, 240, 212) : Color.rgb(190, 151, 124));
        paint.setTextSize(fitTextSize(SEED_NAMES[seedIndex], 19f, bounds.width() - 72f));
        paint.setFakeBoldText(true);
        canvas.drawText(SEED_NAMES[seedIndex], bounds.left + 68f, bounds.top + 34f, paint);
        paint.setTextSize(18f);
        paint.setFakeBoldText(false);
        canvas.drawText("Stok x" + gameState.seedCounts[seedIndex], bounds.left + 68f, bounds.top + 62f, paint);
    }

    private void drawSwapRouteCard(Canvas canvas, long now) {
        drawSwapField(canvas, swapFromCardBounds(), true);
        drawSwapField(canvas, swapToCardBounds(), false);

        RectF button = swapSwitchButtonBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(120, 0, 0, 0));
        canvas.drawCircle(button.centerX() + 4f, button.centerY() + 5f, button.width() * 0.5f, paint);
        paint.setColor(Color.rgb(244, 188, 48));
        canvas.drawCircle(button.centerX(), button.centerY(), button.width() * 0.5f, paint);
        paint.setColor(Color.argb(70, 255, 244, 170));
        canvas.drawCircle(button.centerX() - 8f, button.centerY() - 9f, button.width() * 0.22f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(82, 43, 15));
        canvas.drawCircle(button.centerX(), button.centerY(), button.width() * 0.5f - 2f, paint);
        paint.setStrokeWidth(2f);
        paint.setColor(Color.rgb(255, 224, 91));
        canvas.drawCircle(button.centerX(), button.centerY(), button.width() * 0.5f - 8f, paint);
        float spin = clamp((now - swapSwitchAnimStartMs) / 260f, 0f, 1f);
        canvas.save();
        canvas.rotate(spin * 180f, button.centerX(), button.centerY());
        drawSwapSwitchGlyph(canvas, button.centerX(), button.centerY(), button.width() * 0.42f);
        canvas.restore();
    }

    private void drawSwapSwitchGlyph(Canvas canvas, float cx, float cy, float size) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4.5f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setColor(Color.rgb(61, 35, 15));

        float left = cx - size * 0.62f;
        float right = cx + size * 0.62f;
        float upper = cy - size * 0.38f;
        float lower = cy + size * 0.38f;

        Path top = new Path();
        top.moveTo(left, cy - size * 0.08f);
        top.cubicTo(cx - size * 0.42f, upper, cx + size * 0.40f, upper, right, cy - size * 0.08f);
        canvas.drawPath(top, paint);
        canvas.drawLine(right, cy - size * 0.08f, right - size * 0.22f, cy - size * 0.28f, paint);
        canvas.drawLine(right, cy - size * 0.08f, right - size * 0.08f, cy - size * 0.36f, paint);

        Path bottom = new Path();
        bottom.moveTo(right, cy + size * 0.08f);
        bottom.cubicTo(cx + size * 0.42f, lower, cx - size * 0.40f, lower, left, cy + size * 0.08f);
        canvas.drawPath(bottom, paint);
        canvas.drawLine(left, cy + size * 0.08f, left + size * 0.22f, cy + size * 0.28f, paint);
        canvas.drawLine(left, cy + size * 0.08f, left + size * 0.08f, cy + size * 0.36f, paint);

        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSwapField(Canvas canvas, RectF bounds, boolean from) {
        String headerLeft = from ? "Dari" : "Ke";
        String headerRight = from ? "Jumlah" : "Estimasi";
        int asset = from ? selectedSwapFromAsset() : selectedSwapToAsset();
        String symbol = swapAssetSymbol(asset);
        String name = swapAssetName(asset);
        String amount = from ? selectedSwapInputAmountText() : selectedSwapOutputAmount();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(95, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 16, 16, paint);
        paint.setColor(Color.rgb(126, 61, 24));
        canvas.drawRoundRect(bounds, 16, 16, paint);
        paint.setColor(Color.argb(48, 255, 218, 101));
        canvas.drawRoundRect(bounds.left + 8f, bounds.top + 7f, bounds.right - 8f, bounds.top + 30f, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(72, 35, 11));
        canvas.drawRoundRect(bounds, 16, 16, paint);
        paint.setStrokeWidth(2f);
        paint.setColor(Color.rgb(188, 101, 43));
        canvas.drawRoundRect(bounds.left + 7f, bounds.top + 7f, bounds.right - 7f, bounds.bottom - 7f, 12, 12, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 224, 84));
        paint.setTextSize(22f);
        paint.setFakeBoldText(true);
        canvas.drawText(headerLeft, bounds.left + 30f, bounds.top + 34f, paint);
        paint.setTextSize(fitTextSize(headerRight, 19f, bounds.width() * 0.34f));
        canvas.drawText(headerRight, bounds.right - 30f - paint.measureText(headerRight), bounds.top + 34f, paint);
        paint.setFakeBoldText(false);

        RectF chip = swapChipBounds(from);
        paint.setColor(Color.rgb(84, 42, 18));
        canvas.drawRoundRect(chip, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(swapAssetMenuOpen && swapAssetMenuFrom == from ? 4f : 3f);
        paint.setColor(swapAssetMenuOpen && swapAssetMenuFrom == from ? Color.rgb(255, 218, 46) : Color.rgb(106, 57, 22));
        canvas.drawRoundRect(chip, 14, 14, paint);

        drawSwapTokenIcon(canvas, chip.left + 51f, chip.centerY(), asset, 34f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 240, 212));
        float tokenTextLeft = chip.left + 100f;
        float tokenTextWidth = chip.right - tokenTextLeft - 72f;
        paint.setTextSize(fitTextSize(symbol, 38f, tokenTextWidth));
        paint.setFakeBoldText(true);
        canvas.drawText(symbol, tokenTextLeft, chip.top + 55f, paint);
        drawSwapChevron(canvas, chip.right - 38f, chip.centerY());
        paint.setFakeBoldText(false);

        paint.setColor(Color.rgb(245, 194, 124));
        paint.setTextSize(fitTextSize(name, 21f, tokenTextWidth));
        canvas.drawText(name, tokenTextLeft, chip.bottom - 19f, paint);

        RectF amountBox = swapAmountBounds(from);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(from ? Color.rgb(80, 39, 18) : Color.rgb(95, 45, 18));
        canvas.drawRoundRect(amountBox, 13, 13, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(from ? 3f : 2f);
        paint.setColor(from ? Color.rgb(255, 200, 65) : Color.rgb(130, 70, 28));
        canvas.drawRoundRect(amountBox, 13, 13, paint);
        if (from) {
            drawSwapEditGlyph(canvas, amountBox.left + 21f, amountBox.centerY());
        }

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(selectedSwapInputAmount() > 0 || from ? Color.rgb(255, 240, 212) : Color.rgb(174, 139, 101));
        paint.setTextSize(fitTextSize(amount, 38f, amountBox.width() - (from ? 68f : 26f)));
        paint.setFakeBoldText(true);
        canvas.drawText(amount, amountBox.right - 14f - paint.measureText(amount), amountBox.centerY() + 14f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawSwapEditGlyph(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.rgb(255, 214, 93));
        canvas.drawLine(cx - 6f, cy + 7f, cx + 7f, cy - 6f, paint);
        canvas.drawLine(cx - 9f, cy + 10f, cx - 3f, cy + 8f, paint);
        paint.setStrokeWidth(2f);
        canvas.drawLine(cx + 4f, cy - 9f, cx + 10f, cy - 3f, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSwapAssetDropdown(Canvas canvas) {
        boolean from = swapAssetMenuFrom;
        RectF menu = swapAssetMenuBounds(from);
        int count = swapAssetOptionCount(from);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(125, 0, 0, 0));
        canvas.drawRoundRect(menu.left + 4f, menu.top + 5f, menu.right + 4f, menu.bottom + 5f, 14, 14, paint);
        paint.setColor(Color.rgb(92, 43, 18));
        canvas.drawRoundRect(menu, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(62, 31, 12));
        canvas.drawRoundRect(menu, 14, 14, paint);
        paint.setStrokeWidth(2f);
        paint.setColor(Color.rgb(188, 101, 43));
        canvas.drawRoundRect(menu.left + 6f, menu.top + 6f, menu.right - 6f, menu.bottom - 6f, 10, 10, paint);

        for (int i = 0; i < count; i++) {
            drawSwapAssetOption(canvas, swapAssetOptionBounds(from, i), from, i);
        }
    }

    private void drawSwapAssetOption(Canvas canvas, RectF row, boolean from, int index) {
        int asset = swapAssetOptionAsset(from, index);
        boolean selected = from ? asset == selectedSwapFromAsset() : asset == selectedSwapToAsset();
        boolean enabled = isSwapAssetOptionEnabled(from, asset);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(selected ? Color.rgb(127, 65, 25) : Color.rgb(76, 38, 17));
        if (!enabled) {
            paint.setColor(Color.rgb(58, 36, 26));
        }
        canvas.drawRoundRect(row, 10, 10, paint);
        if (selected) {
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(3f);
            paint.setColor(Color.rgb(255, 218, 46));
            canvas.drawRoundRect(row, 10, 10, paint);
            paint.setStyle(Paint.Style.FILL);
        }

        drawSwapTokenIcon(canvas, row.left + 43f, row.centerY(), asset, 28f);
        paint.setColor(enabled ? Color.rgb(255, 240, 212) : Color.rgb(154, 122, 91));
        paint.setTextSize(fitTextSize(swapAssetSymbol(asset), 30f, row.width() - 116f));
        paint.setFakeBoldText(true);
        canvas.drawText(swapAssetSymbol(asset), row.left + 88f, row.top + 43f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(enabled ? Color.rgb(245, 194, 124) : Color.rgb(119, 90, 66));
        paint.setTextSize(fitTextSize(enabled ? swapAssetName(asset) : "Belum aktif", 18f, row.width() - 116f));
        canvas.drawText(enabled ? swapAssetName(asset) : "Belum aktif", row.left + 88f, row.bottom - 16f, paint);
    }

    private void drawSwapTokenIcon(Canvas canvas, float cx, float cy, int asset) {
        drawSwapTokenIcon(canvas, cx, cy, asset, 20.5f);
    }

    private void drawSwapTokenIcon(Canvas canvas, float cx, float cy, int asset, float radius) {
        if (asset == SWAP_ASSET_COIN) {
            drawSwapCoinIcon(canvas, cx, cy, radius);
        } else if (asset == SWAP_ASSET_ETH) {
            drawSwapEthIcon(canvas, cx, cy, radius);
        } else {
            drawSwapTaniIcon(canvas, cx, cy, radius);
        }
    }

    private void drawSwapChevron(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4.5f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setColor(Color.rgb(255, 218, 91));
        canvas.drawLine(cx - 10f, cy - 6f, cx, cy + 7f, paint);
        canvas.drawLine(cx + 10f, cy - 6f, cx, cy + 7f, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSwapIconBase(Canvas canvas, float cx, float cy, int fill, int stroke, float radius) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(fill);
        canvas.drawCircle(cx, cy, radius, paint);
        paint.setColor(Color.argb(70, 255, 255, 255));
        canvas.drawCircle(cx - radius * 0.25f, cy - radius * 0.27f, radius * 0.34f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(radius * 0.12f);
        paint.setColor(stroke);
        canvas.drawCircle(cx, cy, radius * 0.89f, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSwapCoinIcon(Canvas canvas, float cx, float cy, float radius) {
        float s = radius / 20.5f;
        drawSwapIconBase(canvas, cx, cy, Color.rgb(244, 192, 46), Color.rgb(124, 84, 22), radius);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2.8f * s);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.rgb(255, 239, 151));
        canvas.drawLine(cx - 7f * s, cy - 6f * s, cx + 7f * s, cy - 6f * s, paint);
        canvas.drawLine(cx - 9f * s, cy, cx + 9f * s, cy, paint);
        canvas.drawLine(cx - 5f * s, cy + 6f * s, cx + 5f * s, cy + 6f * s, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSwapEthIcon(Canvas canvas, float cx, float cy, float radius) {
        float s = radius / 20.5f;
        drawSwapIconBase(canvas, cx, cy, Color.rgb(111, 136, 244), Color.rgb(58, 72, 162), radius);
        Path diamond = new Path();
        diamond.moveTo(cx, cy - 14f * s);
        diamond.lineTo(cx + 8f * s, cy - 1f * s);
        diamond.lineTo(cx, cy + 5f * s);
        diamond.lineTo(cx - 8f * s, cy - 1f * s);
        diamond.close();
        paint.setColor(Color.rgb(244, 246, 255));
        canvas.drawPath(diamond, paint);
        Path lower = new Path();
        lower.moveTo(cx - 7f * s, cy + 4f * s);
        lower.lineTo(cx, cy + 15f * s);
        lower.lineTo(cx + 7f * s, cy + 4f * s);
        lower.lineTo(cx, cy + 8f * s);
        lower.close();
        paint.setColor(Color.rgb(206, 214, 255));
        canvas.drawPath(lower, paint);
    }

    private void drawSwapTaniIcon(Canvas canvas, float cx, float cy, float radius) {
        float s = radius / 20.5f;
        drawSwapIconBase(canvas, cx, cy, Color.rgb(50, 184, 113), Color.rgb(24, 106, 65), radius);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2.8f * s);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.WHITE);
        canvas.drawLine(cx, cy + 10f * s, cx, cy - 4f * s, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(226, 255, 231));
        canvas.drawOval(cx - 12f * s, cy - 8f * s, cx + 1f * s, cy + 4f * s, paint);
        canvas.drawOval(cx - 1f * s, cy - 10f * s, cx + 13f * s, cy + 3f * s, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawInfoStrip(Canvas canvas, RectF bounds, String label) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(139, 63, 25));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(95, 43, 12));
        canvas.drawRoundRect(bounds, 10, 10, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 211));
        paint.setTextSize(26f);
        paint.setFakeBoldText(true);
        canvas.drawText(label, bounds.left + 28f, bounds.top + 42f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawShopCard(Canvas canvas, RectF card, int seedIndex) {
        boolean selected = seedIndex == gameState.selectedSeedIndex;
        boolean canBuy = gameState.coins >= totalPriceForSeed(seedIndex);
        int cardFill = selected ? Color.rgb(176, 86, 28) : Color.rgb(141, 65, 27);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(cardFill);
        canvas.drawRoundRect(card, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(selected ? 5f : 3f);
        paint.setColor(selected ? Color.rgb(255, 218, 46) : Color.rgb(89, 42, 13));
        canvas.drawRoundRect(card, 14, 14, paint);

        float iconY = card.top + card.height() * 0.38f;
        drawSeedSproutIcon(canvas, card.left + 62f, iconY, SEED_ICON_COLORS[seedIndex]);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 238, 211));
        paint.setTextSize(24f);
        paint.setFakeBoldText(true);
        canvas.drawText(SEED_SHOP_NAMES[seedIndex], card.left + 118f, card.top + card.height() * 0.34f, paint);
        paint.setTextSize(19f);
        paint.setFakeBoldText(false);
        canvas.drawText("Isi " + SEED_BUNDLE_AMOUNT + " - Stok x" + gameState.seedCounts[seedIndex],
                card.left + 118f,
                card.top + card.height() * 0.55f,
                paint);
        paint.setTextSize(24f);
        paint.setFakeBoldText(true);
        canvas.drawText(SEED_PRICES[seedIndex] + " Coin/paket", card.left + 28f, card.bottom - 33f, paint);

        RectF button = shopBuyButtonBounds(seedIndex);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(canBuy ? Color.rgb(107, 56, 17) : Color.rgb(111, 52, 22));
        canvas.drawRoundRect(button, 9, 9, paint);
        paint.setColor(canBuy ? Color.rgb(255, 238, 211) : Color.rgb(171, 103, 57));
        paint.setTextSize(fitTextSize(canBuy ? "Beli x" + gameState.shopBundleQuantity : "Kurang", 20f, button.width() - 18f));
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, canBuy ? "Beli x" + gameState.shopBundleQuantity : "Kurang", button.centerX(), button.top + 33f);
        paint.setFakeBoldText(false);
    }

    private void drawShopCloseButton(Canvas canvas) {
        RectF close = shopCloseButtonBounds();
        float radius = close.width() * 0.20f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(82, 0, 0, 0));
        canvas.drawRoundRect(close.left + 4f, close.top + 5f, close.right + 4f, close.bottom + 5f, radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(108, 53, 12));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setColor(Color.rgb(164, 78, 23));
        canvas.drawRoundRect(close.left + 8f, close.top + 8f, close.right - 8f, close.top + close.height() * 0.38f,
                radius * 0.72f, radius * 0.72f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(188, 100, 31));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setStrokeWidth(8f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.rgb(255, 238, 211));
        float pad = close.width() * 0.32f;
        canvas.drawLine(close.left + pad, close.top + pad, close.right - pad, close.bottom - pad, paint);
        canvas.drawLine(close.right - pad, close.top + pad, close.left + pad, close.bottom - pad, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawCartIcon(Canvas canvas, float cx, float cy) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(214, 224, 232));
        canvas.drawLine(cx - 24f, cy - 18f, cx - 13f, cy + 15f, paint);
        canvas.drawLine(cx - 13f, cy + 15f, cx + 28f, cy + 15f, paint);
        canvas.drawLine(cx - 16f, cy - 5f, cx + 34f, cy - 5f, paint);
        canvas.drawLine(cx - 20f, cy - 18f, cx + 38f, cy - 18f, paint);
        canvas.drawLine(cx + 38f, cy - 18f, cx + 28f, cy + 15f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(70, 138, 222));
        canvas.drawCircle(cx - 5f, cy + 28f, 6f, paint);
        canvas.drawCircle(cx + 24f, cy + 28f, 6f, paint);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        int index = event.getActionIndex();
        int pointerId = event.getPointerId(index);

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            float x = event.getX(index);
            float y = event.getY(index);
            if (chainHistoryOpen) {
                return handleChainHistoryDialogTouch(x, y);
            }
            if (backpackOpen) {
                return handleBackpackTouch(x, y);
            }
            if (shopPurchaseConfirmOpen) {
                return handleShopPurchaseConfirmTouch(x, y);
            }
            if (shopCatalogOpen) {
                return handleShopCatalogTouch(x, y);
            }
            if (interactionDialogOpen) {
                return handleInteractionDialogTouch(x, y);
            }
            if (topMenuButtonBounds().contains(x, y)) {
                playClickSound();
                toggleMenuPanel();
                return true;
            }
            if (menuOpen) {
                if (handleMenuTouch(x, y, pointerId)) {
                    return true;
                }
                playClickSound();
                menuOpen = false;
                finishAudioSliderDrag();
                return true;
            }
            int tappedPlot = findTappedPlotSign(x, y);
            if (tappedPlot >= 0) {
                playClickSound();
                selectedPlot = tappedPlot;
                openInteractionDialog(plotInteractionKind(gameState.plots.get(tappedPlot), System.currentTimeMillis()));
                return true;
            }
            if (isNearShop() && shopSignTapBounds().contains(x, y)) {
                playClickSound();
                openInteractionDialog(InteractionKind.SHOP);
                return true;
            }
            if (isNearSellHouse() && sellSignTapBounds().contains(x, y)) {
                playClickSound();
                openInteractionDialog(InteractionKind.SELL_HARVEST);
                return true;
            }
            if (isNearSwapHouse() && swapSignTapBounds().contains(x, y)) {
                playClickSound();
                openInteractionDialog(InteractionKind.SWAP_TOKEN);
                return true;
            }
            if (isInsideJoystickArea(x, y)) {
                joystickActive = true;
                joystickPointerId = pointerId;
                joyBaseX = joystickBaseX();
                joyBaseY = joystickBaseY();
                updateJoystick(x, y);
            } else if (isInsideAction(x, y)) {
                playClickSound();
                performAction();
            } else if (isInsideWallet(x, y)) {
                playClickSound();
                performWallet();
            } else if (handleChainHistoryButtonTouch(x, y)) {
                return true;
            } else if (handleBackpackButtonTouch(x, y)) {
                return true;
            }
            return true;
        }

        if (action == MotionEvent.ACTION_MOVE) {
            if (menuOpen && activeAudioSlider >= 0) {
                for (int i = 0; i < event.getPointerCount(); i++) {
                    if (event.getPointerId(i) == activeAudioSliderPointerId) {
                        updateAudioVolumeFromX(activeAudioSlider, event.getX(i));
                        break;
                    }
                }
                return true;
            }
            for (int i = 0; i < event.getPointerCount(); i++) {
                if (event.getPointerId(i) == joystickPointerId) {
                    updateJoystick(event.getX(i), event.getY(i));
                    break;
                }
            }
            return true;
        }

        if (action == MotionEvent.ACTION_UP
                || action == MotionEvent.ACTION_POINTER_UP
                || action == MotionEvent.ACTION_CANCEL) {
            if (pointerId == activeAudioSliderPointerId || action == MotionEvent.ACTION_CANCEL) {
                finishAudioSliderDrag();
            }
            if (pointerId == joystickPointerId) {
                joystickActive = false;
                joystickPointerId = -1;
                joyX = joyBaseX;
                joyY = joyBaseY;
                stopWalkSound();
            }
            return true;
        }
        return true;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (chainHistoryOpen) {
            if (isBackKey(keyCode)) {
                playClickSound();
                chainHistoryOpen = false;
                invalidate();
            }
            return true;
        }
        if (backpackOpen) {
            if (isBackKey(keyCode) || keyCode == KeyEvent.KEYCODE_MENU || keyCode == KeyEvent.KEYCODE_I) {
                playClickSound();
                backpackOpen = false;
                invalidate();
            }
            return true;
        }
        if (menuOpen) {
            if (isBackKey(keyCode) || keyCode == KeyEvent.KEYCODE_MENU || keyCode == KeyEvent.KEYCODE_M) {
                playClickSound();
                menuOpen = false;
                finishAudioSliderDrag();
                invalidate();
            }
            return true;
        }
        return handleHardwareKey(keyCode) || super.onKeyDown(keyCode, event);
    }

    boolean handleHardwareKey(int keyCode) {
        if (shopPurchaseConfirmOpen) {
            return handleShopPurchaseConfirmKey(keyCode);
        }
        if (shopCatalogOpen) {
            return handleShopCatalogKey(keyCode);
        }
        if (interactionDialogOpen) {
            return handleInteractionDialogKey(keyCode);
        }
        if (keyCode == KeyEvent.KEYCODE_MENU || keyCode == KeyEvent.KEYCODE_M) {
            playClickSound();
            toggleMenuPanel();
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_I) {
            playClickSound();
            openBackpackPanel();
            return true;
        }
        if (isPrimaryKey(keyCode)) {
            playClickSound();
            performAction();
            return true;
        }
        if (moveWithHardwareKey(keyCode)) {
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_S || keyCode == KeyEvent.KEYCODE_BUTTON_X) {
            if (isNearShop()) {
                playClickSound();
                openInteractionDialog(InteractionKind.SHOP);
                return true;
            }
            if (isNearSellHouse()) {
                playClickSound();
                openInteractionDialog(InteractionKind.SELL_HARVEST);
                return true;
            }
            if (isNearSwapHouse()) {
                playClickSound();
                openInteractionDialog(InteractionKind.SWAP_TOKEN);
                return true;
            }
        }
        return false;
    }

    private void toggleMenuPanel() {
        menuOpen = !menuOpen;
        if (menuOpen) {
            menuTab = MENU_TAB_SETTINGS;
            backpackOpen = false;
            chainHistoryOpen = false;
            interactionDialogOpen = false;
            shopCatalogOpen = false;
            shopPurchaseConfirmOpen = false;
            shopUntilMs = 0L;
        } else {
            finishAudioSliderDrag();
        }
        invalidate();
    }

    private boolean moveWithHardwareKey(int keyCode) {
        float dx = 0f;
        float dy = 0f;
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT || keyCode == KeyEvent.KEYCODE_A) {
            dx = -1f;
        } else if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || keyCode == KeyEvent.KEYCODE_D) {
            dx = 1f;
        } else if (keyCode == KeyEvent.KEYCODE_DPAD_UP || keyCode == KeyEvent.KEYCODE_W) {
            dy = -1f;
        } else if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN || keyCode == KeyEvent.KEYCODE_S) {
            dy = 1f;
        } else {
            return false;
        }

        updateFacingDirection(dx, dy);
        if (movePlayer(playerX + dx * TILE * 0.42f, playerY + dy * TILE * 0.42f)) {
            startWalkSound(System.currentTimeMillis());
        }
        return true;
    }

    private boolean handleInteractionDialogKey(int keyCode) {
        if (activeInteractionKind == InteractionKind.PLANT) {
            if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || keyCode == KeyEvent.KEYCODE_DPAD_DOWN) {
                playClickSound();
                selectNextSeed(1);
                return true;
            }
            if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT || keyCode == KeyEvent.KEYCODE_DPAD_UP) {
                playClickSound();
                selectNextSeed(-1);
                return true;
            }
        }
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || keyCode == KeyEvent.KEYCODE_DPAD_DOWN
                    || keyCode == KeyEvent.KEYCODE_DPAD_LEFT || keyCode == KeyEvent.KEYCODE_DPAD_UP) {
                playClickSound();
                toggleSwapTarget();
                return true;
            }
        }
        if (isPrimaryKey(keyCode)) {
            playClickSound();
            activateInteractionPrimary();
            return true;
        }
        if (isBackKey(keyCode)) {
            playClickSound();
            interactionDialogOpen = false;
            return true;
        }
        return false;
    }

    private boolean handleShopCatalogKey(int keyCode) {
        if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) {
            playClickSound();
            gameState.selectedSeedIndex = (gameState.selectedSeedIndex + 1) % SEED_NAMES.length;
            showMessage("Benih dipilih: " + SEED_NAMES[gameState.selectedSeedIndex]);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
            playClickSound();
            gameState.selectedSeedIndex = (gameState.selectedSeedIndex + SEED_NAMES.length - 1) % SEED_NAMES.length;
            showMessage("Benih dipilih: " + SEED_NAMES[gameState.selectedSeedIndex]);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_UP
                || keyCode == KeyEvent.KEYCODE_PLUS
                || keyCode == KeyEvent.KEYCODE_EQUALS
                || keyCode == KeyEvent.KEYCODE_NUMPAD_ADD) {
            playClickSound();
            adjustShopBundleQuantity(1);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN
                || keyCode == KeyEvent.KEYCODE_MINUS
                || keyCode == KeyEvent.KEYCODE_NUMPAD_SUBTRACT) {
            playClickSound();
            adjustShopBundleQuantity(-1);
            return true;
        }
        if (isPrimaryKey(keyCode)) {
            playClickSound();
            openShopPurchaseConfirm(gameState.selectedSeedIndex);
            return true;
        }
        if (isBackKey(keyCode)) {
            playClickSound();
            shopCatalogOpen = false;
            shopPurchaseConfirmOpen = false;
            return true;
        }
        return false;
    }

    private boolean handleShopPurchaseConfirmKey(int keyCode) {
        if (isPrimaryKey(keyCode)) {
            playClickSound();
            confirmShopPurchase();
            return true;
        }
        if (isBackKey(keyCode)) {
            playClickSound();
            shopPurchaseConfirmOpen = false;
            return true;
        }
        return true;
    }

    private static boolean isPrimaryKey(int keyCode) {
        return keyCode == KeyEvent.KEYCODE_ENTER
                || keyCode == KeyEvent.KEYCODE_SPACE
                || keyCode == KeyEvent.KEYCODE_DPAD_CENTER
                || keyCode == KeyEvent.KEYCODE_BUTTON_A;
    }

    private static boolean isBackKey(int keyCode) {
        return keyCode == KeyEvent.KEYCODE_BACK
                || keyCode == KeyEvent.KEYCODE_ESCAPE
                || keyCode == KeyEvent.KEYCODE_BUTTON_B;
    }

    private boolean handleMenuTouch(float x, float y, int pointerId) {
        RectF panel = settingsPanelBounds();
        if (!panel.contains(x, y)) {
            return false;
        }
        if (menuCloseButtonBounds().contains(x, y)) {
            playClickSound();
            menuOpen = false;
            finishAudioSliderDrag();
            return true;
        }
        if (settingsAudioTabBounds().contains(x, y)) {
            playClickSound();
            menuTab = MENU_TAB_SETTINGS;
            return true;
        }
        if (settingsAboutTabBounds().contains(x, y)) {
            playClickSound();
            menuTab = MENU_TAB_ABOUT;
            return true;
        }
        if (menuTab == MENU_TAB_SETTINGS) {
            int sliderIndex = audioSliderIndexAt(x, y);
            if (sliderIndex >= 0) {
                activeAudioSlider = sliderIndex;
                activeAudioSliderPointerId = pointerId;
                updateAudioVolumeFromX(sliderIndex, x);
                playClickSound();
                return true;
            }
        }
        if (menuTab == MENU_TAB_ABOUT && aboutGithubButtonBounds().contains(x, y)) {
            playClickSound();
            openCreatorGithub();
            return true;
        }
        return true;
    }

    private int audioSliderIndexAt(float x, float y) {
        for (int i = 0; i < 3; i++) {
            if (audioSliderTouchBounds(i).contains(x, y)) {
                return i;
            }
        }
        return -1;
    }

    private void updateAudioVolumeFromX(int index, float x) {
        RectF slider = audioSliderBounds(index);
        float value = clamp((x - slider.left) / Math.max(1f, slider.width()), 0f, 1f);
        value = Math.round(value * 100f) / 100f;
        if (index == 0) {
            masterVolume = value;
        } else if (index == 1) {
            musicVolume = value;
        } else if (index == 2) {
            sfxVolume = value;
        }
        applyAudioSettings();
        invalidate();
    }

    private void finishAudioSliderDrag() {
        if (activeAudioSlider < 0) {
            return;
        }
        int slider = activeAudioSlider;
        activeAudioSlider = -1;
        activeAudioSliderPointerId = -1;
        saveAudioSettings();
        showMessage(volumeSettingName(slider) + " " + Math.round(audioSliderValue(slider) * 100f) + "%.");
        invalidate();
    }

    private float audioSliderValue(int index) {
        if (index == 0) {
            return masterVolume;
        }
        if (index == 1) {
            return musicVolume;
        }
        return sfxVolume;
    }

    private String volumeSettingName(int index) {
        if (index == 0) {
            return "Master volume";
        }
        if (index == 1) {
            return "Music volume";
        }
        return "SFX volume";
    }

    private void logoutWallet() {
        walletAddress = "";
        walletNativeBalance = "";
        walletTaniBalance = 0;
        walletTaniBalanceAvailable = false;
        preferences.edit()
                .remove(PREF_WALLET_ADDRESS)
                .putBoolean(PREF_DEFAULT_WALLET_DISABLED, true)
                .apply();
        chainStatus = "Wallet logout. Mode lokal aktif.";
        chainPanelUntilMs = System.currentTimeMillis() + 3600L;
        showMessage("Wallet logout. Mode lokal aktif.");
        invalidate();
    }

    private void openCreatorGithub() {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/rhmatzeka"));
        if (!(getContext() instanceof Activity)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        try {
            getContext().startActivity(intent);
            showMessage("Membuka GitHub rhmatzeka.");
        } catch (RuntimeException e) {
            showErrorMessage("Tidak bisa membuka GitHub di perangkat ini.");
        }
    }

    private boolean handleBackpackButtonTouch(float x, float y) {
        if (!backpackButtonBounds().contains(x, y)) {
            return false;
        }
        playClickSound();
        openBackpackPanel();
        return true;
    }

    private void openBackpackPanel() {
        backpackOpen = true;
        menuOpen = false;
        chainHistoryOpen = false;
        interactionDialogOpen = false;
        shopCatalogOpen = false;
        shopPurchaseConfirmOpen = false;
        shopUntilMs = 0L;
        finishAudioSliderDrag();
        invalidate();
    }

    private boolean handleBackpackTouch(float x, float y) {
        RectF panel = backpackPanelBounds();
        if (backpackCloseButtonBounds().contains(x, y) || !panel.contains(x, y)) {
            playClickSound();
            backpackOpen = false;
            invalidate();
            return true;
        }
        return true;
    }

    private boolean handleChainHistoryButtonTouch(float x, float y) {
        if (!chainHistoryButtonBounds().contains(x, y)) {
            return false;
        }
        playClickSound();
        openChainHistoryDialog();
        return true;
    }

    private void openChainHistoryDialog() {
        chainHistoryOpen = true;
        menuOpen = false;
        backpackOpen = false;
        interactionDialogOpen = false;
        shopCatalogOpen = false;
        shopPurchaseConfirmOpen = false;
        shopUntilMs = 0L;
        invalidate();
    }

    private boolean handleChainHistoryDialogTouch(float x, float y) {
        RectF panel = chainHistoryDialogBounds();
        if (chainHistoryDialogCloseBounds().contains(x, y) || !panel.contains(x, y)) {
            playClickSound();
            chainHistoryOpen = false;
            invalidate();
            return true;
        }

        if (!chainHistory.isEmpty() && chainHistoryDialogClearAllBounds().contains(x, y)) {
            playClickSound();
            clearChainHistory();
            return true;
        }

        int rows = visibleChainHistoryDialogRows();
        for (int i = 0; i < rows; i++) {
            if (chainHistoryDialogRowBounds(i).contains(x, y)) {
                playClickSound();
                if (chainHistoryRowDeleteBounds(i).contains(x, y)) {
                    deleteChainHistoryAt(i);
                    return true;
                }
                openEtherscanTransaction(chainHistory.get(i));
                return true;
            }
        }
        playClickSound();
        showMessage(chainHistory.isEmpty() ? "Belum ada transaksi." : "Pilih transaksi yang sudah punya hash.");
        return true;
    }

    private void clearChainHistory() {
        chainHistory.clear();
        chainHistoryStore.save(chainHistory);
        showMessage("Semua riwayat transaksi dihapus.");
        invalidate();
    }

    private void deleteChainHistoryAt(int index) {
        if (index < 0 || index >= chainHistory.size()) {
            return;
        }
        chainHistory.remove(index);
        chainHistoryStore.save(chainHistory);
        showMessage("Riwayat transaksi dihapus.");
        invalidate();
    }

    private void openEtherscanTransaction(ChainHistoryEntry entry) {
        if (!BlockchainClient.isValidTransactionHash(entry.txHash)) {
            showMessage(missingTransactionHashMessage());
            invalidate();
            return;
        }
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://sepolia.etherscan.io/tx/" + entry.txHash));
        if (!(getContext() instanceof Activity)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        try {
            getContext().startActivity(intent);
            chainHistoryOpen = false;
            showMessage("Membuka Etherscan " + BlockchainClient.shortTransactionHash(entry.txHash));
        } catch (RuntimeException e) {
            showErrorMessage("Tidak bisa membuka Etherscan di perangkat ini.");
        }
        invalidate();
    }

    private String missingTransactionHashMessage() {
        if (!blockchainClient.hasGameApi()) {
            return "Belum on-chain: signer backend belum diset.";
        }
        return "Belum ada hash Sepolia. Pastikan signer aktif, lalu buat aksi baru.";
    }

    private boolean handleInteractionDialogTouch(float x, float y) {
        if (activeInteractionKind == InteractionKind.PLANT) {
            for (int i = 0; i < SEED_NAMES.length; i++) {
                if (plantSeedOptionBounds(i).contains(x, y)) {
                    playClickSound();
                    gameState.selectedSeedIndex = i;
                    showMessage("Benih dipilih: " + SEED_NAMES[gameState.selectedSeedIndex]);
                    return true;
                }
            }
            if (interactionSellLandButtonBounds().contains(x, y)) {
                playClickSound();
                activeInteractionKind = InteractionKind.SELL_LAND;
                return true;
            }
        }
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            if (swapAssetMenuOpen) {
                return handleSwapAssetMenuTouch(x, y);
            }
            if (swapChipBounds(true).contains(x, y)) {
                playClickSound();
                openSwapAssetMenu(true);
                return true;
            }
            if (swapChipBounds(false).contains(x, y)) {
                playClickSound();
                openSwapAssetMenu(false);
                return true;
            }
            if (swapAmountBounds(true).contains(x, y)) {
                playClickSound();
                openSwapAmountDialog();
                return true;
            }
            if (swapSwitchButtonBounds().contains(x, y)) {
                playClickSound();
                toggleSwapTarget();
                return true;
            }
        }
        if (interactionPrimaryButtonBounds().contains(x, y)) {
            playClickSound();
            activateInteractionPrimary();
            return true;
        }
        if (interactionSecondaryButtonBounds().contains(x, y)) {
            playClickSound();
            interactionDialogOpen = false;
            return true;
        }
        return true;
    }

    private boolean handleSwapAssetMenuTouch(float x, float y) {
        boolean from = swapAssetMenuFrom;
        for (int i = 0; i < swapAssetOptionCount(from); i++) {
            if (swapAssetOptionBounds(from, i).contains(x, y)) {
                playClickSound();
                int asset = swapAssetOptionAsset(from, i);
                if (!isSwapAssetOptionEnabled(from, asset)) {
                    showMessage(swapAssetSymbol(asset) + " input belum aktif.");
                    invalidate();
                    return true;
                }
                swapAssetMenuOpen = false;
                if (from) {
                    selectSwapInputAsset(asset);
                } else {
                    selectSwapOutputAsset(asset);
                }
                invalidate();
                return true;
            }
        }
        swapAssetMenuOpen = false;
        invalidate();
        return true;
    }

    private void selectNextSeed(int direction) {
        gameState.selectedSeedIndex = (gameState.selectedSeedIndex + direction + SEED_NAMES.length) % SEED_NAMES.length;
        showMessage("Benih dipilih: " + SEED_NAMES[gameState.selectedSeedIndex]);
    }

    private void selectSwapTarget(int target) {
        gameState.swapTarget = target == SWAP_TARGET_ETH ? SWAP_TARGET_ETH : SWAP_TARGET_TANI;
        gameState.swapFromAsset = SWAP_ASSET_COIN;
        saveGameState();
        showMessage("Output swap: " + swapTargetLabel());
    }

    private void selectSwapInputAsset(int asset) {
        gameState.swapFromAsset = asset == SWAP_ASSET_ETH ? SWAP_ASSET_ETH : SWAP_ASSET_COIN;
        ensureSwapAmountWithinBalance();
        showMessage("Input swap: " + swapAssetName(selectedSwapFromAsset()));
    }

    private void selectSwapOutputAsset(int asset) {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH && asset == SWAP_ASSET_COIN) {
            showMessage("Output swap: Game Coin");
            return;
        }
        if (asset == SWAP_ASSET_ETH) {
            selectSwapTarget(SWAP_TARGET_ETH);
            return;
        }
        selectSwapTarget(SWAP_TARGET_TANI);
    }

    private void openSwapAssetMenu(boolean from) {
        swapAssetMenuOpen = true;
        swapAssetMenuFrom = from;
        invalidate();
    }

    private void toggleSwapTarget() {
        swapSwitchAnimStartMs = System.currentTimeMillis();
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            selectSwapInputAsset(SWAP_ASSET_COIN);
            return;
        }
        selectSwapTarget(gameState.swapTarget == SWAP_TARGET_ETH ? SWAP_TARGET_TANI : SWAP_TARGET_ETH);
    }

    private String swapTargetLabel() {
        return gameState.swapTarget == SWAP_TARGET_ETH ? "ETH" : "TANI";
    }

    String selectedSwapOutputText() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return selectedSwapInputAmount() + " Game Coin";
        }
        return selectedSwapOutputAmount() + " " + swapTargetLabel() + " Sepolia";
    }

    private String selectedSwapInputAmountText() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return estimatedEthSwapAmount(selectedSwapInputAmount());
        }
        return String.valueOf(selectedSwapInputAmount());
    }

    int selectedSwapInputAmount() {
        int maxAmount = maxSwapCoinAmount();
        if (maxAmount <= 0) {
            return 0;
        }
        if (gameState.swapAmount <= 0) {
            return maxAmount;
        }
        return clampInt(gameState.swapAmount, 1, maxAmount);
    }

    private void ensureSwapAmountWithinBalance() {
        int maxAmount = maxSwapCoinAmount();
        if (maxAmount <= 0) {
            gameState.swapAmount = 0;
        } else if (gameState.swapAmount <= 0 || gameState.swapAmount > maxAmount) {
            gameState.swapAmount = maxAmount;
        }
        saveGameState();
    }

    int maxSwapCoinAmount() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return maxEthFundingCoins();
        }
        return Math.max(0, gameState.coins);
    }

    private String selectedSwapOutputAmount() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return String.valueOf(selectedSwapInputAmount());
        }
        return swapOutputAmount(selectedSwapInputAmount());
    }

    private String swapOutputAmount(int coinAmount) {
        if (gameState.swapTarget == SWAP_TARGET_ETH) {
            return estimatedEthSwapAmount(coinAmount);
        }
        return String.valueOf(coinAmount * COIN_SWAP_RATE);
    }

    private String swapOutputName() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return "Game Coin";
        }
        return gameState.swapTarget == SWAP_TARGET_ETH ? "Sepolia ETH" : "TANI Sepolia";
    }

    private int selectedSwapToAsset() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return SWAP_ASSET_COIN;
        }
        return gameState.swapTarget == SWAP_TARGET_ETH ? SWAP_ASSET_ETH : SWAP_ASSET_TANI;
    }

    int selectedSwapFromAsset() {
        return gameState.swapFromAsset == SWAP_ASSET_ETH ? SWAP_ASSET_ETH : SWAP_ASSET_COIN;
    }

    private String swapAssetSymbol(int asset) {
        if (asset == SWAP_ASSET_ETH) {
            return "ETH";
        }
        if (asset == SWAP_ASSET_TANI) {
            return "TANI";
        }
        return "COIN";
    }

    private String swapAssetName(int asset) {
        if (asset == SWAP_ASSET_ETH) {
            return "Sepolia ETH";
        }
        if (asset == SWAP_ASSET_TANI) {
            return "TANI Sepolia";
        }
        return "Game Coin";
    }

    private int swapAssetOptionCount(boolean from) {
        if (!from && selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return 1;
        }
        return from ? 3 : 2;
    }

    private int swapAssetOptionAsset(boolean from, int index) {
        if (!from && selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            return SWAP_ASSET_COIN;
        }
        if (from) {
            if (index == 1) {
                return SWAP_ASSET_TANI;
            }
            if (index == 2) {
                return SWAP_ASSET_ETH;
            }
            return SWAP_ASSET_COIN;
        }
        return index == 1 ? SWAP_ASSET_ETH : SWAP_ASSET_TANI;
    }

    private boolean isSwapAssetOptionEnabled(boolean from, int asset) {
        if (!from) {
            return true;
        }
        return asset == SWAP_ASSET_COIN || asset == SWAP_ASSET_ETH;
    }

    private void activateInteractionPrimary() {
        if (activeInteractionKind == InteractionKind.SHOP) {
            interactionDialogOpen = false;
            shopCatalogOpen = true;
            return;
        }
        if (activeInteractionKind == InteractionKind.SELL_HARVEST) {
            interactionDialogOpen = false;
            sellHarvestToWallet();
            return;
        }
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            interactionDialogOpen = false;
            if (selectedSwapFromAsset() == SWAP_ASSET_COIN
                    && gameState.swapTarget == SWAP_TARGET_ETH
                    && isConnectedWalletBackendSigner()) {
                chainStatus = "Wallet ini signer backend. Ganti wallet pemain supaya payout ETH bisa bertambah.";
                chainPanelUntilMs = System.currentTimeMillis() + 5200L;
                performWallet();
                return;
            }
            performSwapToken();
            return;
        }
        if (activeInteractionKind == InteractionKind.SELL_LAND) {
            interactionDialogOpen = false;
            if (canSellActiveLand()) {
                sellLand(activeInteractionPlot);
            }
            return;
        }
        if (activeInteractionKind == InteractionKind.WAIT_CROP) {
            interactionDialogOpen = false;
            return;
        }
        if (activeInteractionKind == InteractionKind.PLANT && gameState.seedCounts[gameState.selectedSeedIndex] <= 0) {
            interactionDialogOpen = false;
            shopCatalogOpen = true;
            return;
        }
        performPlotAction(activeInteractionPlot);
        interactionDialogOpen = false;
    }

    private boolean handleShopCatalogTouch(float x, float y) {
        if (shopCloseButtonBounds().contains(x, y)) {
            playClickSound();
            shopCatalogOpen = false;
            shopPurchaseConfirmOpen = false;
            return true;
        }
        if (shopQuantityMinusBounds().contains(x, y)) {
            playClickSound();
            adjustShopBundleQuantity(-1);
            return true;
        }
        if (shopQuantityPlusBounds().contains(x, y)) {
            playClickSound();
            adjustShopBundleQuantity(1);
            return true;
        }
        for (int i = 0; i < SEED_NAMES.length; i++) {
            if (shopBuyButtonBounds(i).contains(x, y)) {
                playClickSound();
                openShopPurchaseConfirm(i);
                return true;
            }
            if (shopCardBounds(i).contains(x, y)) {
                playClickSound();
                gameState.selectedSeedIndex = i;
                showMessage("Benih dipilih: " + SEED_NAMES[gameState.selectedSeedIndex]);
                return true;
            }
        }
        return true;
    }

    private boolean handleShopPurchaseConfirmTouch(float x, float y) {
        if (shopPurchaseConfirmPrimaryBounds().contains(x, y)) {
            playClickSound();
            confirmShopPurchase();
            return true;
        }
        if (shopPurchaseConfirmSecondaryBounds().contains(x, y)) {
            playClickSound();
            shopPurchaseConfirmOpen = false;
            return true;
        }
        return true;
    }

    private void openShopPurchaseConfirm(int seedIndex) {
        gameState.selectedSeedIndex = seedIndex;
        shopPurchaseSeedIndex = seedIndex;
        shopPurchaseConfirmOpen = true;
    }

    private void confirmShopPurchase() {
        int seedIndex = validShopPurchaseSeedIndex();
        shopPurchaseConfirmOpen = false;
        buySeedsFromShop(seedIndex);
    }

    private int validShopPurchaseSeedIndex() {
        if (shopPurchaseSeedIndex < 0 || shopPurchaseSeedIndex >= SEED_NAMES.length) {
            return gameState.selectedSeedIndex;
        }
        return shopPurchaseSeedIndex;
    }

    private void adjustShopBundleQuantity(int delta) {
        gameState.shopBundleQuantity = (int) clamp(gameState.shopBundleQuantity + delta, 1, MAX_SHOP_BUNDLE_QUANTITY);
        showMessage("Jumlah paket: x" + gameState.shopBundleQuantity + " (" + selectedSeedTotalAmount() + " benih)");
    }

    private void updateJoystick(float x, float y) {
        float dx = x - joyBaseX;
        float dy = y - joyBaseY;
        float distance = (float) Math.hypot(dx, dy);
        float radius = JOYSTICK_TRAVEL;
        if (distance > radius) {
            dx = dx / distance * radius;
            dy = dy / distance * radius;
        }
        joyX = joyBaseX + dx;
        joyY = joyBaseY + dy;
    }

    private boolean isInsideJoystickArea(float x, float y) {
        float baseX = joystickBaseX();
        float baseY = joystickBaseY();
        float wideArea = JOYSTICK_RADIUS * 2.35f;
        return x < getWidth() * 0.42f
                && y > getHeight() * 0.42f
                && Math.hypot(x - baseX, y - baseY) <= wideArea;
    }

    private boolean isInsideAction(float x, float y) {
        float cx = getWidth() - 92;
        float cy = getHeight() - 86;
        return Math.hypot(x - cx, y - cy) <= 52;
    }

    private boolean isInsideWallet(float x, float y) {
        return walletButtonBounds().contains(x, y);
    }

    private void openInteractionDialog(InteractionKind kind) {
        activeInteractionKind = kind;
        activeInteractionPlot = selectedPlot;
        interactionDialogOpen = true;
        shopCatalogOpen = false;
        menuOpen = false;
        backpackOpen = false;
        swapAssetMenuOpen = false;
        if (kind == InteractionKind.SWAP_TOKEN) {
            if (!walletAddress.isEmpty() && walletNativeBalance.isEmpty() && !checkingChain) {
                refreshWalletState(true);
            }
            ensureSwapAmountWithinBalance();
        }
    }

    private String interactionTitle() {
        switch (activeInteractionKind) {
            case SHOP:
                return "Ucup";
            case SELL_HARVEST:
                return "Jual Panen";
            case SWAP_TOKEN:
                return "Swap Token";
            case BUY_LAND:
                return "Lahan";
            case PLANT:
                return "Tanam";
            case SELL_LAND:
                return "Jual Lahan";
            case WAIT_CROP:
                return "Tumbuh";
            case HARVEST:
                return "Panen";
            default:
                return "Interaksi";
        }
    }

    private String interactionBody(long now) {
        switch (activeInteractionKind) {
            case SHOP:
                return "Pilih benih yang mau dibeli memakai Game Coin.";
            case SELL_HARVEST:
                if (walletAddress.isEmpty()) {
                    return "Connect wallet dulu sebelum jual hasil panen.";
                }
                return gameState.harvests > 0
                        ? "Jual " + gameState.harvests + " hasil panen? Coin akan masuk ke wallet."
                        : "Belum ada hasil panen untuk dijual.";
            case SWAP_TOKEN:
                if (walletAddress.isEmpty()) {
                    return "Connect wallet dulu supaya saldo Sepolia bisa dicek.";
                }
                if (selectedSwapFromAsset() == SWAP_ASSET_COIN
                        && gameState.swapTarget == SWAP_TARGET_ETH
                        && isConnectedWalletBackendSigner()) {
                    return "Wallet ini signer backend. Ganti wallet pemain supaya payout ETH bisa masuk.";
                }
                int swapAmount = selectedSwapInputAmount();
                if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
                    if (walletNativeBalance.isEmpty()) {
                        return "Sync wallet dulu supaya saldo ETH Sepolia terbaca.";
                    }
                    return swapAmount > 0
                            ? selectedSwapInputAmountText() + " ETH Sepolia siap menjadi " + selectedSwapOutputText() + "."
                            : "Saldo ETH Sepolia belum cukup untuk isi Game Coin.";
                }
                return swapAmount > 0
                        ? swapAmount + " Game Coin siap menjadi " + selectedSwapOutputText() + "."
                        : "Coin belum ada untuk diswap.";
            case BUY_LAND:
                return "Lahan ini bisa dibeli seharga " + LAND_BUY_PRICE + " coin.";
            case PLANT:
                return gameState.seedCounts[gameState.selectedSeedIndex] > 0
                        ? "Tanam " + SEED_NAMES[gameState.selectedSeedIndex] + " atau jual lahan kosong +" + LAND_SELL_PRICE + " coin."
                        : "Benih habis. Buka toko atau jual lahan kosong +" + LAND_SELL_PRICE + " coin.";
            case SELL_LAND:
                if (!canSellActiveLand()) {
                    return "Lahan terakhir atau lahan berisi tanaman tidak bisa dijual.";
                }
                return "Jual lahan kosong ini? Coin akan bertambah +" + LAND_SELL_PRICE + ".";
            case WAIT_CROP:
                return "Tanaman siap dalam " + activeCropRemainingSeconds(now) + " detik.";
            case HARVEST:
                return "Tanaman sudah siap. Panen sekarang?";
            default:
                return "Pilih aksi untuk melanjutkan.";
        }
    }

    private String interactionPrimaryText() {
        switch (activeInteractionKind) {
            case SHOP:
                return "Buka toko";
            case SELL_HARVEST:
                if (walletAddress.isEmpty()) {
                    return "Connect wallet";
                }
                return gameState.harvests > 0 ? "Ya, jual panen" : "Oke";
            case SWAP_TOKEN:
                if (walletAddress.isEmpty()) {
                    return "Connect wallet";
                }
                if (selectedSwapFromAsset() == SWAP_ASSET_COIN
                        && gameState.swapTarget == SWAP_TARGET_ETH
                        && isConnectedWalletBackendSigner()) {
                    return "Ganti Wallet";
                }
                if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
                    return selectedSwapInputAmount() > 0 ? "Isi Game Coin" : "Sync wallet";
                }
                return selectedSwapInputAmount() > 0 ? "Swap ke " + swapTargetLabel() : "Oke";
            case BUY_LAND:
                return "Ya, beli lahan";
            case PLANT:
                return gameState.seedCounts[gameState.selectedSeedIndex] > 0 ? "Ya, tanam " + SEED_NAMES[gameState.selectedSeedIndex] : "Buka toko";
            case SELL_LAND:
                return canSellActiveLand() ? "Ya, jual lahan" : "Oke";
            case WAIT_CROP:
                return "Oke";
            case HARVEST:
                return "Panen";
            default:
                return "Lanjut";
        }
    }

    private String interactionSecondaryText() {
        switch (activeInteractionKind) {
            case BUY_LAND:
            case PLANT:
            case SELL_LAND:
            case HARVEST:
            case SELL_HARVEST:
            case SWAP_TOKEN:
                return "Batal";
            default:
                return "Tidak apa-apa";
        }
    }

    private int activeCropRemainingSeconds(long now) {
        if (activeInteractionPlot < 0 || activeInteractionPlot >= gameState.plots.size()) {
            return 0;
        }
        Plot plot = gameState.plots.get(activeInteractionPlot);
        return Math.max(0, (int) ((GROW_TIME_MS - (now - plot.plantedAtMs)) / 1000L));
    }

    private RectF walletButtonBounds() {
        return hudRenderer.walletButtonBounds(getWidth(), topMenuTop(), topMenuButtonSize());
    }

    private RectF interactionDialogPanelBounds() {
        float w = activeInteractionKind == InteractionKind.SWAP_TOKEN
                ? clamp(getWidth() * 0.72f, 840f, 1260f)
                : clamp(getWidth() * 0.58f, 720f, 900f);
        float h;
        if (activeInteractionKind == InteractionKind.PLANT) {
            h = clamp(getHeight() * 0.58f, 560f, 650f);
        } else if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            h = clamp(getHeight() * 0.76f, 700f, 800f);
        } else {
            h = clamp(getHeight() * 0.45f, 410f, 510f);
        }
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF interactionBodyBoxBounds() {
        RectF panel = interactionDialogPanelBounds();
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            return new RectF(panel.left + 58f, panel.top + 132f, panel.right - 58f, panel.top + 204f);
        }
        return new RectF(panel.left + 58f, panel.top + 178f, panel.right - 58f, panel.top + 276f);
    }

    private RectF plantSeedOptionBounds(int index) {
        RectF panel = interactionDialogPanelBounds();
        float left = panel.left + 58f;
        float right = panel.right - 58f;
        float gap = 14f;
        float width = (right - left - gap * 3f) / 4f;
        float top = panel.top + 332f;
        return new RectF(left + index * (width + gap), top, left + index * (width + gap) + width, top + 78f);
    }

    private RectF swapFromCardBounds() {
        RectF panel = interactionDialogPanelBounds();
        return new RectF(panel.left + 58f, panel.top + 228f, panel.right - 58f, panel.top + 392f);
    }

    private RectF swapToCardBounds() {
        RectF panel = interactionDialogPanelBounds();
        return new RectF(panel.left + 58f, panel.top + 430f, panel.right - 58f, panel.top + 594f);
    }

    private RectF swapSwitchButtonBounds() {
        RectF from = swapFromCardBounds();
        float size = 68f;
        float left = from.centerX() - size * 0.5f;
        float top = from.bottom - 15f;
        return new RectF(left, top, left + size, top + size);
    }

    private RectF swapChipBounds(boolean from) {
        RectF card = from ? swapFromCardBounds() : swapToCardBounds();
        float width = clamp(card.width() * 0.48f, 340f, 520f);
        return new RectF(card.left + 30f, card.top + 54f, card.left + 30f + width, card.bottom - 16f);
    }

    private RectF swapAmountBounds(boolean from) {
        RectF card = from ? swapFromCardBounds() : swapToCardBounds();
        return new RectF(card.right - card.width() * 0.36f - 30f, card.top + 54f, card.right - 24f, card.bottom - 16f);
    }

    private RectF swapAssetMenuBounds(boolean from) {
        RectF chip = swapChipBounds(from);
        RectF card = from ? swapFromCardBounds() : swapToCardBounds();
        int rows = swapAssetOptionCount(from);
        float width = Math.min(560f, card.right - chip.left - 30f);
        float top = chip.bottom + 10f;
        return new RectF(chip.left, top, chip.left + width, top + rows * 84f + 18f);
    }

    private RectF swapAssetOptionBounds(boolean from, int index) {
        RectF menu = swapAssetMenuBounds(from);
        float top = menu.top + 10f + index * 84f;
        return new RectF(menu.left + 10f, top, menu.right - 10f, top + 74f);
    }

    private RectF interactionPrimaryButtonBounds() {
        RectF panel = interactionDialogPanelBounds();
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            float height = 86f;
            float primaryWidth = clamp(panel.width() * 0.43f, 400f, 470f);
            float secondaryWidth = clamp(panel.width() * 0.28f, 260f, 320f);
            float gap = 30f;
            float totalWidth = primaryWidth + secondaryWidth + gap;
            float left = panel.centerX() - totalWidth * 0.5f;
            float top = panel.bottom - 112f;
            top = Math.max(top, swapToCardBounds().bottom + 18f);
            top = Math.min(top, panel.bottom - height - 10f);
            return new RectF(left, top, left + primaryWidth, top + height);
        }
        float height = 78f;
        if (activeInteractionKind == InteractionKind.PLANT) {
            float gap = 18f;
            float width = Math.min(340f, panel.width() * 0.36f);
            float sellWidth = Math.min(240f, panel.width() * 0.27f);
            float cancelWidth = Math.min(170f, panel.width() * 0.20f);
            float totalWidth = width + sellWidth + cancelWidth + gap * 2f;
            float left = panel.centerX() - totalWidth * 0.5f;
            float top = panel.bottom - 126f;
            return new RectF(left, top, left + width, top + height);
        }
        float width = Math.min(380f, panel.width() * 0.43f);
        float gap = 24f;
        float left = panel.centerX() - width - gap * 0.5f;
        float top = panel.bottom - (activeInteractionKind == InteractionKind.SWAP_TOKEN ? 96f : 126f);
        return new RectF(left, top, left + width, top + height);
    }

    private RectF interactionSellLandButtonBounds() {
        RectF primary = interactionPrimaryButtonBounds();
        RectF panel = interactionDialogPanelBounds();
        float gap = 18f;
        float width = Math.min(240f, panel.width() * 0.27f);
        return new RectF(primary.right + gap, primary.top, primary.right + gap + width, primary.bottom);
    }

    private RectF interactionSecondaryButtonBounds() {
        if (activeInteractionKind == InteractionKind.PLANT) {
            RectF sell = interactionSellLandButtonBounds();
            RectF panel = interactionDialogPanelBounds();
            float gap = 18f;
            float width = Math.min(170f, panel.width() * 0.20f);
            return new RectF(sell.right + gap, sell.top, sell.right + gap + width, sell.bottom);
        }
        RectF primary = interactionPrimaryButtonBounds();
        if (activeInteractionKind == InteractionKind.SWAP_TOKEN) {
            RectF panel = interactionDialogPanelBounds();
            float gap = 30f;
            float width = clamp(panel.width() * 0.28f, 260f, 320f);
            return new RectF(primary.right + gap, primary.top, primary.right + gap + width, primary.bottom);
        }
        float gap = 24f;
        return new RectF(primary.right + gap, primary.top, primary.right + gap + primary.width() * 0.66f, primary.bottom);
    }

    private RectF shopCatalogPanelBounds() {
        float w = clamp(getWidth() * 0.70f, 900f, 1480f);
        float h = clamp(getHeight() * 0.76f, 560f, 760f);
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF shopPurchaseConfirmPanelBounds() {
        float w = clamp(getWidth() * 0.40f, 580f, 760f);
        float h = 350f;
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF shopPurchaseConfirmPrimaryBounds() {
        RectF panel = shopPurchaseConfirmPanelBounds();
        float width = Math.min(250f, panel.width() * 0.36f);
        float height = 64f;
        float gap = 22f;
        float left = panel.centerX() - width - gap * 0.5f;
        float top = panel.bottom - 92f;
        return new RectF(left, top, left + width, top + height);
    }

    private RectF shopPurchaseConfirmSecondaryBounds() {
        RectF primary = shopPurchaseConfirmPrimaryBounds();
        float gap = 22f;
        return new RectF(primary.right + gap, primary.top, primary.right + gap + primary.width() * 0.78f, primary.bottom);
    }

    private RectF shopCloseButtonBounds() {
        RectF panel = shopCatalogPanelBounds();
        float size = 88f;
        return new RectF(panel.right - size - 36f, panel.top + 44f, panel.right - 36f, panel.top + 44f + size);
    }

    private RectF shopQuantityMinusBounds() {
        RectF panel = shopCatalogPanelBounds();
        float top = panel.top + 322f;
        float size = 54f;
        return new RectF(panel.right - 238f, top, panel.right - 238f + size, top + size);
    }

    private RectF shopQuantityValueBounds() {
        RectF minus = shopQuantityMinusBounds();
        return new RectF(minus.right + 10f, minus.top, minus.right + 72f, minus.bottom);
    }

    private RectF shopQuantityPlusBounds() {
        RectF value = shopQuantityValueBounds();
        float size = value.height();
        return new RectF(value.right + 10f, value.top, value.right + 10f + size, value.bottom);
    }

    private RectF shopCardBounds(int index) {
        RectF panel = shopCatalogPanelBounds();
        float gap = 24f;
        float cardW = (panel.width() - 104f - gap) * 0.5f;
        float cardTop = panel.top + Math.min(432f, panel.height() * 0.56f);
        float rowGap = 18f;
        float cardH = Math.max(100f, Math.min(168f, (panel.bottom - cardTop - 24f - rowGap) * 0.5f));
        float left = panel.left + 52f + (index % 2) * (cardW + gap);
        float top = cardTop + (index / 2) * (cardH + rowGap);
        return new RectF(left, top, left + cardW, top + cardH);
    }

    private RectF shopBuyButtonBounds(int seedIndex) {
        RectF card = shopCardBounds(seedIndex);
        return new RectF(card.right - 138f, card.bottom - 68f, card.right - 28f, card.bottom - 24f);
    }

    private void performAction() {
        if (selectedPlot >= 0) {
            openInteractionDialog(plotInteractionKind(gameState.plots.get(selectedPlot), System.currentTimeMillis()));
            return;
        }
        if (isNearShop()) {
            openInteractionDialog(InteractionKind.SHOP);
            return;
        }
        if (isNearSellHouse()) {
            openInteractionDialog(InteractionKind.SELL_HARVEST);
            return;
        }
        if (isNearSwapHouse()) {
            openInteractionDialog(InteractionKind.SWAP_TOKEN);
            return;
        }
        showErrorMessage("Dekati lahan, shop, rumah jual, atau rumah swap dulu.");
    }

    private void showShopNpcBubble() {
        shopNpcBubbleUntilMs = System.currentTimeMillis() + SHOP_NPC_BUBBLE_MS;
        invalidate();
    }

    private void performPlotAction(int plotIndex) {
        long now = System.currentTimeMillis();
        FarmingResult result = farmingSystem.performPlotAction(gameState, plotIndex, now);
        if (!result.success) {
            showErrorMessage(result.message);
            return;
        }
        if (result.harvestEffect) {
            startHarvestEffect(result.harvestPlot, result.harvestSeedIndex, result.harvestAmount, result.harvestAtMs);
        }
        queueChainAction(result.chainAction);
        saveGameState();
        showSuccessPopup(result.message);
    }

    private void sellLand(int plotIndex) {
        FarmingResult result = farmingSystem.sellLand(gameState, plotIndex);
        if (!result.success) {
            showErrorMessage(result.message);
            return;
        }
        queueChainAction(result.chainAction);
        saveGameState();
        showSuccessPopup(result.message);
    }

    private boolean canSellActiveLand() {
        return farmingSystem.canSellLand(gameState, activeInteractionPlot);
    }

    private void startHarvestEffect(Plot plot, int seedIndex, int amount, long now) {
        float centerX = plot.x + plot.w * 0.5f;
        float centerY = plot.y + plot.h * 0.52f;
        harvestEffects.add(new HarvestEffect(centerX, centerY, seedIndex, amount, now));
    }

    private void buySeedsFromShop(int seedIndex) {
        gameState.selectedSeedIndex = seedIndex;
        if (blockchainClient.hasGameApi()) {
            if (walletAddress.isEmpty()) {
                showErrorMessage("Connect wallet dulu supaya pembelian bisa dicatat on-chain.");
                performWallet();
                return;
            }
        }
        ShopPurchaseResult result = shopSystem.buySeeds(gameState, seedIndex);
        if (!result.success) {
            showErrorMessage(result.message);
            return;
        }
        queueChainAction(result.chainAction);
        saveGameState();
        showSuccessPopup(result.message);
    }

    private void sellHarvestToWallet() {
        if (walletAddress.isEmpty()) {
            showErrorMessage("Connect wallet dulu sebelum jual panen.");
            performWallet();
            return;
        }
        if (gameState.harvests <= 0) {
            showErrorMessage("Belum ada hasil panen untuk dijual.");
            return;
        }
        int soldHarvests = gameState.harvests;
        int earnedCoins = soldHarvests * HARVEST_SELL_PRICE;
        gameState.harvests = 0;
        gameState.coins += earnedCoins;
        queueChainAction(new ChainAction("SELL_CROP", 0, soldHarvests));
        saveGameState();
        showSuccessPopup(String.format(Locale.US,
                "Terjual %d panen. Coin wallet +%d.",
                soldHarvests,
                earnedCoins));
    }

    private void performSwapToken() {
        if (selectedSwapFromAsset() == SWAP_ASSET_ETH) {
            swapSepoliaEthToGameCoins();
            return;
        }
        swapCoinsToSepolia();
    }

    private void swapSepoliaEthToGameCoins() {
        if (walletAddress.isEmpty()) {
            showErrorMessage("Connect wallet dulu sebelum isi Game Coin dari Sepolia.");
            performWallet();
            return;
        }
        if (!blockchainClient.hasGameApi()) {
            showErrorMessage("Signer backend belum diset, isi Game Coin belum bisa punya tx hash.");
            return;
        }
        if (walletNativeBalance.isEmpty()) {
            refreshWalletState(true);
            showErrorMessage("Sync saldo ETH Sepolia dulu.");
            return;
        }
        int fundedCoins = selectedSwapInputAmount();
        if (fundedCoins <= 0) {
            showErrorMessage("Saldo ETH Sepolia belum cukup untuk isi Game Coin.");
            return;
        }
        ChainAction action = new ChainAction("SWAP_ETH_COIN", 0, fundedCoins);
        queueChainAction(action, 0);
        showMessage(String.format(Locale.US,
                "Mengirim isi coin %d dari %s ETH Sepolia.",
                fundedCoins,
                estimatedEthSwapAmount(fundedCoins)));
    }

    private void swapCoinsToSepolia() {
        if (walletAddress.isEmpty()) {
            showErrorMessage("Connect wallet dulu sebelum swap ke Sepolia.");
            performWallet();
            return;
        }
        if (!blockchainClient.hasGameApi()) {
            showErrorMessage("Signer backend Vercel belum diset, swap belum bisa on-chain.");
            return;
        }
        if (gameState.coins <= 0) {
            showErrorMessage("Coin belum ada untuk diswap.");
            return;
        }
        int swappedCoins = selectedSwapInputAmount();
        if (swappedCoins <= 0) {
            showErrorMessage("Masukkan jumlah coin yang mau diswap.");
            return;
        }
        boolean swapToEth = gameState.swapTarget == SWAP_TARGET_ETH;
        if (swapToEth && isConnectedWalletBackendSigner()) {
            chainStatus = "Wallet ini signer backend. Ganti wallet pemain supaya payout ETH bisa bertambah.";
            chainPanelUntilMs = System.currentTimeMillis() + 5200L;
            showErrorMessage("Ganti wallet pemain untuk menerima ETH.");
            return;
        }
        gameState.coins -= swappedCoins;
        if (gameState.swapAmount > gameState.coins) {
            gameState.swapAmount = gameState.coins;
        }
        queueChainAction(new ChainAction(swapToEth ? "SWAP_COIN_ETH" : "SWAP_COIN", 0, swappedCoins), swappedCoins);
        saveGameState();
        String output = swapOutputAmount(swappedCoins) + " " + (swapToEth ? "ETH" : "TANI");
        showMessage(String.format(Locale.US, "Mengirim swap %d coin ke Sepolia. Estimasi +%s.",
                swappedCoins,
                output));
    }

    private void openSwapAmountDialog() {
        swapAmountDialogController.open();
    }

    void performWallet() {
        menuOpen = false;
        backpackOpen = false;
        chainHistoryOpen = false;
        finishAudioSliderDrag();
        walletDialogController.showWalletDialog();
    }

    void connectWalletFromDeepLink(String address) {
        walletDialogController.connectWalletFromDeepLink(address);
    }

    String walletAddress() {
        return walletAddress;
    }

    String walletNativeBalance() {
        return walletNativeBalance;
    }

    int coinBalance() {
        return gameState.coins;
    }

    String walletConnectUrl() {
        return blockchainClient.walletConnectUrl();
    }

    void setChainStatus(String status, long visibleForMs) {
        chainStatus = status;
        chainPanelUntilMs = System.currentTimeMillis() + visibleForMs;
    }

    void setSwapAmount(int amount) {
        gameState.swapAmount = amount;
    }

    boolean storeWalletAddress(String address) {
        String cleaned = address.trim();
        boolean changed = !cleaned.equalsIgnoreCase(walletAddress);
        walletAddress = cleaned;
        if (changed) {
            walletNativeBalance = "";
            walletTaniBalance = 0;
            walletTaniBalanceAvailable = false;
            chainStatus = "Wallet pemain diganti: " + shortAddress(walletAddress) + ". Sync Sepolia...";
            chainPanelUntilMs = System.currentTimeMillis() + 4200L;
        }
        preferences.edit()
                .putString(PREF_WALLET_ADDRESS, walletAddress)
                .remove(PREF_DEFAULT_WALLET_DISABLED)
                .apply();
        return changed;
    }

    private void checkSepolia() {
        checkSepolia(true);
    }

    private void checkSepolia(boolean revealPanel) {
        if (checkingChain) {
            return;
        }
        if (!walletAddress.isEmpty()) {
            refreshWalletState(revealPanel);
            return;
        }
        checkingChain = true;
        chainStatus = "Cek Sepolia RPC...";
        blockchainClient.checkSepolia(result -> {
            checkingChain = false;
            chainStatus = result.message + " " + blockchainClient.contractSummary();
            if (!result.success) {
                playErrorSound();
            }
            if (revealPanel) {
                chainPanelUntilMs = System.currentTimeMillis() + 4500L;
            }
            invalidate();
        });
    }

    void refreshWalletState(boolean revealPanel) {
        if (checkingChain) {
            return;
        }
        if (walletAddress.isEmpty()) {
            chainStatus = "Connect wallet dulu untuk sync saldo.";
            if (revealPanel) {
                chainPanelUntilMs = System.currentTimeMillis() + 3600L;
            }
            return;
        }
        checkingChain = true;
        chainStatus = "Sync wallet Sepolia...";
        blockchainClient.loadWalletState(walletAddress, state -> {
            checkingChain = false;
            chainSignerAddress = state.signerAddress;
            chainStatus = state.message;
            walletNativeBalance = state.nativeEth;
            if (!state.success) {
                playErrorSound();
            }
            if (state.success && state.coinBalanceAvailable) {
                walletTaniBalance = state.coinBalance;
                walletTaniBalanceAvailable = true;
                repairLegacyWalletAutofill(walletTaniBalance);
            } else if (state.success) {
                walletTaniBalance = 0;
                walletTaniBalanceAvailable = false;
            }
            if (state.success && isConnectedWalletBackendSigner()) {
                chainStatus = state.message + " Wallet ini signer backend; pakai wallet pemain untuk payout ETH.";
            }
            if (revealPanel) {
                chainPanelUntilMs = System.currentTimeMillis() + 5200L;
            }
            invalidate();
        });
    }

    private void queueChainAction(ChainAction action) {
        queueChainAction(action, 0);
    }

    private void queueChainAction(ChainAction action, int refundCoinsOnFailure) {
        ChainHistoryEntry historyEntry = chainHistoryStore.add(chainHistory, action, initialChainHistoryStatus());
        chainPanelUntilMs = System.currentTimeMillis() + 2200L;
        if (!walletAddress.isEmpty() && blockchainClient.hasGameApi()) {
            pendingChainActions.add(action);
            blockchainClient.submitGameAction(walletAddress, action, result -> {
                pendingChainActions.remove(action);
                if (result.success) {
                    if (requiresSepoliaHash(action) && !BlockchainClient.isValidTransactionHash(result.txHash)) {
                        handleChainActionFailure(historyEntry, action, refundCoinsOnFailure, "Backend tidak mengembalikan tx hash.");
                        chainPanelUntilMs = System.currentTimeMillis() + 3600L;
                        invalidate();
                        return;
                    }
                    String status = BlockchainClient.isValidTransactionHash(result.txHash) ? "on-chain" : "dikirim";
                    chainHistoryStore.update(chainHistory, historyEntry, status, result.txHash);
                    chainStatus = result.message;
                    if ("SWAP_ETH_COIN".equals(action.type)) {
                        creditSepoliaEthFunding(action.amount);
                    }
                    showSwapChainSuccess(action);
                    if (actionUpdatesCoinBalance(action)) {
                        scheduleWalletRefreshAfterChainAction(action);
                    }
                } else {
                    handleChainActionFailure(historyEntry, action, refundCoinsOnFailure, result.message);
                }
                chainPanelUntilMs = System.currentTimeMillis() + 3600L;
                invalidate();
            });
        } else {
            chainStatus = localChainStatus(action);
            chainPanelUntilMs = System.currentTimeMillis() + 3600L;
            invalidate();
        }
    }

    private boolean requiresSepoliaHash(ChainAction action) {
        return "SWAP_ETH_COIN".equals(action.type)
                || "SWAP_COIN_ETH".equals(action.type)
                || "SWAP_COIN".equals(action.type);
    }

    private void handleChainActionFailure(ChainHistoryEntry historyEntry, ChainAction action, int refundCoinsOnFailure, String reason) {
        if (refundCoinsOnFailure > 0) {
            refundFailedSwapCoins(action, refundCoinsOnFailure, reason);
            chainHistoryStore.update(chainHistory, historyEntry, failedChainHistoryStatus(reason, "gagal; coin kembali"), "");
            return;
        }
        if ("SWAP_ETH_COIN".equals(action.type)) {
            String detail = conciseChainError(reason);
            chainHistoryStore.update(chainHistory, historyEntry, failedChainHistoryStatus(reason, "gagal isi coin"), "");
            chainStatus = action.label() + " gagal" + (detail.isEmpty() ? "." : ": " + detail);
            showErrorMessage(detail.isEmpty() ? "Isi coin gagal." : "Isi coin gagal: " + shortPopupDetail(detail));
            return;
        }
        chainHistoryStore.update(chainHistory, historyEntry, "belum sync", "");
        chainStatus = syncedLocalChainStatus(action, reason);
    }

    private String failedChainHistoryStatus(String reason, String fallback) {
        String detail = conciseChainError(reason);
        return detail.isEmpty() ? fallback : "gagal: " + detail;
    }

    private void creditSepoliaEthFunding(int fundedCoins) {
        if (fundedCoins <= 0) {
            return;
        }
        long totalCoins = Math.min(Integer.MAX_VALUE, (long) gameState.coins + fundedCoins);
        gameState.coins = (int) totalCoins;
        gameState.swapFromAsset = SWAP_ASSET_COIN;
        gameState.swapAmount = gameState.coins;
        recordLocalEthFunding(fundedCoins);
        saveGameState();
    }

    private void showSwapChainSuccess(ChainAction action) {
        if ("SWAP_ETH_COIN".equals(action.type)) {
            showSuccessPopup(String.format(Locale.US,
                    "Game Coin +%d dari %s ETH Sepolia.",
                    action.amount,
                    estimatedEthSwapAmount(action.amount)));
        } else if ("SWAP_COIN_ETH".equals(action.type)) {
            showSuccessPopup(String.format(Locale.US,
                    "Swap %d coin ke %s ETH terkirim.",
                    action.amount,
                    estimatedEthSwapAmount(action.amount)));
        } else if ("SWAP_COIN".equals(action.type)) {
            showSuccessPopup("Swap " + action.amount + " coin ke TANI terkirim.");
        }
    }

    private void scheduleWalletRefreshAfterChainAction(ChainAction action) {
        postDelayed(() -> refreshWalletState(true), 9000L);
        if ("SWAP_COIN_ETH".equals(action.type) || "SWAP_ETH_COIN".equals(action.type)) {
            postDelayed(() -> refreshWalletState(true), 18000L);
        }
    }

    private void refundFailedSwapCoins(ChainAction action, int refundCoins, String reason) {
        long restoredCoins = Math.min(Integer.MAX_VALUE, (long) gameState.coins + refundCoins);
        gameState.coins = (int) restoredCoins;
        if (gameState.swapFromAsset == SWAP_ASSET_COIN && gameState.coins > 0) {
            gameState.swapAmount = clampInt(action.amount, 1, gameState.coins);
        }
        saveGameState();
        String detail = conciseChainError(reason);
        chainStatus = action.label() + " gagal; coin dikembalikan +" + refundCoins
                + (detail.isEmpty() ? "." : ": " + detail);
        showErrorMessage(detail.isEmpty()
                ? "Swap gagal, coin dikembalikan +" + refundCoins + "."
                : "Swap gagal: " + shortPopupDetail(detail));
    }

    private boolean actionUpdatesCoinBalance(ChainAction action) {
        return "SELL_LAND".equals(action.type)
                || "SELL_CROP".equals(action.type)
                || "SWAP_CROP".equals(action.type)
                || "SWAP_COIN".equals(action.type)
                || "SWAP_ETH_COIN".equals(action.type)
                || "SWAP_COIN_ETH".equals(action.type);
    }

    private void repairLegacyWalletAutofill(int walletCoinBalance) {
        if (preferences.getBoolean(PREF_COIN_AUTOFILL_MIGRATION, false)) {
            return;
        }
        if (walletCoinBalance > 0 && gameState.coins == walletCoinBalance) {
            gameState.coins = 0;
            gameState.swapAmount = 0;
            saveGameState();
        }
        preferences.edit().putBoolean(PREF_COIN_AUTOFILL_MIGRATION, true).apply();
    }

    private String initialChainHistoryStatus() {
        if (walletAddress.isEmpty()) {
            return "butuh wallet";
        }
        if (blockchainClient.hasGameApi()) {
            return "mengirim";
        }
        if (blockchainClient.hasCoinContract()) {
            return "belum on-chain";
        }
        return "lokal tersimpan";
    }

    private String localChainStatus(ChainAction action) {
        if (walletAddress.isEmpty()) {
            return action.label() + " tersimpan lokal. Connect wallet untuk sync chain.";
        }
        if (!blockchainClient.hasGameApi()) {
            return "Signer backend belum diset; " + action.label() + " baru tersimpan lokal.";
        }
        return action.label() + " tersimpan lokal.";
    }

    private String syncedLocalChainStatus(ChainAction action, String reason) {
        String detail = conciseChainError(reason);
        return action.label() + " tersimpan lokal. Sync chain belum terkirim"
                + (detail.isEmpty() ? "." : ": " + detail);
    }

    private String conciseChainError(String message) {
        if (message == null) {
            return "";
        }
        String cleaned = message.trim();
        String prefix = "Gagal kirim aksi chain:";
        if (cleaned.toLowerCase(Locale.US).startsWith(prefix.toLowerCase(Locale.US))) {
            cleaned = cleaned.substring(prefix.length()).trim();
        }
        cleaned = cleaned.replaceFirst("^HTTP\\s+\\d+\\s*", "").trim();
        if (cleaned.startsWith("{")) {
            try {
                JSONObject object = new JSONObject(cleaned);
                String error = object.optString("error", "").trim();
                cleaned = error.isEmpty() ? object.optString("message", cleaned).trim() : error;
            } catch (JSONException ignored) {
                // Keep the backend response text when it is not valid JSON.
            }
        }
        String lower = cleaned.toLowerCase(Locale.US);
        if (lower.contains("wallet penerima eth sama dengan signer backend")) {
            cleaned = "wallet sama signer; ganti wallet pemain";
        } else if (lower.contains("saldo eth signer backend tidak cukup")) {
            cleaned = "saldo ETH signer backend kurang";
        } else if (lower.contains("tipe aksi tidak dikenal")) {
            cleaned = "backend belum support aksi ini";
        } else if (lower.contains("tidak mengembalikan tx hash")) {
            cleaned = "backend belum mengembalikan tx hash";
        }
        return cleaned.length() > 96 ? cleaned.substring(0, 93) + "..." : cleaned;
    }

    private String shortPopupDetail(String detail) {
        if (detail == null) {
            return "";
        }
        String cleaned = detail.trim();
        return cleaned.length() > 54 ? cleaned.substring(0, 51) + "..." : cleaned;
    }

    private void loadGameState() {
        gameStateStore.load(gameState);
    }

    void saveGameState() {
        gameStateStore.save(gameState);
    }

    private int totalSeeds() {
        return gameState.totalSeeds();
    }

    private int selectedSeedTotalPrice() {
        return totalPriceForSeed(gameState.selectedSeedIndex);
    }

    private int selectedSeedTotalAmount() {
        return totalSeedAmountForQuantity(gameState.shopBundleQuantity);
    }

    private int totalPriceForSeed(int seedIndex) {
        return shopSystem.totalPriceForSeed(gameState, seedIndex);
    }

    private int totalSeedAmountForQuantity(int quantity) {
        return shopSystem.totalSeedAmountForQuantity(quantity);
    }

    void showMessage(String text) {
        long now = System.currentTimeMillis();
        message = text;
        messageUntilMs = now + 1800L;
        if (!text.equals(statusPopupMessage)) {
            statusPopupUntilMs = 0L;
        }
    }

    void showErrorMessage(String text) {
        playErrorSound();
        showMessage(text);
    }

    void showSuccessPopup(String text) {
        showMessage(text);
        statusPopupTitle = "BERHASIL";
        statusPopupMessage = text;
        statusPopupUntilMs = System.currentTimeMillis() + 2400L;
    }

    private void playClickSound() {
        gameAudio.playClick();
    }

    private void playErrorSound() {
        gameAudio.playError();
    }

    private void startWalkSound(long now) {
        lastPlayerMoveMs = now;
        gameAudio.startWalk();
    }

    private void stopWalkSound() {
        gameAudio.stopWalk();
    }

    private int findNearbyPlot() {
        int closest = -1;
        float closestDistance = Float.MAX_VALUE;
        for (int i = 0; i < gameState.plots.size(); i++) {
            Plot plot = gameState.plots.get(i);
            RectF area = new RectF(plot.x - TILE, plot.y - TILE, plot.x + plot.w + TILE, plot.y + plot.h + TILE);
            if (area.contains(playerX, playerY)) {
                float dx = playerX - (plot.x + plot.w * 0.5f);
                float dy = playerY - (plot.y + plot.h * 0.5f);
                float distance = dx * dx + dy * dy;
                if (distance < closestDistance) {
                    closestDistance = distance;
                    closest = i;
                }
            }
        }
        return closest;
    }

    private int findTappedPlotSign(float x, float y) {
        for (int i = 0; i < gameState.plots.size(); i++) {
            if (i == selectedPlot && plotActionSignTapBounds(gameState.plots.get(i)).contains(x, y)) {
                return i;
            }
        }
        return -1;
    }

    private boolean isNearShop() {
        return playerX > SHOP_LEFT_TILE * TILE
                && playerX < SHOP_RIGHT_TILE * TILE
                && playerY > SHOP_TOP_TILE * TILE
                && playerY < SHOP_BOTTOM_TILE * TILE;
    }

    private boolean isNearSellHouse() {
        return playerX > SELL_HOUSE_LEFT_TILE * TILE
                && playerX < SELL_HOUSE_RIGHT_TILE * TILE
                && playerY > SELL_HOUSE_TOP_TILE * TILE
                && playerY < SELL_HOUSE_BOTTOM_TILE * TILE;
    }

    private boolean isNearSwapHouse() {
        return playerX > SWAP_HOUSE_LEFT_TILE * TILE
                && playerX < SWAP_HOUSE_RIGHT_TILE * TILE
                && playerY > SWAP_HOUSE_TOP_TILE * TILE
                && playerY < SWAP_HOUSE_BOTTOM_TILE * TILE;
    }

    private void drawSpriteWorld(
            Canvas canvas,
            Bitmap bitmap,
            int frame,
            int frameW,
            int frameH,
            int columns,
            float worldX,
            float worldY,
            float w,
            float h) {
        worldRenderer.drawSpriteWorld(canvas, bitmap, frame, frameW, frameH, columns, worldX, worldY, w, h);
    }

    private void drawSpriteWithShadowWorld(
            Canvas canvas,
            Bitmap bitmap,
            int frame,
            int frameW,
            int frameH,
            int columns,
            float worldX,
            float worldY,
            float w,
            float h) {
        worldRenderer.drawSpriteWithShadowWorld(canvas, bitmap, frame, frameW, frameH, columns, worldX, worldY, w, h);
    }

    private void drawWorldRect(Canvas canvas, float x, float y, float w, float h) {
        worldRenderer.drawWorldRect(canvas, x, y, w, h);
    }

    private void drawWorldRoundRect(Canvas canvas, float x, float y, float w, float h, float r) {
        worldRenderer.drawWorldRoundRect(canvas, x, y, w, h, r);
    }

    private void drawWorldLine(Canvas canvas, float x1, float y1, float x2, float y2) {
        worldRenderer.drawWorldLine(canvas, x1, y1, x2, y2);
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static float smoothStep(float value) {
        float t = clamp(value, 0f, 1f);
        return t * t * (3f - 2f * t);
    }

    private static BigDecimal resolveEthWeiPerCoin() {
        String configured = BuildConfig.TANIIN_ETH_WEI_PER_COIN == null
                ? DEFAULT_ETH_WEI_PER_COIN
                : BuildConfig.TANIIN_ETH_WEI_PER_COIN.trim();
        try {
            BigDecimal value = new BigDecimal(configured);
            return value.compareTo(BigDecimal.ZERO) > 0 ? value : new BigDecimal(DEFAULT_ETH_WEI_PER_COIN);
        } catch (NumberFormatException exception) {
            return new BigDecimal(DEFAULT_ETH_WEI_PER_COIN);
        }
    }

    private String estimatedEthSwapAmount(int coinAmount) {
        if (coinAmount <= 0) {
            return "0";
        }
        BigDecimal wei = ethWeiPerCoin.multiply(BigDecimal.valueOf(coinAmount));
        BigDecimal eth = wei.divide(WEI_PER_ETH, 12, RoundingMode.DOWN).stripTrailingZeros();
        return eth.compareTo(BigDecimal.ZERO) == 0 ? "0" : eth.toPlainString();
    }

    private int maxEthFundingCoins() {
        BigDecimal availableWei = walletNativeWeiValue().subtract(locallyFundedEthWei());
        if (availableWei.compareTo(BigDecimal.ZERO) <= 0) {
            return 0;
        }
        BigDecimal coinAmount = availableWei.divide(ethWeiPerCoin, 0, RoundingMode.DOWN);
        BigDecimal maxInt = BigDecimal.valueOf(Integer.MAX_VALUE);
        if (coinAmount.compareTo(maxInt) > 0) {
            return Integer.MAX_VALUE;
        }
        return Math.max(0, coinAmount.intValue());
    }

    private void recordLocalEthFunding(int coinAmount) {
        if (coinAmount <= 0 || walletAddress.isEmpty()) {
            return;
        }
        BigDecimal usedWei = locallyFundedEthWei().add(ethWeiPerCoin.multiply(BigDecimal.valueOf(coinAmount)));
        preferences.edit().putString(localEthFundingPreferenceKey(), usedWei.setScale(0, RoundingMode.DOWN).toPlainString()).apply();
    }

    private BigDecimal locallyFundedEthWei() {
        if (walletAddress.isEmpty()) {
            return BigDecimal.ZERO;
        }
        String raw = preferences.getString(localEthFundingPreferenceKey(), "0");
        try {
            BigDecimal value = new BigDecimal(raw == null ? "0" : raw.trim());
            return value.compareTo(BigDecimal.ZERO) > 0 ? value : BigDecimal.ZERO;
        } catch (NumberFormatException exception) {
            return BigDecimal.ZERO;
        }
    }

    private String localEthFundingPreferenceKey() {
        return "game_eth_funded_wei_" + walletAddress.toLowerCase(Locale.US);
    }

    boolean isConnectedWalletBackendSigner() {
        return isValidAddress(walletAddress)
                && isValidAddress(chainSignerAddress)
                && walletAddress.equalsIgnoreCase(chainSignerAddress);
    }

    private BigDecimal walletNativeWeiValue() {
        return walletNativeEthValue().multiply(WEI_PER_ETH).setScale(0, RoundingMode.DOWN);
    }

    private BigDecimal walletNativeEthValue() {
        if (walletNativeBalance == null || walletNativeBalance.trim().isEmpty()) {
            return BigDecimal.ZERO;
        }
        try {
            return new BigDecimal(walletNativeBalance.trim());
        } catch (NumberFormatException exception) {
            return BigDecimal.ZERO;
        }
    }

    private static boolean isValidAddress(String address) {
        return BlockchainClient.isValidAddress(address);
    }

    static String compactEth(String value) {
        if (value == null || value.trim().isEmpty()) {
            return "0";
        }
        String cleaned = value.trim();
        int dot = cleaned.indexOf('.');
        if (dot < 0) {
            return cleaned;
        }
        int end = Math.min(cleaned.length(), dot + 13);
        String compact = cleaned.substring(0, end);
        while (compact.endsWith("0") && compact.indexOf('.') >= 0) {
            compact = compact.substring(0, compact.length() - 1);
        }
        return compact.endsWith(".") ? compact.substring(0, compact.length() - 1) : compact;
    }

    private static String shortAddress(String address) {
        return BlockchainClient.shortAddress(address);
    }
}
