package id.rahmat.taniin;

import android.app.Activity;
import android.app.Dialog;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.text.InputType;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Locale;

final class WalletDialogController {
    private final FarmGameView view;

    WalletDialogController(FarmGameView view) {
        this.view = view;
    }

    void showWalletDialog() {
        Context context = view.getContext();
        if (!(context instanceof Activity)) {
            return;
        }
        boolean connected = !view.walletAddress().isEmpty();
        boolean signerWallet = view.isConnectedWalletBackendSigner();
        boolean compactForLandscape = view.getWidth() > view.getHeight();

        Dialog dialog = new Dialog(context);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout root = new LinearLayout(context);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(
                DialogUi.dp(context, compactForLandscape ? 42 : 44),
                DialogUi.dp(context, compactForLandscape ? 24 : 40),
                DialogUi.dp(context, compactForLandscape ? 50 : 52),
                DialogUi.dp(context, compactForLandscape ? 26 : 46));
        root.setBackground(DialogUi.pixelPanelDrawable(context));

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = new TextView(context);
        icon.setText("W");
        icon.setTextColor(Color.rgb(72, 43, 12));
        icon.setTextSize(compactForLandscape ? 17f : 18f);
        icon.setGravity(Gravity.CENTER);
        icon.setTypeface(null, android.graphics.Typeface.BOLD);
        icon.setIncludeFontPadding(false);
        icon.setBackground(DialogUi.roundedDrawable(DialogUi.CORNER, DialogUi.dp(context, 8)));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(DialogUi.dp(context, 36), DialogUi.dp(context, 36));
        header.addView(icon, iconParams);

        LinearLayout titleBlock = new LinearLayout(context);
        titleBlock.setOrientation(LinearLayout.VERTICAL);
        titleBlock.setPadding(DialogUi.dp(context, 14), 0, 0, 0);
        TextView title = new TextView(context);
        title.setText(connected ? "Ganti Wallet" : "Connect Wallet");
        title.setTextColor(DialogUi.TITLE);
        title.setTextSize(compactForLandscape ? 25f : 28f);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        TextView network = new TextView(context);
        network.setText(signerWallet ? "Wallet signer backend" : connected ? "Sepolia wallet aktif" : "Sepolia network");
        network.setTextColor(signerWallet ? Color.rgb(255, 225, 132) : Color.rgb(170, 235, 165));
        network.setTextSize(compactForLandscape ? 14f : 15f);
        titleBlock.addView(title);
        titleBlock.addView(network);
        header.addView(titleBlock, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        root.addView(header);

        View divider = new View(context);
        divider.setBackgroundColor(Color.rgb(89, 42, 13));
        LinearLayout.LayoutParams dividerParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                DialogUi.dp(context, 3));
        dividerParams.setMargins(0, DialogUi.dp(context, compactForLandscape ? 12 : 22), 0, 0);
        root.addView(divider, dividerParams);

        TextView body = new TextView(context);
        body.setText(walletDialogBodyText());
        body.setTextColor(DialogUi.BODY_TEXT);
        body.setTextSize(compactForLandscape ? 14.5f : 17f);
        body.setPadding(
                DialogUi.dp(context, 16),
                DialogUi.dp(context, compactForLandscape ? 9 : 15),
                DialogUi.dp(context, 16),
                DialogUi.dp(context, compactForLandscape ? 9 : 15));
        body.setBackground(DialogUi.textBoxDrawable(context));
        if (compactForLandscape) {
            body.setMaxLines(4);
            body.setEllipsize(TextUtils.TruncateAt.END);
        }
        LinearLayout.LayoutParams bodyParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        bodyParams.setMargins(0, DialogUi.dp(context, compactForLandscape ? 12 : 22), 0, DialogUi.dp(context, compactForLandscape ? 10 : 18));
        root.addView(body, bodyParams);

        TextView connectLabel = new TextView(context);
        connectLabel.setText("Connect dari wallet app");
        connectLabel.setTextColor(Color.rgb(255, 230, 139));
        connectLabel.setTextSize(compactForLandscape ? 13f : 15f);
        connectLabel.setTypeface(null, android.graphics.Typeface.BOLD);
        connectLabel.setPadding(0, 0, 0, DialogUi.dp(context, 8));
        root.addView(connectLabel);

        LinearLayout walletActions = new LinearLayout(context);
        walletActions.setOrientation(LinearLayout.HORIZONTAL);
        walletActions.setGravity(Gravity.CENTER_VERTICAL);
        Button connectMetaMask = DialogUi.walletButton(context, "MetaMask", Color.rgb(38, 112, 73), Color.WHITE);
        Button connectBrowser = DialogUi.walletButton(context, "Browser", Color.rgb(95, 73, 132), Color.WHITE);
        Button pasteAddress = DialogUi.walletButton(context, "Tempel", Color.rgb(111, 78, 43), Color.rgb(255, 238, 211));
        LinearLayout.LayoutParams walletActionParams = new LinearLayout.LayoutParams(
                0,
                DialogUi.dp(context, compactForLandscape ? 36 : 46),
                1f);
        walletActions.addView(connectMetaMask, walletActionParams);
        LinearLayout.LayoutParams walletActionMidParams = new LinearLayout.LayoutParams(
                0,
                DialogUi.dp(context, compactForLandscape ? 36 : 46),
                1f);
        walletActionMidParams.leftMargin = DialogUi.dp(context, 10);
        walletActions.addView(connectBrowser, walletActionMidParams);
        LinearLayout.LayoutParams walletActionLastParams = new LinearLayout.LayoutParams(
                0,
                DialogUi.dp(context, compactForLandscape ? 36 : 46),
                1f);
        walletActionLastParams.leftMargin = DialogUi.dp(context, 10);
        walletActions.addView(pasteAddress, walletActionLastParams);
        root.addView(walletActions, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        TextView fallbackLabel = new TextView(context);
        fallbackLabel.setText("Fallback public address");
        fallbackLabel.setTextColor(DialogUi.MUTED_TEXT);
        fallbackLabel.setTextSize(compactForLandscape ? 12f : 13.5f);
        fallbackLabel.setPadding(0, DialogUi.dp(context, compactForLandscape ? 10 : 14), 0, DialogUi.dp(context, 6));
        if (!compactForLandscape) {
            root.addView(fallbackLabel);
        }

        final EditText input = new EditText(context);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        input.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        input.setHint("0x wallet address Sepolia");
        input.setText(view.walletAddress());
        input.setSelectAllOnFocus(false);
        input.setTextColor(DialogUi.BODY_TEXT);
        input.setHintTextColor(Color.rgb(210, 170, 125));
        input.setTextSize(compactForLandscape ? 16f : 18f);
        input.setPadding(DialogUi.dp(context, 16), 0, DialogUi.dp(context, 16), 0);
        input.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(122, 55, 19),
                DialogUi.dp(context, 10),
                DialogUi.TEXT_BOX_STROKE,
                DialogUi.dp(context, 2)));
        if (!compactForLandscape) {
            root.addView(input, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    DialogUi.dp(context, 54)));
        }

        LinearLayout actions = new LinearLayout(context);
        actions.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        actions.setPadding(0, DialogUi.dp(context, compactForLandscape ? 8 : 24), 0, 0);
        Button close = DialogUi.walletButton(context, "Tutup", Color.rgb(91, 64, 40), Color.rgb(239, 220, 191));
        Button sync = DialogUi.walletButton(context, "Sync", Color.rgb(43, 108, 72), Color.WHITE);
        Button save = DialogUi.walletButton(context, compactForLandscape ? "Manual" : connected ? "Ganti" : "Simpan", Color.rgb(214, 129, 39), Color.WHITE);
        LinearLayout.LayoutParams closeParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForLandscape ? 88 : 108),
                DialogUi.dp(context, compactForLandscape ? 38 : 48));
        closeParams.leftMargin = DialogUi.dp(context, compactForLandscape ? 8 : 10);
        actions.addView(close, closeParams);
        if (connected) {
            LinearLayout.LayoutParams syncParams = new LinearLayout.LayoutParams(
                    DialogUi.dp(context, compactForLandscape ? 92 : 108),
                    DialogUi.dp(context, compactForLandscape ? 38 : 48));
            syncParams.leftMargin = DialogUi.dp(context, compactForLandscape ? 8 : 10);
            actions.addView(sync, syncParams);
        }
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForLandscape ? 100 : 126),
                DialogUi.dp(context, compactForLandscape ? 38 : 48));
        saveParams.leftMargin = DialogUi.dp(context, compactForLandscape ? 8 : 10);
        actions.addView(save, saveParams);
        root.addView(actions);

        close.setOnClickListener(v -> dialog.dismiss());
        connectMetaMask.setOnClickListener(v -> openWalletConnectPage(dialog, true));
        connectBrowser.setOnClickListener(v -> openWalletConnectPage(dialog, false));
        pasteAddress.setOnClickListener(v -> pasteWalletAddressFromClipboard(input, dialog, compactForLandscape));
        sync.setOnClickListener(v -> {
            if (compactForLandscape) {
                syncCurrentWallet(dialog);
            } else {
                syncWalletFromInput(input, dialog);
            }
        });
        save.setOnClickListener(v -> {
            if (compactForLandscape) {
                dialog.dismiss();
                openManualWalletAddressDialog();
            } else {
                saveWalletFromInput(input, dialog);
            }
        });
        input.setOnEditorActionListener((v, actionId, event) -> {
            boolean enter = event != null
                    && event.getAction() == KeyEvent.ACTION_UP
                    && event.getKeyCode() == KeyEvent.KEYCODE_ENTER;
            if (actionId == EditorInfo.IME_ACTION_DONE || enter) {
                return saveWalletFromInput(input, dialog);
            }
            return false;
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
            dialogWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
                    | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
            dialogWindow.setLayout(
                    Math.min(Math.max(1, view.getWidth() - DialogUi.dp(context, 32)), (int) clamp(view.getWidth() * 0.50f, 720f, compactForLandscape ? 1180f : 900f)),
                    WindowManager.LayoutParams.WRAP_CONTENT);
        }
    }

    void connectWalletFromDeepLink(String address) {
        String cleaned = address == null ? "" : address.trim();
        if (!BlockchainClient.isValidAddress(cleaned)) {
            view.showErrorMessage("Wallet dari wallet app tidak valid.");
            return;
        }
        view.storeWalletAddress(cleaned);
        view.setChainStatus("Wallet tersambung dari wallet app: " + BlockchainClient.shortAddress(view.walletAddress()) + ". Sync Sepolia...", 5200L);
        view.showSuccessPopup("Wallet tersambung: " + BlockchainClient.shortAddress(view.walletAddress()));
        view.refreshWalletState(true);
        view.invalidate();
    }

    private String walletDialogBodyText() {
        if (view.isConnectedWalletBackendSigner()) {
            return "Wallet ini signer backend. Connect wallet pemain lewat MetaMask atau browser wallet supaya payout ETH bisa masuk.";
        }
        if (!view.walletAddress().isEmpty()) {
            return "Connect wallet pemain dari wallet app, atau tekan Sync untuk baca ulang saldo. Jangan masukkan private key.";
        }
        return "Connect wallet pemain dari MetaMask atau browser wallet. Taniin hanya membaca public address.";
    }

    private void openWalletConnectPage(Dialog dialog, boolean metaMask) {
        String url = view.walletConnectUrl();
        if (url.isEmpty()) {
            view.showErrorMessage("TANIIN_GAME_API_URL belum diset untuk connect wallet app.");
            return;
        }
        Uri uri = metaMask
                ? Uri.parse("https://metamask.app.link/dapp/" + walletConnectDappPath(url))
                : Uri.parse(url);
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        if (!(view.getContext() instanceof Activity)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        try {
            view.getContext().startActivity(intent);
            dialog.dismiss();
            view.setChainStatus("Approve connect wallet, lalu Taniin akan menerima public address otomatis.", 5200L);
            view.showMessage(metaMask ? "Membuka MetaMask connect..." : "Membuka halaman connect wallet...");
            view.invalidate();
        } catch (ActivityNotFoundException exception) {
            view.showErrorMessage(metaMask ? "MetaMask belum terpasang." : "Tidak bisa membuka browser wallet.");
        } catch (RuntimeException exception) {
            view.showErrorMessage("Tidak bisa membuka connect wallet di perangkat ini.");
        }
    }

    private String walletConnectDappPath(String url) {
        Uri uri = Uri.parse(url);
        String host = uri.getHost();
        if (host == null || host.trim().isEmpty()) {
            return url;
        }
        String path = uri.getEncodedPath();
        return host + (path == null ? "" : path);
    }

    private void pasteWalletAddressFromClipboard(EditText input, Dialog dialog, boolean saveDirectly) {
        String address = clipboardWalletAddress();
        if (address.isEmpty()) {
            view.showErrorMessage("Clipboard belum berisi public address 0x...");
            return;
        }
        if (saveDirectly) {
            dialog.dismiss();
            connectWalletFromDeepLink(address);
            return;
        }
        input.setText(address);
        input.setSelection(input.getText().length());
        view.showMessage("Address dari clipboard siap dipakai.");
    }

    private void syncCurrentWallet(Dialog dialog) {
        if (view.walletAddress().isEmpty()) {
            view.showErrorMessage("Connect wallet dulu untuk sync.");
            return;
        }
        dialog.dismiss();
        view.refreshWalletState(true);
        view.showMessage("Wallet sync: " + BlockchainClient.shortAddress(view.walletAddress()));
    }

    private void openManualWalletAddressDialog() {
        Context context = view.getContext();
        if (!(context instanceof Activity)) {
            return;
        }
        boolean compactForKeyboard = view.getWidth() > view.getHeight();
        Dialog dialog = new Dialog(context);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout root = new LinearLayout(context);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(
                DialogUi.dp(context, compactForKeyboard ? 18 : 24),
                DialogUi.dp(context, compactForKeyboard ? 14 : 22),
                DialogUi.dp(context, compactForKeyboard ? 18 : 24),
                DialogUi.dp(context, compactForKeyboard ? 14 : 20));
        root.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(55, 37, 24),
                DialogUi.dp(context, 16),
                Color.rgb(173, 91, 31),
                DialogUi.dp(context, 3)));

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(compactForKeyboard ? LinearLayout.HORIZONTAL : LinearLayout.VERTICAL);
        header.setGravity(compactForKeyboard ? Gravity.CENTER_VERTICAL : Gravity.LEFT);

        TextView title = new TextView(context);
        title.setText("Input Wallet Manual");
        title.setTextColor(Color.rgb(255, 230, 158));
        title.setTextSize(compactForKeyboard ? 20f : 22f);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        header.addView(title, new LinearLayout.LayoutParams(
                compactForKeyboard ? LinearLayout.LayoutParams.WRAP_CONTENT : LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        TextView body = new TextView(context);
        body.setText(compactForKeyboard ? "Public address 0x saja, bukan private key." : "Fallback saja. Pakai public address 0x, jangan private key.");
        body.setTextColor(Color.rgb(237, 223, 200));
        body.setTextSize(compactForKeyboard ? 13.5f : 14.5f);
        body.setSingleLine(compactForKeyboard);
        body.setEllipsize(TextUtils.TruncateAt.END);
        body.setPadding(compactForKeyboard ? DialogUi.dp(context, 18) : 0, compactForKeyboard ? 0 : DialogUi.dp(context, 10), 0, compactForKeyboard ? 0 : DialogUi.dp(context, 12));
        header.addView(body, new LinearLayout.LayoutParams(
                compactForKeyboard ? 0 : LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                compactForKeyboard ? 1f : 0f));
        root.addView(header);

        final EditText input = new EditText(context);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        input.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        input.setHint("0x wallet address Sepolia");
        input.setText(view.walletAddress());
        input.setSelectAllOnFocus(false);
        input.setTextColor(Color.WHITE);
        input.setHintTextColor(Color.rgb(185, 164, 138));
        input.setTextSize(compactForKeyboard ? 17f : 16f);
        input.setPadding(DialogUi.dp(context, 16), 0, DialogUi.dp(context, 16), 0);
        input.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(38, 30, 24),
                DialogUi.dp(context, 10),
                Color.rgb(130, 85, 43),
                DialogUi.dp(context, 2)));

        LinearLayout actions = new LinearLayout(context);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        actions.setPadding(0, DialogUi.dp(context, compactForKeyboard ? 10 : 14), 0, 0);
        if (compactForKeyboard) {
            actions.addView(input, new LinearLayout.LayoutParams(
                    0,
                    DialogUi.dp(context, 48),
                    1f));
        } else {
            root.addView(input, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    DialogUi.dp(context, 48)));
        }
        Button close = DialogUi.walletButton(context, "Batal", Color.rgb(91, 64, 40), Color.rgb(239, 220, 191));
        Button paste = DialogUi.walletButton(context, "Tempel", Color.rgb(111, 78, 43), Color.rgb(255, 238, 211));
        Button save = DialogUi.walletButton(context, "Simpan", Color.rgb(214, 129, 39), Color.WHITE);
        LinearLayout.LayoutParams closeParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForKeyboard ? 86 : 94),
                DialogUi.dp(context, compactForKeyboard ? 48 : 42));
        closeParams.leftMargin = compactForKeyboard ? DialogUi.dp(context, 10) : 0;
        actions.addView(close, closeParams);
        LinearLayout.LayoutParams pasteParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForKeyboard ? 92 : 94),
                DialogUi.dp(context, compactForKeyboard ? 48 : 42));
        pasteParams.leftMargin = DialogUi.dp(context, compactForKeyboard ? 8 : 8);
        actions.addView(paste, pasteParams);
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForKeyboard ? 104 : 108),
                DialogUi.dp(context, compactForKeyboard ? 48 : 42));
        saveParams.leftMargin = DialogUi.dp(context, compactForKeyboard ? 8 : 8);
        actions.addView(save, saveParams);
        root.addView(actions);

        close.setOnClickListener(v -> dialog.dismiss());
        paste.setOnClickListener(v -> pasteWalletAddressFromClipboard(input, dialog, false));
        save.setOnClickListener(v -> saveWalletFromInput(input, dialog));
        input.setOnEditorActionListener((v, actionId, event) -> {
            boolean enter = event != null
                    && event.getAction() == KeyEvent.ACTION_UP
                    && event.getKeyCode() == KeyEvent.KEYCODE_ENTER;
            if (actionId == EditorInfo.IME_ACTION_DONE || enter) {
                return saveWalletFromInput(input, dialog);
            }
            return false;
        });

        dialog.setContentView(root);
        dialog.show();
        Window dialogWindow = dialog.getWindow();
        if (dialogWindow != null) {
            dialogWindow.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            WindowManager.LayoutParams params = dialogWindow.getAttributes();
            params.dimAmount = compactForKeyboard ? 0.42f : 0.62f;
            dialogWindow.setAttributes(params);
            dialogWindow.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            dialogWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
                    | (compactForKeyboard
                    ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
                    : WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE));
            if (compactForKeyboard) {
                dialogWindow.setGravity(Gravity.TOP | Gravity.CENTER_HORIZONTAL);
                params = dialogWindow.getAttributes();
                params.y = DialogUi.dp(context, 8);
                dialogWindow.setAttributes(params);
            }
            dialogWindow.setLayout(
                    Math.min(Math.max(1, view.getWidth() - DialogUi.dp(context, 32)), (int) (compactForKeyboard
                            ? clamp(view.getWidth() * 0.90f, 1100f, 1880f)
                            : clamp(view.getWidth() * 0.46f, 680f, 980f))),
                    WindowManager.LayoutParams.WRAP_CONTENT);
        }
        input.requestFocus();
        input.setSelection(input.getText().length());
    }

    private String clipboardWalletAddress() {
        Object service = view.getContext().getSystemService(Context.CLIPBOARD_SERVICE);
        if (!(service instanceof ClipboardManager)) {
            return "";
        }
        ClipboardManager clipboard = (ClipboardManager) service;
        ClipData clipData = clipboard.getPrimaryClip();
        if (clipData == null) {
            return "";
        }
        for (int i = 0; i < clipData.getItemCount(); i++) {
            CharSequence text = clipData.getItemAt(i).coerceToText(view.getContext());
            String address = firstWalletAddressInText(text == null ? "" : text.toString());
            if (!address.isEmpty()) {
                return address;
            }
        }
        return "";
    }

    private String firstWalletAddressInText(String text) {
        if (text == null) {
            return "";
        }
        String lower = text.toLowerCase(Locale.US);
        int from = 0;
        while (from < lower.length()) {
            int start = lower.indexOf("0x", from);
            if (start < 0) {
                return "";
            }
            int end = start + 42;
            if (end <= text.length()) {
                String candidate = text.substring(start, end);
                if (BlockchainClient.isValidAddress(candidate)) {
                    return candidate;
                }
            }
            from = start + 2;
        }
        return "";
    }

    private boolean syncWalletFromInput(EditText input, Dialog dialog) {
        String address = input.getText().toString().trim();
        if (!address.isEmpty()) {
            if (!BlockchainClient.isValidAddress(address)) {
                view.showErrorMessage("Wallet address tidak valid.");
                return true;
            }
            view.storeWalletAddress(address);
        }
        if (view.walletAddress().isEmpty()) {
            view.showErrorMessage("Isi wallet address dulu untuk sync.");
            return true;
        }
        dialog.dismiss();
        view.refreshWalletState(true);
        view.showMessage("Wallet sync: " + BlockchainClient.shortAddress(view.walletAddress()));
        return true;
    }

    private boolean saveWalletFromInput(EditText input, Dialog dialog) {
        String address = input.getText().toString().trim();
        if (!BlockchainClient.isValidAddress(address)) {
            view.showErrorMessage("Wallet address tidak valid.");
            return true;
        }
        boolean changed = view.storeWalletAddress(address);
        view.showMessage((changed ? "Wallet diganti: " : "Wallet tersimpan: ") + BlockchainClient.shortAddress(view.walletAddress()));
        dialog.dismiss();
        view.refreshWalletState(true);
        view.invalidate();
        return true;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
