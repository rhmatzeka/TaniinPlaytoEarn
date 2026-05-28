package id.rahmat.taniin;

final class ChainAction {
    final String type;
    final int plotId;
    final int amount;
    final long createdAtMs;

    ChainAction(String type, int plotId, int amount) {
        this.type = type;
        this.plotId = plotId;
        this.amount = amount;
        this.createdAtMs = System.currentTimeMillis();
    }

    String label() {
        if ("BUY_LAND".equals(type)) {
            return "Mint lahan #" + plotId;
        }
        if ("SELL_LAND".equals(type)) {
            return "Jual lahan #" + plotId;
        }
        if ("PLANT".equals(type)) {
            return "Tanam lahan #" + plotId;
        }
        if ("HARVEST".equals(type)) {
            return "Claim panen " + amount;
        }
        if ("SELL_CROP".equals(type)) {
            return "Swap panen " + amount;
        }
        if ("BUY_SEED".equals(type)) {
            return "Beli bibit " + amount;
        }
        return type;
    }
}
