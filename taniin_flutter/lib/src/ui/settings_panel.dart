import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chain/platform_bridge.dart';
import '../state/farm_state.dart';
import 'pixel_panel.dart';

enum _SettingsSection { audio, wallet, about }

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    required this.farmState,
    required this.onClose,
    super.key,
  });

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  static const String _githubUrl = 'https://github.com/rhmatzeka';

  _SettingsSection _selectedSection = _SettingsSection.audio;

  FarmStateController get farmState => widget.farmState;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.max(360.0, media.width - 80),
        maxHeight: math.max(300.0, media.height - 80),
      ),
      child: SizedBox(
        width: 1120,
        height: 640,
        child: PixelPanel(
          color: const Color(0xFFA34A1C),
          borderColor: const Color(0xFF633010),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuHeader(
                title: 'MENU',
                icon: Icons.menu,
                onClose: widget.onClose,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _SettingsSidebar(
                        selectedSection: _selectedSection,
                        onSelected: _selectSection,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 34),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A2D0E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE07B20),
                              width: 5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 26, 32, 28),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children:
                                  _selectedSection == _SettingsSection.audio
                                  ? _buildAudioContent()
                                  : _selectedSection == _SettingsSection.wallet
                                  ? _buildWalletContent()
                                  : _buildAboutContent(context),
                            ),
                          ),
                        ),
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

  List<Widget> _buildAudioContent() {
    return [
      const _SettingsTitle(icon: Icons.volume_up, title: 'SETTINGS'),
      const SizedBox(height: 24),
      _SettingSwitch(
        icon: Icons.music_note,
        title: 'MUSIC',
        subtitle: 'BACKSOUND GAME',
        value: farmState.musicEnabled,
        onChanged: farmState.setMusicEnabled,
      ),
      const SizedBox(height: 18),
      _VolumeSlider(
        title: 'MASTER VOLUME',
        value: farmState.musicVolume,
        enabled: farmState.musicEnabled,
        onChanged: farmState.setMusicVolume,
      ),
      const SizedBox(height: 22),
      _SettingSwitch(
        icon: Icons.surround_sound,
        title: 'SFX',
        subtitle: 'TOMBOL DAN AKSI',
        value: farmState.sfxEnabled,
        onChanged: farmState.setSfxEnabled,
      ),
      const SizedBox(height: 18),
      _VolumeSlider(
        title: 'SFX VOLUME',
        value: farmState.sfxVolume,
        enabled: farmState.sfxEnabled,
        onChanged: farmState.setSfxVolume,
      ),
    ];
  }

  List<Widget> _buildAboutContent(BuildContext context) {
    return [
      const _SettingsTitle(icon: Icons.info, title: 'ABOUT'),
      const SizedBox(height: 24),
      _AboutCard(onGithubTap: _openGithub),
      const SizedBox(height: 18),
      _AboutInfoRow(
        icon: Icons.person,
        title: 'CREATOR',
        value: 'Rahmat Eka Satria',
      ),
      const SizedBox(height: 14),
      _AboutInfoRow(
        icon: Icons.gamepad,
        title: 'PROJECT',
        value: 'Taniin Play to Earn - Flutter game farming',
      ),
    ];
  }

  List<Widget> _buildWalletContent() {
    return [
      const _SettingsTitle(icon: Icons.account_balance_wallet, title: 'WALLET'),
      const SizedBox(height: 24),
      _AboutInfoRow(
        icon: farmState.walletConnected ? Icons.verified_user : Icons.link_off,
        title: farmState.walletConnected ? 'CONNECTED WALLET' : 'WALLET BELUM LOGIN',
        value: farmState.walletConnected
            ? farmState.walletLabel
            : 'Connect wallet dari panel login untuk mengirim aksi on-chain.',
      ),
      const SizedBox(height: 14),
      _AboutInfoRow(
        icon: Icons.cloud_sync,
        title: 'CHAIN STATUS',
        value: farmState.chainStatus,
      ),
      if (farmState.walletConnected) ...[
        const SizedBox(height: 18),
        _WalletLogoutButton(onTap: _logoutWallet),
      ],
    ];
  }

  void _selectSection(_SettingsSection section) {
    farmState.playClick();
    if (_selectedSection == section) {
      return;
    }
    setState(() => _selectedSection = section);
  }

  Future<void> _openGithub() async {
    farmState.playClick();
    final opened = await PlatformBridge.openUrl(_githubUrl);
    if (!mounted) {
      return;
    }
    farmState.showMessage(
      opened
          ? 'Membuka GitHub rhmatzeka...'
          : 'Tidak bisa membuka link GitHub.',
      success: opened,
    );
  }

  void _logoutWallet() {
    farmState.disconnectWallet();
    widget.onClose();
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.title,
    required this.icon,
    required this.onClose,
  });

  final String title;
  final IconData icon;
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
          Icon(icon, size: 48, color: const Color(0xFFFFF0CE)),
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

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selectedSection,
    required this.onSelected,
  });

  final _SettingsSection selectedSection;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF813411)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          children: [
            _SideTab(
              icon: Icons.volume_up,
              label: 'AUDIO',
              selected: selectedSection == _SettingsSection.audio,
              onTap: () => onSelected(_SettingsSection.audio),
            ),
            const SizedBox(height: 16),
            _SideTab(
              icon: Icons.account_balance_wallet,
              label: 'WALLET',
              selected: selectedSection == _SettingsSection.wallet,
              onTap: () => onSelected(_SettingsSection.wallet),
            ),
            const SizedBox(height: 16),
            _SideTab(
              icon: Icons.info,
              label: 'ABOUT',
              selected: selectedSection == _SettingsSection.about,
              onTap: () => onSelected(_SettingsSection.about),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD51C) : const Color(0xFF8A3A12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFFF07A) : const Color(0xFFCC6D1D),
            width: 4,
          ),
        ),
        child: SizedBox(
          height: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 42,
                color: selected
                    ? const Color(0xFF42B8E9)
                    : const Color(0xFFFFD65A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? const Color(0xFF3C250D)
                        : const Color(0xFFFFF0CE),
                    fontSize: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTitle extends StatelessWidget {
  const _SettingsTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF6E2509),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF5BC7F3)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFDE19),
                  fontSize: 38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.onGithubTap});

  final VoidCallback onGithubTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8C3A14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB23F), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TANIIN PLAY TO EARN',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFFFDE19),
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aplikasi game farming ini dibuat oleh Rahmat Eka Satria dengan alur Flutter dan wallet Sepolia.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFFFF0CE),
                fontSize: 21,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 18),
            _GithubButton(onTap: onGithubTap),
          ],
        ),
      ),
    );
  }
}

