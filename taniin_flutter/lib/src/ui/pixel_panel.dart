import 'package:flutter/material.dart';

import 'taniin_theme.dart';

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = TaniinColors.panel,
    this.borderColor = TaniinColors.darkSoil,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class HudChip extends StatelessWidget {
  const HudChip({
    required this.icon,
    required this.label,
    required this.value,
    this.color = TaniinColors.panel,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: TaniinColors.ink),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 14),
              ),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 62,
        child: Material(
          color: isActive ? TaniinColors.wheat : TaniinColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: TaniinColors.darkSoil, width: 4),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Icon(icon, size: 34, color: TaniinColors.ink),
          ),
        ),
      ),
    );
  }
}

class PanelCloseButton extends StatelessWidget {
  const PanelCloseButton({
    required this.onPressed,
    this.dimension = 72,
    this.iconSize = 52,
    super.key,
  });

  final VoidCallback onPressed;
  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: Material(
        color: const Color(0xFF9B4A1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFFFB33D), width: 5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(
            Icons.close,
            size: iconSize,
            color: const Color(0xFFFFF0CE),
          ),
        ),
      ),
    );
  }
}
