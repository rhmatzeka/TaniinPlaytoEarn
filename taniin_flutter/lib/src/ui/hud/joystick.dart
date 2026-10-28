part of '../game_hud.dart';

double _joystickRadius(bool compact) => compact ? 72 : 82;

double _mobileWebJoystickRadius(Size viewportSize, double viewportScale) {
  final logicalSize = math
      .min(viewportSize.shortestSide * 0.34, 132.0)
      .clamp(112.0, 132.0)
      .toDouble();
  return logicalSize * viewportScale / 2.2;
}

@visibleForTesting
bool shouldShowTouchJoystickForPlatform({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  Size? viewportSize,
  bool? coarsePointer,
}) {
  if (!isWeb) {
    return true;
  }

  final size = viewportSize;
  if (size == null) {
    return false;
  }
  if (!_isPhoneSizedWebViewport(size)) {
    return false;
  }

  final effectivePlatform = platform ?? defaultTargetPlatform;
  if (effectivePlatform == TargetPlatform.android ||
      effectivePlatform == TargetPlatform.iOS) {
    return true;
  }

  return coarsePointer ?? web_input.hasCoarsePointer();
}

bool _isPhoneSizedWebViewport(Size size) {
  final shortestSide = math.min(size.width, size.height);
  final longestSide = math.max(size.width, size.height);
  return shortestSide <= 520 && longestSide <= 1100;
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.game, required this.radius});

  final TaniinGame game;
  final double radius;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  bool _dragging = false;

  double get _radius => widget.radius;

  double get _knobRadius => _radius * 0.42;

  @override
  Widget build(BuildContext context) {
    final size = _radius * 2.2;
    final center = Offset(size * 0.5, size * 0.5);
    final knobCenter = _dragging ? center + _knob : center;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _update(details.localPosition, center),
      onPanUpdate: (details) => _update(details.localPosition, center),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _JoystickPainter(
            knobCenter: knobCenter,
            center: center,
            radius: _radius,
            knobRadius: _knobRadius,
          ),
        ),
      ),
    );
  }

  void _update(Offset position, Offset center) {
    final raw = position - center;
    final distance = raw.distance;
    final travel = _radius * 0.92;
    final clamped = distance > travel ? raw / distance * travel : raw;
    widget.game.setInputVector(clamped / travel);
    setState(() {
      _dragging = true;
      _knob = clamped;
    });
  }

  void _release() {
    widget.game.setInputVector(Offset.zero);
    setState(() {
      _dragging = false;
      _knob = Offset.zero;
    });
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({
    required this.knobCenter,
    required this.center,
    required this.radius,
    required this.knobRadius,
  });

  final Offset knobCenter;
  final Offset center;
  final double radius;
  final double knobRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    paint.color = const Color(0x66141414);
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0x99FFFFFF);
    canvas.drawCircle(knobCenter, knobRadius, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x55FFFFFF);
    canvas.drawCircle(center, radius - 6, paint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knobCenter != knobCenter;
}
