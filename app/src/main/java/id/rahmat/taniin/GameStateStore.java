package id.rahmat.taniin;

import android.content.SharedPreferences;

final class GameStateStore {
    private static final int LAND_STATE_VERSION = 2;

    private final SharedPreferences preferences;
    private final int seedTypeCount;
    private final int maxShopBundleQuantity;
    private final long growTimeMs;

    GameStateStore(SharedPreferences preferences, int seedTypeCount, int maxShopBundleQuantity, long growTimeMs) {
        this.preferences = preferences;
        this.seedTypeCount = seedTypeCount;
        this.maxShopBundleQuantity = maxShopBundleQuantity;
        this.growTimeMs = growTimeMs;
    }

    void load(GameState state) {
        state.coins = preferences.getInt("game_coins", state.coins);
        state.harvests = preferences.getInt("game_harvests", state.harvests);
        state.selectedSeedIndex = clampInt(preferences.getInt("game_selected_seed", state.selectedSeedIndex), 0, seedTypeCount - 1);
        state.shopBundleQuantity = clampInt(preferences.getInt("game_shop_quantity", state.shopBundleQuantity), 1, maxShopBundleQuantity);
        state.swapTarget = clampInt(preferences.getInt("game_swap_target", state.swapTarget), 0, 1);
        boolean repairFreeLandState = preferences.getInt("game_land_state_version", 0) < LAND_STATE_VERSION;

        for (int i = 0; i < state.seedCounts.length; i++) {
            state.seedCounts[i] = Math.max(0, preferences.getInt("game_seed_" + i, state.seedCounts[i]));
        }

        long now = System.currentTimeMillis();
        for (int i = 0; i < state.plots.size(); i++) {
            Plot plot = state.plots.get(i);
            if (repairFreeLandState) {
                plot.owned = i == 0;
                plot.seedIndex = 0;
                plot.state = PlotState.EMPTY;
                plot.plantedAtMs = 0L;
            } else {
                plot.owned = preferences.getBoolean("game_plot_" + i + "_owned", plot.owned);
                plot.seedIndex = clampInt(preferences.getInt("game_plot_" + i + "_seed", plot.seedIndex), 0, seedTypeCount - 1);
                plot.state = GameState.plotStateFromOrdinal(preferences.getInt("game_plot_" + i + "_state", plot.state.ordinal()));
                plot.plantedAtMs = preferences.getLong("game_plot_" + i + "_planted_at", plot.plantedAtMs);
            }
            if (plot.state == PlotState.GROWING && now - plot.plantedAtMs >= growTimeMs) {
                plot.state = PlotState.READY;
            }
        }
        state.ownedLand = state.calculateOwnedLand();
        if (repairFreeLandState) {
            save(state);
        }
    }

    void save(GameState state) {
        SharedPreferences.Editor editor = preferences.edit()
                .putInt("game_coins", state.coins)
                .putInt("game_harvests", state.harvests)
                .putInt("game_owned_land", state.ownedLand)
                .putInt("game_land_state_version", LAND_STATE_VERSION)
                .putInt("game_selected_seed", state.selectedSeedIndex)
                .putInt("game_shop_quantity", state.shopBundleQuantity)
                .putInt("game_swap_target", state.swapTarget);
        for (int i = 0; i < state.seedCounts.length; i++) {
            editor.putInt("game_seed_" + i, state.seedCounts[i]);
        }
        for (int i = 0; i < state.plots.size(); i++) {
            Plot plot = state.plots.get(i);
            editor.putBoolean("game_plot_" + i + "_owned", plot.owned)
                    .putInt("game_plot_" + i + "_seed", plot.seedIndex)
                    .putInt("game_plot_" + i + "_state", plot.state.ordinal())
                    .putLong("game_plot_" + i + "_planted_at", plot.plantedAtMs);
        }
        editor.apply();
    }

    private static int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
