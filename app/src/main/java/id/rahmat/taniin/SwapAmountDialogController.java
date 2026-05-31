package id.rahmat.taniin;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.text.InputType;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

final class SwapAmountDialogController {
    private final FarmGameView view;

    SwapAmountDialogController(FarmGameView view) {
        this.view = view;
    }

    void open() {
        if (view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_COIN && view.coinBalance() <= 0) {
            view.showErrorMessage("Coin belum ada untuk diswap.");
            return;
        }
        if (view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_ETH && view.walletAddress().isEmpty()) {
            view.showErrorMessage("Connect wallet dulu sebelum isi Game Coin dari Sepolia.");
            view.performWallet();
            return;
        }
        if (view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_ETH && view.walletNativeBalance().isEmpty()) {
            view.refreshWalletState(true);
            view.showErrorMessage("Sync saldo ETH Sepolia dulu.");
            return;
        }
        if (view.maxSwapCoinAmount() <= 0) {
            view.showErrorMessage(view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_ETH
                    ? "Saldo ETH Sepolia belum cukup."
                    : "Coin belum ada untuk diswap.");
            return;
        }
        Context context = view.getContext();
        if (!(context instanceof Activity)) {
            return;
        }

        Dialog dialog = new Dialog(context);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        boolean compactForKeyboard = view.getWidth() > view.getHeight();

        LinearLayout root = new LinearLayout(context);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(
                DialogUi.dp(context, compactForKeyboard ? 10 : 30),
                DialogUi.dp(context, compactForKeyboard ? 8 : 26),
                DialogUi.dp(context, compactForKeyboard ? 10 : 30),
                DialogUi.dp(context, compactForKeyboard ? 8 : 24));
        root.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(116, 55, 22),
                DialogUi.dp(context, 18),
                Color.rgb(70, 39, 13),
                DialogUi.dp(context, 4)));

        TextView title = new TextView(context);
        title.setText("Jumlah Swap");
        title.setTextColor(Color.rgb(255, 224, 84));
        title.setTextSize(compactForKeyboard ? 18f : 24f);
        title.setTypeface(null, android.graphics.Typeface.BOLD);

        TextView body = new TextView(context);
        String balanceText = view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_ETH
                ? "Saldo ETH Sepolia: " + FarmGameView.compactEth(view.walletNativeBalance()) + " ETH"
                : "Saldo Game Coin: " + view.coinBalance() + " coin";
        body.setText(balanceText);
        body.setTextColor(Color.rgb(255, 238, 211));
        body.setTextSize(compactForKeyboard ? 11f : 16f);

        TextView route = new TextView(context);
        String routeText = view.selectedSwapFromAsset() == FarmGameView.SWAP_ASSET_ETH
                ? "Isi Game Coin: " + view.selectedSwapOutputText()
                : "Estimasi: " + view.selectedSwapOutputText();
        route.setText(routeText);
        route.setTextColor(Color.rgb(245, 194, 124));
        route.setTextSize(compactForKeyboard ? 11f : 14f);
        route.setPadding(DialogUi.dp(context, compactForKeyboard ? 10 : 16), 0, DialogUi.dp(context, compactForKeyboard ? 10 : 16), 0);
        route.setGravity(Gravity.CENTER);
        route.setSingleLine(true);
        route.setEllipsize(TextUtils.TruncateAt.END);
        route.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(82, 39, 17),
                DialogUi.dp(context, 11),
                Color.rgb(145, 77, 30),
                DialogUi.dp(context, 2)));

        final EditText input = new EditText(context);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_NUMBER);
        input.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        input.setText(String.valueOf(view.selectedSwapInputAmount()));
        input.setSelectAllOnFocus(false);
        input.setTextColor(Color.rgb(255, 240, 212));
        input.setHint("Jumlah Game Coin");
        input.setHintTextColor(Color.rgb(190, 151, 124));
        input.setTextSize(compactForKeyboard ? 18f : 24f);
        input.setGravity(Gravity.CENTER);
        input.setPadding(DialogUi.dp(context, compactForKeyboard ? 12 : 16), 0, DialogUi.dp(context, compactForKeyboard ? 12 : 16), 0);
        input.setBackground(DialogUi.roundedStrokeDrawable(
                Color.rgb(60, 32, 18),
                DialogUi.dp(context, 12),
                Color.rgb(255, 200, 65),
                DialogUi.dp(context, 3)));

        LinearLayout actions = new LinearLayout(context);
        actions.setGravity(Gravity.CENTER);
        actions.setPadding(0, DialogUi.dp(context, compactForKeyboard ? 0 : 22), 0, 0);
        Button close = DialogUi.walletButton(context, "Batal", Color.rgb(100, 54, 28), Color.rgb(255, 238, 211));
        Button save = DialogUi.walletButton(context, "Pakai", Color.rgb(207, 119, 35), Color.WHITE);
        LinearLayout.LayoutParams closeParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForKeyboard ? 92 : 118),
                DialogUi.dp(context, compactForKeyboard ? 38 : 48));
        closeParams.rightMargin = DialogUi.dp(context, compactForKeyboard ? 7 : 12);
        actions.addView(close, closeParams);
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(
                DialogUi.dp(context, compactForKeyboard ? 94 : 126),
                DialogUi.dp(context, compactForKeyboard ? 38 : 48));
        saveParams.leftMargin = DialogUi.dp(context, compactForKeyboard ? 7 : 12);
        actions.addView(save, saveParams);

        if (compactForKeyboard) {
            LinearLayout header = new LinearLayout(context);
            header.setOrientation(LinearLayout.HORIZONTAL);
            header.setGravity(Gravity.CENTER_VERTICAL);

            LinearLayout headerText = new LinearLayout(context);
            headerText.setOrientation(LinearLayout.VERTICAL);
            headerText.addView(title, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT));

            TextView summary = new TextView(context);
            summary.setText(balanceText + " | " + routeText);
            summary.setTextColor(Color.rgb(255, 238, 211));
            summary.setTextSize(10.5f);
            summary.setSingleLine(true);
            summary.setEllipsize(TextUtils.TruncateAt.END);
            headerText.addView(summary, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT));

            LinearLayout.LayoutParams headerTextParams = new LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f);
            header.addView(headerText, headerTextParams);

            LinearLayout.LayoutParams routeParams = new LinearLayout.LayoutParams(
                    DialogUi.dp(context, 270),
                    DialogUi.dp(context, 32));
            routeParams.leftMargin = DialogUi.dp(context, 12);
            header.addView(route, routeParams);
            root.addView(header, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT));

            LinearLayout inputRow = new LinearLayout(context);
            inputRow.setOrientation(LinearLayout.HORIZONTAL);
            inputRow.setGravity(Gravity.CENTER_VERTICAL);
            inputRow.setPadding(0, DialogUi.dp(context, 7), 0, 0);
            inputRow.addView(input, new LinearLayout.LayoutParams(
                    0,
                    DialogUi.dp(context, 38),
                    1f));
            LinearLayout.LayoutParams actionsParams = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT);
            actionsParams.leftMargin = DialogUi.dp(context, 10);
            inputRow.addView(actions, actionsParams);
            root.addView(inputRow, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT));
        } else {
            root.addView(title);
            body.setPadding(0, DialogUi.dp(context, 12), 0, DialogUi.dp(context, 10));
            root.addView(body);
            LinearLayout.LayoutParams routeParams = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    DialogUi.dp(context, 44));
            routeParams.bottomMargin = DialogUi.dp(context, 14);
            root.addView(route, routeParams);
            root.addView(input, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    DialogUi.dp(context, 58)));
            root.addView(actions, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT));
        }

        close.setOnClickListener(v -> dialog.dismiss());
        save.setOnClickListener(v -> applyInput(input, dialog));
        input.setOnEditorActionListener((v, actionId, event) -> {
            boolean enter = event != null
                    && event.getAction() == KeyEvent.ACTION_UP
                    && event.getKeyCode() == KeyEvent.KEYCODE_ENTER;
            if (actionId == EditorInfo.IME_ACTION_DONE || enter) {
                return applyInput(input, dialog);
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
            dialogWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
                    | (compactForKeyboard
                    ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
                    : WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE));
            int maxDialogWidth = Math.max(1, view.getWidth() - DialogUi.dp(context, 32));
            int desiredDialogWidth = (int) (compactForKeyboard
                    ? clamp(view.getWidth() * 0.66f, 900f, 1280f)
                    : clamp(view.getWidth() * 0.44f, 760f, 980f));
            if (compactForKeyboard) {
                dialogWindow.setGravity(Gravity.TOP | Gravity.CENTER_HORIZONTAL);
                params = dialogWindow.getAttributes();
                params.y = DialogUi.dp(context, 4);
                dialogWindow.setAttributes(params);
            }
            dialogWindow.setLayout(
                    Math.min(maxDialogWidth, desiredDialogWidth),
                    WindowManager.LayoutParams.WRAP_CONTENT);
        }
        input.requestFocus();
        input.setSelection(input.getText().length());
    }

    private boolean applyInput(EditText input, Dialog dialog) {
        String raw = input.getText().toString().trim();
        int amount;
        try {
            long parsed = Long.parseLong(raw);
            if (parsed <= 0L || parsed > Integer.MAX_VALUE) {
                throw new NumberFormatException("range");
            }
            amount = (int) parsed;
        } catch (NumberFormatException exception) {
            view.showErrorMessage("Jumlah swap tidak valid.");
            return true;
        }
        view.setSwapAmount(clampInt(amount, 1, view.maxSwapCoinAmount()));
        view.saveGameState();
        view.showMessage("Jumlah swap: " + view.selectedSwapInputAmount() + " coin");
        dialog.dismiss();
        view.invalidate();
        return true;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
