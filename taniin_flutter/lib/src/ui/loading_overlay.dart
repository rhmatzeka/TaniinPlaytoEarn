import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'kayu.dart';

/// Loading screen: a wood card like the web boot screen, with a row of crops
/// that sprout as the farmer walks across it, a striped bar and a game tip.
class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({required this.loaded, this.onFinished, super.key});

  final ValueListenable<bool> loaded;
  final VoidCallback? onFinished;

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  static const _tips = <String>[
    'Beli benih di toko pakai Game Coin, lalu tanam di lahan kosong.',
    'Tanaman sudah siap? Panen, lalu jual hasilnya untuk dapat koin.',
    'Suruh Pak Tani AI bekerja: "tanam kentang di lahan 1".',
    'Selesaikan misi harian untuk hadiah tambahan.',
    'Masuk dengan wallet untuk menukar koin ke TANI atau Sepolia ETH.',
  ];

  late final AnimationController _controller;
  late final Ticker _ticker;
  late final int _firstTip = math.Random().nextInt(_tips.length);
  Duration _elapsed = Duration.zero;
  bool _visible = true;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _controller.addStatusListener((_) => _completeIfReady());
    _controller.forward();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
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
    _ticker.dispose();
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
    final size = MediaQuery.sizeOf(context);
    final short = size.height < 560;
    final still = MediaQuery.of(context).disableAnimations;
    final elapsed = still ? Duration.zero : _elapsed;
    final tip =
        _tips[(_firstTip + _elapsed.inMilliseconds ~/ 3600) % _tips.length];
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _finishing ? 0 : 1,
        duration: const Duration(milliseconds: 280),
        onEnd: _hide,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.45, 1],
                  colors: [
                    Color(0x40101C14),
                    Color(0x26101C14),
                    Color(0xC0101C14),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingCard(
                      width: math.min(size.width - 32, 660),
                      short: short,
                      progress: progress,
                      elapsed: elapsed,
                    ),
                    SizedBox(height: short ? 12 : 22),
                    _TipStrip(width: math.min(size.width - 32, 660), text: tip),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    // Hold "Siap bertani!" for a beat, then fade into the game.
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (mounted) {
        setState(() => _finishing = true);
      }
    });
  }

  void _hide() {
    if (!_finishing || !mounted) {
      return;
    }
    _ticker.stop();
    setState(() => _visible = false);
    widget.onFinished?.call();
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.width,
    required this.short,
    required this.progress,
    required this.elapsed,
  });

  final double width;
  final bool short;
  final double progress;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final narrow = width < 480;
    final done = progress >= 0.999;
    final label = done
        ? 'Siap bertani!'
        : progress < 0.35
        ? 'Menyiapkan lahan…'
        : progress < 0.7
        ? 'Menanam benih…'
        : 'Memuat kebun…';
    final pad = narrow ? 18.0 : 26.0;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Kayu.kayu,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Kayu.kayuGelap, width: 5),
        boxShadow: const [
          BoxShadow(color: Kayu.kayuGelap, offset: Offset(0, 10)),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Kayu.rim, width: 3),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            pad,
            short ? 14 : pad,
            pad,
            short ? 16 : pad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Kayu.kayuGelap, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/iconaplikasi.png',
                        width: narrow || short ? 52 : 66,
                        height: narrow || short ? 52 : 66,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  SizedBox(width: narrow ? 12 : 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Taniin',
                          style: Kayu.judul(narrow || short ? 40 : 54).copyWith(
                            shadows: const [
                              Shadow(
                                color: Kayu.kayuGelap,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Game bertani on-chain',
                          style: Kayu.teks(
                            narrow ? 15 : 18,
                            color: Kayu.kremRedup,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: short ? 10 : 18),
              _Kebun(progress: progress, elapsed: elapsed, short: short),
              SizedBox(height: short ? 10 : 16),
              _StripedBar(progress: progress, elapsed: elapsed),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Kayu.teks(
                        narrow ? 15 : 17,
                        color: done ? Kayu.daunTerang : Kayu.krem,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: Kayu.judul(narrow ? 20 : 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A strip of tilled soil: each crop sprouts and grows once the walking
/// farmer has passed it, so the field fills up with the loading progress.
class _Kebun extends StatelessWidget {
  const _Kebun({
    required this.progress,
    required this.elapsed,
    required this.short,
  });

  static const _crops = 8;
  // 16 px rows of the crop sheet: stroberi, bawang, kentang, bit.
  static const _cropRows = [0, 1, 2, 3];

  final double progress;
  final Duration elapsed;
  final bool short;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Whole art pixels only: 4x on wide cards, 3x on narrow or short ones.
        final px = width >= 560 && !short ? 4.0 : 3.0;
        final cropSize = 16 * px;
        final farmerSize = 32 * px;
        final soilHeight = cropSize + 8 * px;
        // The farmer's head pokes a little above the soil strip.
        final height = soilHeight + 13 * px;
        final slot = width / _crops;
        final done = progress >= 0.999;
        final walkFrame = (elapsed.inMilliseconds ~/ 110) % 6;
        final idleFrame = (elapsed.inMilliseconds ~/ 240) % 4;
        final farmerX =
            (width - farmerSize * 0.5) * progress - farmerSize * 0.25;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: soilHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B3A1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Kayu.kayuGelap, width: 3),
                  ),
                  child: CustomPaint(painter: _FurrowPainter(px)),
                ),
              ),
              Positioned(
                left: farmerX,
                // Behind the crop row, so every plant stays in view.
                bottom: 9 * px,
                child: done
                    ? _SheetFrame(
                        asset: 'assets/images/idle.png',
                        sheet: const Size(128, 96),
                        frame: Rect.fromLTWH(idleFrame * 32.0, 0, 32, 32),
                        scale: px,
                      )
                    : _SheetFrame(
                        asset: 'assets/images/walk.png',
                        sheet: const Size(192, 96),
                        frame: Rect.fromLTWH(walkFrame * 32.0, 64, 32, 32),
                        scale: px,
                      ),
              ),
              for (var i = 0; i < _crops; i++)
                Positioned(
                  left: slot * i + (slot - cropSize) / 2,
                  bottom: 5 * px,
                  child: _SheetFrame(
                    asset: 'assets/images/spring_crops.png',
                    sheet: const Size(224, 128),
                    frame: Rect.fromLTWH(
                      _stage(i) * 16.0,
                      _cropRows[i % _cropRows.length] * 32.0 + 16,
                      16,
                      16,
                    ),
                    scale: px,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Sheet column 0 (seed) to 5 (ripe) for crop [index].
  int _stage(int index) {
    final grown = (progress * _crops - index).clamp(0.0, 1.0);
    return progress >= 0.999 ? 5 : (grown * 5).round();
  }
}

class _FurrowPainter extends CustomPainter {
  const _FurrowPainter(this.px);

  final double px;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF552C14);
    final light = Paint()..color = const Color(0xFF8A5530);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, px * 2), light);
    for (var y = px * 6; y < size.height - px * 2; y += px * 6) {
      canvas.drawRect(Rect.fromLTWH(px * 3, y, size.width - px * 6, px), dark);
    }
  }

  @override
  bool shouldRepaint(_FurrowPainter oldDelegate) => oldDelegate.px != px;
}

