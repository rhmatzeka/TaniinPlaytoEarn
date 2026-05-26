package id.rahmat.taniin;

import android.app.Activity;
import android.app.AlertDialog;
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
import android.os.Build;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;

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
        private static final int TILE = 96;
        private static final int WORLD_COLS = 72;
        private static final int WORLD_ROWS = 52;
        private static final float PLAYER_SPEED = TILE * 3.9f;
        private static final long GROW_TIME_MS = 12_000L;

        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint pixelPaint = new Paint();
        private final Rect src = new Rect();
        private final RectF dst = new RectF();
        private final List<Plot> plots = new ArrayList<>();
        private final List<ChainAction> pendingChainActions = new ArrayList<>();
        private final BlockchainClient blockchainClient = new BlockchainClient();
        private final SharedPreferences preferences;
        private TmxMap tmxMap;

        private final Bitmap idleSheet;
        private final Bitmap walkSheet;
        private final Bitmap cropSheet;
        private final Bitmap chest;
        private final Bitmap chicken;
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
                mapStatus = "TMX map loaded";
            } catch (Exception exception) {
                tmxMap = null;
                mapStatus = "TMX gagal: " + exception.getMessage();
            }
        }

        private void createWorld() {
            int startX = 7;
            int startY = 25;
            for (int i = 0; i < 6; i++) {
                Plot plot = new Plot((startX + i * 3) * TILE, startY * TILE, 2 * TILE, 6 * TILE);
                plot.owned = i == 0;
                plots.add(plot);
            }
            for (int i = 0; i < 4; i++) {
                Plot plot = new Plot((45 + i * 4) * TILE, 22 * TILE, 3 * TILE, 6 * TILE);
                plots.add(plot);
            }
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
                playerX = clamp(playerX + nx * PLAYER_SPEED * dt, 2 * TILE, worldWidthPixels - 2 * TILE);
                playerY = clamp(playerY + ny * PLAYER_SPEED * dt, 2 * TILE, worldHeightPixels - 2 * TILE);
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

        private void drawGame(Canvas canvas, long now) {
            int width = getWidth();
            int height = getHeight();
            cameraX = clamp(playerX - width * 0.5f, 0, Math.max(0, worldWidthPixels - width));
            cameraY = clamp(playerY - height * 0.56f, 0, Math.max(0, worldHeightPixels - height));

            drawWorld(canvas);
            drawPlots(canvas, now);
            if (tmxMap == null) {
                drawDecorations(canvas);
            }
            drawPlayer(canvas, now);
            drawHud(canvas, now);
        }

        private void drawWorld(Canvas canvas) {
            if (tmxMap != null) {
                canvas.drawColor(Color.rgb(113, 181, 82));
                tmxMap.draw(canvas, cameraX, cameraY, TILE);
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
            for (int row = 1; row < 7; row += 2) {
                for (int col = 0; col < 3; col++) {
                    float x = plot.x + col * TILE + 7 - cameraX;
                    float y = plot.y + row * TILE + 8 - cameraY;
                    dst.set(x, y, x + 22, y + 22);
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

        private void drawPlayer(Canvas canvas, long now) {
            Bitmap sheet = moving ? walkSheet : idleSheet;
            int frameW = 16;
            int frameH = 32;
            int columns = Math.max(1, sheet.getWidth() / frameW);
            int frame = moving ? walkFrame : (int) ((now / 240L) % 6L);
            int frameIndex = frame % columns;
            src.set(frameIndex * frameW, 0, frameIndex * frameW + frameW, frameH);

            float playerHeight = TILE * 1.12f;
            float playerWidth = playerHeight * 0.56f;
            float screenX = playerX - cameraX - playerWidth * 0.5f;
            float screenY = playerY - cameraY - playerHeight * 0.82f;

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(80, 0, 0, 0));
            canvas.drawOval(
                    screenX + playerWidth * 0.20f,
                    screenY + playerHeight * 0.78f,
                    screenX + playerWidth * 0.80f,
                    screenY + playerHeight * 0.94f,
                    paint);

            dst.set(screenX, screenY, screenX + playerWidth, screenY + playerHeight);
            canvas.drawBitmap(sheet, src, dst, pixelPaint);
        }

        private void drawHud(Canvas canvas, long now) {
            drawInventory(canvas);
            drawChainBar(canvas);
            drawMiniMap(canvas);
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
        }

        private void drawInventory(Canvas canvas) {
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(210, 82, 49, 21));
            canvas.drawRoundRect(18, 14, 400, 66, 12, 12, paint);
            paint.setColor(Color.rgb(255, 226, 88));
            paint.setTextSize(21f);
            paint.setFakeBoldText(true);
            canvas.drawText("Coin " + coins, 34, 48, paint);
            paint.setColor(Color.WHITE);
            canvas.drawText("Bibit " + seeds, 140, 48, paint);
            canvas.drawText("Panen " + harvests, 238, 48, paint);
            paint.setFakeBoldText(false);
        }

        private void drawChainBar(Canvas canvas) {
            float left = 416;
            float top = 14;
            float right = Math.min(getWidth() - 192f, 780f);
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
            float mapW = 152;
            float mapH = 92;
            float left = getWidth() - mapW - 18;
            float top = 16;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(210, 30, 62, 36));
            canvas.drawRoundRect(left, top, left + mapW, top + mapH, 8, 8, paint);
            paint.setColor(Color.rgb(117, 184, 82));
            canvas.drawRect(left + 8, top + 8, left + mapW - 8, top + mapH - 8, paint);
            paint.setColor(Color.rgb(235, 151, 73));
            for (Plot plot : plots) {
                float px = left + 8 + plot.x / worldWidthPixels * (mapW - 16);
                float py = top + 8 + plot.y / worldHeightPixels * (mapH - 16);
                canvas.drawRect(px, py, px + 5, py + 13, paint);
            }
            paint.setColor(Color.rgb(41, 80, 221));
            float x = left + 8 + playerX / worldWidthPixels * (mapW - 16);
            float y = top + 8 + playerY / worldHeightPixels * (mapH - 16);
            canvas.drawCircle(x, y, 4, paint);
        }

        private void drawJoystick(Canvas canvas) {
            float baseX = joystickActive ? joyBaseX : 92;
            float baseY = joystickActive ? joyBaseY : getHeight() - 92;
            float knobX = joystickActive ? joyX : baseX;
            float knobY = joystickActive ? joyY : baseY;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(90, 20, 20, 20));
            canvas.drawCircle(baseX, baseY, 64, paint);
            paint.setColor(Color.argb(160, 255, 255, 255));
            canvas.drawCircle(knobX, knobY, 26, paint);
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
            float right = getWidth() - 18;
            float top = 122;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(44, 85, 64));
            canvas.drawRoundRect(right - 152, top, right, top + 48, 10, 10, paint);
            paint.setColor(Color.WHITE);
            paint.setTextSize(18f);
            paint.setFakeBoldText(true);
            canvas.drawText("WALLET", right - 124, top + 31, paint);
            paint.setFakeBoldText(false);
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
            canvas.drawText("Tap WALLET untuk input address & cek RPC.", x + 22, y + 190, paint);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            int index = event.getActionIndex();
            int pointerId = event.getPointerId(index);

            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
                float x = event.getX(index);
                float y = event.getY(index);
                if (x < getWidth() * 0.42f && y > getHeight() * 0.45f) {
                    joystickActive = true;
                    joystickPointerId = pointerId;
                    joyBaseX = x;
                    joyBaseY = y;
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

        private void updateJoystick(float x, float y) {
            float dx = x - joyBaseX;
            float dy = y - joyBaseY;
            float distance = (float) Math.hypot(dx, dy);
            float radius = 58f;
            if (distance > radius) {
                dx = dx / distance * radius;
                dy = dy / distance * radius;
            }
            joyX = joyBaseX + dx;
            joyY = joyBaseY + dy;
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
            float right = getWidth() - 18;
            float top = 122;
            return x >= right - 152 && x <= right && y >= top && y <= top + 48;
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
            chainPanelUntilMs = System.currentTimeMillis() + 4000L;
            checkSepolia();
            Context context = getContext();
            if (!(context instanceof Activity)) {
                return;
            }
            final android.widget.EditText input = new android.widget.EditText(context);
            input.setSingleLine(true);
            input.setHint("0x wallet address Sepolia");
            input.setText(walletAddress);
            new AlertDialog.Builder(context)
                    .setTitle("Wallet Sepolia")
                    .setMessage("Masukkan public wallet address. Jangan masukkan private key.")
                    .setView(input)
                    .setPositiveButton("Simpan", (dialog, which) -> {
                        String address = input.getText().toString().trim();
                        if (!isValidAddress(address)) {
                            showMessage("Wallet address tidak valid.");
                            return;
                        }
                        walletAddress = address;
                        preferences.edit().putString("wallet_address", walletAddress).apply();
                        showMessage("Wallet tersimpan: " + shortAddress(walletAddress));
                    })
                    .setNegativeButton("Tutup", null)
                    .show();
        }

        private void checkSepolia() {
            if (checkingChain) {
                return;
            }
            checkingChain = true;
            chainStatus = "Cek Sepolia RPC...";
            blockchainClient.checkSepolia(result -> {
                checkingChain = false;
                chainStatus = result.message;
                chainPanelUntilMs = System.currentTimeMillis() + 4500L;
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
            return playerX > 37 * TILE && playerX < 43 * TILE && playerY > 28 * TILE && playerY < 34 * TILE;
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

        private void drawWorldRect(Canvas canvas, float x, float y, float w, float h) {
            canvas.drawRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, paint);
        }

        private void drawWorldRoundRect(Canvas canvas, float x, float y, float w, float h, float r) {
            canvas.drawRoundRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, r, r, paint);
        }

        private void drawWorldLine(Canvas canvas, float x1, float y1, float x2, float y2) {
            canvas.drawLine(x1 - cameraX, y1 - cameraY, x2 - cameraX, y2 - cameraY, paint);
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
