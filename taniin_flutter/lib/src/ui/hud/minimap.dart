part of '../game_hud.dart';

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.game,
    required this.width,
    required this.height,
  });

  final TaniinGame game;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mapWidth = width.clamp(236.0, 286.0).toDouble();
    final mapHeight = height.clamp(194.0, 264.0).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x62000000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 5),
          child: SizedBox(
            width: mapWidth,
            height: mapHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF5A3F1F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2D2110), width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF77B858),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFFB18845),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        isComplex: true,
                        willChange: false,
                        painter: _MiniMapPainter(game),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.game) : super(repaint: game.miniMapNotifier);

  final TaniinGame game;

  @override
  void paint(Canvas canvas, Size size) {
    game.drawMiniMapPreview(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.game != game;
}
