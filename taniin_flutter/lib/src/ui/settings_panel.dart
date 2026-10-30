import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_update.dart';
import '../chain/platform_bridge.dart';
import '../state/farm_state.dart';
import 'kayu.dart';
import 'pixel_art.dart';

enum _SettingsSection { audio, about }

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
    // Sideways phones are short: skip the section titles, the tabs say it.
    final short = media.height < 600;
    return KayuPanel(
      title: 'Menu',
      subtitle: 'Suara dan info game',
      leading: const PixelIcon('menu', size: 52),
      maxWidth: 760,
      onClose: widget.onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _tab('Suara', Icons.volume_up, _SettingsSection.audio),
              _tab('Tentang', Icons.info, _SettingsSection.about),
              if (farmState.isLoggedIn)
                KayuButton(
                  label: 'Keluar',
                  icon: Icons.logout,
                  tone: KayuTone.bahaya,
                  compact: true,
                  onPressed: () {
                    farmState.playClick();
                    unawaited(_logoutWallet());
                  },
                ),
            ],
          ),
          SizedBox(height: short ? 10 : 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF7A2D0E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Kayu.rim, width: 3),
            ),
            child: Padding(
              padding: short
                  ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                  : const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _selectedSection == _SettingsSection.audio
                    ? _buildAudioContent(short)
                    : _buildAboutContent(context, short),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, _SettingsSection section) {
    final selected = _selectedSection == section;
    return KayuButton(
      label: label,
      icon: icon,
      tone: selected ? KayuTone.utama : KayuTone.kedua,
      compact: true,
      onPressed: () => _selectSection(section),
    );
  }

  List<Widget> _buildAudioContent(bool short) {
    return [
      if (!short) ...[
        const _SettingsTitle(icon: Icons.volume_up, title: 'Suara'),
        const SizedBox(height: 24),
      ],
      _SettingSwitch(
        icon: Icons.music_note,
        title: 'Musik',
        subtitle: 'Musik latar game',
        value: farmState.musicEnabled,
        onChanged: farmState.setMusicEnabled,
      ),
      SizedBox(height: short ? 10 : 18),
      _VolumeSlider(
        title: 'Volume musik',
        value: farmState.musicVolume,
        enabled: farmState.musicEnabled,
        onChanged: farmState.setMusicVolume,
      ),
      SizedBox(height: short ? 12 : 22),
      _SettingSwitch(
        icon: Icons.surround_sound,
        title: 'Efek suara',
        subtitle: 'Bunyi tombol dan aksi',
        value: farmState.sfxEnabled,
        onChanged: farmState.setSfxEnabled,
      ),
      SizedBox(height: short ? 10 : 18),
      _VolumeSlider(
        title: 'Volume efek',
        value: farmState.sfxVolume,
        enabled: farmState.sfxEnabled,
        onChanged: farmState.setSfxVolume,
      ),
    ];
  }

  List<Widget> _buildAboutContent(BuildContext context, bool short) {
    return [
      if (!short) ...[
        const _SettingsTitle(icon: Icons.info, title: 'Tentang'),
        const SizedBox(height: 24),
      ],
      _AboutCard(onGithubTap: _openGithub),
      const SizedBox(height: 18),
      _AboutInfoRow(
        icon: Icons.person,
        title: 'Pembuat',
        value: 'Rahmat Eka Satria',
      ),
      const SizedBox(height: 14),
      _AboutInfoRow(
        icon: Icons.gamepad,
        title: 'Proyek',
        value: 'Taniin Play to Earn - Flutter game farming',
      ),
      const SizedBox(height: 14),
      _AboutInfoRow(
        icon: Icons.system_update,
        title: 'Versi',
        value: appBuild > 0 ? '1.0.$appBuild' : 'Web',
      ),
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

  Future<void> _logoutWallet() async {
    await farmState.logout();
    widget.onClose();
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
                      'GitHub',
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
