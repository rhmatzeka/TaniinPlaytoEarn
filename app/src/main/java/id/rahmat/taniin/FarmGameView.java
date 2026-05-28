package id.rahmat.taniin;

import android.app.Activity;
import android.app.Dialog;
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
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

final class FarmGameView extends CanvasGameView {
    private static final int TILE = 128;
    private static final int WORLD_COLS = 72;
    private static final int WORLD_ROWS = 52;
    private static final float PLAYER_SPEED = TILE * 3.9f;
    private static final long GROW_TIME_MS = 12_000L;
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
    private static final int LAND_BUY_PRICE = 250;
    private static final int LAND_SELL_PRICE = 175;
    private static final int SEED_BUNDLE_AMOUNT = 3;
    private static final int MAX_SHOP_BUNDLE_QUANTITY = 9;
    private static final int LAND_STATE_VERSION = 2;
    private static final long HARVEST_EFFECT_MS = 1450L;
    private static final long SHOP_NPC_BUBBLE_MS = 4200L;
    private static final String[] SEED_NAMES = {"Kentang", "Bawang", "Stroberi", "Bit"};
    private static final String[] SEED_SHOP_NAMES = {"Potato Seed", "Leek Seed", "Strawberry Seed", "Beetroot Seed"};
    private static final int[] SEED_PRICES = {60, 75, 110, 90};
    private static final int[] SEED_HARVEST_YIELDS = {3, 4, 5, 4};
    private static final int[] SEED_CROP_ROWS = {4, 2, 0, 6};
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
    private static final int MENU_TAB_INVENTORY = 0;
    private static final int MENU_TAB_SETTINGS = 1;
    private static final int MENU_TAB_ABOUT = 2;
    private static final int CHAIN_HISTORY_LIMIT = 8;
    private static final String PREF_CHAIN_HISTORY = "game_chain_history";

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Rect src = new Rect();
    private final RectF dst = new RectF();
    private final List<Plot> plots = new ArrayList<>();
    private final List<RectF> collisionRects = new ArrayList<>();
    private final List<ChainAction> pendingChainActions = new ArrayList<>();
    private final List<ChainHistoryEntry> chainHistory = new ArrayList<>();
    private final List<HarvestEffect> harvestEffects = new ArrayList<>();
    private final BlockchainClient blockchainClient = new BlockchainClient();
    private final GameAudio gameAudio;
    private final SharedPreferences preferences;
    private TmxMap tmxMap;

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
    private String chainStatus = "Mode lokal. Sepolia belum dicek.";
    private String walletNativeBalance = "";
    private boolean coinBalanceOnChain;
    private boolean checkingChain;
    private String mapStatus = "";

