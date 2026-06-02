import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chain/chain_client.dart';
import '../chain/platform_bridge.dart';
import '../state/farm_state.dart';
import 'pixel_panel.dart';

class WalletPanel extends StatefulWidget {
  const WalletPanel({
    required this.farmState,
    required this.onClose,
    this.showCloseButton = true,
    this.prominent = false,
    this.showFacts = true,
    this.title,
    this.subtitle,
    super.key,
  });

  final FarmStateController farmState;
  final VoidCallback onClose;
  final bool showCloseButton;
  final bool prominent;
  final bool showFacts;
  final String? title;
  final String? subtitle;

  @override
  State<WalletPanel> createState() => _WalletPanelState();
}

class _WalletPanelState extends State<WalletPanel> {
  late final TextEditingController _controller;

  FarmStateController get farmState => widget.farmState;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: farmState.walletAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final title =
        widget.title ??
        (farmState.walletConnected ? 'Ganti Wallet' : 'Connect Wallet');
    final subtitle =
        widget.subtitle ??
        (farmState.walletIsBackendSigner
            ? 'Wallet signer backend'
            : farmState.walletConnected
            ? 'Sepolia wallet aktif'
            : 'Sepolia network');
    final prominent = widget.prominent;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(
          media.width - (prominent ? 32 : 44),
          prominent ? 1120 : 880,
        ),
        maxHeight: math.min(
          media.height - (prominent ? 32 : 44),
          prominent ? 760 : 690,
        ),
      ),
      child: PixelPanel(
        color: const Color(0xFF9E4E20),
        borderColor: const Color(0xFF4D2A0E),
        padding: prominent
            ? const EdgeInsets.fromLTRB(40, 34, 40, 38)
            : const EdgeInsets.fromLTRB(28, 24, 28, 26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _WalletBadge(
                    connected: farmState.walletConnected,
                    prominent: prominent,
                  ),
                  SizedBox(width: prominent ? 20 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFFFFDE19),
                                fontSize: prominent ? 54 : 38,
                              ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: farmState.walletIsBackendSigner
                                    ? const Color(0xFFFFE184)
                                    : const Color(0xFFA9EFA7),
                                fontSize: prominent ? 25 : 18,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showCloseButton)
                    PanelCloseButton(onPressed: widget.onClose),
                ],
              ),
              SizedBox(height: prominent ? 24 : 18),
              _StatusBox(
                text: farmState.chainStatus,
                connected: farmState.walletConnected,
                prominent: prominent,
              ),
              SizedBox(height: prominent ? 24 : 18),
              Wrap(
                spacing: prominent ? 16 : 12,
                runSpacing: prominent ? 16 : 12,
                children: [
                  _WalletActionButton(
                    label: 'MetaMask',
                    icon: Icons.account_balance_wallet,
                    color: const Color(0xFF267049),
                    prominent: prominent,
                    onPressed: () => _openWalletConnect(metaMask: true),
                  ),
                  _WalletActionButton(
                    label: 'Browser',
                    icon: Icons.open_in_browser,
                    color: const Color(0xFF5F4984),
                    prominent: prominent,
                    onPressed: () => _openWalletConnect(metaMask: false),
                  ),
                  _WalletActionButton(
                    label: 'Tempel',
                    icon: Icons.content_paste,
                    color: const Color(0xFF6F4E2B),
                    prominent: prominent,
                    onPressed: _pasteWallet,
                  ),
                  _WalletActionButton(
                    label: 'Sync',
                    icon: Icons.sync,
                    color: const Color(0xFF2B6C48),
                    prominent: prominent,
                    onPressed: farmState.walletConnected
                        ? () => unawaited(
                            farmState.refreshWalletState(revealMessage: true),
                          )
                        : null,
                  ),
                ],
              ),
              SizedBox(height: prominent ? 24 : 18),
              Text(
                'Public address Sepolia',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFE9C692),
                  fontSize: prominent ? 22 : 17,
                ),
              ),
              SizedBox(height: prominent ? 12 : 8),
              TextField(
                controller: _controller,
                maxLines: 1,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFFF0D4),
                  fontSize: prominent ? 26 : 20,
                ),
                decoration: InputDecoration(
                  hintText: '0x wallet address',
                  hintStyle: const TextStyle(color: Color(0xFFD2AA7D)),
                  filled: true,
                  fillColor: const Color(0xFF7A3713),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: prominent ? 22 : 16,
                    vertical: prominent ? 20 : 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF5C2A0C),
                      width: 3,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFD900),
                      width: 3,
                    ),
                  ),
                ),
                onSubmitted: (_) => _saveWallet(),
              ),
              if (widget.showFacts) ...[
                const SizedBox(height: 16),
                _WalletFacts(farmState: farmState),
              ],
              SizedBox(height: prominent ? 26 : 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: prominent ? 18 : 14,
                runSpacing: prominent ? 16 : 12,
                children: [
                  if (farmState.walletConnected)
                    _WalletActionButton(
                      label: 'Logout',
                      icon: Icons.logout,
                      color: const Color(0xFF8B2F23),
                      prominent: prominent,
                      onPressed: _logoutWallet,
                    ),
                  _WalletActionButton(
                    label: farmState.walletConnected ? 'Ganti' : 'Simpan',
                    icon: Icons.check,
                    color: const Color(0xFFD68127),
                    prominent: prominent,
                    onPressed: _saveWallet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveWallet() {
    final address = _controller.text.trim();
    if (!isValidAddress(address)) {
      farmState.showMessage('Wallet address tidak valid.', success: false);
      return;
    }
    unawaited(farmState.connectWallet(address));
  }

  Future<void> _pasteWallet() async {
    final address = await PlatformBridge.clipboardWalletAddress();
    if (address.isEmpty) {
      farmState.showMessage(
        'Clipboard belum berisi public address 0x...',
        success: false,
      );
      return;
    }
    _controller.text = address;
    _controller.selection = TextSelection.collapsed(offset: address.length);
    farmState.showMessage('Address dari clipboard siap dipakai.');
  }

  Future<void> _openWalletConnect({required bool metaMask}) async {
    final url = metaMask
        ? PlatformBridge.metamaskWalletConnectUrl(farmState.chainConfig)
        : PlatformBridge.walletConnectUrl(farmState.chainConfig);
    if (url.isEmpty) {
      farmState.showMessage(
        'TANIIN_GAME_API_URL belum diset untuk connect wallet app.',
        success: false,
      );
      return;
    }
    final opened = await PlatformBridge.openUrl(url);
    farmState.showMessage(
      opened
          ? (metaMask
                ? 'Membuka MetaMask connect...'
                : 'Membuka halaman connect wallet...')
          : 'Tidak bisa membuka wallet connect di perangkat ini.',
      success: opened,
    );
    if (opened) {
      if (widget.showCloseButton) {
        widget.onClose();
      }
    }
  }

  void _logoutWallet() {
    farmState.disconnectWallet();
    if (widget.showCloseButton) {
      widget.onClose();
    }
  }
}

class _WalletBadge extends StatelessWidget {
  const _WalletBadge({required this.connected, required this.prominent});

  final bool connected;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final dimension = prominent ? 64.0 : 46.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: connected ? const Color(0xFF70E084) : const Color(0xFFFFD51C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4C230B), width: 3),
      ),
      child: SizedBox.square(
        dimension: dimension,
        child: Center(
          child: Icon(
            connected ? Icons.check : Icons.account_balance_wallet,
            color: const Color(0xFF3A2614),
            size: prominent ? 37 : 27,
          ),
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.text,
    required this.connected,
    required this.prominent,
  });

  final String text;
  final bool connected;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: connected ? const Color(0xFF285A3D) : const Color(0xFF8E411B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5C2A0C), width: 4),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: prominent ? 24 : 18,
          vertical: prominent ? 20 : 15,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFFFF0D4),
            fontSize: prominent ? 26 : 20,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _WalletFacts extends StatelessWidget {
  const _WalletFacts({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FactChip(
          icon: Icons.account_balance_wallet,
          label: 'Wallet',
          value: farmState.walletConnected
              ? shortAddress(farmState.walletAddress)
              : 'belum connect',
        ),
        _FactChip(
          icon: Icons.bolt,
          label: 'ETH',
          value: farmState.walletNativeBalance.isEmpty
              ? '-'
              : farmState.walletNativeBalance,
        ),
        _FactChip(
          icon: Icons.token,
          label: 'TANI',
          value: farmState.walletTaniBalanceAvailable
              ? '${farmState.tani}'
              : '-',
        ),
        _FactChip(
          icon: Icons.cloud_done,
          label: 'API',
          value: farmState.hasGameApi ? 'aktif' : 'lokal',
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF793A17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB23F), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFDE19), size: 24),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE9C692),
                fontSize: 15,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFFFF0D4),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFF5F4A38),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFFFB23F) : const Color(0xFF8B6A53),
            width: 3,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: prominent ? 82 : 60),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: prominent ? 25 : 18,
                vertical: prominent ? 20 : 14,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFFFFF0D4),
                    size: prominent ? 34 : 26,
                  ),
                  SizedBox(width: prominent ? 13 : 10),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFFF0D4),
                      fontSize: prominent ? 23 : 18,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
