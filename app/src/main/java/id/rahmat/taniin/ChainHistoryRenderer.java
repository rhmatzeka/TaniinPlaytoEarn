package id.rahmat.taniin;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;

import java.util.List;
import java.util.Locale;

final class ChainHistoryRenderer {
    private final Paint paint;
    private final int historyLimit;

    ChainHistoryRenderer(Paint paint, int historyLimit) {
        this.paint = paint;
        this.historyLimit = historyLimit;
    }

    void drawButton(Canvas canvas, RectF walletBounds, List<ChainHistoryEntry> history) {
        RectF bounds = buttonBounds(walletBounds);
        boolean hasHash = !history.isEmpty() && BlockchainClient.isValidTransactionHash(history.get(0).txHash);
        boolean needsSync = hasUnsyncedHistory(history);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(90, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 14, 14, paint);
        paint.setColor(Color.rgb(28, 69, 52));
        canvas.drawRoundRect(bounds, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(hasHash ? Color.rgb(105, 207, 123)
                : needsSync ? Color.rgb(230, 180, 85) : Color.rgb(92, 151, 105));
        canvas.drawRoundRect(bounds, 14, 14, paint);

        drawListIcon(canvas, bounds.centerX(), bounds.centerY(), hasHash);

        paint.setColor(history.isEmpty() ? Color.rgb(76, 112, 84) : Color.rgb(255, 219, 95));
        canvas.drawCircle(bounds.right - 10f, bounds.top + 12f, 17f, paint);
        paint.setColor(Color.rgb(30, 42, 28));
        paint.setTextSize(16f);
        paint.setFakeBoldText(true);
        drawCenteredText(canvas, String.valueOf(history.size()), bounds.right - 10f, bounds.top + 18f);
        paint.setFakeBoldText(false);
    }

    void drawDialog(Canvas canvas, int viewWidth, int viewHeight, List<ChainHistoryEntry> history, boolean hasGameApi) {
        canvas.drawColor(Color.argb(166, 0, 0, 0));

        RectF panel = dialogBounds(viewWidth, viewHeight, history.size());
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(135, 0, 0, 0));
        canvas.drawRoundRect(panel.left + 8f, panel.top + 10f, panel.right + 8f, panel.bottom + 10f, 22, 22, paint);
        paint.setColor(DialogUi.PANEL_FILL);
        canvas.drawRoundRect(panel, 22, 22, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(6f);
        paint.setColor(DialogUi.PANEL_STROKE);
        canvas.drawRoundRect(panel, 22, 22, paint);
        paint.setStrokeWidth(3f);
        paint.setColor(DialogUi.PANEL_INNER_STROKE);
        canvas.drawRoundRect(panel.left + 10f, panel.top + 10f, panel.right - 10f, panel.bottom - 10f, 16, 16, paint);

        drawPanelCorner(canvas, panel.left + 24f, panel.top + 24f, true, true);
        drawPanelCorner(canvas, panel.right - 24f, panel.top + 24f, false, true);
        drawPanelCorner(canvas, panel.left + 24f, panel.bottom - 24f, true, false);
        drawPanelCorner(canvas, panel.right - 24f, panel.bottom - 24f, false, false);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(DialogUi.TITLE);
        paint.setTextSize(32f);
        paint.setFakeBoldText(true);
        canvas.drawText("Riwayat transaksi", panel.left + 34f, panel.top + 52f, paint);
        paint.setFakeBoldText(false);
        paint.setColor(DialogUi.BODY_TEXT);
        String mode = hasGameApi
                ? "Gameplay lokal + signer Sepolia"
                : "Gameplay lokal: signer belum diset";
        float modeMaxWidth = history.isEmpty()
                ? panel.width() - 138f
                : dialogClearAllBounds(viewWidth, viewHeight, history.size()).left - panel.left - 46f;
        paint.setTextSize(fitTextSize(mode, 20f, Math.max(160f, modeMaxWidth)));
        canvas.drawText(mode, panel.left + 34f, panel.top + 86f, paint);

        if (!history.isEmpty()) {
            drawClearAllButton(canvas, dialogClearAllBounds(viewWidth, viewHeight, history.size()));
        }
        drawCloseButton(canvas, dialogCloseBounds(viewWidth, viewHeight, history.size()));

        if (history.isEmpty()) {
            RectF empty = new RectF(panel.left + 30f, panel.top + 120f, panel.right - 30f, panel.bottom - 30f);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(DialogUi.TEXT_BOX_FILL);
            canvas.drawRoundRect(empty, 12, 12, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(3f);
            paint.setColor(DialogUi.TEXT_BOX_STROKE);
            canvas.drawRoundRect(empty, 12, 12, paint);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(DialogUi.BODY_TEXT);
            paint.setTextSize(fitTextSize("Belum ada transaksi.", 22f, empty.width() - 40f));
            drawCenteredText(canvas, "Belum ada transaksi.", empty.centerX(), empty.centerY() + 7f);
            return;
        }

        int rows = visibleDialogRows(viewWidth, viewHeight, history.size());
        for (int i = 0; i < rows; i++) {
            drawRow(canvas, dialogRowBounds(i, viewWidth, viewHeight, history.size()), history.get(i));
        }

        if (history.size() > rows) {
            String more = "+" + (history.size() - rows) + " riwayat lain";
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(DialogUi.BODY_TEXT);
            paint.setTextSize(18f);
            drawCenteredText(canvas, more, panel.centerX(), panel.bottom - 22f);
        }
    }

    RectF buttonBounds(RectF walletBounds) {
        float top = walletBounds.bottom + 8f;
        float size = 86f;
        return new RectF(walletBounds.right - size, top, walletBounds.right, top + size);
    }

    RectF dialogBounds(int viewWidth, int viewHeight, int historySize) {
        int desiredRows = Math.min(historyLimit, historySize);
        float desiredWidth = clamp(viewWidth * 0.78f, 740f, 1060f);
        float width = Math.min(viewWidth - 40f, desiredWidth);
        float desiredHeight = historySize == 0 ? 304f : 180f + desiredRows * 78f;
        float maxHeight = Math.max(220f, viewHeight - 54f);
        float height = Math.min(desiredHeight, maxHeight);
        float left = (viewWidth - width) * 0.5f;
        float top = (viewHeight - height) * 0.5f;
        return new RectF(left, top, left + width, top + height);
    }

    RectF dialogCloseBounds(int viewWidth, int viewHeight, int historySize) {
        RectF panel = dialogBounds(viewWidth, viewHeight, historySize);
        float size = 64f;
        return new RectF(panel.right - size - 28f, panel.top + 20f, panel.right - 28f, panel.top + 20f + size);
    }

    RectF dialogClearAllBounds(int viewWidth, int viewHeight, int historySize) {
        RectF panel = dialogBounds(viewWidth, viewHeight, historySize);
        float width = Math.min(158f, Math.max(122f, panel.width() * 0.23f));
        return new RectF(panel.right - width - 112f, panel.top + 27f, panel.right - 112f, panel.top + 73f);
    }

    RectF dialogRowBounds(int rowIndex, int viewWidth, int viewHeight, int historySize) {
        RectF panel = dialogBounds(viewWidth, viewHeight, historySize);
        float left = panel.left + 30f;
        float top = panel.top + 132f + rowIndex * 78f;
        return new RectF(left, top, panel.right - 30f, top + 66f);
    }

    RectF rowDeleteBounds(int rowIndex, int viewWidth, int viewHeight, int historySize) {
        return rowDeleteBounds(dialogRowBounds(rowIndex, viewWidth, viewHeight, historySize));
    }

    int visibleDialogRows(int viewWidth, int viewHeight, int historySize) {
        if (historySize == 0) {
            return 0;
        }
        RectF panel = dialogBounds(viewWidth, viewHeight, historySize);
        int rowsByHeight = Math.max(1, (int) ((panel.height() - 154f) / 78f));
        return Math.min(Math.min(historyLimit, historySize), rowsByHeight);
    }

    private void drawPanelCorner(Canvas canvas, float x, float y, boolean left, boolean top) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(DialogUi.CORNER);
        float cornerLeft = left ? x : x - 18f;
        float cornerTop = top ? y : y - 18f;
        canvas.drawRoundRect(cornerLeft, cornerTop, cornerLeft + 18f, cornerTop + 18f, 5, 5, paint);
    }

    private void drawCloseButton(Canvas canvas, RectF close) {
        float radius = close.width() * 0.22f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(82, 0, 0, 0));
        canvas.drawRoundRect(close.left + 4f, close.top + 5f, close.right + 4f, close.bottom + 5f, radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(108, 53, 12));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setColor(Color.rgb(164, 78, 23));
        canvas.drawRoundRect(close.left + 6f, close.top + 6f, close.right - 6f, close.top + close.height() * 0.40f,
                radius * 0.72f, radius * 0.72f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setColor(Color.rgb(188, 100, 31));
        canvas.drawRoundRect(close, radius, radius, paint);
        paint.setStrokeWidth(7f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(DialogUi.BODY_TEXT);
        float pad = close.width() * 0.32f;
        canvas.drawLine(close.left + pad, close.top + pad, close.right - pad, close.bottom - pad, paint);
        canvas.drawLine(close.right - pad, close.top + pad, close.left + pad, close.bottom - pad, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawClearAllButton(Canvas canvas, RectF bounds) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(72, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 3f, bounds.top + 4f, bounds.right + 3f, bounds.bottom + 4f, 11, 11, paint);
        paint.setColor(Color.rgb(151, 47, 29));
        canvas.drawRoundRect(bounds, 11, 11, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(93, 23, 16));
        canvas.drawRoundRect(bounds, 11, 11, paint);

        drawTrashIcon(canvas, bounds.left + 28f, bounds.centerY(), 0.82f, Color.WHITE);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.WHITE);
        paint.setTextSize(fitTextSize("Hapus semua", 18f, bounds.width() - 58f));
        paint.setFakeBoldText(true);
        canvas.drawText("Hapus semua", bounds.left + 52f, bounds.centerY() + 7f, paint);
        paint.setFakeBoldText(false);
    }

    private void drawListIcon(Canvas canvas, float cx, float cy, boolean hasHash) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(hasHash ? Color.rgb(107, 224, 130) : Color.rgb(255, 219, 95));
        canvas.drawCircle(cx, cy, 27f, paint);

        int iconColor = Color.rgb(31, 49, 36);
        RectF arc = new RectF(cx - 16f, cy - 16f, cx + 16f, cy + 16f);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(5f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(iconColor);
        canvas.drawArc(arc, -210f, 285f, false, paint);
        canvas.drawLine(cx + 14f, cy - 9f, cx + 14f, cy - 21f, paint);
        canvas.drawLine(cx + 14f, cy - 9f, cx + 3f, cy - 9f, paint);

        paint.setStrokeWidth(4f);
        canvas.drawLine(cx, cy, cx, cy - 10f, paint);
        canvas.drawLine(cx, cy, cx + 9f, cy + 5f, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(iconColor);
        canvas.drawCircle(cx, cy, 3.6f, paint);
    }

    private void drawRow(Canvas canvas, RectF row, ChainHistoryEntry entry) {
        boolean hasHash = BlockchainClient.isValidTransactionHash(entry.txHash);
        boolean sending = chainStatusContains(entry.status, "mengirim");
        boolean waitingSync = chainStatusContains(entry.status, "belum sync")
                || chainStatusContains(entry.status, "belum on-chain")
                || chainStatusContains(entry.status, "butuh wallet")
                || chainStatusContains(entry.status, "terkirim signer")
                || chainStatusContains(entry.status, "tx hash");
        boolean localSaved = chainStatusContains(entry.status, "lokal")
                || chainStatusContains(entry.status, "tersimpan");
        boolean failed = chainStatusContains(entry.status, "gagal");
        RectF delete = rowDeleteBounds(row);
        float textRight = hasHash ? delete.left - 52f : delete.left - 14f;
        float textWidth = Math.max(120f, textRight - (row.left + 50f));
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(rowFillColor(hasHash, sending, waitingSync, localSaved, failed));
        canvas.drawRoundRect(row, 10, 10, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(rowStrokeColor(hasHash, sending, waitingSync, localSaved, failed));
        canvas.drawRoundRect(row, 10, 10, paint);

        drawStateDot(canvas, row.left + 24f, row.top + 25f, hasHash, entry.status);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(241, 252, 232));
        paint.setFakeBoldText(true);
        paint.setTextSize(fitTextSize(entry.label, 21f, textWidth));
        canvas.drawText(entry.label, row.left + 50f, row.top + 27f, paint);

        paint.setFakeBoldText(false);
        paint.setColor(hasHash ? Color.rgb(181, 248, 188) : Color.rgb(203, 219, 207));
        String status = hasHash ? "Sepolia " + BlockchainClient.shortTransactionHash(entry.txHash) : entry.status;
        paint.setTextSize(fitTextSize(status, 16f, textWidth));
        canvas.drawText(status, row.left + 50f, row.top + 54f, paint);

        if (hasHash) {
            drawExternalLinkIcon(canvas, delete.left - 28f, row.centerY());
        }
        drawDeleteButton(canvas, delete);
    }

    private void drawDeleteButton(Canvas canvas, RectF bounds) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(92, 46, 40));
        canvas.drawRoundRect(bounds, 9, 9, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2.5f);
        paint.setColor(Color.rgb(218, 119, 101));
        canvas.drawRoundRect(bounds, 9, 9, paint);
        drawTrashIcon(canvas, bounds.centerX(), bounds.centerY(), 0.76f, Color.rgb(255, 225, 207));
    }

    private void drawTrashIcon(Canvas canvas, float cx, float cy, float scale, int color) {
        float w = 22f * scale;
        float h = 22f * scale;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3.2f * scale);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setColor(color);
        canvas.drawLine(cx - w * 0.50f, cy - h * 0.38f, cx + w * 0.50f, cy - h * 0.38f, paint);
        canvas.drawLine(cx - w * 0.16f, cy - h * 0.56f, cx + w * 0.16f, cy - h * 0.56f, paint);
        canvas.drawRoundRect(cx - w * 0.36f, cy - h * 0.26f, cx + w * 0.36f, cy + h * 0.50f, 2.5f, 2.5f, paint);
        canvas.drawLine(cx - w * 0.12f, cy - h * 0.10f, cx - w * 0.12f, cy + h * 0.30f, paint);
        canvas.drawLine(cx + w * 0.12f, cy - h * 0.10f, cx + w * 0.12f, cy + h * 0.30f, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStyle(Paint.Style.FILL);
    }

    private int rowFillColor(boolean hasHash, boolean sending, boolean waitingSync, boolean localSaved, boolean failed) {
        if (hasHash) {
            return Color.rgb(73, 91, 48);
        }
        if (failed) {
            return Color.rgb(102, 47, 34);
        }
        if (sending) {
            return Color.rgb(102, 72, 30);
        }
        if (waitingSync) {
            return Color.rgb(114, 62, 24);
        }
        if (localSaved) {
            return Color.rgb(83, 74, 38);
        }
        return Color.rgb(109, 52, 21);
    }

    private int rowStrokeColor(boolean hasHash, boolean sending, boolean waitingSync, boolean localSaved, boolean failed) {
        if (hasHash) {
            return Color.rgb(102, 207, 123);
        }
        if (failed) {
            return Color.rgb(218, 119, 101);
        }
        if (sending) {
            return Color.rgb(235, 201, 93);
        }
        if (waitingSync) {
            return Color.rgb(219, 167, 81);
        }
        if (localSaved) {
            return Color.rgb(104, 183, 156);
        }
        return Color.rgb(83, 116, 92);
    }

    private void drawStateDot(Canvas canvas, float cx, float cy, boolean hasHash, String status) {
        paint.setStyle(Paint.Style.FILL);
        if (hasHash) {
            paint.setColor(Color.rgb(105, 224, 129));
        } else if (chainStatusContains(status, "gagal")) {
            paint.setColor(Color.rgb(232, 105, 88));
        } else if (chainStatusContains(status, "mengirim")) {
            paint.setColor(Color.rgb(255, 216, 89));
        } else if (chainStatusContains(status, "belum") || chainStatusContains(status, "butuh")) {
            paint.setColor(Color.rgb(245, 166, 72));
        } else if (chainStatusContains(status, "lokal") || chainStatusContains(status, "tersimpan")) {
            paint.setColor(Color.rgb(104, 216, 181));
        } else {
            paint.setColor(Color.rgb(157, 184, 165));
        }
        canvas.drawCircle(cx, cy, 6f, paint);
    }

    private boolean hasUnsyncedHistory(List<ChainHistoryEntry> history) {
        for (ChainHistoryEntry entry : history) {
            if (!BlockchainClient.isValidTransactionHash(entry.txHash)
                    && !chainStatusContains(entry.status, "on-chain")) {
                return true;
            }
        }
        return false;
    }

    private RectF rowDeleteBounds(RectF row) {
        float size = 44f;
        float left = row.right - size - 12f;
        float top = row.centerY() - size * 0.5f;
        return new RectF(left, top, left + size, top + size);
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

    private float fitTextSize(String text, float preferredSize, float maxWidth) {
        paint.setTextSize(preferredSize);
        float width = paint.measureText(text);
        if (width <= maxWidth) {
            return preferredSize;
        }
        return Math.max(15f, preferredSize * maxWidth / Math.max(1f, width));
    }

    private void drawCenteredText(Canvas canvas, String text, float centerX, float baselineY) {
        canvas.drawText(text, centerX - paint.measureText(text) * 0.5f, baselineY, paint);
    }

    private static boolean chainStatusContains(String status, String needle) {
        return status != null && status.toLowerCase(Locale.US).contains(needle);
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