    private int coins = 500;
    private final int[] seedCounts = {6, 0, 0, 0};
    private int selectedSeedIndex;
    private int shopBundleQuantity = 1;
    private int harvests = 0;
    private int ownedLand = 1;
    private int selectedPlot = -1;
    private int activeInteractionPlot = -1;
    private boolean moving;
    private boolean menuOpen;
    private boolean interactionDialogOpen;
    private boolean shopCatalogOpen;
    private boolean shopPurchaseConfirmOpen;
    private boolean chainHistoryOpen;
    private boolean audioBgmEnabled = true;
    private boolean audioSfxEnabled = true;
    private int menuTab = MENU_TAB_INVENTORY;
    private InteractionKind activeInteractionKind = InteractionKind.NONE;
    private int shopPurchaseSeedIndex = -1;
    private int audioTrackIndex;
    private int facingDirection = DIR_DOWN;
    private int walkFrame;
    private long walkTickMs;
    private long lastPlayerMoveMs;
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
        walletAddress = resolveInitialWalletAddress();
        loadAudioSettings();
        idleSheet = decodePixelResource(R.drawable.idle);
        walkSheet = decodePixelResource(R.drawable.walk);
        cropSheet = decodePixelResource(R.drawable.spring_crops);
        chest = decodePixelResource(R.drawable.chest);
        chicken = decodePixelResource(R.drawable.chicken_blonde_green);
        babyChicken = decodePixelResource(R.drawable.baby_chicken_yellow);
        cow = decodePixelResource(R.drawable.female_cow_brown);
        maleCow = decodePixelResource(R.drawable.male_cow_brown);
        chickenRed = decodePixelResource(R.drawable.chicken_red);
        appIcon = decodePixelResource(R.drawable.iconaplikasi);
        shopNpcSheet = decodePixelAsset(context, "game/Tileset/Cute_Fantasy_Free/Player/Player.png", idleSheet);
        outdoorDecorSheet = decodePixelAsset(context, "game/Tileset/Cute_Fantasy_Free/Outdoor decoration/Outdoor_Decor_Free.png", null);
        loadTmxMap(context);
        createWorld();
        loadGameState();
        loadChainHistory();
        if (!walletAddress.isEmpty()) {
            refreshWalletState(false);
        }
    }

    private String resolveInitialWalletAddress() {
        String defaultWalletAddress = blockchainClient.defaultWalletAddress();
        String savedWalletAddress = preferences.getString("wallet_address", "");
        if (!defaultWalletAddress.isEmpty()) {
            if (!defaultWalletAddress.equalsIgnoreCase(savedWalletAddress)) {
                preferences.edit().putString("wallet_address", defaultWalletAddress).apply();
            }
            chainStatus = "Wallet otomatis dari .env: " + shortAddress(defaultWalletAddress);
            return defaultWalletAddress;
        }
        return savedWalletAddress;
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
        audioTrackIndex = clampInt(preferences.getInt("audio_track_index", 0), 0, Math.max(0, gameAudio.getBgmCount() - 1));
        gameAudio.setBgmIndex(audioTrackIndex);
        gameAudio.setBgmEnabled(audioBgmEnabled);
        gameAudio.setSfxEnabled(audioSfxEnabled);
    }

    private void saveAudioSettings() {
        preferences.edit()
                .putBoolean("audio_bgm_enabled", audioBgmEnabled)
                .putBoolean("audio_sfx_enabled", audioSfxEnabled)
                .putInt("audio_track_index", audioTrackIndex)
                .apply();
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
            plots.add(plot);
        }
    }

    private void createFallbackCollisionRects() {
        addCollisionRect(0, 7 * TILE, 44 * TILE, 4 * TILE);
        addCollisionRect(0, 0, 3 * TILE, WORLD_ROWS * TILE);
        addCollisionRect(0, 45 * TILE, 34 * TILE, 7 * TILE);
        addCollisionRect(52 * TILE, 0, 4 * TILE, 19 * TILE);

        addFenceCollision(27 * TILE, 22 * TILE, 22 * TILE, 11 * TILE);
        addFenceCollision(6 * TILE, 23 * TILE, 20 * TILE, 9 * TILE);

        addHouseCollision(32 * TILE, 24 * TILE, 7 * TILE, 7 * TILE);
        addHouseCollision(56 * TILE, 10 * TILE, 7 * TILE, 7 * TILE);
        addCollisionRect(39 * TILE, 29 * TILE, 4.6f * TILE, 1.3f * TILE);

        addTreeCollision(6 * TILE, 15 * TILE, 1.2f);
        addTreeCollision(14 * TILE, 13 * TILE, 1.0f);
        addTreeCollision(23 * TILE, 13 * TILE, 1.0f);
        addTreeCollision(42 * TILE, 13 * TILE, 1.0f);
        addTreeCollision(62 * TILE, 5 * TILE, 1.05f);
        addTreeCollision(58 * TILE, 22 * TILE, 1.0f);
        addTreeCollision(31 * TILE, 43 * TILE, 1.3f);
        addTreeCollision(37 * TILE, 43 * TILE, 1.3f);
        addTreeCollision(43 * TILE, 43 * TILE, 1.3f);
        addTreeCollision(49 * TILE, 43 * TILE, 1.3f);

        addCollisionRect(17 * TILE, 16 * TILE + 12, 58, 30);
        addCollisionRect(31 * TILE, 15 * TILE + 12, 58, 30);
        addCollisionRect(13 * TILE, 10 * TILE + 9, 24, 18);
        addCollisionRect(54 * TILE, 32 * TILE + 9, 24, 18);
        addCollisionRect(65 * TILE, 29 * TILE + 9, 24, 18);
        addCollisionRect(40 * TILE, 30 * TILE, 42, 42);
        addCollisionRect(29 * TILE, 32 * TILE, 64, 32);
        addCollisionRect(45 * TILE, 30 * TILE, 86, 64);
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
        for (Plot plot : plots) {
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

        drawWorld(canvas);
        drawMapDecorations(canvas, false, now);
        drawShopNpc(canvas, now);
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
        drawShopNpcBubble(canvas, now);
        drawHud(canvas, now);
    }

    private void drawWorld(Canvas canvas) {
        if (tmxMap != null) {
            canvas.drawColor(Color.rgb(113, 181, 82));
            tmxMap.drawBackground(canvas, cameraX, cameraY, TILE);
            return;
        }

        canvas.drawColor(Color.rgb(113, 181, 82));
        drawGrassTexture(canvas);

        drawWaterRect(canvas, 0, 7 * TILE, 44 * TILE, 4 * TILE);
        drawWaterRect(canvas, 0, 0, 3 * TILE, WORLD_ROWS * TILE);
        drawWaterRect(canvas, 0, 45 * TILE, 34 * TILE, 7 * TILE);
        drawWaterRect(canvas, 52 * TILE, 0, 4 * TILE, 19 * TILE);

        drawRoad(canvas, 8 * TILE, 6 * TILE, 39 * TILE, 2 * TILE);
        drawRoad(canvas, 44 * TILE, 5 * TILE, 10 * TILE, 2 * TILE);
        drawRoad(canvas, 44 * TILE, 5 * TILE, 2 * TILE, 19 * TILE);
        drawRoad(canvas, 16 * TILE, 20 * TILE, 34 * TILE, 2 * TILE);
        drawRoad(canvas, 26 * TILE, 33 * TILE, 42 * TILE, 2 * TILE);
        drawRoad(canvas, 34 * TILE, 23 * TILE, 2 * TILE, 12 * TILE);
        drawRoad(canvas, 62 * TILE, 30 * TILE, 7 * TILE, 5 * TILE);

        drawBridge(canvas, 44 * TILE, 7 * TILE, 2 * TILE, 4 * TILE, true);
        drawBridge(canvas, 52 * TILE, 11 * TILE, 4 * TILE, 2 * TILE, false);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(37, 128, 63));
        drawWorldLine(canvas, 3 * TILE, 6 * TILE, 47 * TILE, 6 * TILE);
        drawWorldLine(canvas, 3 * TILE, 11 * TILE, 44 * TILE, 11 * TILE);
        drawWorldLine(canvas, 3 * TILE, 45 * TILE, 34 * TILE, 45 * TILE);
    }

    private void drawPlots(Canvas canvas, long now) {
        for (int i = 0; i < plots.size(); i++) {
            Plot plot = plots.get(i);
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
        int stage = plot.state == PlotState.READY
                ? 3
                : Math.min(2, (int) ((now - plot.plantedAtMs) / (GROW_TIME_MS / 3)));
        int cell = 16;
        int cropRow = SEED_CROP_ROWS[plot.seedIndex];
        src.set(stage * cell, cropRow * cell, stage * cell + cell, cropRow * cell + cell);
        int cols = Math.max(1, Math.round(plot.w / TILE));
        int rows = Math.max(1, Math.round(plot.h / TILE));
        float cropSize = TILE * 0.42f;
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                float x = plot.x + col * TILE + (TILE - cropSize) * 0.5f - cameraX;
                float y = plot.y + row * TILE + TILE * 0.34f - cameraY;
                dst.set(x, y, x + cropSize, y + cropSize);
                canvas.drawBitmap(cropSheet, src, dst, pixelPaint);
            }
        }
    }

    private void drawHarvestEffects(Canvas canvas, long now) {
        for (HarvestEffect effect : harvestEffects) {
            float progress = clamp((now - effect.startedAtMs) / (float) HARVEST_EFFECT_MS, 0f, 1f);
            int alpha = (int) (255f * (1f - progress));
            float lift = TILE * 0.82f * progress;
            int cell = 16;
            int cropRow = SEED_CROP_ROWS[effect.seedIndex];
            src.set(3 * cell, cropRow * cell, 3 * cell + cell, cropRow * cell + cell);

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
        paint.setColor(Color.argb(185, 20, 16, 12));
        canvas.drawRoundRect(cx - 25, cy - 22, cx + 25, cy + 22, 8, 8, paint);
        paint.setColor(Color.rgb(255, 207, 71));
        canvas.drawRoundRect(cx - 14, cy - 2, cx + 14, cy + 18, 4, 4, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        canvas.drawArc(cx - 12, cy - 20, cx + 12, cy + 8, 180, -180, false, paint);
    }

    private void drawDecorations(Canvas canvas) {
        drawFence(canvas, 27 * TILE, 22 * TILE, 22 * TILE, 11 * TILE);
        drawFence(canvas, 6 * TILE, 23 * TILE, 20 * TILE, 9 * TILE);

        drawHouse(canvas, 32 * TILE, 24 * TILE, 7 * TILE, 7 * TILE, true);
        drawHouse(canvas, 56 * TILE, 10 * TILE, 7 * TILE, 7 * TILE, false);
        drawShopStand(canvas, 39 * TILE, 29 * TILE);

        drawLamp(canvas, 48 * TILE, 4 * TILE);
        drawLamp(canvas, 20 * TILE, 18 * TILE);
        drawLamp(canvas, 50 * TILE, 32 * TILE);
        drawLamp(canvas, 11 * TILE, 33 * TILE);

        drawTree(canvas, 6 * TILE, 15 * TILE, 1.2f);
        drawTree(canvas, 14 * TILE, 13 * TILE, 1.0f);
        drawTree(canvas, 23 * TILE, 13 * TILE, 1.0f);
        drawTree(canvas, 42 * TILE, 13 * TILE, 1.0f);
        drawTree(canvas, 62 * TILE, 5 * TILE, 1.05f);
        drawTree(canvas, 58 * TILE, 22 * TILE, 1.0f);
        drawTree(canvas, 31 * TILE, 43 * TILE, 1.3f);
        drawTree(canvas, 37 * TILE, 43 * TILE, 1.3f);
        drawTree(canvas, 43 * TILE, 43 * TILE, 1.3f);
        drawTree(canvas, 49 * TILE, 43 * TILE, 1.3f);

        drawBush(canvas, 17 * TILE, 16 * TILE);
        drawBush(canvas, 31 * TILE, 15 * TILE);
        drawRock(canvas, 13 * TILE, 10 * TILE);
        drawRock(canvas, 54 * TILE, 32 * TILE);
        drawRock(canvas, 65 * TILE, 29 * TILE);

        drawBitmapWorld(canvas, chest, 40 * TILE, 30 * TILE, 42, 42);
        drawBitmapWorld(canvas, chicken, 29 * TILE, 32 * TILE, 64, 32);
        drawBitmapWorld(canvas, cow, 45 * TILE, 30 * TILE, 86, 64);
    }

    private void drawMapDecorations(Canvas canvas, boolean foreground, long now) {
        if (tmxMap == null) {
            return;
        }
        if (foreground) {
            drawShopHouseSign(canvas);
            drawSellHouseSign(canvas);
            return;
        }
        drawFieldEdgeNatureDecorations(canvas, now);
        drawShopPenNatureDecorations(canvas);
        drawOpenMeadowDecorations(canvas, now);
        drawRoadsideDecorations(canvas, now);
        drawVillageNpcDecorations(canvas, now);
        drawShopPenAnimals(canvas, now);
    }

    private void drawShopPenAnimals(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 440L) % 4L);
        int babyFrame = (int) ((now / 520L) % 4L);
        int cowFrame = (int) ((now / 620L) % 4L);

        float chickenWiggleA = (float) Math.sin(now / 360.0) * TILE * 0.025f;
        float chickenWiggleB = (float) Math.sin(now / 430.0 + 1.7) * TILE * 0.025f;
        float babyWiggle = (float) Math.sin(now / 390.0 + 2.4) * TILE * 0.020f;
        float cowWiggle = (float) Math.sin(now / 720.0 + 0.8) * TILE * 0.018f;

        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                22.38f * TILE + chickenWiggleA, 18.08f * TILE, TILE * 0.50f, TILE * 0.50f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 1) % 4, 16, 16, 4,
                23.34f * TILE + chickenWiggleB, 18.42f * TILE, TILE * 0.50f, TILE * 0.50f);
        drawSpriteWithShadowWorld(canvas, cow, cowFrame, 32, 32, 4,
                22.82f * TILE + cowWiggle, 20.04f * TILE, TILE, TILE);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                23.58f * TILE - chickenWiggleA, 21.68f * TILE, TILE * 0.50f, TILE * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                22.42f * TILE + babyWiggle, 22.00f * TILE, TILE * 0.38f, TILE * 0.38f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 3) % 4, 16, 16, 4,
                22.98f * TILE - chickenWiggleB, 22.50f * TILE, TILE * 0.50f, TILE * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                23.66f * TILE - babyWiggle, 22.34f * TILE, TILE * 0.38f, TILE * 0.38f);
    }

    private void drawFieldEdgeNatureDecorations(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 440L) % 4L);
        int babyFrame = (int) ((now / 520L) % 4L);

        drawOutdoorTile(canvas, 0, 2, 10.10f * TILE, 23.38f * TILE, TILE * 0.72f);
        drawOutdoorTile(canvas, 1, 2, 11.22f * TILE, 24.08f * TILE, TILE * 0.56f);
        drawOutdoorTile(canvas, 2, 3, 13.10f * TILE, 23.76f * TILE, TILE * 0.56f);
        drawOutdoorTile(canvas, 1, 2, 14.35f * TILE, 23.18f * TILE, TILE * 0.50f);
        drawOutdoorTile(canvas, 2, 3, 14.92f * TILE, 23.76f * TILE, TILE * 0.54f);
        drawOutdoorTile(canvas, 0, 8, 12.12f * TILE, 22.70f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 0, 11, 12.82f * TILE, 24.58f * TILE, TILE * 0.52f);
        drawOutdoorTile(canvas, 1, 11, 13.74f * TILE, 24.42f * TILE, TILE * 0.52f);

        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                10.86f * TILE, 24.54f * TILE, TILE * 0.50f, TILE * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                11.62f * TILE, 24.92f * TILE, TILE * 0.37f, TILE * 0.37f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                13.74f * TILE, 24.64f * TILE, TILE * 0.48f, TILE * 0.48f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                14.42f * TILE, 24.96f * TILE, TILE * 0.35f, TILE * 0.35f);
    }

    private void drawShopPenNatureDecorations(Canvas canvas) {
        drawOutdoorTile(canvas, 0, 8, 16.18f * TILE, 18.70f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 1, 8, 16.66f * TILE, 18.86f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 4, 8, 18.34f * TILE, 20.46f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 5, 8, 18.84f * TILE, 20.38f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 0, 2, 20.06f * TILE, 18.62f * TILE, TILE * 0.62f);
        drawOutdoorTile(canvas, 2, 3, 20.88f * TILE, 19.02f * TILE, TILE * 0.54f);
        drawOutdoorTile(canvas, 0, 10, 17.16f * TILE, 22.12f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 1, 10, 17.64f * TILE, 22.08f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 5, 1, 20.76f * TILE, 22.02f * TILE, TILE * 0.60f);
        drawOutdoorTile(canvas, 6, 1, 21.36f * TILE, 22.00f * TILE, TILE * 0.60f);

        drawOutdoorTile(canvas, 1, 2, 22.05f * TILE, 18.22f * TILE, TILE * 0.52f);
        drawOutdoorTile(canvas, 2, 3, 23.98f * TILE, 18.58f * TILE, TILE * 0.56f);
        drawOutdoorTile(canvas, 0, 2, 22.18f * TILE, 19.86f * TILE, TILE * 0.70f);
        drawOutdoorTile(canvas, 1, 3, 23.78f * TILE, 20.20f * TILE, TILE * 0.52f);
        drawOutdoorTile(canvas, 1, 2, 22.38f * TILE, 21.26f * TILE, TILE * 0.54f);
        drawOutdoorTile(canvas, 2, 3, 23.88f * TILE, 21.58f * TILE, TILE * 0.54f);
        drawOutdoorTile(canvas, 0, 11, 22.42f * TILE, 22.84f * TILE, TILE * 0.46f);
        drawOutdoorTile(canvas, 2, 10, 23.72f * TILE, 22.90f * TILE, TILE * 0.48f);
    }

    private void drawOpenMeadowDecorations(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 430L) % 4L);
        int babyFrame = (int) ((now / 510L) % 4L);
        int cowFrame = (int) ((now / 660L) % 4L);
        float swayA = (float) Math.sin(now / 520.0) * TILE * 0.018f;
        float swayB = (float) Math.sin(now / 610.0 + 1.8) * TILE * 0.018f;

        drawOutdoorTile(canvas, 0, 8, 18.70f * TILE, 28.86f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 1, 8, 19.25f * TILE, 29.06f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 5, 8, 20.45f * TILE, 28.82f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 6, 8, 21.00f * TILE, 29.08f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 0, 1, 22.18f * TILE, 29.10f * TILE, TILE * 0.58f);
        drawOutdoorTile(canvas, 2, 1, 23.02f * TILE, 29.34f * TILE, TILE * 0.50f);

        drawOutdoorTile(canvas, 0, 2, 19.18f * TILE, 30.84f * TILE, TILE * 0.68f);
        drawOutdoorTile(canvas, 1, 2, 20.16f * TILE, 31.20f * TILE, TILE * 0.54f);
        drawOutdoorTile(canvas, 0, 3, 22.48f * TILE, 30.96f * TILE, TILE * 0.70f);
        drawOutdoorTile(canvas, 2, 3, 23.54f * TILE, 31.52f * TILE, TILE * 0.56f);
        drawOutdoorTile(canvas, 4, 5, 18.52f * TILE, 32.84f * TILE, TILE * 0.78f);
        drawOutdoorTile(canvas, 5, 5, 24.26f * TILE, 32.58f * TILE, TILE * 0.78f);
        drawOutdoorTile(canvas, 6, 4, 21.36f * TILE, 33.04f * TILE, TILE * 1.10f);

        drawSpriteWithShadowWorld(canvas, chickenRed, chickenFrame, 16, 16, 4,
                19.70f * TILE + swayA, 28.24f * TILE, TILE * 0.54f, TILE * 0.54f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                20.38f * TILE - swayB, 28.68f * TILE, TILE * 0.38f, TILE * 0.38f);
        drawSpriteWithShadowWorld(canvas, maleCow, cowFrame, 32, 32, 4,
                24.10f * TILE + swayB, 28.14f * TILE, TILE * 1.04f, TILE * 1.04f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                24.18f * TILE - swayA, 30.22f * TILE, TILE * 0.52f, TILE * 0.52f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                24.82f * TILE + swayA, 30.58f * TILE, TILE * 0.38f, TILE * 0.38f);
    }

    private void drawRoadsideDecorations(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 470L) % 4L);
        int cowFrame = (int) ((now / 690L) % 4L);
        float drift = (float) Math.sin(now / 720.0) * TILE * 0.016f;

        drawOutdoorTile(canvas, 2, 8, 29.12f * TILE, 25.92f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 3, 8, 29.60f * TILE, 25.84f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 0, 9, 31.70f * TILE, 25.12f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 1, 9, 32.24f * TILE, 25.10f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 0, 2, 34.10f * TILE, 31.08f * TILE, TILE * 0.64f);
        drawOutdoorTile(canvas, 2, 3, 35.00f * TILE, 31.30f * TILE, TILE * 0.58f);

        drawOutdoorTile(canvas, 0, 10, 29.22f * TILE, 32.70f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 1, 10, 29.68f * TILE, 32.66f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 4, 8, 32.72f * TILE, 33.18f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 5, 8, 33.16f * TILE, 33.12f * TILE, TILE * 0.48f);
        drawOutdoorTile(canvas, 3, 5, 35.54f * TILE, 32.72f * TILE, TILE * 0.80f);
        drawOutdoorTile(canvas, 6, 5, 36.50f * TILE, 32.98f * TILE, TILE * 0.78f);

        drawSpriteWithShadowWorld(canvas, cow, cowFrame, 32, 32, 4,
                31.18f * TILE + drift, 29.22f * TILE, TILE * 1.02f, TILE * 1.02f);
        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                34.62f * TILE - drift, 31.48f * TILE, TILE * 0.52f, TILE * 0.52f);
        drawSpriteWithShadowWorld(canvas, chickenRed, (chickenFrame + 1) % 4, 16, 16, 4,
                35.20f * TILE + drift, 31.82f * TILE, TILE * 0.52f, TILE * 0.52f);

        drawOutdoorTile(canvas, 0, 11, 13.26f * TILE, 35.88f * TILE, TILE * 0.50f);
        drawOutdoorTile(canvas, 1, 11, 13.74f * TILE, 35.82f * TILE, TILE * 0.50f);
        drawOutdoorTile(canvas, 2, 11, 14.22f * TILE, 35.88f * TILE, TILE * 0.50f);
        drawOutdoorTile(canvas, 5, 1, 16.66f * TILE, 36.18f * TILE, TILE * 0.62f);
        drawOutdoorTile(canvas, 6, 1, 17.30f * TILE, 36.18f * TILE, TILE * 0.62f);
        drawOutdoorTile(canvas, 0, 3, 20.62f * TILE, 35.82f * TILE, TILE * 0.68f);
        drawOutdoorTile(canvas, 2, 3, 21.52f * TILE, 36.20f * TILE, TILE * 0.56f);
    }

    private void drawVillageNpcDecorations(Canvas canvas, long now) {
        int frame = (int) ((now / 360L) % 6L);
        float bob = (float) Math.sin(now / 540.0) * 1.5f;
        drawNpcWorld(canvas, 6 + frame, 17.80f * TILE, 27.70f * TILE + bob, TILE * 1.05f);
        drawNpcWorld(canvas, 18 + frame, 33.96f * TILE, 31.92f * TILE - bob, TILE * 1.02f);
    }

    private void drawNpcWorld(Canvas canvas, int frame, float worldX, float worldY, float size) {
        drawSpriteWithShadowWorld(canvas, shopNpcSheet, frame, 32, 32, 6, worldX, worldY, size, size);
    }

    private void drawOutdoorTile(Canvas canvas, int col, int row, float worldX, float worldY, float size) {
        if (outdoorDecorSheet == null) {
            return;
        }
        int tileSize = 16;
        src.set(col * tileSize, row * tileSize, col * tileSize + tileSize, row * tileSize + tileSize);
        dst.set(worldX - cameraX, worldY - cameraY, worldX - cameraX + size, worldY - cameraY + size);
        canvas.drawBitmap(outdoorDecorSheet, src, dst, pixelPaint);
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

        drawWoodSignBoard(canvas, sign, "JUAL PANEN", 28f, true);
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
        for (int i = 0; i < plots.size(); i++) {
            if (i != selectedPlot) {
                continue;
            }
            Plot plot = plots.get(i);
            InteractionKind kind = plotInteractionKind(plot, now);
            RectF sign = plotActionSignBounds(plot);
            if (isOffscreen(sign) || sign.top < 8f) {
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
        paint.setColor(Color.rgb(255, 235, 190));
        paint.setTextSize(fitTextSize(label, textSize, sign.width() - 22f));
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, label, sign.centerX(), sign.centerY() + (paint.getTextSize() * 0.35f));
        paint.setFakeBoldText(false);
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
        drawActionButton(canvas);
        drawWalletButton(canvas);
        drawChainHistoryButton(canvas);
        drawContextMessage(canvas, now);
        if (shopUntilMs > now) {
            drawShopPanel(canvas);
        }
        if (chainPanelUntilMs > now) {
            drawChainPanel(canvas, now);
        }
        if (menuOpen) {
            drawMenuPanel(canvas);
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
        String coinLabel = coinBalanceOnChain ? "Wallet Coin " : "Coin ";
        canvas.drawText(coinLabel + coins, left + 16f, top + 34f, paint);
        paint.setColor(Color.WHITE);
        canvas.drawText("Bibit " + totalSeeds(), left + 122f, top + 34f, paint);
        canvas.drawText("Panen " + harvests, left + 220f, top + 34f, paint);
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
        canvas.drawText(coinBalanceOnChain ? "Sepolia TANI" : "Sepolia", left + 16, 47, paint);
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
        RectF inner = new RectF(left + inset, top + inset, left + mapW - inset, top + mapH - inset);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(left + 4f, top + 5f, left + mapW + 4f, top + mapH + 5f, 8, 8, paint);
        paint.setColor(Color.rgb(78, 63, 30));
        canvas.drawRoundRect(left, top, left + mapW, top + mapH, 8, 8, paint);
        paint.setColor(Color.rgb(147, 108, 45));
        canvas.drawRoundRect(left + 3f, top + 3f, left + mapW - 3f, top + mapH - 3f, 6, 6, paint);

        canvas.save();
        canvas.clipRect(inner);
        if (tmxMap != null) {
            tmxMap.drawMiniMap(canvas, inner, TILE);
        } else {
            paint.setColor(Color.rgb(105, 184, 78));
            canvas.drawRect(inner, paint);
        }

        float x = inner.left + playerX / worldWidthPixels * inner.width();
        float y = inner.top + playerY / worldHeightPixels * inner.height();
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
        canvas.drawText(String.valueOf(coins), barLeft + 76f, top + 48f, paint);

        paint.setColor(Color.rgb(76, 42, 12));
        canvas.drawRect(barLeft + topMenuBarWidth() * 0.52f, top + 13f, barLeft + topMenuBarWidth() * 0.52f + 4f, bottom - 13f, paint);

        drawHarvestHudIcon(canvas, barLeft + topMenuBarWidth() * 0.67f, top + buttonSize * 0.5f);
        paint.setColor(Color.rgb(240, 222, 179));
        canvas.drawText(String.valueOf(harvests), barLeft + topMenuBarWidth() * 0.67f + 39f, top + 48f, paint);
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
        drawBackpackPanel(canvas);
    }

    private void drawBackpackPanel(Canvas canvas) {
        canvas.drawColor(Color.argb(155, 0, 0, 0));

        RectF panel = inventoryPanelBounds();
        float headerH = 118f;
        float sidebarW = 220f;
        float bodyTop = panel.top + headerH;
        float bodyLeft = panel.left + sidebarW;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(120, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 8f, panel.top + 10f, panel.right + 8f, panel.bottom + 10f, 26, 26, paint);
        paint.setColor(Color.rgb(134, 70, 25));
        canvas.drawRoundRect(panel, 26, 26, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(6f);
        paint.setColor(Color.rgb(83, 43, 18));
        canvas.drawRoundRect(panel, 26, 26, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(128, 61, 23));
        canvas.drawRoundRect(panel.left + 4f, panel.top + 4f, panel.right - 4f, bodyTop, 24, 24, paint);
        paint.setColor(Color.rgb(95, 43, 16));
        canvas.drawRect(panel.left + 4f, bodyTop - 4f, panel.right - 4f, bodyTop + 2f, paint);
        paint.setColor(Color.rgb(161, 81, 33));
        canvas.drawRect(bodyLeft, bodyTop, panel.right - 4f, panel.bottom - 4f, paint);
        paint.setColor(Color.rgb(112, 52, 20));
        canvas.drawRect(panel.left + 4f, bodyTop, bodyLeft, panel.bottom - 4f, paint);

        drawBackpackTitle(canvas, panel.left + 58f, panel.top + 61f);
        drawBackpackCloseButton(canvas);

        drawBackpackSideTab(canvas, backpackSeedTabBounds(), menuTab == MENU_TAB_INVENTORY, "SEEDS", Color.rgb(255, 207, 14));
        drawBackpackSideTab(canvas, backpackAudioTabBounds(), menuTab == MENU_TAB_SETTINGS, "AUDIO", Color.rgb(105, 196, 250));
        drawBackpackSideTab(canvas, backpackAboutTabBounds(), menuTab == MENU_TAB_ABOUT, "ABOUT", Color.rgb(255, 151, 83));

        if (menuTab == MENU_TAB_SETTINGS) {
            drawAudioSettingsPanel(canvas, panel, bodyLeft, bodyTop);
            return;
        }
        if (menuTab == MENU_TAB_ABOUT) {
            drawAboutPanel(canvas, panel, bodyLeft, bodyTop);
            return;
        }

        float cardTop = bodyTop + 43f;
        float cardLeft = bodyLeft + 42f;
        float cardW = 116f;
        float cardH = 118f;
        float gap = 34f;
        for (int i = 0; i < SEED_NAMES.length; i++) {
            drawInventoryItemCard(canvas,
                    cardLeft + i * (cardW + gap),
                    cardTop,
                    cardW,
                    cardH,
                    SEED_CARD_COLORS[i],
                    SEED_ICON_COLORS[i],
                    i == 1 ? "Benih Daun" : "Benih",
                    SEED_NAMES[i],
                    seedCounts[i]);
        }
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
        RectF close = inventoryCloseButtonBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(148, 75, 25));
        canvas.drawRoundRect(close, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(183, 100, 35));
        canvas.drawRoundRect(close, 10, 10, paint);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(255, 236, 190));
        canvas.drawLine(close.left + 16f, close.top + 16f, close.right - 16f, close.bottom - 16f, paint);
        canvas.drawLine(close.right - 16f, close.top + 16f, close.left + 16f, close.bottom - 16f, paint);
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
        float left = bodyLeft + 58f;
        float top = bodyTop + 48f;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 235, 171));
        paint.setTextSize(30f);
        paint.setFakeBoldText(true);
        canvas.drawText("Audio", left, top, paint);
        paint.setFakeBoldText(false);

        RectF chip = new RectF(left + 104f, top - 27f, left + 296f, top + 4f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(120, 58, 22));
        canvas.drawRoundRect(chip, 15, 15, paint);
        paint.setColor(Color.rgb(255, 218, 93));
        paint.setTextSize(15f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, "PIXEL SOUND", chip.centerX(), chip.top + 21f);
        paint.setFakeBoldText(false);

        paint.setColor(Color.rgb(248, 224, 188));
        paint.setTextSize(18f);
        canvas.drawText("Backsound, efek tombol, error, dan langkah karakter.", left, top + 35f, paint);

        drawAudioSettingRow(canvas, audioBgmRowBounds(), audioBgmToggleBounds(),
                "Backsound", "Musik latar game", audioBgmEnabled, Color.rgb(255, 203, 65), 0);
        drawAudioSettingRow(canvas, audioSfxRowBounds(), audioSfxToggleBounds(),
                "Efek suara", "Klik, error, langkah", audioSfxEnabled, Color.rgb(93, 202, 250), 1);
        drawAudioTrackRow(canvas, audioTrackRowBounds(), audioTrackButtonBounds());
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
        for (Plot plot : plots) {
            if (plot.state == PlotState.GROWING) {
                growing++;
            } else if (plot.state == PlotState.READY) {
                ready++;
            }
        }

        drawInventoryRow(canvas, x, y + 45f, Color.rgb(255, 209, 84), coinBalanceOnChain ? "Wallet coin" : "Coin lokal", coins);
        drawInventoryRow(canvas, x, y + 90f, Color.rgb(116, 209, 85), "Bibit tanaman", totalSeeds());
        drawInventoryRow(canvas, x, y + 135f, Color.rgb(235, 150, 63), "Hasil panen", harvests);
        drawInventoryRow(canvas, x, y + 180f, Color.rgb(123, 188, 91), "Lahan dimiliki", ownedLand);
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

    private RectF inventoryPanelBounds() {
        float w = clamp(getWidth() * 0.58f, 980f, 1320f);
        float h = clamp(getHeight() * 0.58f, 520f, 640f);
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
    }

    private RectF inventoryCloseButtonBounds() {
        RectF panel = inventoryPanelBounds();
        return new RectF(panel.right - 92f, panel.top + 38f, panel.right - 42f, panel.top + 88f);
    }

    private RectF backpackSeedTabBounds() {
        RectF panel = inventoryPanelBounds();
        float bodyTop = panel.top + 118f;
        return new RectF(panel.left + 34f, bodyTop + 30f, panel.left + 170f, bodyTop + 138f);
    }

    private RectF backpackAudioTabBounds() {
        RectF panel = inventoryPanelBounds();
        float bodyTop = panel.top + 118f;
        return new RectF(panel.left + 34f, bodyTop + 160f, panel.left + 170f, bodyTop + 268f);
    }

    private RectF backpackAboutTabBounds() {
        RectF panel = inventoryPanelBounds();
        float bodyTop = panel.top + 118f;
        return new RectF(panel.left + 34f, bodyTop + 290f, panel.left + 170f, bodyTop + 398f);
    }

    private RectF aboutGithubButtonBounds() {
        RectF panel = inventoryPanelBounds();
        float bodyTop = panel.top + 118f;
        float bodyLeft = panel.left + 220f;
        float left = bodyLeft + 252f;
        float top = bodyTop + 252f;
        return new RectF(left, top, Math.min(panel.right - 86f, left + 326f), top + 50f);
    }

    private RectF audioBgmRowBounds() {
        RectF panel = inventoryPanelBounds();
        float bodyTop = panel.top + 118f;
        float bodyLeft = panel.left + 220f;
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

    private void drawActionButton(Canvas canvas) {
        float cx = getWidth() - 92;
        float cy = getHeight() - 86;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(31, 100, 178));
        canvas.drawCircle(cx, cy, 42, paint);
        paint.setColor(Color.WHITE);
        paint.setTextSize(28f);
        paint.setFakeBoldText(true);
        canvas.drawText("A", cx - 10, cy + 10, paint);
        paint.setFakeBoldText(false);
    }

    private void drawWalletButton(Canvas canvas) {
        RectF bounds = walletButtonBounds();
        boolean connected = !walletAddress.isEmpty();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(95, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 14, 14, paint);
        paint.setColor(connected ? Color.rgb(36, 102, 68) : Color.rgb(42, 87, 62));
        canvas.drawRoundRect(bounds, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(connected ? Color.rgb(105, 196, 135) : Color.rgb(91, 143, 104));
        canvas.drawRoundRect(bounds, 14, 14, paint);

        float iconCx = bounds.left + 40f;
        float iconCy = (bounds.top + bounds.bottom) * 0.5f;
        drawWalletHudIcon(canvas, iconCx, iconCy, connected);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(236, 248, 226));
        paint.setTextSize(connected ? 20f : 21f);
        paint.setFakeBoldText(true);
        String label = connected ? shortAddress(walletAddress) : "CONNECT WALLET";
        paint.setTextSize(fitTextSize(label, connected ? 20f : 21f, bounds.width() - 96f));
        canvas.drawText(label, bounds.left + 76f, bounds.top + (connected ? 34f : 44f), paint);
        if (connected) {
            paint.setFakeBoldText(false);
            paint.setColor(Color.rgb(177, 238, 185));
            String subtitle = walletSubtitle();
            paint.setTextSize(fitTextSize(subtitle, 15f, bounds.width() - 96f));
            canvas.drawText(subtitle, bounds.left + 76f, bounds.top + 58f, paint);
        }
        paint.setFakeBoldText(false);
    }

    private void drawChainHistoryButton(Canvas canvas) {
        RectF bounds = chainHistoryButtonBounds();
        boolean hasHash = !chainHistory.isEmpty() && BlockchainClient.isValidTransactionHash(chainHistory.get(0).txHash);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 14, 14, paint);
        paint.setColor(Color.rgb(28, 69, 52));
        canvas.drawRoundRect(bounds, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(hasHash ? Color.rgb(105, 207, 123) : Color.rgb(92, 151, 105));
        canvas.drawRoundRect(bounds, 14, 14, paint);

        drawChainHistoryListIcon(canvas, bounds.centerX(), bounds.centerY(), hasHash);

        paint.setColor(chainHistory.isEmpty() ? Color.rgb(76, 112, 84) : Color.rgb(255, 219, 95));
        canvas.drawCircle(bounds.right - 8f, bounds.top + 9f, 15f, paint);
        paint.setColor(Color.rgb(30, 42, 28));
        paint.setTextSize(15f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, String.valueOf(chainHistory.size()), bounds.right - 8f, bounds.top + 14f);
        paint.setFakeBoldText(false);
    }

    private void drawChainHistoryDialog(Canvas canvas) {
        canvas.drawColor(Color.argb(166, 0, 0, 0));

        RectF panel = chainHistoryDialogBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(135, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 7f, panel.top + 9f, panel.right + 7f, panel.bottom + 9f, 18, 18, paint);
        paint.setColor(Color.rgb(23, 45, 39));
        canvas.drawRoundRect(panel, 18, 18, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(Color.rgb(92, 178, 114));
        canvas.drawRoundRect(panel, 18, 18, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(190, 248, 188));
        paint.setTextSize(32f);
        paint.setFakeBoldText(true);
        canvas.drawText("Riwayat transaksi", panel.left + 34f, panel.top + 52f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.rgb(202, 223, 207));
        String mode = blockchainClient.hasGameApi() ? "Signer backend aktif" : "Belum on-chain: signer backend kosong";
        paint.setTextSize(fitTextSize(mode, 20f, panel.width() - 138f));
        canvas.drawText(mode, panel.left + 34f, panel.top + 86f, paint);

        drawChainHistoryCloseButton(canvas, chainHistoryDialogCloseBounds());

        if (chainHistory.isEmpty()) {
            RectF empty = new RectF(panel.left + 30f, panel.top + 120f, panel.right - 30f, panel.bottom - 30f);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(34, 61, 51));
            canvas.drawRoundRect(empty, 12, 12, paint);
            paint.setColor(Color.rgb(211, 228, 211));
            paint.setTextSize(fitTextSize("Belum ada transaksi.", 22f, empty.width() - 40f));
            drawCenteredText(canvas, "Belum ada transaksi.", empty.centerX(), empty.centerY() + 7f);
            return;
        }

        int rows = visibleChainHistoryDialogRows();
        for (int i = 0; i < rows; i++) {
            drawChainHistoryRow(canvas, chainHistoryDialogRowBounds(i), chainHistory.get(i));
        }

        if (chainHistory.size() > rows) {
            String more = "+" + (chainHistory.size() - rows) + " riwayat lain";
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(197, 218, 201));
            paint.setTextSize(18f);
            drawCenteredText(canvas, more, panel.centerX(), panel.bottom - 22f);
        }
    }

    private void drawChainHistoryCloseButton(Canvas canvas, RectF close) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(43, 78, 61));
        canvas.drawRoundRect(close, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(213, 248, 211));
        canvas.drawLine(close.left + 17f, close.top + 17f, close.right - 17f, close.bottom - 17f, paint);
        canvas.drawLine(close.right - 17f, close.top + 17f, close.left + 17f, close.bottom - 17f, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawChainHistoryListIcon(Canvas canvas, float cx, float cy, boolean hasHash) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(hasHash ? Color.rgb(107, 224, 130) : Color.rgb(255, 219, 95));
        canvas.drawCircle(cx, cy, 22f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(31, 49, 36));
        canvas.drawLine(cx - 9f, cy - 8f, cx + 10f, cy - 8f, paint);
        canvas.drawLine(cx - 9f, cy, cx + 10f, cy, paint);
        canvas.drawLine(cx - 9f, cy + 8f, cx + 10f, cy + 8f, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawChainHistoryRow(Canvas canvas, RectF row, ChainHistoryEntry entry) {
        boolean hasHash = BlockchainClient.isValidTransactionHash(entry.txHash);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(hasHash ? Color.rgb(33, 78, 58) : Color.rgb(44, 63, 53));
        canvas.drawRoundRect(row, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(hasHash ? Color.rgb(102, 207, 123) : Color.rgb(83, 116, 92));
        canvas.drawRoundRect(row, 10, 10, paint);

        drawChainHistoryStateDot(canvas, row.left + 24f, row.top + 25f, hasHash, entry.status);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(241, 252, 232));
        paint.setFakeBoldText(true);
        paint.setTextSize(fitTextSize(entry.label, 21f, row.width() - 134f));
        canvas.drawText(entry.label, row.left + 50f, row.top + 27f, paint);

        paint.setFakeBoldText(false);
        paint.setColor(hasHash ? Color.rgb(181, 248, 188) : Color.rgb(203, 219, 207));
        String status = hasHash ? BlockchainClient.shortTransactionHash(entry.txHash) : entry.status;
        paint.setTextSize(fitTextSize(status, 16f, row.width() - 110f));
        canvas.drawText(status, row.left + 50f, row.top + 54f, paint);

        if (hasHash) {
            drawExternalLinkIcon(canvas, row.right - 32f, row.centerY());
        }
    }

    private void drawChainHistoryStateDot(Canvas canvas, float cx, float cy, boolean hasHash, String status) {
        paint.setStyle(Paint.Style.FILL);
        if (hasHash) {
            paint.setColor(Color.rgb(105, 224, 129));
        } else if (status != null && status.toLowerCase(Locale.US).contains("gagal")) {
            paint.setColor(Color.rgb(232, 105, 88));
        } else if (status != null && status.toLowerCase(Locale.US).contains("mengirim")) {
            paint.setColor(Color.rgb(255, 216, 89));
        } else if (status != null && status.toLowerCase(Locale.US).contains("belum")) {
            paint.setColor(Color.rgb(245, 166, 72));
        } else {
            paint.setColor(Color.rgb(157, 184, 165));
        }
        canvas.drawCircle(cx, cy, 6f, paint);
    }

    private RectF chainHistoryButtonBounds() {
        RectF wallet = walletButtonBounds();
        float top = wallet.bottom + 8f;
        float size = 66f;
        return new RectF(wallet.right - size, top, wallet.right, top + size);
    }

    private RectF chainHistoryDialogBounds() {
        int desiredRows = Math.min(CHAIN_HISTORY_LIMIT, chainHistory.size());
        float desiredWidth = clamp(getWidth() * 0.78f, 740f, 1060f);
        float width = Math.min(getWidth() - 40f, desiredWidth);
        float desiredHeight = chainHistory.isEmpty() ? 286f : 158f + desiredRows * 78f;
        float maxHeight = Math.max(220f, getHeight() - 54f);
        float height = Math.min(desiredHeight, maxHeight);
        float left = (getWidth() - width) * 0.5f;
        float top = (getHeight() - height) * 0.5f;
        return new RectF(left, top, left + width, top + height);
    }

    private RectF chainHistoryDialogCloseBounds() {
        RectF panel = chainHistoryDialogBounds();
        return new RectF(panel.right - 82f, panel.top + 24f, panel.right - 30f, panel.top + 76f);
    }

    private RectF chainHistoryDialogRowBounds(int rowIndex) {
        RectF panel = chainHistoryDialogBounds();
        float left = panel.left + 30f;
        float top = panel.top + 112f + rowIndex * 78f;
        return new RectF(left, top, panel.right - 30f, top + 66f);
    }

    private int visibleChainHistoryDialogRows() {
        if (chainHistory.isEmpty()) {
            return 0;
        }
        RectF panel = chainHistoryDialogBounds();
        int rowsByHeight = Math.max(1, (int) ((panel.height() - 136f) / 78f));
        return Math.min(Math.min(CHAIN_HISTORY_LIMIT, chainHistory.size()), rowsByHeight);
    }

    private String walletSubtitle() {
        if (checkingChain) {
            return "sync Sepolia...";
        }
        if (!walletNativeBalance.isEmpty()) {
            return "Sepolia ETH " + compactEth(walletNativeBalance);
        }
        return "tap untuk sync saldo";
    }

    private void drawWalletHudIcon(Canvas canvas, float cx, float cy, boolean connected) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(connected ? Color.rgb(112, 224, 132) : Color.rgb(244, 208, 87));
        canvas.drawCircle(cx, cy, 23f, paint);
        paint.setColor(Color.rgb(33, 47, 32));
        canvas.drawRoundRect(cx - 15f, cy - 11f, cx + 16f, cy + 12f, 5, 5, paint);
        paint.setColor(Color.rgb(240, 246, 228));
        canvas.drawRect(cx - 10f, cy - 4f, cx + 11f, cy + 0f, paint);
        paint.setColor(connected ? Color.rgb(69, 170, 83) : Color.rgb(193, 138, 36));
        canvas.drawCircle(cx + 15f, cy - 15f, 6f, paint);
    }

    private void drawContextMessage(Canvas canvas, long now) {
        String text = contextText(now);
        if (text.isEmpty()) {
            return;
        }
        paint.setTextSize(20f);
        float textW = paint.measureText(text);
        float x = (getWidth() - textW) / 2f;
        float y = getHeight() - 28f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(190, 23, 21, 18));
        canvas.drawRoundRect(x - 16, y - 30, x + textW + 16, y + 10, 8, 8, paint);
        paint.setColor(Color.WHITE);
        canvas.drawText(text, x, y, paint);
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
                return harvests > 0 ? "A: jual hasil panen ke wallet." : "Rumah jual panen: belum ada hasil panen.";
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
            return plotInteractionKind(plots.get(selectedPlot), now);
        }
        if (isNearShop()) {
            return InteractionKind.SHOP;
        }
        if (isNearSellHouse()) {
            return InteractionKind.SELL_HARVEST;
        }
        return InteractionKind.NONE;
    }

    private InteractionKind plotInteractionKind(Plot plot, long now) {
        if (!plot.owned) {
            return InteractionKind.BUY_LAND;
        }
        if (plot.state == PlotState.EMPTY) {
            return InteractionKind.PLANT;
        }
        if (plot.state == PlotState.GROWING) {
            if (now - plot.plantedAtMs >= GROW_TIME_MS) {
                return InteractionKind.HARVEST;
            }
            return InteractionKind.WAIT_CROP;
        }
        return InteractionKind.HARVEST;
    }

    private void drawShopPanel(Canvas canvas) {
        float w = 360;
        float h = 156;
        float x = (getWidth() - w) / 2f;
        float y = 84;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(230, 52, 34, 21));
        canvas.drawRoundRect(x, y, x + w, y + h, 10, 10, paint);
        paint.setColor(Color.rgb(255, 226, 88));
        paint.setTextSize(24f);
        paint.setFakeBoldText(true);
        canvas.drawText("Toko Aset", x + 22, y + 38, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.WHITE);
        String shopLine = "SHOP: pilih benih, bayar pakai coin wallet";
        String landLine = "Lahan: beli " + LAND_BUY_PRICE + ", jual kosong +" + LAND_SELL_PRICE + " coin";
        String harvestLine = "Rumah Jual Panen: tukar panen = 35 coin";
        paint.setTextSize(fitTextSize(shopLine, 19f, w - 44f));
        canvas.drawText(shopLine, x + 22, y + 78, paint);
        paint.setTextSize(fitTextSize(landLine, 19f, w - 44f));
        canvas.drawText(landLine, x + 22, y + 108, paint);
        paint.setTextSize(fitTextSize(harvestLine, 19f, w - 44f));
        canvas.drawText(harvestLine, x + 22, y + 138, paint);
    }

    private void drawChainPanel(Canvas canvas, long now) {
        RectF panel = chainPanelBounds(now);
        float w = panel.width();
        float x = panel.left;
        float y = panel.top;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(235, 18, 34, 30));
        canvas.drawRoundRect(panel, 10, 10, paint);
        paint.setColor(Color.rgb(152, 239, 176));
        paint.setTextSize(23f);
        paint.setFakeBoldText(true);
        canvas.drawText("Sepolia Blockchain", x + 22, y + 38, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.WHITE);
        paint.setTextSize(18f);
        paint.setTextSize(fitTextSize(chainStatus, 18f, w - 44f));
        canvas.drawText(chainStatus, x + 22, y + 72, paint);
        paint.setTextSize(18f);
        canvas.drawText("Wallet: " + (walletAddress.isEmpty() ? "belum diset" : shortAddress(walletAddress)), x + 22, y + 102, paint);
        String balanceLine = "TANI on-chain " + coins + (walletNativeBalance.isEmpty() ? "" : " | Sepolia ETH " + compactEth(walletNativeBalance));
        canvas.drawText(balanceLine, x + 22, y + 132, paint);
        paint.setTextSize(fitTextSize(chainModeText(), 17f, w - 44f));
        canvas.drawText(chainModeText(), x + 22, y + 162, paint);

        paint.setColor(Color.rgb(255, 219, 95));
        String nextAction = pendingChainActions.isEmpty()
                ? "Tidak ada aksi on-chain pending."
                : "Next: " + pendingChainActions.get(0).label();
        paint.setTextSize(18f);
        canvas.drawText(nextAction, x + 22, y + 194, paint);
        paint.setColor(Color.rgb(210, 225, 216));
        canvas.drawText("Tap wallet di kanan atas untuk sync saldo.", x + 22, y + 220, paint);
    }

    private RectF chainPanelBounds(long now) {
        float w = Math.min(getWidth() - 44f, 620f);
        float h = 232f;
        float x = (getWidth() - w) * 0.5f;
        float y = 78f;
        if (isStatusPopupVisible(now)) {
            y = statusPopupBounds().bottom + 18f;
        }
        float maxY = Math.max(78f, getHeight() - h - 82f);
        y = Math.min(y, maxY);
        return new RectF(x, y, x + w, y + h);
    }

    private String chainModeText() {
        if (blockchainClient.hasCoinContract() && blockchainClient.hasGameApi()) {
            return "Mode on-chain: saldo TANI dibaca dari contract, aksi dikirim ke signer.";
        }
        if (blockchainClient.hasCoinContract()) {
            return "Saldo TANI on-chain aktif; transaksi gameplay butuh signer backend.";
        }
        if (blockchainClient.hasGameApi()) {
            return "Signer backend aktif; contract TANI belum diset.";
        }
        return "Mode lokal: contract/API belum diisi di .env, aksi belum on-chain.";
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

        RectF textBox = new RectF(panel.left + 58f, panel.top + 178f, panel.right - 58f, panel.top + 276f);
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
        paint.setTextSize(fitTextSize(body, 28f, textBox.width() - 56f));
        paint.setFakeBoldText(false);
        canvas.drawText(body, textBox.left + 28f, textBox.top + 60f, paint);

        if (activeInteractionKind == InteractionKind.PLANT) {
            drawPlantSeedSelector(canvas);
            drawDialogButton(canvas, interactionSellLandButtonBounds(), "Jual lahan",
                    Color.rgb(114, 71, 24), Color.rgb(255, 178, 63), Color.rgb(255, 237, 205));
        }

        drawDialogButton(canvas, interactionPrimaryButtonBounds(), interactionPrimaryText(),
                Color.rgb(97, 50, 12), Color.rgb(255, 217, 0), Color.rgb(255, 237, 205));
        drawDialogButton(canvas, interactionSecondaryButtonBounds(), interactionSecondaryText(),
                Color.rgb(160, 5, 0), Color.rgb(92, 0, 0), Color.WHITE);
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
                shopBundleQuantity,
                SEED_NAMES[seedIndex]);
        String line2 = String.format(Locale.US,
                "Total %d benih - %d Coin. %s kamu %d.",
                selectedSeedTotalAmount(),
                selectedSeedTotalPrice(),
                coinBalanceOnChain ? "Wallet coin" : "Coin",
                coins);
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
        paint.setTextSize(fitTextSize(label, 23f, bounds.width() - 24f));
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, label, bounds.centerX(), bounds.top + bounds.height() * 0.62f);
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

        String selected = SEED_NAMES[selectedSeedIndex];
        String summary = String.format(Locale.US,
                "%s: %d | %s | Paket x%d = %d benih | Total %d Coin",
                coinBalanceOnChain ? "Wallet Coin" : "Coin",
                coins,
                selected,
                shopBundleQuantity,
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
        drawCenteredText(canvas, "x" + shopBundleQuantity, bounds.centerX(), bounds.top + 34f);
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
        boolean selected = seedIndex == selectedSeedIndex;
        boolean available = seedCounts[seedIndex] > 0;
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
        canvas.drawText("Stok x" + seedCounts[seedIndex], bounds.left + 68f, bounds.top + 62f, paint);
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
        boolean selected = seedIndex == selectedSeedIndex;
        boolean canBuy = coins >= totalPriceForSeed(seedIndex);
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
        canvas.drawText("Isi " + SEED_BUNDLE_AMOUNT + " - Stok x" + seedCounts[seedIndex],
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
        paint.setTextSize(fitTextSize(canBuy ? "Beli x" + shopBundleQuantity : "Kurang", 20f, button.width() - 18f));
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, canBuy ? "Beli x" + shopBundleQuantity : "Kurang", button.centerX(), button.top + 33f);
        paint.setFakeBoldText(false);
    }

    private void drawShopCloseButton(Canvas canvas) {
        RectF close = shopCloseButtonBounds();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(108, 53, 12));
        canvas.drawRoundRect(close, 12, 12, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(137, 68, 20));
        canvas.drawRoundRect(close, 12, 12, paint);
        paint.setStrokeWidth(6f);
        paint.setColor(Color.rgb(255, 238, 211));
        canvas.drawLine(close.left + 25f, close.top + 25f, close.right - 25f, close.bottom - 25f, paint);
        canvas.drawLine(close.right - 25f, close.top + 25f, close.left + 25f, close.bottom - 25f, paint);
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
                if (handleMenuTouch(x, y)) {
                    return true;
                }
                playClickSound();
                menuOpen = false;
                return true;
            }
            int tappedPlot = findTappedPlotSign(x, y);
            if (tappedPlot >= 0) {
                playClickSound();
                selectedPlot = tappedPlot;
                openInteractionDialog(plotInteractionKind(plots.get(tappedPlot), System.currentTimeMillis()));
                return true;
            }
            if (isNearShop() && shopNpcTapBounds().contains(x, y)) {
                playClickSound();
                showShopNpcBubble();
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
            }
            return true;
        }

        if (action == MotionEvent.ACTION_MOVE) {
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
        }
        return false;
    }

    private void toggleMenuPanel() {
        menuOpen = !menuOpen;
        if (menuOpen) {
            menuTab = MENU_TAB_INVENTORY;
        }
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
            selectedSeedIndex = (selectedSeedIndex + 1) % SEED_NAMES.length;
            showMessage("Benih dipilih: " + SEED_NAMES[selectedSeedIndex]);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
            playClickSound();
            selectedSeedIndex = (selectedSeedIndex + SEED_NAMES.length - 1) % SEED_NAMES.length;
            showMessage("Benih dipilih: " + SEED_NAMES[selectedSeedIndex]);
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
            openShopPurchaseConfirm(selectedSeedIndex);
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

    private boolean handleMenuTouch(float x, float y) {
        RectF panel = inventoryPanelBounds();
        if (!panel.contains(x, y)) {
            return false;
        }
        if (inventoryCloseButtonBounds().contains(x, y)) {
            playClickSound();
            menuOpen = false;
            return true;
        }
        if (backpackSeedTabBounds().contains(x, y)) {
            playClickSound();
            menuTab = MENU_TAB_INVENTORY;
            return true;
        }
        if (backpackAudioTabBounds().contains(x, y)) {
            playClickSound();
            menuTab = MENU_TAB_SETTINGS;
            return true;
        }
        if (backpackAboutTabBounds().contains(x, y)) {
            playClickSound();
            menuTab = MENU_TAB_ABOUT;
            return true;
        }
        if (menuTab == MENU_TAB_SETTINGS) {
            if (audioBgmRowBounds().contains(x, y) || audioBgmToggleBounds().contains(x, y)) {
                audioBgmEnabled = !audioBgmEnabled;
                gameAudio.setBgmEnabled(audioBgmEnabled);
                playClickSound();
                saveAudioSettings();
                showMessage(audioBgmEnabled ? "Backsound dinyalakan." : "Backsound dimatikan.");
                return true;
            }
            if (audioSfxRowBounds().contains(x, y) || audioSfxToggleBounds().contains(x, y)) {
                boolean nextEnabled = !audioSfxEnabled;
                if (audioSfxEnabled) {
                    playClickSound();
                }
                audioSfxEnabled = nextEnabled;
                gameAudio.setSfxEnabled(audioSfxEnabled);
                if (audioSfxEnabled) {
                    playClickSound();
                }
                saveAudioSettings();
                showMessage(audioSfxEnabled ? "Efek suara dinyalakan." : "Efek suara dimatikan.");
                return true;
            }
            if (audioTrackRowBounds().contains(x, y) || audioTrackButtonBounds().contains(x, y)) {
                gameAudio.nextBgm();
                audioTrackIndex = gameAudio.getBgmIndex();
                playClickSound();
                saveAudioSettings();
                showMessage("Backsound track " + (audioTrackIndex + 1) + " dipilih.");
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

        playClickSound();
        int rows = visibleChainHistoryDialogRows();
        for (int i = 0; i < rows; i++) {
            if (chainHistoryDialogRowBounds(i).contains(x, y)) {
                openEtherscanTransaction(chainHistory.get(i));
                return true;
            }
        }
        showMessage(chainHistory.isEmpty() ? "Belum ada transaksi." : "Pilih transaksi yang sudah punya hash.");
        return true;
    }

    private void openEtherscanTransaction(ChainHistoryEntry entry) {
        if (!BlockchainClient.isValidTransactionHash(entry.txHash)) {
            chainHistoryOpen = false;
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
        return "Transaksi ini belum punya hash Etherscan.";
    }

    private boolean handleInteractionDialogTouch(float x, float y) {
        if (activeInteractionKind == InteractionKind.PLANT) {
            for (int i = 0; i < SEED_NAMES.length; i++) {
                if (plantSeedOptionBounds(i).contains(x, y)) {
                    playClickSound();
                    selectedSeedIndex = i;
                    showMessage("Benih dipilih: " + SEED_NAMES[selectedSeedIndex]);
                    return true;
                }
            }
            if (interactionSellLandButtonBounds().contains(x, y)) {
                playClickSound();
                activeInteractionKind = InteractionKind.SELL_LAND;
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

    private void selectNextSeed(int direction) {
        selectedSeedIndex = (selectedSeedIndex + direction + SEED_NAMES.length) % SEED_NAMES.length;
        showMessage("Benih dipilih: " + SEED_NAMES[selectedSeedIndex]);
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
        if (activeInteractionKind == InteractionKind.PLANT && seedCounts[selectedSeedIndex] <= 0) {
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
                selectedSeedIndex = i;
                showMessage("Benih dipilih: " + SEED_NAMES[selectedSeedIndex]);
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
        selectedSeedIndex = seedIndex;
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
            return selectedSeedIndex;
        }
        return shopPurchaseSeedIndex;
    }

    private void adjustShopBundleQuantity(int delta) {
        shopBundleQuantity = (int) clamp(shopBundleQuantity + delta, 1, MAX_SHOP_BUNDLE_QUANTITY);
        showMessage("Jumlah paket: x" + shopBundleQuantity + " (" + selectedSeedTotalAmount() + " benih)");
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
    }

    private String interactionTitle() {
        switch (activeInteractionKind) {
            case SHOP:
                return "Ucup";
            case SELL_HARVEST:
                return "Jual Panen";
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
                return "Pilih benih yang mau dibeli memakai coin wallet.";
            case SELL_HARVEST:
                if (walletAddress.isEmpty()) {
                    return "Connect wallet dulu sebelum jual hasil panen.";
                }
                return harvests > 0
                        ? "Jual " + harvests + " hasil panen? Coin akan masuk ke wallet."
                        : "Belum ada hasil panen untuk dijual.";
            case BUY_LAND:
                return "Lahan ini bisa dibeli seharga " + LAND_BUY_PRICE + " coin.";
            case PLANT:
                return seedCounts[selectedSeedIndex] > 0
                        ? "Tanam " + SEED_NAMES[selectedSeedIndex] + " atau jual lahan kosong +" + LAND_SELL_PRICE + " coin."
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
                return harvests > 0 ? "Ya, jual panen" : "Oke";
            case BUY_LAND:
                return "Ya, beli lahan";
            case PLANT:
                return seedCounts[selectedSeedIndex] > 0 ? "Ya, tanam " + SEED_NAMES[selectedSeedIndex] : "Buka toko";
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
                return "Batal";
            default:
                return "Tidak apa-apa";
        }
    }

    private int activeCropRemainingSeconds(long now) {
        if (activeInteractionPlot < 0 || activeInteractionPlot >= plots.size()) {
            return 0;
        }
        Plot plot = plots.get(activeInteractionPlot);
        return Math.max(0, (int) ((GROW_TIME_MS - (now - plot.plantedAtMs)) / 1000L));
    }

    private RectF walletButtonBounds() {
        float right = getWidth() - 20f;
        float top = topMenuTop() + topMenuButtonSize() + 14f;
        float width = clamp(getWidth() * 0.28f, 292f, 360f);
        return new RectF(right - width, top, right, top + 72f);
    }

    private RectF interactionDialogPanelBounds() {
        float w = clamp(getWidth() * 0.58f, 720f, 900f);
        float h = activeInteractionKind == InteractionKind.PLANT
                ? clamp(getHeight() * 0.58f, 560f, 650f)
                : clamp(getHeight() * 0.45f, 410f, 510f);
        float left = (getWidth() - w) * 0.5f;
        float top = (getHeight() - h) * 0.5f;
        return new RectF(left, top, left + w, top + h);
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

    private RectF interactionPrimaryButtonBounds() {
        RectF panel = interactionDialogPanelBounds();
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
        float top = panel.bottom - 126f;
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
        return new RectF(panel.right - 118f, panel.top + 50f, panel.right - 38f, panel.top + 130f);
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
            openInteractionDialog(plotInteractionKind(plots.get(selectedPlot), System.currentTimeMillis()));
            return;
        }
        if (isNearShop()) {
            showShopNpcBubble();
            openInteractionDialog(InteractionKind.SHOP);
            return;
        }
        if (isNearSellHouse()) {
            openInteractionDialog(InteractionKind.SELL_HARVEST);
            return;
        }
        showErrorMessage("Dekati lahan, shop, atau rumah jual panen dulu.");
    }

    private void showShopNpcBubble() {
        shopNpcBubbleUntilMs = System.currentTimeMillis() + SHOP_NPC_BUBBLE_MS;
        invalidate();
    }

    private void performPlotAction(int plotIndex) {
        long now = System.currentTimeMillis();
        if (plotIndex < 0 || plotIndex >= plots.size()) {
            showErrorMessage("Dekati lahan dulu.");
            return;
        }
        Plot plot = plots.get(plotIndex);
        if (!plot.owned) {
            if (coins < LAND_BUY_PRICE) {
                showErrorMessage("Coin belum cukup untuk beli tanah.");
                return;
            }
            coins -= LAND_BUY_PRICE;
            plot.owned = true;
            ownedLand = calculateOwnedLand();
            queueChainAction(new ChainAction("BUY_LAND", plotIndex + 1, 1));
            saveGameState();
            showSuccessPopup("Tanah berhasil dibeli.");
            return;
        }
        if (plot.state == PlotState.EMPTY) {
            if (seedCounts[selectedSeedIndex] <= 0) {
                showErrorMessage("Benih " + SEED_NAMES[selectedSeedIndex] + " habis. Pilih benih lain di toko.");
                return;
            }
            seedCounts[selectedSeedIndex]--;
            plot.seedIndex = selectedSeedIndex;
            plot.state = PlotState.GROWING;
            plot.plantedAtMs = now;
            queueChainAction(new ChainAction("PLANT", plotIndex + 1, selectedSeedIndex + 1));
            saveGameState();
            showSuccessPopup("Benih " + SEED_NAMES[selectedSeedIndex] + " berhasil ditanam.");
            return;
        }
        if (plot.state == PlotState.GROWING) {
            showErrorMessage("Tanaman belum siap panen.");
            return;
        }
        int harvestedSeedIndex = plot.seedIndex;
        int harvestAmount = SEED_HARVEST_YIELDS[harvestedSeedIndex];
        startHarvestEffect(plot, harvestedSeedIndex, harvestAmount, now);
        plot.state = PlotState.EMPTY;
        harvests += harvestAmount;
        queueChainAction(new ChainAction("HARVEST", plotIndex + 1, harvestAmount));
        saveGameState();
        showSuccessPopup("Panen " + SEED_NAMES[harvestedSeedIndex] + " +" + harvestAmount + " masuk inventory.");
    }

    private void sellLand(int plotIndex) {
        if (plotIndex < 0 || plotIndex >= plots.size()) {
            showErrorMessage("Dekati lahan dulu.");
            return;
        }
        Plot plot = plots.get(plotIndex);
        if (!plot.owned) {
            showErrorMessage("Lahan ini belum dimiliki.");
            return;
        }
        if (plot.state != PlotState.EMPTY) {
            showErrorMessage("Kosongkan lahan sebelum dijual.");
            return;
        }
        if (actualOwnedLandCount() <= 1) {
            showErrorMessage("Minimal satu lahan harus tetap dimiliki.");
            return;
        }
        plot.owned = false;
        plot.seedIndex = 0;
        plot.plantedAtMs = 0L;
        ownedLand = calculateOwnedLand();
        coins += LAND_SELL_PRICE;
        queueChainAction(new ChainAction("SELL_LAND", plotIndex + 1, LAND_SELL_PRICE));
        saveGameState();
        showSuccessPopup("Lahan terjual. Coin +" + LAND_SELL_PRICE + ".");
    }

    private boolean canSellActiveLand() {
        if (activeInteractionPlot < 0 || activeInteractionPlot >= plots.size()) {
            return false;
        }
        Plot plot = plots.get(activeInteractionPlot);
        return plot.owned && plot.state == PlotState.EMPTY && actualOwnedLandCount() > 1;
    }

    private void startHarvestEffect(Plot plot, int seedIndex, int amount, long now) {
        float centerX = plot.x + plot.w * 0.5f;
        float centerY = plot.y + plot.h * 0.52f;
        harvestEffects.add(new HarvestEffect(centerX, centerY, seedIndex, amount, now));
    }

    private void buySeedsFromShop(int seedIndex) {
        selectedSeedIndex = seedIndex;
        if (blockchainClient.hasCoinContract()) {
            if (walletAddress.isEmpty()) {
                showErrorMessage("Connect wallet dulu supaya coin shop pakai wallet.");
                performWallet();
                return;
            }
            if (!coinBalanceOnChain && !checkingChain) {
                refreshWalletState(true);
                showErrorMessage("Sync saldo wallet dulu.");
                return;
            }
        }
        int price = totalPriceForSeed(seedIndex);
        if (coins < price) {
            showErrorMessage("Coin belum cukup untuk beli " + shopBundleQuantity + " paket " + SEED_NAMES[seedIndex] + ".");
            return;
        }
        coins -= price;
        int totalSeeds = totalSeedAmountForQuantity(shopBundleQuantity);
        seedCounts[seedIndex] += totalSeeds;
        queueChainAction(new ChainAction("BUY_SEED", seedIndex + 1, totalSeeds));
        saveGameState();
        showSuccessPopup("Berhasil membeli " + totalSeeds + " benih " + SEED_NAMES[seedIndex] + ".");
    }

    private void sellHarvestToWallet() {
        if (walletAddress.isEmpty()) {
            showErrorMessage("Connect wallet dulu sebelum jual panen.");
            performWallet();
            return;
        }
        if (harvests <= 0) {
            showErrorMessage("Belum ada hasil panen untuk dijual.");
            return;
        }
        int soldHarvests = harvests;
        int earnedCoins = soldHarvests * 35;
        harvests = 0;
        coins += earnedCoins;
        queueChainAction(new ChainAction("SELL_CROP", 0, soldHarvests));
        saveGameState();
        showSuccessPopup(String.format(Locale.US,
                "Terjual %d panen. Coin wallet +%d.",
                soldHarvests,
                earnedCoins));
    }

    private void performWallet() {
        if (!walletAddress.isEmpty()) {
            refreshWalletState(true);
            showMessage("Wallet sync: " + shortAddress(walletAddress));
            return;
        }
        checkSepolia(false);
        Context context = getContext();
        if (!(context instanceof Activity)) {
            return;
        }

        Dialog dialog = new Dialog(context);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout root = new LinearLayout(context);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(context, 30), dp(context, 28), dp(context, 30), dp(context, 24));
        root.setBackground(roundedStrokeDrawable(
                Color.rgb(55, 37, 24),
                dp(context, 18),
                Color.rgb(173, 91, 31),
                dp(context, 3)));

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = new TextView(context);
        icon.setText("W");
        icon.setTextColor(Color.rgb(52, 42, 23));
        icon.setTextSize(18f);
        icon.setGravity(Gravity.CENTER);
        icon.setTypeface(null, android.graphics.Typeface.BOLD);
        icon.setBackground(roundedDrawable(Color.rgb(244, 204, 72), dp(context, 11)));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dp(context, 38), dp(context, 38));
        header.addView(icon, iconParams);

        LinearLayout titleBlock = new LinearLayout(context);
        titleBlock.setOrientation(LinearLayout.VERTICAL);
        titleBlock.setPadding(dp(context, 14), 0, 0, 0);
        TextView title = new TextView(context);
        title.setText("Connect Wallet");
        title.setTextColor(Color.rgb(255, 230, 158));
        title.setTextSize(26f);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        TextView network = new TextView(context);
        network.setText("Sepolia network");
        network.setTextColor(Color.rgb(155, 220, 164));
        network.setTextSize(15f);
        titleBlock.addView(title);
        titleBlock.addView(network);
        header.addView(titleBlock, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        root.addView(header);

        TextView body = new TextView(context);
        body.setText("Masukkan public wallet address untuk sync saldo Sepolia dan coin TANI. Jangan masukkan private key.");
        body.setTextColor(Color.rgb(237, 223, 200));
        body.setTextSize(17f);
        body.setPadding(0, dp(context, 20), 0, dp(context, 18));
        root.addView(body);

        final EditText input = new EditText(context);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        input.setHint("0x wallet address Sepolia");
        input.setText(walletAddress);
        input.setTextColor(Color.WHITE);
        input.setHintTextColor(Color.rgb(185, 164, 138));
        input.setTextSize(18f);
        input.setPadding(dp(context, 16), 0, dp(context, 16), 0);
        input.setBackground(roundedStrokeDrawable(
                Color.rgb(38, 30, 24),
                dp(context, 10),
                Color.rgb(130, 85, 43),
                dp(context, 2)));
        root.addView(input, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(context, 54)));

        LinearLayout actions = new LinearLayout(context);
        actions.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        actions.setPadding(0, dp(context, 24), 0, 0);
        Button close = walletDialogButton(context, "Tutup", Color.rgb(91, 64, 40), Color.rgb(239, 220, 191));
        Button save = walletDialogButton(context, "Simpan", Color.rgb(214, 129, 39), Color.WHITE);
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(dp(context, 118), dp(context, 48));
        buttonParams.leftMargin = dp(context, 14);
        actions.addView(close, buttonParams);
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(dp(context, 126), dp(context, 48));
        saveParams.leftMargin = dp(context, 14);
        actions.addView(save, saveParams);
        root.addView(actions);

        close.setOnClickListener(v -> dialog.dismiss());
        save.setOnClickListener(v -> {
            String address = input.getText().toString().trim();
            if (!isValidAddress(address)) {
                showErrorMessage("Wallet address tidak valid.");
                return;
            }
            walletAddress = address;
            preferences.edit().putString("wallet_address", walletAddress).apply();
            showMessage("Wallet tersimpan: " + shortAddress(walletAddress));
            dialog.dismiss();
            refreshWalletState(true);
        });

        dialog.setContentView(root);
        dialog.show();
        Window dialogWindow = dialog.getWindow();
        if (dialogWindow != null) {
            dialogWindow.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            WindowManager.LayoutParams params = dialogWindow.getAttributes();
            params.dimAmount = 0.62f;
            dialogWindow.setAttributes(params);
            dialogWindow.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            dialogWindow.setLayout(
                    (int) clamp(getWidth() * 0.42f, 650f, 880f),
                    WindowManager.LayoutParams.WRAP_CONTENT);
        }
    }

    private static Button walletDialogButton(Context context, String label, int background, int textColor) {
        Button button = new Button(context);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextSize(15f);
        button.setTypeface(null, android.graphics.Typeface.BOLD);
        button.setTextColor(textColor);
        button.setBackground(roundedStrokeDrawable(background, dp(context, 10), Color.rgb(235, 164, 74), dp(context, 2)));
        return button;
    }

    private static GradientDrawable roundedDrawable(int color, float radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    private static GradientDrawable roundedStrokeDrawable(int color, float radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = roundedDrawable(color, radius);
        drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    private static int dp(Context context, float value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
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

    private void refreshWalletState(boolean revealPanel) {
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
            chainStatus = state.message;
            walletNativeBalance = state.nativeEth;
            if (!state.success) {
                playErrorSound();
            }
            if (state.success && state.coinBalanceAvailable) {
                coins = state.coinBalance;
                coinBalanceOnChain = true;
                saveGameState();
            } else if (state.success) {
                coinBalanceOnChain = false;
            }
            if (revealPanel) {
                chainPanelUntilMs = System.currentTimeMillis() + 5200L;
            }
            invalidate();
        });
    }

    private void queueChainAction(ChainAction action) {
        ChainHistoryEntry historyEntry = addChainHistory(action, initialChainHistoryStatus());
        chainPanelUntilMs = System.currentTimeMillis() + 2200L;
        if (!walletAddress.isEmpty() && blockchainClient.hasGameApi()) {
            pendingChainActions.add(action);
            blockchainClient.submitGameAction(walletAddress, action, result -> {
                chainStatus = result.message;
                pendingChainActions.remove(action);
                if (result.success) {
                    String status = BlockchainClient.isValidTransactionHash(result.txHash) ? "on-chain" : "dikirim";
                    updateChainHistory(historyEntry, status, result.txHash);
                } else {
                    updateChainHistory(historyEntry, "gagal kirim", "");
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
        return "lokal";
    }

    private String localChainStatus(ChainAction action) {
        if (walletAddress.isEmpty()) {
            return "Wallet belum connect; " + action.label() + " belum dikirim ke chain.";
        }
        if (!blockchainClient.hasGameApi()) {
            return "Signer backend belum diset; " + action.label() + " baru tersimpan lokal.";
        }
        return action.label() + " tersimpan lokal.";
    }

    private ChainHistoryEntry addChainHistory(ChainAction action, String status) {
        ChainHistoryEntry entry = new ChainHistoryEntry(action.label(), action.type, action.createdAtMs, status, "");
        chainHistory.add(0, entry);
        trimChainHistory();
        saveChainHistory();
        return entry;
    }

    private void updateChainHistory(ChainHistoryEntry entry, String status, String txHash) {
        entry.status = ChainHistoryEntry.normalizeStatus(status);
        if (BlockchainClient.isValidTransactionHash(txHash)) {
            entry.txHash = txHash.trim();
        }
        saveChainHistory();
    }

    private void trimChainHistory() {
        while (chainHistory.size() > CHAIN_HISTORY_LIMIT) {
            chainHistory.remove(chainHistory.size() - 1);
        }
    }

    private void loadGameState() {
        coins = preferences.getInt("game_coins", coins);
        harvests = preferences.getInt("game_harvests", harvests);
        selectedSeedIndex = clampInt(preferences.getInt("game_selected_seed", selectedSeedIndex), 0, SEED_NAMES.length - 1);
        shopBundleQuantity = clampInt(preferences.getInt("game_shop_quantity", shopBundleQuantity), 1, MAX_SHOP_BUNDLE_QUANTITY);
        boolean repairFreeLandState = preferences.getInt("game_land_state_version", 0) < LAND_STATE_VERSION;
        for (int i = 0; i < seedCounts.length; i++) {
            seedCounts[i] = Math.max(0, preferences.getInt("game_seed_" + i, seedCounts[i]));
        }

        long now = System.currentTimeMillis();
        for (int i = 0; i < plots.size(); i++) {
            Plot plot = plots.get(i);
            if (repairFreeLandState) {
                plot.owned = i == 0;
                plot.seedIndex = 0;
                plot.state = PlotState.EMPTY;
                plot.plantedAtMs = 0L;
            } else {
                plot.owned = preferences.getBoolean("game_plot_" + i + "_owned", plot.owned);
                plot.seedIndex = clampInt(preferences.getInt("game_plot_" + i + "_seed", plot.seedIndex), 0, SEED_NAMES.length - 1);
                plot.state = plotStateFromOrdinal(preferences.getInt("game_plot_" + i + "_state", plot.state.ordinal()));
                plot.plantedAtMs = preferences.getLong("game_plot_" + i + "_planted_at", plot.plantedAtMs);
            }
            if (plot.state == PlotState.GROWING && now - plot.plantedAtMs >= GROW_TIME_MS) {
                plot.state = PlotState.READY;
            }
        }
        ownedLand = calculateOwnedLand();
        if (repairFreeLandState) {
            saveGameState();
        }
    }

    private void loadChainHistory() {
        chainHistory.clear();
        String raw = preferences.getString(PREF_CHAIN_HISTORY, "");
        if (raw == null || raw.trim().isEmpty()) {
            return;
        }
        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                JSONObject object = array.optJSONObject(i);
                ChainHistoryEntry entry = ChainHistoryEntry.fromJson(object);
                if (entry != null) {
                    chainHistory.add(entry);
                }
            }
            trimChainHistory();
            saveChainHistory();
        } catch (JSONException exception) {
            chainHistory.clear();
            preferences.edit().remove(PREF_CHAIN_HISTORY).apply();
        }
    }

    private void saveChainHistory() {
        try {
            JSONArray array = new JSONArray();
            for (ChainHistoryEntry entry : chainHistory) {
                array.put(entry.toJson());
            }
            preferences.edit().putString(PREF_CHAIN_HISTORY, array.toString()).apply();
        } catch (JSONException ignored) {
            // A malformed local history entry should not block gameplay saves.
        }
    }

    private void saveGameState() {
        SharedPreferences.Editor editor = preferences.edit()
                .putInt("game_coins", coins)
                .putInt("game_harvests", harvests)
                .putInt("game_owned_land", ownedLand)
                .putInt("game_land_state_version", LAND_STATE_VERSION)
                .putInt("game_selected_seed", selectedSeedIndex)
                .putInt("game_shop_quantity", shopBundleQuantity);
        for (int i = 0; i < seedCounts.length; i++) {
            editor.putInt("game_seed_" + i, seedCounts[i]);
        }
        for (int i = 0; i < plots.size(); i++) {
            Plot plot = plots.get(i);
            editor.putBoolean("game_plot_" + i + "_owned", plot.owned)
                    .putInt("game_plot_" + i + "_seed", plot.seedIndex)
                    .putInt("game_plot_" + i + "_state", plot.state.ordinal())
                    .putLong("game_plot_" + i + "_planted_at", plot.plantedAtMs);
        }
        editor.apply();
    }

    private int calculateOwnedLand() {
        return Math.max(1, actualOwnedLandCount());
    }

    private int actualOwnedLandCount() {
        int total = 0;
        for (Plot plot : plots) {
            if (plot.owned) {
                total++;
            }
        }
        return total;
    }

    private static PlotState plotStateFromOrdinal(int ordinal) {
        PlotState[] states = PlotState.values();
        if (ordinal < 0 || ordinal >= states.length) {
            return PlotState.EMPTY;
        }
        return states[ordinal];
    }

    private static int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private int totalSeeds() {
        int total = 0;
        for (int count : seedCounts) {
            total += count;
        }
        return total;
    }

    private int selectedSeedTotalPrice() {
        return totalPriceForSeed(selectedSeedIndex);
    }

    private int selectedSeedTotalAmount() {
        return totalSeedAmountForQuantity(shopBundleQuantity);
    }

    private int totalPriceForSeed(int seedIndex) {
        return SEED_PRICES[seedIndex] * shopBundleQuantity;
    }

    private int totalSeedAmountForQuantity(int quantity) {
        return SEED_BUNDLE_AMOUNT * quantity;
    }

    private void showMessage(String text) {
        long now = System.currentTimeMillis();
        message = text;
        messageUntilMs = now + 1800L;
        if (!text.equals(statusPopupMessage)) {
            statusPopupUntilMs = 0L;
        }
    }

    private void showErrorMessage(String text) {
        playErrorSound();
        showMessage(text);
    }

    private void showSuccessPopup(String text) {
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
        for (int i = 0; i < plots.size(); i++) {
            Plot plot = plots.get(i);
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
        for (int i = 0; i < plots.size(); i++) {
            if (i == selectedPlot && plotActionSignTapBounds(plots.get(i)).contains(x, y)) {
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

    private void drawGrassTexture(Canvas canvas) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 79, 156, 72));
        int firstCol = Math.max(0, (int) (cameraX / TILE) - 1);
        int lastCol = Math.min(WORLD_COLS, (int) ((cameraX + getWidth()) / TILE) + 2);
        int firstRow = Math.max(0, (int) (cameraY / TILE) - 1);
        int lastRow = Math.min(WORLD_ROWS, (int) ((cameraY + getHeight()) / TILE) + 2);
        for (int y = firstRow; y < lastRow; y++) {
            for (int x = firstCol; x < lastCol; x++) {
                if ((x * 17 + y * 11) % 9 == 0) {
                    drawWorldRect(canvas, x * TILE + 9, y * TILE + 8, 4, 4);
                } else if ((x * 7 + y * 13) % 17 == 0) {
                    drawWorldRect(canvas, x * TILE + 21, y * TILE + 20, 3, 5);
                }
            }
        }
    }

    private void drawWaterRect(Canvas canvas, float x, float y, float w, float h) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(58, 177, 215));
        drawWorldRect(canvas, x, y, w, h);
        paint.setColor(Color.rgb(33, 138, 186));
        for (float yy = y + 12; yy < y + h; yy += 22) {
            for (float xx = x + 8; xx < x + w; xx += 58) {
                drawWorldRoundRect(canvas, xx, yy, 20, 5, 3);
            }
        }
        paint.setColor(Color.rgb(40, 113, 153));
        drawWorldRect(canvas, x, y, w, 5);
        drawWorldRect(canvas, x, y + h - 5, w, 5);
        drawWorldRect(canvas, x, y, 5, h);
        drawWorldRect(canvas, x + w - 5, y, 5, h);
    }

    private void drawRoad(Canvas canvas, float x, float y, float w, float h) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(238, 158, 78));
        drawWorldRect(canvas, x, y, w, h);
        paint.setColor(Color.rgb(210, 128, 58));
        for (float yy = y + 8; yy < y + h; yy += TILE) {
            for (float xx = x + 8; xx < x + w; xx += TILE) {
                drawWorldRect(canvas, xx, yy, 3, 3);
            }
        }
        paint.setColor(Color.rgb(31, 125, 64));
        for (float xx = x; xx < x + w; xx += 14) {
            drawWorldRect(canvas, xx, y - 5, 7, 5);
            drawWorldRect(canvas, xx, y + h, 7, 5);
        }
        for (float yy = y; yy < y + h; yy += 14) {
            drawWorldRect(canvas, x - 5, yy, 5, 7);
            drawWorldRect(canvas, x + w, yy, 5, 7);
        }
    }

    private void drawBridge(Canvas canvas, float x, float y, float w, float h, boolean vertical) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(153, 92, 55));
        drawWorldRect(canvas, x, y, w, h);
        paint.setColor(Color.rgb(93, 55, 43));
        if (vertical) {
            for (float yy = y + 6; yy < y + h; yy += 14) {
                drawWorldRect(canvas, x, yy, w, 4);
            }
        } else {
            for (float xx = x + 6; xx < x + w; xx += 14) {
                drawWorldRect(canvas, xx, y, 4, h);
            }
        }
    }

    private void drawFence(Canvas canvas, float x, float y, float w, float h) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(78, 43, 37));
        for (float xx = x; xx <= x + w; xx += TILE) {
            drawWorldRect(canvas, xx, y, 7, 30);
            drawWorldRect(canvas, xx, y + h - 30, 7, 30);
        }
        for (float yy = y; yy <= y + h; yy += TILE) {
            drawWorldRect(canvas, x, yy, 7, 30);
            drawWorldRect(canvas, x + w, yy, 7, 30);
        }
        paint.setColor(Color.rgb(126, 73, 47));
        drawWorldRect(canvas, x, y + 11, w, 7);
        drawWorldRect(canvas, x, y + h - 18, w, 7);
        drawWorldRect(canvas, x + 11, y, 7, h);
        drawWorldRect(canvas, x + w - 18, y, 7, h);
    }

    private void drawHouse(Canvas canvas, float x, float y, float w, float h, boolean shopHouse) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(101, 53, 42));
        drawWorldRect(canvas, x + 16, y + 58, w - 32, h - 62);
        paint.setColor(Color.rgb(244, 201, 166));
        drawWorldRect(canvas, x + 28, y + 72, w - 56, h - 92);
        paint.setColor(Color.rgb(119, 38, 24));
        drawWorldRect(canvas, x + 4, y + 42, w - 8, 30);
        paint.setColor(Color.rgb(183, 62, 26));
        for (int i = 0; i < 5; i++) {
            drawWorldRect(canvas, x + 12 + i * 36, y + 22 + i % 2 * 5, 46, 30);
        }
        paint.setColor(Color.rgb(70, 34, 31));
        drawWorldRect(canvas, x + 70, y + h - 100, 44, 82);
        paint.setColor(Color.rgb(139, 61, 35));
        drawWorldRect(canvas, x + 81, y + h - 86, 24, 48);
        paint.setColor(Color.rgb(74, 126, 181));
        drawWorldRect(canvas, x + w - 90, y + 93, 42, 36);
        paint.setColor(Color.WHITE);
        drawWorldRect(canvas, x + w - 84, y + 99, 12, 11);
        drawWorldRect(canvas, x + w - 66, y + 99, 12, 11);
        if (shopHouse) {
            paint.setColor(Color.rgb(255, 219, 95));
            drawWorldRect(canvas, x + 34, y + 100, 36, 20);
        }
    }

    private void drawShopStand(Canvas canvas, float x, float y) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(91, 55, 34));
        drawWorldRoundRect(canvas, x, y, 4.6f * TILE, 1.3f * TILE, 8);
        drawBitmapWorld(canvas, chest, x + 13, y + 3, 34, 34);
        paint.setColor(Color.WHITE);
        paint.setTextSize(15f);
        paint.setFakeBoldText(true);
        canvas.drawText("TOKO", x + 58 - cameraX, y + 27 - cameraY, paint);
        paint.setFakeBoldText(false);
    }

    private void drawLamp(Canvas canvas, float x, float y) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(37, 34, 40));
        drawWorldRect(canvas, x + 13, y + 16, 6, 58);
        drawWorldRect(canvas, x + 6, y + 72, 20, 7);
        paint.setColor(Color.rgb(255, 203, 60));
        drawWorldRect(canvas, x + 7, y + 2, 18, 24);
        paint.setColor(Color.rgb(57, 48, 56));
        drawWorldRect(canvas, x + 4, y, 24, 5);
        drawWorldRect(canvas, x + 4, y + 25, 24, 5);
    }

    private void drawTree(Canvas canvas, float x, float y, float scale) {
        float s = TILE * scale;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(92, 48, 31));
        drawWorldRect(canvas, x + s * 0.42f, y + s * 0.78f, s * 0.16f, s * 0.45f);
        paint.setColor(Color.rgb(40, 129, 62));
        drawWorldRoundRect(canvas, x, y + s * 0.2f, s, s * 0.7f, s * 0.18f);
        paint.setColor(Color.rgb(62, 179, 72));
        drawWorldRoundRect(canvas, x + s * 0.15f, y, s * 0.72f, s * 0.58f, s * 0.18f);
        paint.setColor(Color.rgb(107, 207, 82));
        drawWorldRoundRect(canvas, x + s * 0.38f, y + s * 0.08f, s * 0.25f, s * 0.16f, s * 0.08f);
    }

    private void drawBush(Canvas canvas, float x, float y) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(39, 132, 63));
        drawWorldRoundRect(canvas, x, y + 12, 58, 30, 16);
        paint.setColor(Color.rgb(219, 44, 63));
        drawWorldRoundRect(canvas, x + 8, y + 9, 10, 10, 5);
        drawWorldRoundRect(canvas, x + 34, y + 18, 10, 10, 5);
    }

    private void drawRock(Canvas canvas, float x, float y) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(111, 130, 130));
        drawWorldRoundRect(canvas, x, y + 9, 24, 18, 7);
        paint.setColor(Color.rgb(170, 186, 181));
        drawWorldRoundRect(canvas, x + 6, y + 5, 12, 9, 4);
    }

    private void drawBitmapWorld(Canvas canvas, Bitmap bitmap, float worldX, float worldY, float w, float h) {
        dst.set(worldX - cameraX, worldY - cameraY, worldX - cameraX + w, worldY - cameraY + h);
        canvas.drawBitmap(bitmap, null, dst, pixelPaint);
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
        int sourceX = (frame % columns) * frameW;
        int sourceY = (frame / columns) * frameH;
        src.set(sourceX, sourceY, sourceX + frameW, sourceY + frameH);
        dst.set(worldX - cameraX, worldY - cameraY, worldX - cameraX + w, worldY - cameraY + h);
        canvas.drawBitmap(bitmap, src, dst, pixelPaint);
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
        drawSpriteShadowWorld(canvas, worldX, worldY, w, h);
        drawSpriteWorld(canvas, bitmap, frame, frameW, frameH, columns, worldX, worldY, w, h);
    }

    private void drawSpriteShadowWorld(Canvas canvas, float worldX, float worldY, float w, float h) {
        float shadowW = w * 0.72f;
        float shadowH = Math.max(5f, h * 0.16f);
        float centerX = worldX + w * 0.5f - cameraX;
        float centerY = worldY + h * 0.87f - cameraY;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(62, 0, 0, 0));
        canvas.drawOval(
                centerX - shadowW * 0.5f,
                centerY - shadowH * 0.5f,
                centerX + shadowW * 0.5f,
                centerY + shadowH * 0.5f,
                paint);
    }

    private void drawWorldRect(Canvas canvas, float x, float y, float w, float h) {
        canvas.drawRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, paint);
    }

    private void drawWorldRoundRect(Canvas canvas, float x, float y, float w, float h, float r) {
        canvas.drawRoundRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, r, r, paint);
    }

    private void drawWorldLine(Canvas canvas, float x1, float y1, float x2, float y2) {
        canvas.drawLine(x1 - cameraX, y1 - cameraY, x2 - cameraX, y2 - cameraY, paint);
    }

    private void addFenceCollision(float x, float y, float w, float h) {
        float rail = TILE * 0.24f;
        addCollisionRect(x, y, w, rail);
        addCollisionRect(x, y + h - rail, w, rail);
        addCollisionRect(x, y, rail, h);
        addCollisionRect(x + w - rail, y, rail, h);
    }

    private void addHouseCollision(float x, float y, float w, float h) {
        addCollisionRect(x + TILE * 0.18f, y + TILE * 0.48f, w - TILE * 0.36f, h - TILE * 0.64f);
        addCollisionRect(x + TILE * 0.45f, y + h - TILE * 1.02f, TILE * 0.62f, TILE * 0.72f);
    }

    private void addTreeCollision(float x, float y, float scale) {
        float s = TILE * scale;
        addCollisionRect(x + s * 0.16f, y + s * 0.62f, s * 0.68f, s * 0.55f);
    }

    private void addCollisionRect(float x, float y, float w, float h) {
        collisionRects.add(new RectF(x, y, x + w, y + h));
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static boolean isValidAddress(String address) {
        return BlockchainClient.isValidAddress(address);
    }

    private static String compactEth(String value) {
        if (value == null || value.trim().isEmpty()) {
            return "0";
        }
        String cleaned = value.trim();
        int dot = cleaned.indexOf('.');
        if (dot < 0) {
            return cleaned;
        }
        int end = Math.min(cleaned.length(), dot + 7);
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
enum PlotState {
    EMPTY,
    GROWING,
    READY
}

enum InteractionKind {
    NONE,
    SHOP,
    SELL_HARVEST,
    BUY_LAND,
    PLANT,
    SELL_LAND,
    WAIT_CROP,
    HARVEST
}

final class HarvestEffect {
    final float centerX;
    final float centerY;
    final int seedIndex;
    final int amount;
    final long startedAtMs;
    final float phase;

    HarvestEffect(float centerX, float centerY, int seedIndex, int amount, long startedAtMs) {
        this.centerX = centerX;
        this.centerY = centerY;
        this.seedIndex = seedIndex;
        this.amount = amount;
        this.startedAtMs = startedAtMs;
        this.phase = (centerX * 0.017f + centerY * 0.011f) % 6.28f;
    }
}

final class ChainHistoryEntry {
    final String label;
    final String type;
    final long createdAtMs;
    String status;
    String txHash;

    ChainHistoryEntry(String label, String type, long createdAtMs, String status, String txHash) {
        this.label = label == null ? "Transaksi" : label;
        this.type = type == null ? "" : type;
        this.createdAtMs = createdAtMs;
        this.status = normalizeStatus(status);
        this.txHash = txHash == null ? "" : txHash;
    }

    static String normalizeStatus(String status) {
        String cleaned = status == null ? "" : status.trim();
        String lower = cleaned.toLowerCase(Locale.US);
        if ("pending signer".equals(lower) || "pending lokal".equals(lower)) {
            return "belum on-chain";
        }
        if ("pending wallet".equals(lower)) {
            return "butuh wallet";
        }
        return cleaned;
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("label", label);
        object.put("type", type);
        object.put("createdAtMs", createdAtMs);
        object.put("status", status);
        object.put("txHash", txHash);
        return object;
    }

    static ChainHistoryEntry fromJson(JSONObject object) {
        if (object == null) {
            return null;
        }
        String label = object.optString("label", "Transaksi");
        String type = object.optString("type", "");
        long createdAtMs = object.optLong("createdAtMs", System.currentTimeMillis());
        String status = object.optString("status", "");
        String txHash = object.optString("txHash", "");
        if (!BlockchainClient.isValidTransactionHash(txHash)) {
            txHash = "";
        }
        return new ChainHistoryEntry(label, type, createdAtMs, status, txHash);
    }
}

final class Plot {
    final float x;
    final float y;
    final float w;
    final float h;
    boolean owned;
    int seedIndex;
    PlotState state = PlotState.EMPTY;
    long plantedAtMs;

    Plot(float x, float y, float w, float h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }
}
