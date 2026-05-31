package id.rahmat.taniin;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.widget.Button;

final class DialogUi {
    private DialogUi() {
    }

    static Button walletButton(Context context, String label, int background, int textColor) {
        Button button = new Button(context);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextSize(15f);
        button.setTypeface(null, android.graphics.Typeface.BOLD);
        button.setTextColor(textColor);
        button.setBackground(roundedStrokeDrawable(background, dp(context, 10), Color.rgb(235, 164, 74), dp(context, 2)));
        return button;
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
}