class _GithubButton extends StatelessWidget {
  const _GithubButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF273E32),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF86D68B), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.code, color: Color(0xFFFFF0CE), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GITHUB',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFA9EFA7),
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'rhmatzeka',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFF0CE),
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Color(0xFFFFD51C), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      child: Row(
        children: [
          Icon(icon, size: 36, color: const Color(0xFFFFD51C)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFE9C692),
                    fontSize: 16,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFFF0CE),
                    fontSize: 24,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletLogoutButton extends StatelessWidget {
  const _WalletLogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF832C20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFB23F), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: Color(0xFFFFF0CE), size: 28),
              const SizedBox(width: 12),
              Text(
                'LOGOUT WALLET',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFFFF0CE),
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      child: Row(
        children: [
          Icon(icon, size: 42, color: const Color(0xFFFFD51C)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFFF0CE),
                    fontSize: 28,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE9C692),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.35,
            child: Switch(
              value: value,
              activeThumbColor: const Color(0xFFFFD51C),
              activeTrackColor: const Color(0xFF2F7D45),
              inactiveThumbColor: const Color(0xFFD09A62),
              inactiveTrackColor: const Color(0xFF5C230A),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFFF0CE),
                    fontSize: 28,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFF0CE),
                  fontSize: 28,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 13,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              activeTrackColor: const Color(0xFFFFD51C),
              inactiveTrackColor: const Color(0xFF5D260E),
              thumbColor: const Color(0xFFFF971B),
              disabledActiveTrackColor: const Color(0xFF9C6B39),
              disabledInactiveTrackColor: const Color(0xFF5D260E),
              disabledThumbColor: const Color(0xFF855534),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8C3A14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D260E), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: child,
      ),
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
