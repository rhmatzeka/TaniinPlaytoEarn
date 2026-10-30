import 'package:flutter/material.dart';

import '../chain/chain_client.dart';
import '../chain/platform_bridge.dart';
import '../state/farm_state.dart';
import 'kayu.dart';
import 'pixel_art.dart';

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
    final compact = media.width < 760 || media.height < 600;
    return ListenableBuilder(
      listenable: farmState,
      builder: (context, _) {
        final history = farmState.history;
        return KayuPanel(
          title: 'Riwayat',
          subtitle: 'Aksi dan transaksi terakhirmu',
          leading: const PixelIcon('riwayat', size: 52),
          maxWidth: 760,
          onClose: onClose,
          trailing: history.isEmpty
              ? null
              : KayuButton(
                  label: 'Hapus semua',
                  tone: KayuTone.bahaya,
                  compact: true,
                  onPressed: () {
                    farmState.playClick();
                    farmState.clearAllHistory();
                    farmState.showMessage('Seluruh riwayat berhasil dihapus.');
                  },
                ),
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada riwayat. Tanam, panen, atau tukar koin dulu.',
                    textAlign: TextAlign.center,
                    style: Kayu.teks(17, color: Kayu.kremRedup),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < history.length; i++) ...[
                      if (i > 0) SizedBox(height: compact ? 8 : 12),
                      _HistoryRow(
                        record: history[i],
                        farmState: farmState,
                        compact: compact,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.farmState,
    required this.compact,
  });

  final HistoryRecord record;
  final FarmStateController farmState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasHash = record.hasTxHash;
    final status = record.status.trim().toLowerCase();
    final isConfirmed = hasHash && status == 'on-chain';
    final isFailure = status.contains('gagal');
    final isPendingHash = hasHash && !isConfirmed && !isFailure;

    final IconData iconData;
    final Color iconColor;
    final Color boxColor;
    if (isConfirmed) {
      iconData = Icons.open_in_new;
      iconColor = const Color(0xFF203124);
      boxColor = const Color(0xFF69E081);
    } else if (isFailure) {
      iconData = Icons.error_outline;
      iconColor = const Color(0xFF5D1212);
      boxColor = const Color(0xFFFF6B6B);
    } else if (isPendingHash) {
      iconData = Icons.hourglass_top;
      iconColor = const Color(0xFF4C230B);
      boxColor = const Color(0xFFFFC857);
    } else {
      iconData = Icons.sync;
      iconColor = const Color(0xFF4C230B);
      boxColor = const Color(0xFFFFD51C);
    }

    return GestureDetector(
      onTap: () => _openTransaction(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isConfirmed
              ? const Color(0xFF4E6334)
              : isPendingHash
              ? const Color(0xFF6F4A1C)
              : const Color(0xFF8C3A14),
          borderRadius: BorderRadius.circular(compact ? 6 : 10),
          border: Border.all(
            color: isConfirmed
                ? const Color(0xFF66CF7B)
                : isPendingHash
                ? const Color(0xFFFFC857)
                : const Color(0xFF5D260E),
            width: compact ? 3 : 4,
          ),
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(compact ? 4 : 5),
                  border: Border.all(
                    color: const Color(0xFF4C230B),
                    width: compact ? 2 : 3,
                  ),
                ),
                child: SizedBox.square(
                  dimension: compact ? 22 : 26,
                  child: Icon(
                    iconData,
                    size: compact ? 13 : 17,
                    color: iconColor,
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 18),
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
                        fontSize: compact ? 17 : 26,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      _statusText(
                        hasHash: hasHash,
                        isConfirmed: isConfirmed,
                        isPendingHash: isPendingHash,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isConfirmed
                            ? const Color(0xFFB5F8BC)
                            : isPendingHash
                            ? const Color(0xFFFFE7A8)
                            : const Color(0xFFE9C692),
                        fontSize: compact ? 12 : 18,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 12 : 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isFailure ? 'GAGAL' : record.valueLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isFailure
                          ? const Color(0xFFFF9B8F)
                          : const Color(0xFFFFDE19),
                      fontSize: compact ? 17 : 26,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Text(
                    record.timeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE9C692),
                      fontSize: compact ? 12 : 18,
                    ),
                  ),
                ],
              ),
              SizedBox(width: compact ? 12 : 18),
              GestureDetector(
                onTap: () {
                  farmState.playClick();
                  farmState.deleteHistoryItem(record.id);
                  farmState.showMessage('Riwayat berhasil dihapus.');
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA00500),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF5C0000), width: 2),
                  ),
                  child: Icon(
                    Icons.delete,
                    size: compact ? 16 : 22,
                    color: const Color(0xFFFFEDCD),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText({
    required bool hasHash,
    required bool isConfirmed,
    required bool isPendingHash,
  }) {
    final status = record.status.trim().toLowerCase();
    if (status.contains('gagal') && record.errorMessage.isNotEmpty) {
      return record.errorMessage;
    }
    if (isConfirmed) {
      return 'Confirmed ${shortTransactionHash(record.txHash)}';
    }
    if (isPendingHash) {
      if (record.status.toLowerCase().contains('saldo eth')) {
        return 'Menunggu saldo ETH ${shortTransactionHash(record.txHash)}';
      }
      return 'Menunggu Sepolia ${shortTransactionHash(record.txHash)}';
    }
    if (hasHash) {
      return '${record.status} ${shortTransactionHash(record.txHash)}';
    }
    return record.status;
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
