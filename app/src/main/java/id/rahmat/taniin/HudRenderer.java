package id.rahmat.taniin;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;

final class HudRenderer {
    private final Paint paint;

    HudRenderer(Paint paint) {
        this.paint = paint;
    }

    void drawWalletButton(
            Canvas canvas,
            RectF bounds,
            boolean connected,
            boolean checkingChain,
            boolean signerWallet,
            String label,
            String compactNativeEth) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(95, 0, 0, 0));
        canvas.drawRoundRect(bounds.left + 5f, bounds.top + 6f, bounds.right + 5f, bounds.bottom + 6f, 14, 14, paint);
        paint.setColor(signerWallet ? Color.rgb(96, 72, 34) : connected ? Color.rgb(36, 102, 68) : Color.rgb(42, 87, 62));
        canvas.drawRoundRect(bounds, 14, 14, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(4f);
        paint.setColor(signerWallet ? Color.rgb(255, 202, 86) : connected ? Color.rgb(105, 196, 135) : Color.rgb(91, 143, 104));
        canvas.drawRoundRect(bounds, 14, 14, paint);

        float iconCx = bounds.left + 40f;
        float iconCy = (bounds.top + bounds.bottom) * 0.5f;
        drawWalletHudIcon(canvas, iconCx, iconCy, connected, signerWallet);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(236, 248, 226));
        paint.setTextSize(connected ? 20f : 21f);
        paint.setFakeBoldText(true);
        paint.setTextSize(fitTextSize(label, connected ? 20f : 21f, bounds.width() - 96f));
        canvas.drawText(label, bounds.left + 76f, bounds.top + (connected ? 34f : 44f), paint);
        if (connected) {
            paint.setFakeBoldText(false);
            paint.setColor(signerWallet ? Color.rgb(255, 227, 137) : Color.rgb(177, 238, 185));
            String subtitle = walletSubtitle(checkingChain, signerWallet, compactNativeEth);
            paint.setTextSize(fitTextSize(subtitle, 15f, bounds.width() - 96f));
            canvas.drawText(subtitle, bounds.left + 76f, bounds.top + 58f, paint);
        }
        paint.setFakeBoldText(false);
    }

    void drawShopPanel(Canvas canvas, int viewWidth, int landBuyPrice, int landSellPrice, int harvestSellPrice) {
        float w = 360;
        float h = 186;
        float x = (viewWidth - w) / 2f;
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
        String shopLine = "SHOP: pilih benih, bayar pakai Game Coin";
        String landLine = "Lahan: beli " + landBuyPrice + ", jual kosong +" + landSellPrice + " coin";
        String harvestLine = "Rumah Jual: panen -> Game Coin (1 = " + harvestSellPrice + ")";
        String swapLine = "Rumah Swap: ETH Sepolia -> Game Coin, atau coin -> Sepolia";
        paint.setTextSize(fitTextSize(shopLine, 19f, w - 44f));
        canvas.drawText(shopLine, x + 22, y + 78, paint);
        paint.setTextSize(fitTextSize(landLine, 19f, w - 44f));
        canvas.drawText(landLine, x + 22, y + 108, paint);
        paint.setTextSize(fitTextSize(harvestLine, 19f, w - 44f));
        canvas.drawText(harvestLine, x + 22, y + 138, paint);
        paint.setTextSize(fitTextSize(swapLine, 19f, w - 44f));
        canvas.drawText(swapLine, x + 22, y + 168, paint);
    }

    void drawContextMessage(Canvas canvas, int viewWidth, int viewHeight, String text) {
        if (text.isEmpty()) {
            return;
        }
        paint.setTextSize(20f);
        float textW = paint.measureText(text);
        float x = (viewWidth - textW) / 2f;
        float y = viewHeight - 28f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(190, 23, 21, 18));
        canvas.drawRoundRect(x - 16, y - 30, x + textW + 16, y + 10, 8, 8, paint);
        paint.setColor(Color.WHITE);
        canvas.drawText(text, x, y, paint);
    }

    void drawChainPanel(
            Canvas canvas,
            int viewWidth,
            int viewHeight,
            boolean statusPopupVisible,
            RectF statusPopupBounds,
            boolean signerWallet,
            String chainStatus,
            String walletLine,
            String balanceLine,
            boolean hasCoinContract,
            boolean hasGameApi,
            String nextAction,
            String footnote) {
        RectF panel = chainPanelBounds(viewWidth, viewHeight, statusPopupVisible, statusPopupBounds);
        float w = panel.width();
        float x = panel.left;
        float y = panel.top;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(235, 18, 34, 30));
        canvas.drawRoundRect(panel, 10, 10, paint);
        paint.setColor(signerWallet ? Color.rgb(255, 218, 98) : Color.rgb(152, 239, 176));
        paint.setTextSize(23f);
        paint.setFakeBoldText(true);
        canvas.drawText(signerWallet ? "Sepolia Blockchain - Wallet Signer" : "Sepolia Blockchain", x + 22, y + 38, paint);
        paint.setFakeBoldText(false);
        paint.setColor(Color.WHITE);
        paint.setTextSize(fitTextSize(chainStatus, 18f, w - 44f));
        canvas.drawText(chainStatus, x + 22, y + 72, paint);
        paint.setTextSize(fitTextSize(walletLine, 18f, w - 44f));
        canvas.drawText(walletLine, x + 22, y + 102, paint);
        paint.setTextSize(fitTextSize(balanceLine, 18f, w - 44f));
        canvas.drawText(balanceLine, x + 22, y + 132, paint);
        String modeText = chainModeText(hasCoinContract, hasGameApi);
        paint.setTextSize(fitTextSize(modeText, 17f, w - 44f));
        canvas.drawText(modeText, x + 22, y + 162, paint);

        paint.setColor(signerWallet ? Color.rgb(255, 198, 91) : Color.rgb(255, 219, 95));
        paint.setTextSize(fitTextSize(nextAction, 18f, w - 44f));
        canvas.drawText(nextAction, x + 22, y + 194, paint);
        paint.setColor(Color.rgb(210, 225, 216));
        paint.setTextSize(fitTextSize(footnote, 18f, w - 44f));
        canvas.drawText(footnote, x + 22, y + 220, paint);
    }

    RectF walletButtonBounds(int viewWidth, float topMenuTop, float topMenuButtonSize) {
        float right = viewWidth - 20f;
        float top = topMenuTop + topMenuButtonSize + 14f;
        float width = clamp(viewWidth * 0.28f, 292f, 360f);
        return new RectF(right - width, top, right, top + 72f);
    }

    private void drawWalletHudIcon(Canvas canvas, float cx, float cy, boolean connected, boolean signerWallet) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(signerWallet ? Color.rgb(255, 225, 118) : connected ? Color.rgb(112, 224, 132) : Color.rgb(244, 208, 87));
        canvas.drawCircle(cx, cy, 23f, paint);
        paint.setColor(Color.rgb(33, 47, 32));
        canvas.drawRoundRect(cx - 15f, cy - 11f, cx + 16f, cy + 12f, 5, 5, paint);
        paint.setColor(Color.rgb(240, 246, 228));
        canvas.drawRect(cx - 10f, cy - 4f, cx + 11f, cy + 0f, paint);
        if (signerWallet) {
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(4f);
            paint.setColor(Color.rgb(111, 61, 23));
            canvas.drawLine(cx - 12f, cy + 14f, cx + 12f, cy + 14f, paint);
            paint.setStyle(Paint.Style.FILL);
        }
        paint.setColor(signerWallet ? Color.rgb(207, 126, 35) : connected ? Color.rgb(69, 170, 83) : Color.rgb(193, 138, 36));
        canvas.drawCircle(cx + 15f, cy - 15f, 6f, paint);
    }

    private RectF chainPanelBounds(int viewWidth, int viewHeight, boolean statusPopupVisible, RectF statusPopupBounds) {
        float w = Math.min(viewWidth - 44f, 620f);
        float h = 232f;
        float x = (viewWidth - w) * 0.5f;
        float y = 78f;
        if (statusPopupVisible) {
            y = statusPopupBounds.bottom + 18f;
        }
        float maxY = Math.max(78f, viewHeight - h - 82f);
        y = Math.min(y, maxY);
        return new RectF(x, y, x + w, y + h);
    }

    private String walletSubtitle(boolean checkingChain, boolean signerWallet, String compactNativeEth) {
        if (checkingChain) {
            return "sync Sepolia...";
        }
        if (signerWallet) {
            return "ganti wallet pemain";
        }
        if (!compactNativeEth.isEmpty()) {
            return "Sepolia ETH " + compactNativeEth;
        }
        return "tap untuk ganti/sync";
    }

    private String chainModeText(boolean hasCoinContract, boolean hasGameApi) {
        if (hasCoinContract && hasGameApi) {
            return "Mode sinkron: game tersimpan lokal, signer mencoba kirim on-chain.";
        }
        if (hasCoinContract) {
            return "Saldo wallet terbaca via RPC; aksi game tersimpan lokal sampai signer diset.";
        }
        if (hasGameApi) {
            return "Signer diset; contract TANI belum diset, coin masih lokal.";
        }
        return "Mode lokal: contract/API belum diisi di .env, aksi belum on-chain.";
    }

    private float fitTextSize(String text, float preferredSize, float maxWidth) {
        paint.setTextSize(preferredSize);
        float width = paint.measureText(text);
        if (width <= maxWidth) {
            return preferredSize;
        }
        return Math.max(15f, preferredSize * maxWidth / Math.max(1f, width));
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
