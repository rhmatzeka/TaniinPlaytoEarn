import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({required this.loaded, this.onFinished, super.key});

  final ValueListenable<bool> loaded;
  final VoidCallback? onFinished;

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = true;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2800),
          )
          ..addListener(() => setState(() {}))
          ..addStatusListener((_) => _completeIfReady())
          ..forward();
    widget.loaded.addListener(_completeIfReady);
  }

  @override
  void didUpdateWidget(covariant LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loaded != widget.loaded) {
      oldWidget.loaded.removeListener(_completeIfReady);
      widget.loaded.addListener(_completeIfReady);
    }
  }

  @override
  void dispose() {
    widget.loaded.removeListener(_completeIfReady);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    final progress = widget.loaded.value
        ? _controller.value
        : math.min(_controller.value, 0.92);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF275D35)),
          Image.asset(
            'assets/images/loadingscreen.jpg',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x54101C14)),
          ),
          CustomPaint(painter: _LoadingPainter(progress)),
        ],
      ),
    );
  }

  void _completeIfReady() {
    if (_finishing || !mounted || !widget.loaded.value) {
      return;
    }
    if (!_controller.isCompleted) {
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _finishing = true;
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() => _visible = false);
        widget.onFinished?.call();
      }
    });
  }
}

class _LoadingPainter extends CustomPainter {
  const _LoadingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(0.68, math.min(1.15, size.height / 390));
    final centerX = size.width * 0.5;
    final titleY = math.max(58 * scale, size.height * 0.18);
    _drawPixelText(
      canvas,
      'Taniin',
      Offset(centerX, titleY),
      72 * scale,
      const Color(0xFFFFDE52),
      const Color(0xFF1E4724),
      5 * scale,
    );
    _drawPixelText(
      canvas,
      'GAME ONCHAIN BERTANI',
      Offset(centerX, titleY + 38 * scale),
      20 * scale,
      const Color(0xFFFAF7D0),
      const Color(0xFF173723),
      3 * scale,
    );
    _drawPixelLeaf(canvas, centerX - 172 * scale, titleY + 8 * scale, scale);
    _drawPixelLeaf(
      canvas,
      centerX + 172 * scale,
      titleY + 8 * scale,
      scale,
      flipped: true,
    );
    _drawLoadingPanel(canvas, size, scale);
  }

  void _drawLoadingPanel(Canvas canvas, Size size, double scale) {
    final paint = Paint()..isAntiAlias = false;
    final panelWidth = math.min(size.width - 48 * scale, 650 * scale);
    final panelHeight = 108 * scale;
    final left = (size.width - panelWidth) * 0.5;
    final bottom = size.height - math.max(28 * scale, size.height * 0.10);
    final panel = Rect.fromLTWH(
      left,
      bottom - panelHeight,
      panelWidth,
      panelHeight,
    );

    paint.color = const Color(0x96000000);
    canvas.drawRect(panel.shift(Offset(6 * scale, 7 * scale)), paint);
    paint.color = const Color(0xFF18301F);
    canvas.drawRect(panel, paint);
    paint.color = const Color(0xFFFFDB57);
    canvas.drawRect(
      Rect.fromLTWH(panel.left, panel.top, panel.width, 5 * scale),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        panel.left,
        panel.bottom - 5 * scale,
        panel.width,
        5 * scale,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(panel.left, panel.top, 5 * scale, panel.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        panel.right - 5 * scale,
        panel.top,
        5 * scale,
        panel.height,
      ),
      paint,
    );
    paint.color = const Color(0xFF366D3A);
    canvas.drawRect(panel.deflate(10 * scale), paint);

    final percent = math.max(1, math.min(100, (progress * 100).round()));
    _drawText(
      canvas,
      'LOADING FARM',
      Offset(panel.left + 24 * scale, panel.top + 34 * scale),
      19 * scale,
    );
    _drawText(
      canvas,
      '$percent%',
      Offset(panel.right - 24 * scale, panel.top + 35 * scale),
      22 * scale,
      align: TextAlign.right,
    );

    final bar = Rect.fromLTWH(
      panel.left + 24 * scale,
      panel.top + 55 * scale,
      panel.width - 48 * scale,
      25 * scale,
    );
    paint.color = const Color(0xFF0F2014);
    canvas.drawRect(bar, paint);
    paint.color = const Color(0xFF734120);
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width, 4 * scale),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.bottom - 4 * scale, bar.width, 4 * scale),
      paint,
    );

    final fillRight = bar.left + bar.width * progress.clamp(0, 1);
    paint.color = const Color(0xFFFFCE35);
    canvas.drawRect(
      Rect.fromLTRB(
        bar.left + 4 * scale,
        bar.top + 4 * scale,
        math.max(bar.left + 4 * scale, fillRight - 4 * scale),
        bar.bottom - 4 * scale,
      ),
      paint,
    );
    paint.color = const Color(0xFFFFF288);
    canvas.drawRect(
      Rect.fromLTRB(
        bar.left + 7 * scale,
        bar.top + 7 * scale,
        math.max(bar.left + 7 * scale, fillRight - 9 * scale),
        bar.top + 11 * scale,
      ),
      paint,
    );
    _drawProgressSpark(canvas, fillRight, bar.center.dy, scale);
  }

  void _drawPixelText(
    Canvas canvas,
    String text,
    Offset baseline,
    double size,
    Color fill,
    Color outline,
    double outlineWidth,
  ) {
    final step = math.max(2.0, outlineWidth.roundToDouble());
    for (final offset in <Offset>[
      Offset(-step, 0),
      Offset(step, 0),
      Offset(0, -step),
      Offset(0, step),
      Offset(-step, -step),
      Offset(step, step),
    ]) {
      _drawText(
        canvas,
        text,
        baseline + offset,
        size,
        color: outline,
        align: TextAlign.center,
      );
    }
    _drawText(
      canvas,
      text,
      baseline + Offset(step * 2, step * 2),
      size,
      color: const Color(0x6E000000),
      align: TextAlign.center,
    );
    _drawText(
      canvas,
      text,
      baseline,
      size,
      color: fill,
      align: TextAlign.center,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset baseline,
    double size, {
    Color color = const Color(0xFFF5F5D5),
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => baseline.dx - painter.width * 0.5,
      TextAlign.right => baseline.dx - painter.width,
      _ => baseline.dx,
    };
    painter.paint(canvas, Offset(dx, baseline.dy - painter.height));
  }

  void _drawPixelLeaf(
    Canvas canvas,
    double cx,
    double cy,
    double scale, {
    bool flipped = false,
  }) {
    final paint = Paint()..isAntiAlias = false;
    final dir = flipped ? -1.0 : 1.0;
    final unit = 7 * scale;
    void rect(
      double left,
      double top,
      double right,
      double bottom,
      Color color,
    ) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTRB(
          math.min(left, right),
          math.min(top, bottom),
          math.max(left, right),
          math.max(top, bottom),
        ),
        paint,
      );
    }

    rect(cx, cy, cx + dir * unit, cy + unit * 5, const Color(0xFF216035));
    rect(
      cx + dir * unit,
      cy,
      cx + dir * unit * 4,
      cy + unit,
      const Color(0xFF74BB48),
    );
    rect(
      cx + dir * unit * 2,
      cy - unit,
      cx + dir * unit * 5,
      cy,
      const Color(0xFF74BB48),
    );
    rect(
      cx - dir * unit * 2,
      cy + unit,
      cx + dir * unit,
      cy + unit * 2,
      const Color(0xFFFFD741),
    );
    rect(
      cx - dir * unit * 3,
      cy + unit * 2,
      cx,
      cy + unit * 3,
      const Color(0xFFFFD741),
    );
  }

  void _drawProgressSpark(Canvas canvas, double x, double y, double scale) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFFFFAB6);
    final unit = 5 * scale;
    canvas.drawRect(
      Rect.fromLTRB(x - unit, y - unit, x + unit, y + unit),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        x - unit * 3,
        y - unit * 0.5,
        x - unit * 1.5,
        y + unit * 0.5,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        x + unit * 1.5,
        y - unit * 0.5,
        x + unit * 3,
        y + unit * 0.5,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        x - unit * 0.5,
        y - unit * 3,
        x + unit * 0.5,
        y - unit * 1.5,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        x - unit * 0.5,
        y + unit * 1.5,
        x + unit * 0.5,
        y + unit * 3,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
