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
    final compact = media.width < 560 || media.height < 720;
    final margin = compact ? 28.0 : 92.0;
    final maxWidth = math.min(
      math.max(292.0, media.width - margin),
      960.0,
    );
    final maxHeight = math.min(
      math.max(420.0, media.height - margin),
      620.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
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
              compact: compact,
            ),
            Expanded(
              child: Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(14, 14, 14, 16)
                    : const EdgeInsets.fromLTRB(30, 26, 30, 32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A2D0E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE07B20),
                      width: compact ? 4 : 5,
                    ),
                  ),
                  child: Padding(
                    padding: compact ? const EdgeInsets.all(10) : const EdgeInsets.all(18),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: farmState.history.length,
                      separatorBuilder: (_, _) => SizedBox(height: compact ? 8 : 14),
                      itemBuilder: (context, index) => _HistoryRow(
                        record: farmState.history[index],
                        farmState: farmState,
                        compact: compact,
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.onClose,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 76 : 116,
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 10, 14, 10)
          : const EdgeInsets.fromLTRB(24, 18, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFA94F1E),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF763513),
            width: compact ? 4 : 5,
          ),
        ),
      ),
      child: Row(
        children: [
          _YellowPixelDot(compact: compact),
          SizedBox(width: compact ? 12 : 24),
          Icon(
            icon,
            size: compact ? 28 : 50,
            color: const Color(0xFFFFF0CE),
          ),
          SizedBox(width: compact ? 12 : 22),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: compact ? 24 : 42,
              ),
            ),
          ),
          PanelCloseButton(
            onPressed: onClose,
            dimension: compact ? 46 : 62,
            iconSize: compact ? 30 : 44,
          ),
        ],
      ),
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
                    record.valueLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFDE19),
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

class _YellowPixelDot extends StatelessWidget {
  const _YellowPixelDot({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD51C),
        borderRadius: BorderRadius.circular(compact ? 3 : 5),
      ),
      child: SizedBox.square(dimension: compact ? 12 : 20),
    );
  }
}
