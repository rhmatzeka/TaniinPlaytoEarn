package id.rahmat.taniin;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.widget.Button;

final class DialogUi {
    static final int PANEL_FILL = Color.rgb(158, 78, 32);
    static final int PANEL_INNER_FILL = Color.rgb(171, 81, 31);
    static final int PANEL_STROKE = Color.rgb(77, 42, 14);
    static final int PANEL_INNER_STROKE = Color.rgb(185, 92, 40);
    static final int TEXT_BOX_FILL = Color.rgb(142, 65, 27);
    static final int TEXT_BOX_STROKE = Color.rgb(92, 42, 12);
    static final int TITLE = Color.rgb(255, 222, 25);
    static final int BODY_TEXT = Color.rgb(255, 240, 212);
    static final int MUTED_TEXT = Color.rgb(232, 202, 164);
    static final int CORNER = Color.rgb(255, 211, 0);
    static final int BUTTON_STROKE = Color.rgb(255, 178, 63);

    private DialogUi() {
    }

    static Button walletButton(Context context, String label, int background, int textColor) {
        Button button = new Button(context);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextSize(15f);
        button.setTypeface(null, android.graphics.Typeface.BOLD);
        button.setTextColor(textColor);
        button.setGravity(Gravity.CENTER);
        button.setIncludeFontPadding(false);
        button.setMinWidth(0);
        button.setMinHeight(0);
        button.setPadding(dp(context, 8), 0, dp(context, 8), 0);
        button.setBackground(pixelButtonDrawable(context, background, BUTTON_STROKE));
        return button;
    }

    static Drawable pixelPanelDrawable(Context context) {
        return new PixelPanelDrawable(
                PANEL_FILL,
                PANEL_STROKE,
                PANEL_INNER_STROKE,
                CORNER,
                dp(context, 18),
                dp(context, 7),
                dp(context, 3),
                dp(context, 8),
                dp(context, 10));
    }

    static Drawable pixelButtonDrawable(Context context, int fill, int stroke) {
        return new PixelButtonDrawable(
                fill,
                stroke,
                dp(context, 10),
                dp(context, 3),
                dp(context, 4),
                dp(context, 5));
    }

    static GradientDrawable textBoxDrawable(Context context) {
        return roundedStrokeDrawable(
                TEXT_BOX_FILL,
                dp(context, 10),
                TEXT_BOX_STROKE,
                dp(context, 2));
    }

