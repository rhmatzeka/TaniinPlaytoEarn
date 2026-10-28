import 'package:flutter/material.dart';

import '../../state/farm_state.dart';

/// Small row of service indicators. Each state has an icon shape as well as a
/// color, so it reads without relying on color alone.
class StatusStrip extends StatefulWidget {
  const StatusStrip({
    required this.farmState,
    required this.multiplayerOnline,
    required this.aiOnline,
    super.key,
  });

  final FarmStateController farmState;
  final bool multiplayerOnline;
  final bool aiOnline;

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

/// One quiet summary chip; tapping it lists every service.
class _StatusStripState extends State<StatusStrip> {
  bool _open = false;

  List<_StatusItem> get _items {
    final farmState = widget.farmState;
    return <_StatusItem>[
      _StatusItem('Akun', farmState.isLoggedIn ? _Level.ok : _Level.idle,
          farmState.isLoggedIn ? 'masuk' : 'tamu'),
      _StatusItem('Sepolia', _fromService(farmState.sepoliaState),
          _serviceWord(farmState.sepoliaState)),
      _StatusItem('Server', _fromService(farmState.serverState),
          _serviceWord(farmState.serverState)),
      _StatusItem('Multiplayer', widget.multiplayerOnline ? _Level.ok : _Level.down,
          widget.multiplayerOnline ? 'online' : 'offline'),
      _StatusItem('AI', widget.aiOnline ? _Level.ok : _Level.down,
          widget.aiOnline ? 'online' : 'offline'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final down = items.where((item) => item.level == _Level.down).length;
    final summary = down == 0 ? 'Semua online' : '$down offline';
    final chip = Semantics(
      button: true,
      label: [for (final item in items) '${item.label}: ${item.word}'].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC25140A),
            border: Border.all(color: const Color(0xFF6E2A0C), width: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items) ...[
                Container(width: 10, height: 10, color: _color(item.level)),
                const SizedBox(width: 3),
              ],
              const SizedBox(width: 6),
              Text(
                summary,
                style: const TextStyle(
                  color: Color(0xFFF4F1E0),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFFF4F1E0)),
            ],
          ),
        ),
      ),
    );
    if (!_open) return chip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [for (final item in items) _StatusChip(item: item)],
        ),
      ],
    );
  }

  static Color _color(_Level level) => switch (level) {
    _Level.ok => const Color(0xFF8FE39A),
    _Level.idle => const Color(0xFFFFE49D),
    _Level.down => const Color(0xFFFF9C8A),
  };

  static _Level _fromService(ServiceState state) => switch (state) {
    ServiceState.online => _Level.ok,
    ServiceState.offline => _Level.down,
    ServiceState.unknown => _Level.idle,
  };

  static String _serviceWord(ServiceState state) => switch (state) {
    ServiceState.online => 'online',
    ServiceState.offline => 'offline',
    ServiceState.unknown => 'memeriksa',
  };
}

enum _Level { ok, idle, down }

class _StatusItem {
  const _StatusItem(this.label, this.level, this.word);

  final String label;
  final _Level level;
  final String word;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.level) {
      _Level.ok => (Icons.check_circle, const Color(0xFF8FE39A)),
      _Level.idle => (Icons.remove_circle, const Color(0xFFFFE49D)),
      _Level.down => (Icons.cancel, const Color(0xFFFF9C8A)),
    };
    return Semantics(
      label: '${item.label}: ${item.word}',
      excludeSemantics: true,
      child: Tooltip(
        message: '${item.label}: ${item.word}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC1F2A1B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x66FFFFFF)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFFF4F1E0),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
