package id.rahmat.taniin;

import android.graphics.Bitmap;
import android.graphics.Canvas;

final class MapDecorationRenderer {
    private final int tile;
    private final WorldRenderer worldRenderer;
    private final Bitmap chicken;
    private final Bitmap babyChicken;
    private final Bitmap cow;
    private final Bitmap maleCow;
    private final Bitmap chickenRed;

    MapDecorationRenderer(
            int tile,
            WorldRenderer worldRenderer,
            Bitmap chicken,
            Bitmap babyChicken,
            Bitmap cow,
            Bitmap maleCow,
            Bitmap chickenRed) {
        this.tile = tile;
        this.worldRenderer = worldRenderer;
        this.chicken = chicken;
        this.babyChicken = babyChicken;
        this.cow = cow;
        this.maleCow = maleCow;
        this.chickenRed = chickenRed;
    }

    void drawBackgroundDecorations(Canvas canvas, long now) {
        drawFieldEdgeAnimals(canvas, now);
        drawOpenMeadowAnimals(canvas, now);
        drawRoadsideAnimals(canvas, now);
        drawShopPenAnimals(canvas, now);
    }

    private void drawShopPenAnimals(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 440L) % 4L);
        int babyFrame = (int) ((now / 520L) % 4L);
        int cowFrame = (int) ((now / 620L) % 4L);

        float chickenWiggleA = (float) Math.sin(now / 360.0) * tile * 0.025f;
        float chickenWiggleB = (float) Math.sin(now / 430.0 + 1.7) * tile * 0.025f;
        float babyWiggle = (float) Math.sin(now / 390.0 + 2.4) * tile * 0.020f;
        float cowWiggle = (float) Math.sin(now / 720.0 + 0.8) * tile * 0.018f;

        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                22.38f * tile + chickenWiggleA, 18.08f * tile, tile * 0.50f, tile * 0.50f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 1) % 4, 16, 16, 4,
                23.34f * tile + chickenWiggleB, 18.42f * tile, tile * 0.50f, tile * 0.50f);
        drawSpriteWithShadowWorld(canvas, cow, cowFrame, 32, 32, 4,
                22.82f * tile + cowWiggle, 20.04f * tile, tile, tile);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                23.58f * tile - chickenWiggleA, 21.68f * tile, tile * 0.50f, tile * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                22.42f * tile + babyWiggle, 22.00f * tile, tile * 0.38f, tile * 0.38f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 3) % 4, 16, 16, 4,
                22.98f * tile - chickenWiggleB, 22.50f * tile, tile * 0.50f, tile * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                23.66f * tile - babyWiggle, 22.34f * tile, tile * 0.38f, tile * 0.38f);
    }

    private void drawFieldEdgeAnimals(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 440L) % 4L);
        int babyFrame = (int) ((now / 520L) % 4L);

        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                10.86f * tile, 24.54f * tile, tile * 0.50f, tile * 0.50f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                11.62f * tile, 24.92f * tile, tile * 0.37f, tile * 0.37f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                13.74f * tile, 24.64f * tile, tile * 0.48f, tile * 0.48f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                14.42f * tile, 24.96f * tile, tile * 0.35f, tile * 0.35f);
    }

    private void drawOpenMeadowAnimals(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 430L) % 4L);
        int babyFrame = (int) ((now / 510L) % 4L);
        int cowFrame = (int) ((now / 660L) % 4L);
        float swayA = (float) Math.sin(now / 520.0) * tile * 0.018f;
        float swayB = (float) Math.sin(now / 610.0 + 1.8) * tile * 0.018f;

        drawSpriteWithShadowWorld(canvas, chickenRed, chickenFrame, 16, 16, 4,
                19.70f * tile + swayA, 28.24f * tile, tile * 0.54f, tile * 0.54f);
        drawSpriteWithShadowWorld(canvas, babyChicken, babyFrame, 16, 16, 4,
                20.38f * tile - swayB, 28.68f * tile, tile * 0.38f, tile * 0.38f);
        drawSpriteWithShadowWorld(canvas, maleCow, cowFrame, 32, 32, 4,
                24.10f * tile + swayB, 28.14f * tile, tile * 1.04f, tile * 1.04f);
        drawSpriteWithShadowWorld(canvas, chicken, (chickenFrame + 2) % 4, 16, 16, 4,
                24.18f * tile - swayA, 30.22f * tile, tile * 0.52f, tile * 0.52f);
        drawSpriteWithShadowWorld(canvas, babyChicken, (babyFrame + 1) % 4, 16, 16, 4,
                24.82f * tile + swayA, 30.58f * tile, tile * 0.38f, tile * 0.38f);
    }

    private void drawRoadsideAnimals(Canvas canvas, long now) {
        int chickenFrame = (int) ((now / 470L) % 4L);
        int cowFrame = (int) ((now / 690L) % 4L);
        float drift = (float) Math.sin(now / 720.0) * tile * 0.016f;

        drawSpriteWithShadowWorld(canvas, cow, cowFrame, 32, 32, 4,
                31.18f * tile + drift, 29.22f * tile, tile * 1.02f, tile * 1.02f);
        drawSpriteWithShadowWorld(canvas, chicken, chickenFrame, 16, 16, 4,
                34.62f * tile - drift, 31.48f * tile, tile * 0.52f, tile * 0.52f);
        drawSpriteWithShadowWorld(canvas, chickenRed, (chickenFrame + 1) % 4, 16, 16, 4,
                35.20f * tile + drift, 31.82f * tile, tile * 0.52f, tile * 0.52f);
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
}
