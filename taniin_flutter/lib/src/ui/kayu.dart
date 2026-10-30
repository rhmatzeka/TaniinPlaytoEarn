import 'package:flutter/material.dart';

/// Shared in-game UI kit: wood panels with an orange rim, the same look as the
/// HUD and the landing page, so every dialog reads as part of one game.
class Kayu {
  const Kayu._();

  static const kayu = Color(0xFFA34A1C);
  static const kayuTua = Color(0xFF7A2D0E);
  static const kayuGelap = Color(0xFF4A1D08);
  static const rim = Color(0xFFE07B20);
  static const emas = Color(0xFFFFDE19);
  static const krem = Color(0xFFFFF0D4);
  static const kremRedup = Color(0xFFF3C99A);
  static const daun = Color(0xFF2F7D45);
  static const daunTerang = Color(0xFF86E276);
  static const merah = Color(0xFFFF9C8A);

  static TextStyle judul(double size, {Color color = emas}) => TextStyle(
    fontFamily: 'Pixelify',
    fontSize: size,
    height: 1.1,
    color: color,
    fontVariations: const [FontVariation('wght', 700)],
  );

  static TextStyle teks(
    double size, {
    Color color = krem,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(fontSize: size, height: 1.35, color: color, fontWeight: weight);
}

/// A dialog-sized wood panel with a title row and a scrollable body.
class KayuPanel extends StatelessWidget {
  const KayuPanel({
    required this.title,
    required this.child,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.maxWidth = 1040,
    super.key,
  });

  final String title;
  final IconData? icon;

  /// Pixel art shown before the title; takes precedence over [icon].
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 760;
    // Sideways phones: small header and padding so the content gets the
    // little height there is.
    final short = size.height < 600;
    final tight = narrow || short;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (size.width - (narrow ? 24 : 48)).clamp(280, maxWidth),
        maxHeight: (size.height - (short ? 16 : narrow ? 32 : 48)).clamp(
          240,
          900,
        ),
      ),
      child: DecoratedBox(
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
              tight ? 16 : 28,
              short ? 10 : (narrow ? 16 : 22),
              tight ? 16 : 28,
              short ? 12 : (narrow ? 18 : 26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      SizedBox.square(
                        dimension: short ? 30 : (narrow ? 40 : 52),
                        child: FittedBox(fit: BoxFit.scaleDown, child: leading),
                      ),
                      SizedBox(width: tight ? 10 : 14),
                    ] else if (icon != null) ...[
                      Icon(
                        icon,
                        size: short ? 26 : (narrow ? 34 : 42),
                        color: Kayu.emas,
                      ),
                      SizedBox(width: tight ? 10 : 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: Kayu.judul(short ? 24 : (narrow ? 30 : 40)),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: EdgeInsets.only(top: short ? 2 : 4),
                              child: Text(
                                subtitle!,
                                maxLines: short ? 1 : null,
                                overflow: short ? TextOverflow.ellipsis : null,
                                style: Kayu.teks(
                                  short ? 14 : (narrow ? 16 : 18),
                                  color: Kayu.kremRedup,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                    if (onClose != null) ...[
                      const SizedBox(width: 12),
                      KayuCloseButton(onPressed: onClose!, compact: short),
                    ],
                  ],
                ),
                SizedBox(height: short ? 8 : (narrow ? 14 : 20)),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KayuCloseButton extends StatelessWidget {
  const KayuCloseButton({
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tutup',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: compact ? 40 : 56,
          height: compact ? 40 : 56,
          decoration: BoxDecoration(
            color: Kayu.kayuTua,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Kayu.emas, width: 3),
          ),
          child: Icon(Icons.close, color: Kayu.krem, size: compact ? 24 : 32),
        ),
      ),
    );
  }
}

enum KayuTone { utama, kedua, bahaya }

/// Game button. Passing `onPressed: null` shows it disabled; the label should
/// then say why ("Koin kurang"), not just grey out.
class KayuButton extends StatelessWidget {
  const KayuButton({
    required this.label,
    required this.onPressed,
    this.tone = KayuTone.utama,
    this.icon,
    this.compact = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final KayuTone tone;
  final IconData? icon;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (fill, border, text) = !enabled
        ? (const Color(0xFF6B5442), const Color(0xFF8B6A53), const Color(0xFFE2D2BE))
        : switch (tone) {
            KayuTone.utama => (Kayu.daun, Kayu.daunTerang, Kayu.krem),
            KayuTone.kedua => (Kayu.krem, Kayu.kayuTua, Kayu.kayuTua),
            KayuTone.bahaya => (const Color(0xFF8B2F23), Kayu.merah, Kayu.krem),
          };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: text, size: compact ? 20 : 24),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Kayu.judul(compact ? 19 : 23, color: text),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(
              minHeight: compact ? 50 : 60,
              minWidth: compact ? 110 : 140,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 3),
              boxShadow: enabled
                  ? const [
                      BoxShadow(color: Kayu.kayuGelap, offset: Offset(0, 5)),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A recessed wood well for grouping content inside a panel.
class KayuWell extends StatelessWidget {
  const KayuWell({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF8E3F17) : Kayu.kayuTua,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? Kayu.emas : Kayu.kayuGelap,
          width: highlighted ? 4 : 3,
        ),
      ),
      child: child,
    );
  }
}

/// Coin amount with the same coin mark as the HUD.
class CoinAmount extends StatelessWidget {
  const CoinAmount({required this.amount, this.size = 22, this.color = Kayu.emas, super.key});

  final int amount;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.05,
          height: size * 1.05,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFC928),
            border: Border.all(color: const Color(0xFF8A5A00), width: size * 0.12),
          ),
        ),
        SizedBox(width: size * 0.35),
        Text('$amount', style: Kayu.judul(size, color: color)),
      ],
    );
  }
}

enum CropFrame { benih, panen }

/// One crop from the game's spring_crops sheet, drawn crisp. The sheet uses
/// 16x32 cells; seed packets and harvests sit in the lower 16x16 of a cell.
/// [cropRow] is the 32px row: 0 stroberi, 1 bawang, 2 kentang, 3 bit.
class CropSprite extends StatelessWidget {
  const CropSprite({
    required this.cropRow,
    this.frame = CropFrame.benih,
    this.height = 64,
    super.key,
  });

  static const _sheetWidth = 224.0;
  static const _sheetHeight = 128.0;
  static const _cellWidth = 16.0;
  static const _cellHeight = 32.0;
  static const _frameSize = 16.0;
  static const _frameTop = 16.0;

  final int cropRow;
  final CropFrame frame;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scale = height / _frameSize;
    final column = frame == CropFrame.benih ? 7 : 8;
    return ExcludeSemantics(
      child: SizedBox(
        width: _frameSize * scale,
        height: height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: _sheetWidth * scale,
            maxHeight: _sheetHeight * scale,
            child: Transform.translate(
              offset: Offset(
                -column * _cellWidth * scale,
                -(cropRow * _cellHeight + _frameTop) * scale,
              ),
              child: Image.asset(
                'assets/images/spring_crops.png',
                width: _sheetWidth * scale,
                height: _sheetHeight * scale,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
