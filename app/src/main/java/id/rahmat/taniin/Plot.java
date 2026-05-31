package id.rahmat.taniin;

final class Plot {
    final float x;
    final float y;
    final float w;
    final float h;
    boolean owned;
    int seedIndex;
    PlotState state = PlotState.EMPTY;
    long plantedAtMs;

    Plot(float x, float y, float w, float h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }
}
