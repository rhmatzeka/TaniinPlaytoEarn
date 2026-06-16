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
    // Keep text controller synchronized if the wallet address changes externally (e.g. via deep link).
    if (farmState.walletConnected && _controller.text != farmState.walletAddress) {
      _controller.text = farmState.walletAddress;
    }
    
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 560 || media.height < 720;
    final contentProminent = widget.prominent && !compact;
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
    final margin = compact ? 28.0 : (widget.prominent ? 56.0 : 72.0);
    final maxWidth = math.min(
      math.max(292.0, media.width - margin),
      widget.prominent ? 680.0 : 780.0,
    );
    final maxHeight = math.min(
      math.max(420.0, media.height - margin),
      widget.prominent ? 720.0 : 660.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: PixelPanel(
        color: const Color(0xFFA34A1C),
        borderColor: const Color(0xFF633010),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WalletPanelHeader(
              title: title,
              subtitle: subtitle,
              connected: farmState.walletConnected,
              backendSigner: farmState.walletIsBackendSigner,
              prominent: contentProminent,
              compact: compact,
              showCloseButton: widget.showCloseButton,
              onClose: widget.onClose,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 30,
                  compact ? 14 : 26,
                  compact ? 14 : 30,
                  compact ? 16 : 32,
                ),
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
                    padding: EdgeInsets.all(compact ? 14 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusBox(
                          text: farmState.chainStatus,
                          connected: farmState.walletConnected,
                          prominent: contentProminent,
                        ),
                        SizedBox(height: contentProminent ? 24 : 14),
                        SizedBox(
                          width: double.infinity,
                          child: _WalletActionButton(
                            label: 'MetaMask',
                            icon: Icons.account_balance_wallet,
                            color: const Color(0xFFB85B1E),
                            prominent: contentProminent,
                            onPressed: () => _openWalletConnect(metaMask: true),
                          ),
                        ),
                        SizedBox(height: contentProminent ? 24 : 16),
                        Text(
                          'Public address Sepolia',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFFE9C692),
                                fontSize: contentProminent ? 22 : 15,
                              ),
                        ),
                        SizedBox(height: contentProminent ? 12 : 8),
                        TextField(
                          controller: _controller,
                          maxLines: 1,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFFFFF0D4),
                                fontSize: contentProminent ? 26 : 17,
                              ),
                          decoration: InputDecoration(
                            hintText: '0x wallet address',
                            hintStyle: const TextStyle(
                              color: Color(0xFFD2AA7D),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF7A3713),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: contentProminent ? 22 : 14,
                              vertical: contentProminent ? 20 : 12,
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
                        SizedBox(height: contentProminent ? 26 : 18),
                        if (compact || widget.prominent)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (farmState.walletConnected) ...[
                                _WalletActionButton(
                                  label: 'Logout',
                                  icon: Icons.logout,
                                  color: const Color(0xFF8B2F23),
                                  prominent: contentProminent,
                                  onPressed: _logoutWallet,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _WalletActionButton(
                                label: farmState.walletConnected
                                    ? 'Ganti'
                                    : 'Simpan',
                                icon: Icons.check,
                                color: const Color(0xFFD68127),
                                prominent: contentProminent,
                                onPressed: _saveWallet,
                              ),
                            ],
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 14,
                            runSpacing: 12,
                            children: [
                              if (farmState.walletConnected)
                                _WalletActionButton(
                                  label: 'Logout',
                                  icon: Icons.logout,
                                  color: const Color(0xFF8B2F23),
                                  prominent: contentProminent,
                                  onPressed: _logoutWallet,
                                ),
                              _WalletActionButton(
                                label: farmState.walletConnected
                                    ? 'Ganti'
                                    : 'Simpan',
                                icon: Icons.check,
                                color: const Color(0xFFD68127),
                                prominent: contentProminent,
                                onPressed: _saveWallet,
                              ),
                            ],
                          ),
                      ],
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

  void _saveWallet() async {
    final address = _controller.text.trim();
    if (!isValidAddress(address)) {
      farmState.showMessage('Wallet address tidak valid.', success: false);
      return;
    }
    await farmState.connectWallet(address);
    if (widget.showCloseButton) {
      widget.onClose();
    }
  }

  Future<void> _openWalletConnect({required bool metaMask}) async {
    farmState.playClick();
    if (metaMask && PlatformBridge.hasBrowserWalletProvider()) {
      farmState.showMessage('Menunggu approve MetaMask...');
      final address = await PlatformBridge.requestBrowserWalletAddress();
      if (address.isNotEmpty) {
        _controller.text = address;
        _controller.selection = TextSelection.collapsed(offset: address.length);
        unawaited(farmState.connectWalletFromDeepLink(address));
        if (widget.showCloseButton) {
          widget.onClose();
        }
        return;
      }
      final error = PlatformBridge.browserWalletConnectError();
      farmState.showMessage(
        error.isEmpty ? 'Connect MetaMask dibatalkan.' : error,
        success: false,
      );
      return;
    }

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

class _WalletPanelHeader extends StatelessWidget {
  const _WalletPanelHeader({
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.backendSigner,
    required this.prominent,
    required this.compact,
    required this.showCloseButton,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool backendSigner;
  final bool prominent;
  final bool compact;
  final bool showCloseButton;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 76 : 96),
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 14 : 18,
        compact ? 14 : 22,
        compact ? 14 : 18,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFA94F1E),
        border: Border(bottom: BorderSide(color: Color(0xFF763513), width: 5)),
      ),
      child: Row(
        children: [
          const _HeaderDot(),
          SizedBox(width: compact ? 12 : 20),
          _WalletBadge(connected: connected, prominent: prominent),
          SizedBox(width: compact ? 12 : 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFDE19),
                    fontSize: prominent ? 42 : (compact ? 25 : 34),
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: backendSigner
                        ? const Color(0xFFFFE184)
                        : const Color(0xFFA9EFA7),
                    fontSize: prominent ? 20 : (compact ? 12 : 16),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (showCloseButton) ...[
            SizedBox(width: compact ? 10 : 16),
            PanelCloseButton(
              onPressed: onClose,
              dimension: compact ? 46 : 62,
              iconSize: compact ? 30 : 44,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderDot extends StatelessWidget {
  const _HeaderDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFDE19),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const SizedBox.square(dimension: 10),
    );
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
