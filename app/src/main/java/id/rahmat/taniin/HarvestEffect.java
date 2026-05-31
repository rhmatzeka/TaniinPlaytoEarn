package id.rahmat.taniin;

final class HarvestEffect {
    final float centerX;
    final float centerY;
    final int seedIndex;
    final int amount;
    final long startedAtMs;
    final float phase;

    HarvestEffect(float centerX, float centerY, int seedIndex, int amount, long startedAtMs) {
        this.centerX = centerX;
        this.centerY = centerY;
        this.seedIndex = seedIndex;
        this.amount = amount;
        this.startedAtMs = startedAtMs;
        this.phase = (centerX * 0.017f + centerY * 0.011f) % 6.28f;
    }
}