class _StripedBar extends StatelessWidget {
  const _StripedBar({required this.progress, required this.elapsed});

  final double progress;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: Kayu.kayuGelap,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF25140A), width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            heightFactor: 1,
            child: CustomPaint(
              painter: _StripePainter(
                (elapsed.inMilliseconds / 40).floorToDouble() % 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.shift);

  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Kayu.daun);
    final light = Paint()..color = Kayu.daunTerang;
    for (var x = shift - 14; x < size.width; x += 14) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 10, size.height), light);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 4),
      Paint()..color = const Color(0x55FFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 4, size.width, 4),
      Paint()..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.shift != shift;
}

class _TipStrip extends StatelessWidget {
  const _TipStrip({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xD91A0E05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Kayu.kayuTua, width: 3),
      ),
      child: Row(
        children: [
          Text('TIPS', style: Kayu.judul(18)),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                text,
                key: ValueKey(text),
                style: Kayu.teks(16, color: Kayu.krem),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One frame of a sprite sheet asset, drawn crisp at a whole-pixel [scale].
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.asset,
    required this.sheet,
    required this.frame,
    required this.scale,
  });

  final String asset;
  final Size sheet;
  final Rect frame;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: frame.width * scale,
        height: frame.height * scale,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: sheet.width * scale,
            maxHeight: sheet.height * scale,
            child: Transform.translate(
              offset: Offset(-frame.left * scale, -frame.top * scale),
              child: Image.asset(
                asset,
                width: sheet.width * scale,
                height: sheet.height * scale,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
