package id.rahmat.taniin;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.View;

final class LoadingScreenView extends View {
    private static final long LOADING_DURATION_MS = 2800L;
    private static final long COMPLETE_HOLD_MS = 260L;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Bitmap background;
    private final Typeface pixelTypeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD);
    private long startedAtMs;
    private boolean completed;
    private Runnable completeCallback;

    LoadingScreenView(Context context) {
        super(context);
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inScaled = false;
        background = BitmapFactory.decodeResource(getResources(), R.drawable.loadingscreen, options);
    }

    void start(Runnable callback) {
        completeCallback = callback;
        startedAtMs = System.currentTimeMillis();
        completed = false;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        long now = System.currentTimeMillis();
        if (startedAtMs == 0L) {
            startedAtMs = now;
        }
        float progress = Math.min(1f, (now - startedAtMs) / (float) LOADING_DURATION_MS);
        int percent = Math.max(1, Math.min(100, Math.round(progress * 100f)));

        drawBackground(canvas);
        drawTitle(canvas);
        drawLoadingPanel(canvas, progress, percent);

        if (percent >= 100) {
            if (!completed) {
                completed = true;
                postDelayed(() -> {
                    if (completeCallback != null) {
                        completeCallback.run();
                    }
                }, COMPLETE_HOLD_MS);
            }
            return;
        }
        postInvalidateOnAnimation();
    }

    private void drawBackground(Canvas canvas) {
        canvas.drawColor(Color.rgb(39, 93, 53));
        if (background == null) {
            return;
        }

        float scale = Math.max(
                getWidth() / (float) background.getWidth(),
                getHeight() / (float) background.getHeight());
        float width = background.getWidth() * scale;
        float height = background.getHeight() * scale;
        float left = (getWidth() - width) * 0.5f;
        float top = (getHeight() - height) * 0.5f;
        canvas.drawBitmap(background, null, new RectF(left, top, left + width, top + height), paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(84, 16, 28, 20));
        canvas.drawRect(0, 0, getWidth(), getHeight(), paint);
    }

    private void drawTitle(Canvas canvas) {
        float scale = uiScale();
        float centerX = getWidth() * 0.5f;
        float titleY = Math.max(58f * scale, getHeight() * 0.18f);

        drawPixelText(canvas, "Taniin", centerX, titleY, 72f * scale,
                Color.rgb(255, 222, 82), Color.rgb(30, 71, 36), 5f * scale);
        drawPixelText(canvas, "GAME ONCHAIN BERTANI", centerX, titleY + 38f * scale, 20f * scale,
                Color.rgb(250, 247, 208), Color.rgb(23, 55, 35), 3f * scale);
        drawPixelLeaf(canvas, centerX - 172f * scale, titleY + 8f * scale, scale, false);
        drawPixelLeaf(canvas, centerX + 172f * scale, titleY + 8f * scale, scale, true);
    }

    private void drawLoadingPanel(Canvas canvas, float progress, int percent) {
        float scale = uiScale();
        float panelW = Math.min(getWidth() - 48f * scale, 650f * scale);
        float panelH = 108f * scale;
        float left = (getWidth() - panelW) * 0.5f;
        float bottom = getHeight() - Math.max(28f * scale, getHeight() * 0.10f);
        RectF panel = new RectF(left, bottom - panelH, left + panelW, bottom);

        paint.setTypeface(null);
        paint.setAntiAlias(false);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(150, 0, 0, 0));
        canvas.drawRect(panel.left + 6f * scale, panel.top + 7f * scale,
                panel.right + 6f * scale, panel.bottom + 7f * scale, paint);
        paint.setColor(Color.rgb(24, 48, 31));
        canvas.drawRect(panel, paint);
        paint.setColor(Color.rgb(255, 219, 87));
        canvas.drawRect(panel.left, panel.top, panel.right, panel.top + 5f * scale, paint);
        canvas.drawRect(panel.left, panel.bottom - 5f * scale, panel.right, panel.bottom, paint);
        canvas.drawRect(panel.left, panel.top, panel.left + 5f * scale, panel.bottom, paint);
        canvas.drawRect(panel.right - 5f * scale, panel.top, panel.right, panel.bottom, paint);
        paint.setColor(Color.rgb(54, 109, 58));
        canvas.drawRect(panel.left + 10f * scale, panel.top + 10f * scale,
                panel.right - 10f * scale, panel.bottom - 10f * scale, paint);

        paint.setTypeface(pixelTypeface);
        paint.setTextAlign(Paint.Align.LEFT);
        paint.setFakeBoldText(true);
        paint.setTextSize(19f * scale);
        paint.setColor(Color.rgb(245, 245, 213));
        canvas.drawText("LOADING FARM", panel.left + 24f * scale, panel.top + 34f * scale, paint);
        paint.setTextAlign(Paint.Align.RIGHT);
        paint.setTextSize(22f * scale);
        canvas.drawText(percent + "%", panel.right - 24f * scale, panel.top + 35f * scale, paint);

        RectF bar = new RectF(panel.left + 24f * scale, panel.top + 55f * scale,
                panel.right - 24f * scale, panel.top + 80f * scale);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(15, 32, 20));
        canvas.drawRect(bar, paint);
        paint.setColor(Color.rgb(115, 65, 32));
        canvas.drawRect(bar.left, bar.top, bar.right, bar.top + 4f * scale, paint);
        canvas.drawRect(bar.left, bar.bottom - 4f * scale, bar.right, bar.bottom, paint);

        float fillRight = bar.left + bar.width() * progress;
        paint.setColor(Color.rgb(255, 206, 53));
        canvas.drawRect(bar.left + 4f * scale, bar.top + 4f * scale,
                Math.max(bar.left + 4f * scale, fillRight - 4f * scale), bar.bottom - 4f * scale, paint);
        paint.setColor(Color.rgb(255, 242, 136));
        canvas.drawRect(bar.left + 7f * scale, bar.top + 7f * scale,
                Math.max(bar.left + 7f * scale, fillRight - 9f * scale), bar.top + 11f * scale, paint);

        drawProgressSpark(canvas, fillRight, bar.centerY(), scale);
        paint.setTypeface(null);
        paint.setFakeBoldText(false);
        paint.setAntiAlias(true);
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private void drawPixelText(Canvas canvas, String text, float centerX, float baseline,
            float size, int fillColor, int outlineColor, float outline) {
        paint.setTypeface(pixelTypeface);
        paint.setAntiAlias(false);
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setFakeBoldText(true);
        paint.setTextSize(size);

        int step = Math.max(2, Math.round(outline));
        paint.setColor(outlineColor);
        canvas.drawText(text, centerX - step, baseline, paint);
        canvas.drawText(text, centerX + step, baseline, paint);
        canvas.drawText(text, centerX, baseline - step, paint);
        canvas.drawText(text, centerX, baseline + step, paint);
        canvas.drawText(text, centerX - step, baseline - step, paint);
        canvas.drawText(text, centerX + step, baseline + step, paint);

        paint.setColor(Color.argb(110, 0, 0, 0));
        canvas.drawText(text, centerX + step * 2f, baseline + step * 2f, paint);
        paint.setColor(fillColor);
        canvas.drawText(text, centerX, baseline, paint);
        paint.setFakeBoldText(false);
        paint.setTypeface(null);
        paint.setAntiAlias(true);
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private void drawPixelLeaf(Canvas canvas, float cx, float cy, float scale, boolean flipped) {
        float dir = flipped ? -1f : 1f;
        float unit = 7f * scale;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(33, 96, 53));
        drawPixelRect(canvas, cx, cy, cx + dir * unit, cy + unit * 5f);
        paint.setColor(Color.rgb(116, 187, 72));
        drawPixelRect(canvas, cx + dir * unit, cy, cx + dir * unit * 4f, cy + unit);
        drawPixelRect(canvas, cx + dir * unit * 2f, cy - unit, cx + dir * unit * 5f, cy);
        paint.setColor(Color.rgb(255, 215, 65));
        drawPixelRect(canvas, cx - dir * unit * 2f, cy + unit, cx + dir * unit, cy + unit * 2f);
        drawPixelRect(canvas, cx - dir * unit * 3f, cy + unit * 2f, cx, cy + unit * 3f);
    }

    private void drawPixelRect(Canvas canvas, float left, float top, float right, float bottom) {
        canvas.drawRect(Math.min(left, right), Math.min(top, bottom),
                Math.max(left, right), Math.max(top, bottom), paint);
    }

    private void drawProgressSpark(Canvas canvas, float x, float y, float scale) {
        float unit = 5f * scale;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 250, 182));
        canvas.drawRect(x - unit, y - unit, x + unit, y + unit, paint);
        canvas.drawRect(x - unit * 3f, y - unit * 0.5f, x - unit * 1.5f, y + unit * 0.5f, paint);
        canvas.drawRect(x + unit * 1.5f, y - unit * 0.5f, x + unit * 3f, y + unit * 0.5f, paint);
        canvas.drawRect(x - unit * 0.5f, y - unit * 3f, x + unit * 0.5f, y - unit * 1.5f, paint);
        canvas.drawRect(x - unit * 0.5f, y + unit * 1.5f, x + unit * 0.5f, y + unit * 3f, paint);
    }

    private float uiScale() {
        return Math.max(0.68f, Math.min(1.15f, getHeight() / 390f));
    }
}
