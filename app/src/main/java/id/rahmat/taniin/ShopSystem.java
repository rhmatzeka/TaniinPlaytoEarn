package id.rahmat.taniin;

final class ShopSystem {
    private final int bundleAmount;
    private final int[] seedPrices;
    private final String[] seedNames;

    ShopSystem(int bundleAmount, int[] seedPrices, String[] seedNames) {
        this.bundleAmount = bundleAmount;
        this.seedPrices = seedPrices;
        this.seedNames = seedNames;
    }

    int totalPriceForSeed(GameState state, int seedIndex) {
        return seedPrices[seedIndex] * state.shopBundleQuantity;
    }

    int totalSeedAmountForQuantity(int quantity) {
        return bundleAmount * quantity;
    }

    ShopPurchaseResult buySeeds(GameState state, int seedIndex) {
        int price = totalPriceForSeed(state, seedIndex);
        if (state.coins < price) {
            return ShopPurchaseResult.error(
                    "Coin belum cukup untuk beli " + state.shopBundleQuantity + " paket " + seedNames[seedIndex] + ".");
        }
        int totalSeeds = totalSeedAmountForQuantity(state.shopBundleQuantity);
        state.coins -= price;
        state.seedCounts[seedIndex] += totalSeeds;
        state.selectedSeedIndex = seedIndex;
        return ShopPurchaseResult.success(
                "Berhasil membeli " + totalSeeds + " benih " + seedNames[seedIndex] + ".",
                totalSeeds,
                new ChainAction("BUY_SEED", seedIndex + 1, totalSeeds));
    }
}

final class ShopPurchaseResult {
    final boolean success;
    final String message;
    final int seedAmount;
    final ChainAction chainAction;

    private ShopPurchaseResult(boolean success, String message, int seedAmount, ChainAction chainAction) {
        this.success = success;
        this.message = message;
        this.seedAmount = seedAmount;
        this.chainAction = chainAction;
    }

    static ShopPurchaseResult error(String message) {
        return new ShopPurchaseResult(false, message, 0, null);
    }

    static ShopPurchaseResult success(String message, int seedAmount, ChainAction chainAction) {
        return new ShopPurchaseResult(true, message, seedAmount, chainAction);
    }
}
