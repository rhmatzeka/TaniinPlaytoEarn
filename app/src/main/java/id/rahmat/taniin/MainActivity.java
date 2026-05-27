package id.rahmat.taniin;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        configureFullscreenWindow();
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        hideSystemUi();
        setContentView(new FarmGameView(this));
    }

    @Override
    protected void onResume() {
        super.onResume();
        hideSystemUi();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUi();
        }
    }

    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        }
    }

    private void configureFullscreenWindow() {
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(attributes);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false);
        }
    }

    private static final class FarmGameView extends View {
        private static final int TILE = 128;
        private static final int WORLD_COLS = 72;
        private static final int WORLD_ROWS = 52;
        private static final float PLAYER_SPEED = TILE * 3.9f;
        private static final long GROW_TIME_MS = 12_000L;
        private static final int DIR_RIGHT = 0;
        private static final int DIR_UP = 1;
        private static final int DIR_DOWN = 2;
        private static final int DIR_LEFT = 3;
        private static final float HORIZONTAL_FACING_BIAS = 0.70f;
        private static final float JOYSTICK_RADIUS = 82f;
        private static final float JOYSTICK_KNOB_RADIUS = 34f;
        private static final float JOYSTICK_TRAVEL = 76f;
        private static final float SHOP_LEFT_TILE = 13.8f;
        private static final float SHOP_RIGHT_TILE = 26.4f;
        private static final float SHOP_TOP_TILE = 16.6f;
        private static final float SHOP_BOTTOM_TILE = 31.2f;
        private static final float SHOP_ALT_LEFT_TILE = 27.8f;
        private static final float SHOP_ALT_RIGHT_TILE = 35.6f;
        private static final float SHOP_ALT_TOP_TILE = 8.2f;
        private static final float SHOP_ALT_BOTTOM_TILE = 18.2f;
        private static final int MENU_TAB_INVENTORY = 0;
        private static final int MENU_TAB_SETTINGS = 1;

        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint pixelPaint = new Paint();
        private final Rect src = new Rect();
        private final RectF dst = new RectF();
        private final List<Plot> plots = new ArrayList<>();
        private final List<RectF> collisionRects = new ArrayList<>();
        private final List<ChainAction> pendingChainActions = new ArrayList<>();
        private final BlockchainClient blockchainClient = new BlockchainClient();
        private final SharedPreferences preferences;
        private TmxMap tmxMap;

        private final Bitmap idleSheet;
        private final Bitmap walkSheet;
        private final Bitmap cropSheet;
        private final Bitmap chest;
        private final Bitmap chicken;
        private final Bitmap babyChicken;
        private final Bitmap cow;

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
        private long lastFrameMs;
        private long messageUntilMs;
        private long shopUntilMs;
        private long chainPanelUntilMs;
        private String message = "Dekati lahan atau toko, lalu tekan tombol aksi.";
        private String walletAddress = "";
        private String chainStatus = "Sepolia belum dicek.";
        private boolean checkingChain;
        private String mapStatus = "";

        private int coins = 500;
        private int seeds = 6;
        private int harvests = 0;
        private int ownedLand = 1;
        private int selectedPlot = -1;
        private boolean moving;
        private boolean menuOpen;
        private int menuTab = MENU_TAB_INVENTORY;
        private int facingDirection = DIR_DOWN;
        private int walkFrame;
        private long walkTickMs;
        private int worldWidthPixels = WORLD_COLS * TILE;
        private int worldHeightPixels = WORLD_ROWS * TILE;

        FarmGameView(Context context) {
            super(context);
            setFocusable(true);
            pixelPaint.setAntiAlias(false);
            pixelPaint.setFilterBitmap(false);
            preferences = context.getSharedPreferences("taniin_chain", Context.MODE_PRIVATE);
            walletAddress = preferences.getString("wallet_address", "");
            idleSheet = decodePixelResource(R.drawable.idle);
            walkSheet = decodePixelResource(R.drawable.walk);
            cropSheet = decodePixelResource(R.drawable.spring_crops);
            chest = decodePixelResource(R.drawable.chest);
            chicken = decodePixelResource(R.drawable.chicken_blonde_green);
            babyChicken = decodePixelResource(R.drawable.baby_chicken_yellow);
            cow = decodePixelResource(R.drawable.female_cow_brown);
            loadTmxMap(context);
            createWorld();
        }

        private Bitmap decodePixelResource(int resId) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inScaled = false;
            return BitmapFactory.decodeResource(getResources(), resId, options);
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
        protected void onDraw(Canvas canvas) {
            long now = System.currentTimeMillis();
            if (lastFrameMs == 0L) {
                lastFrameMs = now;
            }
            float dt = Math.min((now - lastFrameMs) / 1000f, 0.033f);
            lastFrameMs = now;

            update(dt, now);
            drawGame(canvas, now);
            postInvalidateOnAnimation();
        }

        private void update(float dt, long now) {
            float dx = joyX - joyBaseX;
            float dy = joyY - joyBaseY;
            float distance = (float) Math.hypot(dx, dy);
            moving = joystickActive && distance > 8f;
            if (moving) {
                float nx = dx / Math.max(distance, 1f);
                float ny = dy / Math.max(distance, 1f);
                updateFacingDirection(nx, ny);
                movePlayer(
                        playerX + nx * PLAYER_SPEED * dt,
                        playerY + ny * PLAYER_SPEED * dt);
                if (now - walkTickMs > 120L) {
                    walkFrame = (walkFrame + 1) % 6;
                    walkTickMs = now;
                }
            }

            selectedPlot = findNearbyPlot();
            for (Plot plot : plots) {
                if (plot.state == PlotState.GROWING && now - plot.plantedAtMs >= GROW_TIME_MS) {
                    plot.state = PlotState.READY;
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

        private void movePlayer(float targetX, float targetY) {
            float nextX = clamp(targetX, 1.2f * TILE, worldWidthPixels - 1.2f * TILE);
            float nextY = clamp(targetY, 1.2f * TILE, worldHeightPixels - 1.2f * TILE);
            if (!collidesAt(nextX, playerY)) {
                playerX = nextX;
            }
            if (!collidesAt(playerX, nextY)) {
                playerY = nextY;
            }
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
            drawMapDecorations(canvas, false);
            drawPlots(canvas, now);
            if (tmxMap == null) {
                drawDecorations(canvas);
            }
            drawPlayer(canvas, now);
            if (tmxMap != null) {
                tmxMap.drawForeground(canvas, cameraX, cameraY, TILE);
            }
            drawMapDecorations(canvas, true);
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
            src.set(stage * cell, 0, stage * cell + cell, cell);
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

            drawHouse(canvas, 32 * TILE, 24 * TILE, 7 * TILE, 7 * TILE, false);
            drawHouse(canvas, 56 * TILE, 10 * TILE, 7 * TILE, 7 * TILE, true);
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

        private void drawMapDecorations(Canvas canvas, boolean foreground) {
            if (tmxMap == null) {
                return;
            }
            if (foreground) {
                return;
            }
            drawSpriteWorld(canvas, chicken, 0, 16, 16, 4, 22.25f * TILE, 17.50f * TILE, TILE * 0.50f, TILE * 0.50f);
            drawSpriteWorld(canvas, chicken, 1, 16, 16, 4, 23.00f * TILE, 17.50f * TILE, TILE * 0.50f, TILE * 0.50f);
            drawSpriteWorld(canvas, chicken, 2, 16, 16, 4, 24.15f * TILE, 22.10f * TILE, TILE * 0.50f, TILE * 0.50f);
            drawSpriteWorld(canvas, chicken, 4, 16, 16, 4, 20.80f * TILE, 22.55f * TILE, TILE * 0.50f, TILE * 0.50f);
            drawSpriteWorld(canvas, babyChicken, 0, 16, 16, 4, 21.45f * TILE, 22.95f * TILE, TILE * 0.38f, TILE * 0.38f);
            drawSpriteWorld(canvas, babyChicken, 1, 16, 16, 4, 22.85f * TILE, 21.85f * TILE, TILE * 0.38f, TILE * 0.38f);
            drawSpriteWorld(canvas, cow, 0, 32, 32, 4, 22.60f * TILE, 20.00f * TILE, TILE, TILE);
            drawSpriteWorld(canvas, chest, 0, 32, 16, 1, 23.80f * TILE, 23.10f * TILE, TILE * 0.75f, TILE * 0.38f);
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
            drawShopButton(canvas);
            drawWalletButton(canvas);
            drawContextMessage(canvas, now);
            if (shopUntilMs > now) {
                drawShopPanel(canvas);
            }
            if (chainPanelUntilMs > now) {
                drawChainPanel(canvas);
            }
            if (menuOpen) {
                drawMenuPanel(canvas);
            }
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
            canvas.drawText("Coin " + coins, left + 16f, top + 34f, paint);
            paint.setColor(Color.WHITE);
            canvas.drawText("Bibit " + seeds, left + 122f, top + 34f, paint);
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
            canvas.drawText("Sepolia", left + 16, 47, paint);
            paint.setColor(Color.WHITE);
            String wallet = walletAddress.isEmpty() ? "wallet belum connect" : shortAddress(walletAddress);
            canvas.drawText(wallet, left + 98, 47, paint);
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

            RectF seedTab = new RectF(panel.left + 34f, bodyTop + 42f, panel.left + 170f, bodyTop + 188f);
            RectF harvestTab = new RectF(panel.left + 34f, bodyTop + 218f, panel.left + 170f, bodyTop + 364f);
            drawBackpackSideTab(canvas, seedTab, true, "SEEDS", Color.rgb(255, 207, 14));
            drawBackpackSideTab(canvas, harvestTab, false, "HARVEST", Color.rgb(244, 151, 47));

            float cardTop = bodyTop + 43f;
            float cardLeft = bodyLeft + 42f;
            float cardW = 116f;
            float cardH = 118f;
            float gap = 34f;
            drawInventoryItemCard(canvas, cardLeft, cardTop, cardW, cardH,
                    Color.rgb(169, 75, 31), Color.rgb(174, 97, 222), "Benih", "Kentang", seeds);
            drawInventoryItemCard(canvas, cardLeft + (cardW + gap), cardTop, cardW, cardH,
                    Color.rgb(74, 113, 159), Color.rgb(122, 205, 126), "Benih Daun", "Bawang", 0);
            drawInventoryItemCard(canvas, cardLeft + 2f * (cardW + gap), cardTop, cardW, cardH,
                    Color.rgb(170, 60, 36), Color.rgb(236, 70, 103), "Benih", "Stroberi", 0);
            drawInventoryItemCard(canvas, cardLeft + 3f * (cardW + gap), cardTop, cardW, cardH,
                    Color.rgb(169, 77, 27), Color.rgb(247, 156, 88), "Benih", "Bit", 0);
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
            float iconY = tab.top + 55f;
            if ("SEEDS".equals(label)) {
                drawSeedSproutIcon(canvas, cx, iconY, active ? Color.rgb(80, 210, 83) : Color.rgb(235, 185, 70));
            } else {
                drawHarvestIcon(canvas, cx, iconY, accent);
            }
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(active ? Color.rgb(48, 29, 11) : Color.rgb(242, 228, 198));
            paint.setTextSize(19f);
            paint.setFakeBoldText(true);
            drawCenteredText(canvas, label, cx, tab.bottom - 31f);
            paint.setFakeBoldText(false);
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

            drawInventoryRow(canvas, x, y + 45f, Color.rgb(255, 209, 84), "Coin", coins);
            drawInventoryRow(canvas, x, y + 90f, Color.rgb(116, 209, 85), "Bibit tanaman", seeds);
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
            canvas.drawText(chainStatus, x, y + 108f, paint);
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

        private void drawShopButton(Canvas canvas) {
            float right = getWidth() - 150;
            float bottom = getHeight() - 42;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(116, 72, 31));
            canvas.drawRoundRect(right - 128, bottom - 52, right, bottom, 12, 12, paint);
            paint.setColor(Color.WHITE);
            paint.setTextSize(20f);
            paint.setFakeBoldText(true);
            canvas.drawText("SHOP", right - 94, bottom - 18, paint);
            paint.setFakeBoldText(false);
        }

        private void drawWalletButton(Canvas canvas) {
            RectF bounds = walletButtonBounds();
            boolean connected = !walletAddress.isEmpty();

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(95, 0, 0, 0));
            canvas.drawRoundRect(bounds.left + 4f, bounds.top + 5f, bounds.right + 4f, bounds.bottom + 5f, 12, 12, paint);
            paint.setColor(connected ? Color.rgb(36, 102, 68) : Color.rgb(42, 87, 62));
            canvas.drawRoundRect(bounds, 12, 12, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(3f);
            paint.setColor(connected ? Color.rgb(105, 196, 135) : Color.rgb(91, 143, 104));
            canvas.drawRoundRect(bounds, 12, 12, paint);

            float iconCx = bounds.left + 30f;
            float iconCy = (bounds.top + bounds.bottom) * 0.5f;
            drawWalletHudIcon(canvas, iconCx, iconCy, connected);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(236, 248, 226));
            paint.setTextSize(16f);
            paint.setFakeBoldText(true);
            String label = connected ? shortAddress(walletAddress) : "CONNECT WALLET";
            canvas.drawText(label, bounds.left + 58f, bounds.top + 31f, paint);
            paint.setFakeBoldText(false);
        }

        private void drawWalletHudIcon(Canvas canvas, float cx, float cy, boolean connected) {
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(connected ? Color.rgb(112, 224, 132) : Color.rgb(244, 208, 87));
            canvas.drawCircle(cx, cy, 17f, paint);
            paint.setColor(Color.rgb(33, 47, 32));
            canvas.drawRoundRect(cx - 11f, cy - 8f, cx + 12f, cy + 9f, 4, 4, paint);
            paint.setColor(Color.rgb(240, 246, 228));
            canvas.drawRect(cx - 7f, cy - 3f, cx + 8f, cy + 0f, paint);
            paint.setColor(connected ? Color.rgb(69, 170, 83) : Color.rgb(193, 138, 36));
            canvas.drawCircle(cx + 11f, cy - 11f, 5f, paint);
        }

        private void drawContextMessage(Canvas canvas, long now) {
            String text = contextText(now);
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
            if (isNearShop()) {
                return "Toko: SHOP beli bibit, A jual hasil panen.";
            }
            if (selectedPlot >= 0) {
                Plot plot = plots.get(selectedPlot);
                if (!plot.owned) {
                    return "A beli lahan 250 coin.";
                }
                if (plot.state == PlotState.EMPTY) {
                    return "A tanam bibit.";
                }
                if (plot.state == PlotState.GROWING) {
                    int remain = Math.max(0, (int) ((GROW_TIME_MS - (now - plot.plantedAtMs)) / 1000L));
                    return "Tanaman tumbuh: " + remain + " detik.";
                }
                return "A panen tanaman.";
            }
            return "Dekati lahan atau toko.";
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
            paint.setTextSize(19f);
            canvas.drawText("SHOP: beli 3 bibit = 60 coin", x + 22, y + 78, paint);
            canvas.drawText("Dekati lahan terkunci lalu A: beli tanah", x + 22, y + 108, paint);
            canvas.drawText("Dekati toko lalu A: jual panen = 35 coin", x + 22, y + 138, paint);
        }

        private void drawChainPanel(Canvas canvas) {
            float w = 470;
            float h = 205;
            float x = (getWidth() - w) / 2f;
            float y = 78;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(235, 18, 34, 30));
            canvas.drawRoundRect(x, y, x + w, y + h, 10, 10, paint);
            paint.setColor(Color.rgb(152, 239, 176));
            paint.setTextSize(23f);
            paint.setFakeBoldText(true);
            canvas.drawText("Sepolia Blockchain", x + 22, y + 38, paint);
            paint.setFakeBoldText(false);
            paint.setColor(Color.WHITE);
            paint.setTextSize(18f);
            canvas.drawText(chainStatus, x + 22, y + 72, paint);
            canvas.drawText("Wallet: " + (walletAddress.isEmpty() ? "belum diset" : shortAddress(walletAddress)), x + 22, y + 102, paint);
            canvas.drawText("Contract: isi address setelah deploy.", x + 22, y + 132, paint);

            paint.setColor(Color.rgb(255, 219, 95));
            String nextAction = pendingChainActions.isEmpty()
                    ? "Tidak ada aksi on-chain pending."
                    : "Next: " + pendingChainActions.get(0).label();
            canvas.drawText(nextAction, x + 22, y + 164, paint);
            paint.setColor(Color.rgb(210, 225, 216));
            canvas.drawText("Tap CONNECT WALLET untuk input address & cek RPC.", x + 22, y + 190, paint);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            int index = event.getActionIndex();
            int pointerId = event.getPointerId(index);

            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
                float x = event.getX(index);
                float y = event.getY(index);
                if (topMenuButtonBounds().contains(x, y)) {
                    menuOpen = !menuOpen;
                    if (menuOpen) {
                        menuTab = MENU_TAB_INVENTORY;
                    }
                    return true;
                }
                if (menuOpen) {
                    if (handleMenuTouch(x, y)) {
                        return true;
                    }
                    menuOpen = false;
                    return true;
                }
                if (isInsideJoystickArea(x, y)) {
                    joystickActive = true;
                    joystickPointerId = pointerId;
                    joyBaseX = joystickBaseX();
                    joyBaseY = joystickBaseY();
                    updateJoystick(x, y);
                } else if (isInsideAction(x, y)) {
                    performAction();
                } else if (isInsideShop(x, y)) {
                    performShop();
                } else if (isInsideWallet(x, y)) {
                    performWallet();
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
                }
                return true;
            }
            return true;
        }

        private boolean handleMenuTouch(float x, float y) {
            RectF panel = inventoryPanelBounds();
            if (!panel.contains(x, y)) {
                return false;
            }
            if (inventoryCloseButtonBounds().contains(x, y)) {
                menuOpen = false;
                return true;
            }
            return true;
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

        private boolean isInsideShop(float x, float y) {
            float right = getWidth() - 150;
            float bottom = getHeight() - 42;
            return x >= right - 128 && x <= right && y >= bottom - 52 && y <= bottom;
        }

        private boolean isInsideWallet(float x, float y) {
            return walletButtonBounds().contains(x, y);
        }

        private RectF walletButtonBounds() {
            float right = getWidth() - 20f;
            float top = topMenuTop() + topMenuButtonSize() + 14f;
            float width = clamp(getWidth() * 0.23f, 190f, 236f);
            return new RectF(right - width, top, right, top + 52f);
        }

        private void performAction() {
            long now = System.currentTimeMillis();
            if (isNearShop()) {
                if (harvests <= 0) {
                    showMessage("Belum ada hasil panen untuk dijual.");
                    return;
                }
                queueChainAction(new ChainAction("SELL_CROP", 0, harvests));
                coins += harvests * 35;
                showMessage(String.format(Locale.US, "Terjual %d panen. Coin +%d.", harvests, harvests * 35));
                harvests = 0;
                return;
            }
            if (selectedPlot < 0) {
                showMessage("Dekati lahan dulu.");
                return;
            }
            Plot plot = plots.get(selectedPlot);
            if (!plot.owned) {
                if (coins < 250) {
                    showMessage("Coin belum cukup untuk beli tanah.");
                    return;
                }
                coins -= 250;
                ownedLand++;
                plot.owned = true;
                queueChainAction(new ChainAction("BUY_LAND", selectedPlot + 1, 1));
                showMessage("Tanah berhasil dibeli.");
                return;
            }
            if (plot.state == PlotState.EMPTY) {
                if (seeds <= 0) {
                    showMessage("Bibit habis. Beli di toko.");
                    return;
                }
                seeds--;
                plot.state = PlotState.GROWING;
                plot.plantedAtMs = now;
                queueChainAction(new ChainAction("PLANT", selectedPlot + 1, 1));
                showMessage("Bibit ditanam.");
                return;
            }
            if (plot.state == PlotState.GROWING) {
                showMessage("Tanaman belum siap panen.");
                return;
            }
            plot.state = PlotState.EMPTY;
            harvests += 3;
            queueChainAction(new ChainAction("HARVEST", selectedPlot + 1, 3));
            showMessage("Panen +3 masuk inventory.");
        }

        private void performShop() {
            if (!isNearShop()) {
                showMessage("Dekati toko dulu.");
                return;
            }
            shopUntilMs = System.currentTimeMillis() + 2500L;
            if (coins < 60) {
                showMessage("Coin belum cukup untuk beli bibit.");
                return;
            }
            coins -= 60;
            seeds += 3;
            queueChainAction(new ChainAction("BUY_SEED", 0, 3));
            showMessage("Beli 3 bibit.");
        }

        private void performWallet() {
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
            body.setText("Masukkan public wallet address untuk menyimpan profil wallet. Jangan masukkan private key.");
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
                    showMessage("Wallet address tidak valid.");
                    return;
                }
                walletAddress = address;
                preferences.edit().putString("wallet_address", walletAddress).apply();
                showMessage("Wallet tersimpan: " + shortAddress(walletAddress));
                dialog.dismiss();
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
            checkingChain = true;
            chainStatus = "Cek Sepolia RPC...";
            blockchainClient.checkSepolia(result -> {
                checkingChain = false;
                chainStatus = result.message;
                if (revealPanel) {
                    chainPanelUntilMs = System.currentTimeMillis() + 4500L;
                }
                invalidate();
            });
        }

        private void queueChainAction(ChainAction action) {
            pendingChainActions.add(action);
            chainPanelUntilMs = System.currentTimeMillis() + 2200L;
        }

        private void showMessage(String text) {
            message = text;
            messageUntilMs = System.currentTimeMillis() + 1800L;
        }

        private int findNearbyPlot() {
            for (int i = 0; i < plots.size(); i++) {
                Plot plot = plots.get(i);
                RectF area = new RectF(plot.x - TILE, plot.y - TILE, plot.x + plot.w + TILE, plot.y + plot.h + TILE);
                if (area.contains(playerX, playerY)) {
                    return i;
                }
            }
            return -1;
        }

        private boolean isNearShop() {
            boolean nearMainHouse = playerX > SHOP_LEFT_TILE * TILE
                    && playerX < SHOP_RIGHT_TILE * TILE
                    && playerY > SHOP_TOP_TILE * TILE
                    && playerY < SHOP_BOTTOM_TILE * TILE;
            boolean nearUpperHouse = playerX > SHOP_ALT_LEFT_TILE * TILE
                    && playerX < SHOP_ALT_RIGHT_TILE * TILE
                    && playerY > SHOP_ALT_TOP_TILE * TILE
                    && playerY < SHOP_ALT_BOTTOM_TILE * TILE;
            return nearMainHouse || nearUpperHouse;
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
            return address != null && address.matches("^0x[0-9a-fA-F]{40}$");
        }

        private static String shortAddress(String address) {
            if (address == null || address.length() < 12) {
                return "";
            }
            return address.substring(0, 6) + "..." + address.substring(address.length() - 4);
        }
    }

    private enum PlotState {
        EMPTY,
        GROWING,
        READY
    }

    private static final class Plot {
        final float x;
        final float y;
        final float w;
        final float h;
        boolean owned;
        PlotState state = PlotState.EMPTY;
        long plantedAtMs;

        Plot(float x, float y, float w, float h) {
            this.x = x;
            this.y = y;
            this.w = w;
            this.h = h;
        }
    }
}
