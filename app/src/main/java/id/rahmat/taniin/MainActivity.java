package id.rahmat.taniin;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;

public class MainActivity extends Activity {
    private FarmGameView gameView;
    private LoadingScreenView loadingView;
    private boolean resumed;
    private String pendingWalletAddress = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        configureFullscreenWindow();
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        hideSystemUi();
        handleWalletIntent(getIntent());
        loadingView = new LoadingScreenView(this);
        setContentView(loadingView);
        loadingView.start(this::showGameView);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleWalletIntent(intent);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN
                && gameView != null
                && gameView.handleHardwareKey(event.getKeyCode())) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    protected void onResume() {
        super.onResume();
        resumed = true;
        hideSystemUi();
        if (gameView != null) {
            gameView.resumeAudio();
        }
    }

    @Override
    protected void onPause() {
        if (gameView != null) {
            gameView.pauseAudio();
        }
        resumed = false;
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (gameView != null) {
            gameView.releaseAudio();
        }
        super.onDestroy();
    }

    private void showGameView() {
        if (isFinishing() || isDestroyed()) {
            return;
        }
        gameView = new FarmGameView(this);
        loadingView = null;
        setContentView(gameView);
        if (!pendingWalletAddress.isEmpty()) {
            gameView.connectWalletFromDeepLink(pendingWalletAddress);
            pendingWalletAddress = "";
        }
        hideSystemUi();
        if (resumed) {
            gameView.resumeAudio();
        }
    }

    private void handleWalletIntent(Intent intent) {
        if (intent == null || intent.getData() == null) {
            return;
        }
        Uri data = intent.getData();
        if (!"taniin".equals(data.getScheme()) || !"wallet".equals(data.getHost())) {
            return;
        }
        String address = data.getQueryParameter("address");
        if (address == null || address.trim().isEmpty()) {
            return;
        }
        if (gameView != null) {
            gameView.connectWalletFromDeepLink(address.trim());
        } else {
            pendingWalletAddress = address.trim();
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUi();
        }
    }

    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        }
    }

    private void configureFullscreenWindow() {
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(attributes);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false);
        }
    }
}
