package id.rahmat.taniin;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;

import java.util.List;

final class WorldRenderer {
    private final int tile;
    private final int worldCols;
    private final int worldRows;
    private final Paint paint;
    private final Paint pixelPaint;
    private final Rect src;
    private final RectF dst;
    private float cameraX;
    private float cameraY;

    WorldRenderer(int tile, int worldCols, int worldRows, Paint paint, Paint pixelPaint, Rect src, RectF dst) {
        this.tile = tile;
        this.worldCols = worldCols;
        this.worldRows = worldRows;
        this.paint = paint;
        this.pixelPaint = pixelPaint;
        this.src = src;
        this.dst = dst;
    }

    void setCamera(float cameraX, float cameraY) {
        this.cameraX = cameraX;
        this.cameraY = cameraY;
    }

    void appendFallbackCollisionRects(List<RectF> rects) {
        addCollisionRect(rects, 0, 7 * tile, 44 * tile, 4 * tile);
        addCollisionRect(rects, 0, 0, 3 * tile, worldRows * tile);
        addCollisionRect(rects, 0, 45 * tile, 34 * tile, 7 * tile);
        addCollisionRect(rects, 52 * tile, 0, 4 * tile, 19 * tile);

        addFenceCollision(rects, 27 * tile, 22 * tile, 22 * tile, 11 * tile);
        addFenceCollision(rects, 6 * tile, 23 * tile, 20 * tile, 9 * tile);

        addHouseCollision(rects, 32 * tile, 24 * tile, 7 * tile, 7 * tile);
        addHouseCollision(rects, 56 * tile, 10 * tile, 7 * tile, 7 * tile);
        addCollisionRect(rects, 39 * tile, 29 * tile, 4.6f * tile, 1.3f * tile);

        addTreeCollision(rects, 6 * tile, 15 * tile, 1.2f);
        addTreeCollision(rects, 14 * tile, 13 * tile, 1.0f);
        addTreeCollision(rects, 23 * tile, 13 * tile, 1.0f);
        addTreeCollision(rects, 42 * tile, 13 * tile, 1.0f);
        addTreeCollision(rects, 62 * tile, 5 * tile, 1.05f);
        addTreeCollision(rects, 58 * tile, 22 * tile, 1.0f);
        addTreeCollision(rects, 31 * tile, 43 * tile, 1.3f);
        addTreeCollision(rects, 37 * tile, 43 * tile, 1.3f);
        addTreeCollision(rects, 43 * tile, 43 * tile, 1.3f);
        addTreeCollision(rects, 49 * tile, 43 * tile, 1.3f);

        addCollisionRect(rects, 17 * tile, 16 * tile + 12, 58, 30);
        addCollisionRect(rects, 31 * tile, 15 * tile + 12, 58, 30);
        addCollisionRect(rects, 13 * tile, 10 * tile + 9, 24, 18);
        addCollisionRect(rects, 54 * tile, 32 * tile + 9, 24, 18);
        addCollisionRect(rects, 65 * tile, 29 * tile + 9, 24, 18);
        addCollisionRect(rects, 40 * tile, 30 * tile, 42, 42);
        addCollisionRect(rects, 29 * tile, 32 * tile, 64, 32);
        addCollisionRect(rects, 45 * tile, 30 * tile, 86, 64);
    }