    static GradientDrawable roundedDrawable(int color, float radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    static GradientDrawable roundedStrokeDrawable(int color, float radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = roundedDrawable(color, radius);
        drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    static int dp(Context context, float value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }

    private static final class PixelPanelDrawable extends Drawable {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF panel = new RectF();
        private final int fill;
        private final int stroke;
        private final int innerStroke;
        private final int cornerColor;
        private final float radius;
        private final float strokeWidth;
        private final float innerStrokeWidth;
        private final float shadowDx;
        private final float shadowDy;
        private int alpha = 255;

        PixelPanelDrawable(
                int fill,
                int stroke,
                int innerStroke,
                int cornerColor,
                float radius,
                float strokeWidth,
                float innerStrokeWidth,
                float shadowDx,
                float shadowDy) {
            this.fill = fill;
            this.stroke = stroke;
            this.innerStroke = innerStroke;
            this.cornerColor = cornerColor;
            this.radius = radius;
            this.strokeWidth = strokeWidth;
            this.innerStrokeWidth = innerStrokeWidth;
            this.shadowDx = shadowDx;
            this.shadowDy = shadowDy;
        }

        @Override
        public void draw(Canvas canvas) {
            Rect bounds = getBounds();
            panel.set(bounds.left, bounds.top, bounds.right - shadowDx, bounds.bottom - shadowDy);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.BLACK);
            paint.setAlpha(scaleAlpha(130));
            canvas.drawRoundRect(panel.left + shadowDx, panel.top + shadowDy, panel.right + shadowDx, panel.bottom + shadowDy, radius, radius, paint);

            paint.setColor(fill);
            paint.setAlpha(alpha);
            canvas.drawRoundRect(panel, radius, radius, paint);

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(strokeWidth);
            paint.setColor(stroke);
            paint.setAlpha(alpha);
            canvas.drawRoundRect(panel, radius, radius, paint);

            float inset = Math.max(strokeWidth, 4f) + 5f;
            paint.setStrokeWidth(innerStrokeWidth);
            paint.setColor(innerStroke);
            paint.setAlpha(alpha);
            canvas.drawRoundRect(
                    panel.left + inset,
                    panel.top + inset,
                    panel.right - inset,
                    panel.bottom - inset,
                    Math.max(1f, radius - inset * 0.5f),
                    Math.max(1f, radius - inset * 0.5f),
                    paint);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(cornerColor);
            paint.setAlpha(alpha);
            float cornerSize = Math.max(10f, radius * 0.42f);
            float cornerInset = Math.max(12f, radius * 0.70f);
            drawCorner(canvas, panel.left + cornerInset, panel.top + cornerInset, cornerSize);
            drawCorner(canvas, panel.right - cornerInset - cornerSize, panel.top + cornerInset, cornerSize);
            drawCorner(canvas, panel.left + cornerInset, panel.bottom - cornerInset - cornerSize, cornerSize);
            drawCorner(canvas, panel.right - cornerInset - cornerSize, panel.bottom - cornerInset - cornerSize, cornerSize);
        }

        private void drawCorner(Canvas canvas, float left, float top, float size) {
            canvas.drawRoundRect(left, top, left + size, top + size, Math.max(2f, size * 0.22f), Math.max(2f, size * 0.22f), paint);
        }

        private int scaleAlpha(int value) {
            return Math.round(value * (alpha / 255f));
        }

        @Override
        public void setAlpha(int alpha) {
            this.alpha = alpha;
            invalidateSelf();
        }

        @Override
        public void setColorFilter(ColorFilter colorFilter) {
            paint.setColorFilter(colorFilter);
            invalidateSelf();
        }

        @Override
        public int getOpacity() {
            return PixelFormat.TRANSLUCENT;
        }
    }

    private static final class PixelButtonDrawable extends Drawable {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF rect = new RectF();
        private final int fill;
        private final int stroke;
        private final float radius;
        private final float strokeWidth;
        private final float shadowDx;
        private final float shadowDy;
        private int alpha = 255;

        PixelButtonDrawable(int fill, int stroke, float radius, float strokeWidth, float shadowDx, float shadowDy) {
            this.fill = fill;
            this.stroke = stroke;
            this.radius = radius;
            this.strokeWidth = strokeWidth;
            this.shadowDx = shadowDx;
            this.shadowDy = shadowDy;
        }

        @Override
        public void draw(Canvas canvas) {
            Rect bounds = getBounds();
            rect.set(bounds.left, bounds.top, bounds.right - shadowDx, bounds.bottom - shadowDy);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.BLACK);
            paint.setAlpha(Math.round(85 * (alpha / 255f)));
            canvas.drawRoundRect(rect.left + shadowDx, rect.top + shadowDy, rect.right + shadowDx, rect.bottom + shadowDy, radius, radius, paint);

            paint.setColor(fill);
            paint.setAlpha(alpha);
            canvas.drawRoundRect(rect, radius, radius, paint);

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(strokeWidth);
            paint.setColor(stroke);
            paint.setAlpha(alpha);
            canvas.drawRoundRect(rect, radius, radius, paint);
        }

        @Override
        public void setAlpha(int alpha) {
            this.alpha = alpha;
            invalidateSelf();
        }

        @Override
        public void setColorFilter(ColorFilter colorFilter) {
            paint.setColorFilter(colorFilter);
            invalidateSelf();
        }

        @Override
        public int getOpacity() {
            return PixelFormat.TRANSLUCENT;
        }
    }
}
