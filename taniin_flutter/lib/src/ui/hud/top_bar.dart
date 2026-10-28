part of '../game_hud.dart';

class _TopCluster extends StatelessWidget {
  const _TopCluster({
    required this.farmState,
    required this.compact,
    required this.menuActive,
    required this.onMenuPressed,
    required this.onWalletPressed,
  });

  final FarmStateController farmState;
  final bool compact;
  final bool menuActive;
  final VoidCallback onMenuPressed;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context) {
    final barWidth = compact ? 198.0 : 218.0;
    final walletWidth = compact ? 220.0 : 390.0;
    final walletHeight = compact ? 64.0 : 94.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CurrencyBar(farmState: farmState, width: barWidth),
            const SizedBox(width: 12),
            _HudIconButton(
              icon: Icons.menu,
              tooltip: 'Menu',
              isActive: menuActive,
              onPressed: onMenuPressed,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WalletButton(
          farmState: farmState,
          width: walletWidth,
          height: walletHeight,
          compact: compact,
          onPressed: onWalletPressed,
        ),
      ],
    );
  }
}

class _CurrencyBar extends StatelessWidget {
  const _CurrencyBar({required this.farmState, required this.width});

  final FarmStateController farmState;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _HudFrame(
      width: width,
      height: 76,
      color: const Color(0xFF704110),
      border: const Color(0xFF56300C),
      child: Row(
        children: [
          _CoinIcon(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: _AmountBlock(label: 'COIN', value: '${farmState.coins}'),
          ),
        ],
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFF0DEB3),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFF0DEB3),
            fontSize: 26,
            height: 0.92,
          ),
        ),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.farmState,
    required this.width,
    required this.height,
    required this.compact,
    required this.onPressed,
  });

  final FarmStateController farmState;
  final double width;
  final double height;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final connected = farmState.walletConnected;
    return Tooltip(
      message: connected ? 'Akun Privy' : 'Masuk dengan Privy',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: _HudFrame(
          width: width,
          height: height,
          color: connected ? const Color(0xFF246644) : const Color(0xFF2A573E),
          border: connected ? const Color(0xFF69C487) : const Color(0xFF5B8F68),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 18,
            vertical: compact ? 6 : 12,
          ),
          child: Row(
            children: [
              _WalletIcon(connected: connected),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmState.walletLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFECF8E2),
                        fontSize: compact ? 16 : (connected ? 22 : 23),
                        height: 1.0,
                      ),
                    ),
                    Text(
                      connected && farmState.walletNativeBalance.isNotEmpty
                          ? '${farmState.walletNativeBalance} ETH - tap untuk sync'
                          : connected
                          ? 'tap untuk akun & sync'
                          : 'main sebagai tamu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: connected
                            ? const Color(0xFFB1EEB9)
                            : const Color(0xFFD9EBCB),
                        fontSize: compact ? 10 : 14,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _HudFrame(
              width: 76,
              height: 76,
              color: isActive
                  ? const Color(0xFF8D5218)
                  : const Color(0xFF7A4818),
              border: const Color(0xFF5B3510),
              padding: EdgeInsets.zero,
              child: Icon(icon, size: 42, color: const Color(0xFFF5E7CB)),
            ),
            if (badge != null)
              Positioned(
                right: -8,
                top: -8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDB5F),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2C1F0F),
                      width: 3,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Center(
                      child: Text(
                        badge!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF2C1F0F),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HudFrame extends StatelessWidget {
  const _HudFrame({
    required this.child,
    required this.width,
    required this.height,
    required this.color,
    required this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  final Widget child;
  final double width;
  final double height;
  final Color color;
  final Color border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x5A000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 5),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 4),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _CoinIcon extends StatelessWidget {
  const _CoinIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _WalletIcon extends StatelessWidget {
  const _WalletIcon({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 60,
      child: CustomPaint(painter: _WalletPainter(connected)),
    );
  }
}

class _SeedPacket extends StatelessWidget {
  const _SeedPacket({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SeedPacketPainter(color)),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final center = size.center(Offset.zero);
    paint.color = const Color(0xFFF8F2D7);
    canvas.drawCircle(center, size.width * 0.50, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..color = const Color(0xFF362A12);
    canvas.drawCircle(center, size.width * 0.40, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFEEC530);
    canvas.drawCircle(center, size.width * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletPainter extends CustomPainter {
  const _WalletPainter(this.connected);

  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final center = size.center(Offset.zero);
    paint.color = connected ? const Color(0xFF70E084) : const Color(0xFFF4D057);
    canvas.drawCircle(center, size.width * 0.45, paint);
    paint.color = const Color(0xFF212F20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.62,
          height: size.height * 0.44,
        ),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.color = const Color(0xFFF0F6E4);
    canvas.drawRect(
      Rect.fromCenter(
        center: center.translate(0, -2),
        width: size.width * 0.42,
        height: 4,
      ),
      paint,
    );
    paint.color = connected ? const Color(0xFF45AA53) : const Color(0xFFC18A24);
    canvas.drawCircle(
      center.translate(size.width * 0.30, -size.height * 0.30),
      size.width * 0.11,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WalletPainter oldDelegate) =>
      oldDelegate.connected != connected;
}

class _SeedPacketPainter extends CustomPainter {
  const _SeedPacketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final scale = size.width / 44;
    final center = size.center(Offset.zero);
    paint.color = const Color(0xFFFFF6D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 32 * scale, height: 38 * scale),
        Radius.circular(4 * scale),
      ),
      paint,
    );
    paint.color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 12 * scale,
        center.dy - 12 * scale,
        24 * scale,
        19 * scale,
      ),
      paint,
    );
    paint.color = const Color(0xFF472C1F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - 8 * scale,
          center.dy + 3 * scale,
          16 * scale,
          11 * scale,
        ),
        Radius.circular(3 * scale),
      ),
      paint,
    );
    paint.color = const Color(0xFF60D25C);
    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - 10 * scale,
        center.dy - 4 * scale,
        12 * scale,
        9 * scale,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(center.dx, center.dy - 7 * scale, 11 * scale, 10 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeedPacketPainter oldDelegate) =>
      oldDelegate.color != color;
}