    void drawFallbackWorld(Canvas canvas, int viewportWidth, int viewportHeight) {
        canvas.drawColor(Color.rgb(113, 181, 82));
        drawGrassTexture(canvas, viewportWidth, viewportHeight);

        drawWaterRect(canvas, 0, 7 * tile, 44 * tile, 4 * tile);
        drawWaterRect(canvas, 0, 0, 3 * tile, worldRows * tile);
        drawWaterRect(canvas, 0, 45 * tile, 34 * tile, 7 * tile);
        drawWaterRect(canvas, 52 * tile, 0, 4 * tile, 19 * tile);

        drawRoad(canvas, 8 * tile, 6 * tile, 39 * tile, 2 * tile);
        drawRoad(canvas, 44 * tile, 5 * tile, 10 * tile, 2 * tile);
        drawRoad(canvas, 44 * tile, 5 * tile, 2 * tile, 19 * tile);
        drawRoad(canvas, 16 * tile, 20 * tile, 34 * tile, 2 * tile);
        drawRoad(canvas, 26 * tile, 33 * tile, 42 * tile, 2 * tile);
        drawRoad(canvas, 34 * tile, 23 * tile, 2 * tile, 12 * tile);
        drawRoad(canvas, 62 * tile, 30 * tile, 7 * tile, 5 * tile);

        drawBridge(canvas, 44 * tile, 7 * tile, 2 * tile, 4 * tile, true);
        drawBridge(canvas, 52 * tile, 11 * tile, 4 * tile, 2 * tile, false);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(37, 128, 63));
        drawWorldLine(canvas, 3 * tile, 6 * tile, 47 * tile, 6 * tile);
        drawWorldLine(canvas, 3 * tile, 11 * tile, 44 * tile, 11 * tile);
        drawWorldLine(canvas, 3 * tile, 45 * tile, 34 * tile, 45 * tile);
    }

    void drawFallbackDecorations(Canvas canvas, Bitmap chest, Bitmap chicken, Bitmap cow) {
        drawFence(canvas, 27 * tile, 22 * tile, 22 * tile, 11 * tile);
        drawFence(canvas, 6 * tile, 23 * tile, 20 * tile, 9 * tile);

        drawHouse(canvas, 32 * tile, 24 * tile, 7 * tile, 7 * tile, true);
        drawHouse(canvas, 56 * tile, 10 * tile, 7 * tile, 7 * tile, false);
        drawShopStand(canvas, chest, 39 * tile, 29 * tile);

        drawLamp(canvas, 48 * tile, 4 * tile);
        drawLamp(canvas, 20 * tile, 18 * tile);
        drawLamp(canvas, 50 * tile, 32 * tile);
        drawLamp(canvas, 11 * tile, 33 * tile);

        drawTree(canvas, 6 * tile, 15 * tile, 1.2f);
        drawTree(canvas, 14 * tile, 13 * tile, 1.0f);
        drawTree(canvas, 23 * tile, 13 * tile, 1.0f);
        drawTree(canvas, 42 * tile, 13 * tile, 1.0f);
        drawTree(canvas, 62 * tile, 5 * tile, 1.05f);
        drawTree(canvas, 58 * tile, 22 * tile, 1.0f);
        drawTree(canvas, 31 * tile, 43 * tile, 1.3f);
        drawTree(canvas, 37 * tile, 43 * tile, 1.3f);
        drawTree(canvas, 43 * tile, 43 * tile, 1.3f);
        drawTree(canvas, 49 * tile, 43 * tile, 1.3f);

        drawBush(canvas, 17 * tile, 16 * tile);
        drawBush(canvas, 31 * tile, 15 * tile);
        drawRock(canvas, 13 * tile, 10 * tile);
        drawRock(canvas, 54 * tile, 32 * tile);
        drawRock(canvas, 65 * tile, 29 * tile);

        drawBitmapWorld(canvas, chest, 40 * tile, 30 * tile, 42, 42);
        drawBitmapWorld(canvas, chicken, 29 * tile, 32 * tile, 64, 32);
        drawBitmapWorld(canvas, cow, 45 * tile, 30 * tile, 86, 64);
    }

    void drawSpriteWorld(
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

    void drawSpriteWithShadowWorld(
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

    void drawWorldRect(Canvas canvas, float x, float y, float w, float h) {
        canvas.drawRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, paint);
    }

    void drawWorldRoundRect(Canvas canvas, float x, float y, float w, float h, float r) {
        canvas.drawRoundRect(x - cameraX, y - cameraY, x - cameraX + w, y - cameraY + h, r, r, paint);
    }

    void drawWorldLine(Canvas canvas, float x1, float y1, float x2, float y2) {
        canvas.drawLine(x1 - cameraX, y1 - cameraY, x2 - cameraX, y2 - cameraY, paint);
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

    private void drawGrassTexture(Canvas canvas, int viewportWidth, int viewportHeight) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 79, 156, 72));
        int firstCol = Math.max(0, (int) (cameraX / tile) - 1);
        int lastCol = Math.min(worldCols, (int) ((cameraX + viewportWidth) / tile) + 2);
        int firstRow = Math.max(0, (int) (cameraY / tile) - 1);
        int lastRow = Math.min(worldRows, (int) ((cameraY + viewportHeight) / tile) + 2);
        for (int y = firstRow; y < lastRow; y++) {
            for (int x = firstCol; x < lastCol; x++) {
                if ((x * 17 + y * 11) % 9 == 0) {
                    drawWorldRect(canvas, x * tile + 9, y * tile + 8, 4, 4);
                } else if ((x * 7 + y * 13) % 17 == 0) {
                    drawWorldRect(canvas, x * tile + 21, y * tile + 20, 3, 5);
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
        for (float yy = y + 8; yy < y + h; yy += tile) {
            for (float xx = x + 8; xx < x + w; xx += tile) {
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
        for (float xx = x; xx <= x + w; xx += tile) {
            drawWorldRect(canvas, xx, y, 7, 30);
            drawWorldRect(canvas, xx, y + h - 30, 7, 30);
        }
        for (float yy = y; yy <= y + h; yy += tile) {
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

    private void drawShopStand(Canvas canvas, Bitmap chest, float x, float y) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(91, 55, 34));
        drawWorldRoundRect(canvas, x, y, 4.6f * tile, 1.3f * tile, 8);
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
        float s = tile * scale;
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

    private void addFenceCollision(List<RectF> rects, float x, float y, float w, float h) {
        float rail = tile * 0.24f;
        addCollisionRect(rects, x, y, w, rail);
        addCollisionRect(rects, x, y + h - rail, w, rail);
        addCollisionRect(rects, x, y, rail, h);
        addCollisionRect(rects, x + w - rail, y, rail, h);
    }

    private void addHouseCollision(List<RectF> rects, float x, float y, float w, float h) {
        addCollisionRect(rects, x + tile * 0.18f, y + tile * 0.48f, w - tile * 0.36f, h - tile * 0.64f);
        addCollisionRect(rects, x + tile * 0.45f, y + h - tile * 1.02f, tile * 0.62f, tile * 0.72f);
    }

    private void addTreeCollision(List<RectF> rects, float x, float y, float scale) {
        float s = tile * scale;
        addCollisionRect(rects, x + s * 0.16f, y + s * 0.62f, s * 0.68f, s * 0.55f);
    }

    private static void addCollisionRect(List<RectF> rects, float x, float y, float w, float h) {
        rects.add(new RectF(x, y, x + w, y + h));
    }
}
