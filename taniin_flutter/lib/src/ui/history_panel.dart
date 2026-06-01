import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chain/chain_client.dart';
import '../chain/platform_bridge.dart';
import '../state/farm_state.dart';
import 'pixel_panel.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({
    required this.farmState,
    required this.onClose,
    super.key,
  });

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.max(360.0, media.width - 92),
        maxHeight: math.max(300.0, media.height - 92),
      ),
      child: SizedBox(
        width: 960,
        height: 620,
        child: PixelPanel(
          color: const Color(0xFFA34A1C),
          borderColor: const Color(0xFF633010),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PanelHeader(
                icon: Icons.history,
                title: 'RIWAYAT',
                onClose: onClose,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 32),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A2D0E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE07B20),
                        width: 5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: farmState.history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) => _HistoryRow(
                          record: farmState.history[index],
                          farmState: farmState,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(24, 18, 22, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFA94F1E),
        border: Border(bottom: BorderSide(color: Color(0xFF763513), width: 5)),
      ),
      child: Row(
        children: [
          const _YellowPixelDot(),
          const SizedBox(width: 24),
          Icon(icon, size: 50, color: const Color(0xFFFFF0CE)),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: 42,
              ),
            ),
          ),
          PanelCloseButton(onPressed: onClose),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.farmState});

  final HistoryRecord record;
  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    final hasHash = record.hasTxHash;
    return GestureDetector(
      onTap: () => _openTransaction(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasHash ? const Color(0xFF4E6334) : const Color(0xFF8C3A14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasHash ? const Color(0xFF66CF7B) : const Color(0xFF5D260E),
            width: 4,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: hasHash
                      ? const Color(0xFF69E081)
                      : const Color(0xFFFFD51C),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF4C230B), width: 3),
                ),
                child: SizedBox.square(
                  dimension: 26,
                  child: hasHash
                      ? const Icon(
                          Icons.open_in_new,
                          size: 17,
                          color: Color(0xFF203124),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFF0CE),
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasHash
                          ? 'Sepolia ${shortTransactionHash(record.txHash)}'
                          : record.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasHash
                            ? const Color(0xFFB5F8BC)
                            : const Color(0xFFE9C692),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.valueLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFDE19),
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.timeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE9C692),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTransaction(BuildContext context) async {
    farmState.playClick();
    if (!record.hasTxHash) {
      farmState.showMessage(
        farmState.hasGameApi
            ? 'Belum ada hash Sepolia untuk riwayat ini.'
            : 'Belum on-chain: signer backend belum diset.',
        success: false,
      );
      return;
    }
    final opened = await PlatformBridge.openUrl(transactionUrl(record.txHash));
    farmState.showMessage(
      opened
          ? 'Membuka Etherscan ${shortTransactionHash(record.txHash)}'
          : 'Tidak bisa membuka Etherscan di perangkat ini.',
      success: opened,
    );
  }
}

class _YellowPixelDot extends StatelessWidget {
  const _YellowPixelDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD51C),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const SizedBox.square(dimension: 20),
    );
  }
}
