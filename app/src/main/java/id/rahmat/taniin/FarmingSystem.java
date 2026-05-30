package id.rahmat.taniin;

final class FarmingSystem {
    private final int landBuyPrice;
    private final int landSellPrice;
    private final long growTimeMs;
    private final int[] harvestYields;
    private final String[] seedNames;

    FarmingSystem(int landBuyPrice, int landSellPrice, long growTimeMs, int[] harvestYields, String[] seedNames) {
        this.landBuyPrice = landBuyPrice;
        this.landSellPrice = landSellPrice;
        this.growTimeMs = growTimeMs;
        this.harvestYields = harvestYields;
        this.seedNames = seedNames;
    }

    InteractionKind interactionKind(Plot plot, long now) {
        if (!plot.owned) {
            return InteractionKind.BUY_LAND;
        }
        if (plot.state == PlotState.EMPTY) {
            return InteractionKind.PLANT;
        }
        if (plot.state == PlotState.GROWING) {
            if (now - plot.plantedAtMs >= growTimeMs) {
                return InteractionKind.HARVEST;
            }
            return InteractionKind.WAIT_CROP;
        }
        return InteractionKind.HARVEST;
    }

    FarmingResult performPlotAction(GameState state, int plotIndex, long now) {
        Plot plot = plotAt(state, plotIndex);
        if (plot == null) {
            return FarmingResult.error("Dekati lahan dulu.");
        }
        if (!plot.owned) {
            return buyLand(state, plotIndex, plot);
        }
        if (plot.state == PlotState.EMPTY) {
            return plant(state, plotIndex, plot, now);
        }
        if (plot.state == PlotState.GROWING) {
            return FarmingResult.error("Tanaman belum siap panen.");
        }
        return harvest(state, plotIndex, plot, now);
    }

    FarmingResult sellLand(GameState state, int plotIndex) {
        Plot plot = plotAt(state, plotIndex);
        if (plot == null) {
            return FarmingResult.error("Dekati lahan dulu.");
        }
        if (!plot.owned) {
            return FarmingResult.error("Lahan ini belum dimiliki.");
        }
        if (plot.state != PlotState.EMPTY) {
            return FarmingResult.error("Kosongkan lahan sebelum dijual.");
        }
        if (state.actualOwnedLandCount() <= 1) {
            return FarmingResult.error("Minimal satu lahan harus tetap dimiliki.");
        }

        plot.owned = false;
        plot.seedIndex = 0;
        plot.plantedAtMs = 0L;
        state.ownedLand = state.calculateOwnedLand();
        state.coins += landSellPrice;
        return FarmingResult.success(
                "Lahan terjual. Coin +" + landSellPrice + ".",
                new ChainAction("SELL_LAND", plotIndex + 1, landSellPrice));
    }

    boolean canSellLand(GameState state, int plotIndex) {
        Plot plot = plotAt(state, plotIndex);
        return plot != null
                && plot.owned
                && plot.state == PlotState.EMPTY
                && state.actualOwnedLandCount() > 1;
    }

    private FarmingResult buyLand(GameState state, int plotIndex, Plot plot) {
        if (state.coins < landBuyPrice) {
            return FarmingResult.error("Coin belum cukup untuk beli tanah.");
        }
        state.coins -= landBuyPrice;
        plot.owned = true;
        state.ownedLand = state.calculateOwnedLand();
        return FarmingResult.success(
                "Tanah berhasil dibeli.",
                new ChainAction("BUY_LAND", plotIndex + 1, 1));
    }

    private FarmingResult plant(GameState state, int plotIndex, Plot plot, long now) {
        int seedIndex = state.selectedSeedIndex;
        if (state.seedCounts[seedIndex] <= 0) {
            return FarmingResult.error("Benih " + seedNames[seedIndex] + " habis. Pilih benih lain di toko.");
        }
        state.seedCounts[seedIndex]--;
        plot.seedIndex = seedIndex;
        plot.state = PlotState.GROWING;
        plot.plantedAtMs = now;
        return FarmingResult.success(
                "Benih " + seedNames[seedIndex] + " berhasil ditanam.",
                new ChainAction("PLANT", plotIndex + 1, seedIndex + 1));
    }

    private FarmingResult harvest(GameState state, int plotIndex, Plot plot, long now) {
        int seedIndex = plot.seedIndex;
        int harvestAmount = harvestYields[seedIndex];
        plot.state = PlotState.EMPTY;
        state.harvests += harvestAmount;
        return FarmingResult.harvest(
                "Panen " + seedNames[seedIndex] + " +" + harvestAmount + " masuk inventory.",
                new ChainAction("HARVEST", plotIndex + 1, harvestAmount),
                plot,
                seedIndex,
                harvestAmount,
                now);
    }

    private static Plot plotAt(GameState state, int plotIndex) {
        if (plotIndex < 0 || plotIndex >= state.plots.size()) {
            return null;
        }
        return state.plots.get(plotIndex);
    }
}

final class FarmingResult {
    final boolean success;
    final String message;
    final ChainAction chainAction;
    final boolean harvestEffect;
    final Plot harvestPlot;
    final int harvestSeedIndex;
    final int harvestAmount;
    final long harvestAtMs;

    private FarmingResult(boolean success, String message, ChainAction chainAction,
            boolean harvestEffect, Plot harvestPlot, int harvestSeedIndex, int harvestAmount, long harvestAtMs) {
        this.success = success;
        this.message = message;
        this.chainAction = chainAction;
        this.harvestEffect = harvestEffect;
        this.harvestPlot = harvestPlot;
        this.harvestSeedIndex = harvestSeedIndex;
        this.harvestAmount = harvestAmount;
        this.harvestAtMs = harvestAtMs;
    }

    static FarmingResult error(String message) {
        return new FarmingResult(false, message, null, false, null, 0, 0, 0L);
    }

    static FarmingResult success(String message, ChainAction chainAction) {
        return new FarmingResult(true, message, chainAction, false, null, 0, 0, 0L);
    }

    static FarmingResult harvest(String message, ChainAction chainAction, Plot plot,
            int seedIndex, int amount, long now) {
        return new FarmingResult(true, message, chainAction, true, plot, seedIndex, amount, now);
    }
}
