import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Lays HUD and panels out on a fixed design canvas and scales it to the
/// screen, so sizes follow the screen's logical size rather than its pixel
/// density. Landscape screens get at least 1280 design pixels of width
/// (desktops at 1280+ render 1:1); portrait phones get a 600-wide canvas.
class PhysicalViewport extends StatelessWidget {
  const PhysicalViewport({
    required this.child,
    this.alignment = Alignment.topLeft,
    super.key,
  });

  static const double landscapeMinWidth = 1280;
  static const double portraitWidth = 600;

  final Widget child;
  final Alignment alignment;

  /// True for tall screens; use with the canvas size inside the viewport.
  static bool isPortrait(Size size) => size.height > size.width * 1.1;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = Size(constraints.maxWidth, constraints.maxHeight);
        if (logical.isEmpty || !logical.isFinite) {
          return const SizedBox.shrink();
        }
        final canvasWidth = isPortrait(logical)
            ? portraitWidth
            : math.max(logical.width, landscapeMinWidth);
        final scale = logical.width / canvasWidth;
        final canvas = Size(canvasWidth, logical.height / scale);
        return FittedBox(
          fit: BoxFit.fill,
          alignment: alignment,
          child: SizedBox(
            width: canvas.width,
            height: canvas.height,
            child: MediaQuery(
              data: media.copyWith(size: canvas, devicePixelRatio: 1),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
