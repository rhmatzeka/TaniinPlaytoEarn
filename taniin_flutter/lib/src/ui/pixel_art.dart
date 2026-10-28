import 'package:flutter/material.dart';

/// Hand-made 16x16 HUD icons in assets/ui, drawn crisp at any size.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.name, {this.size = 44, super.key});

  /// One of: koin, tas, riwayat, menu, kunci, petani, chat, bintang.
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/ui/ikon_$name.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
        fit: BoxFit.contain,
      ),
    );
  }
}

enum PixelFrameTone { kayu, aktif, gelap }

/// Chunky pixel-style wood frame: dark outline, then a bevel that is light on
/// the top-left and dark on the bottom-right, then the wood fill.
class PixelFrame extends StatelessWidget {
  const PixelFrame({
    required this.child,
    this.tone = PixelFrameTone.kayu,
    this.padding = const EdgeInsets.all(14),
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final PixelFrameTone tone;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  static const _px = 4.0;

  @override
  Widget build(BuildContext context) {
    final (fill, light, dark) = switch (tone) {
      PixelFrameTone.kayu => (
        const Color(0xFFA34A1C),
        const Color(0xFFE07B20),
        const Color(0xFF6E2A0C),
      ),
      PixelFrameTone.aktif => (
        const Color(0xFFC0602A),
        const Color(0xFFFFDE19),
        const Color(0xFF7A2D0E),
      ),
      PixelFrameTone.gelap => (
        const Color(0xFF6E2A0C),
        const Color(0xFFA34A1C),
        const Color(0xFF3E1806),
      ),
    };
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF25140A),
        border: Border.all(color: const Color(0xFF25140A), width: _px),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, _px * 1.5)),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            top: BorderSide(color: light, width: _px),
            left: BorderSide(color: light, width: _px),
            right: BorderSide(color: dark, width: _px),
            bottom: BorderSide(color: dark, width: _px),
          ),
        ),
        child: child,
      ),
    );
  }
}
