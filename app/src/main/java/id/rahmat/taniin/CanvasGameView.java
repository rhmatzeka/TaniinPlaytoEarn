package id.rahmat.taniin;

import android.content.Context;
import android.graphics.Canvas;
import android.view.View;

abstract class CanvasGameView extends View {
    private long lastFrameMs;

    CanvasGameView(Context context) {
        super(context);
    }

    @Override
    protected final void onDraw(Canvas canvas) {
        long now = System.currentTimeMillis();
        if (lastFrameMs == 0L) {
            lastFrameMs = now;
        }
        float dt = Math.min((now - lastFrameMs) / 1000f, 0.033f);
        lastFrameMs = now;

        updateFrame(dt, now);
        renderFrame(canvas, now);
        postInvalidateOnAnimation();
    }

    protected abstract void updateFrame(float dt, long now);

    protected abstract void renderFrame(Canvas canvas, long now);
}
