package id.rahmat.taniin;

import java.util.ArrayList;
import java.util.List;

final class GameState {
    final List<Plot> plots = new ArrayList<>();
    final int[] seedCounts = {6, 0, 0, 0};

    int coins = 500;
    int selectedSeedIndex;
    int shopBundleQuantity = 1;
    int swapTarget;
    int harvests;
    int ownedLand = 1;

    int calculateOwnedLand() {
        return Math.max(1, actualOwnedLandCount());
    }

    int actualOwnedLandCount() {
        int total = 0;
        for (Plot plot : plots) {
            if (plot.owned) {
                total++;
            }
        }
        return total;
    }

    int totalSeeds() {
        int total = 0;
        for (int count : seedCounts) {
            total += count;
        }
        return total;
    }

    static PlotState plotStateFromOrdinal(int ordinal) {
        PlotState[] states = PlotState.values();
        if (ordinal < 0 || ordinal >= states.length) {
            return PlotState.EMPTY;
        }
        return states[ordinal];
    }
}
