import 'package:flutter/material.dart';

import '../../state/farm_state.dart';

/// Small row of service indicators. Each state has an icon shape as well as a
/// color, so it reads without relying on color alone.
class StatusStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final items = <_StatusItem>[
      _StatusItem('Akun', farmState.isLoggedIn ? _Level.ok : _Level.idle,
          farmState.isLoggedIn ? 'masuk' : 'tamu'),
      _StatusItem('Sepolia', _fromService(farmState.sepoliaState),
          _serviceWord(farmState.sepoliaState)),
      _StatusItem('Server', _fromService(farmState.serverState),
          _serviceWord(farmState.serverState)),
      _StatusItem('Multiplayer', multiplayerOnline ? _Level.ok : _Level.down,
          multiplayerOnline ? 'online' : 'offline'),
      _StatusItem('AI', aiOnline ? _Level.ok : _Level.down,
          aiOnline ? 'online' : 'offline'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (final item in items) _StatusChip(item: item)],
    );
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFFF4F1E0),
                    fontSize: 11,
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
