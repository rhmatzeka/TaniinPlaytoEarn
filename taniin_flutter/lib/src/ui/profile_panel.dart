import 'package:flutter/material.dart';

import '../state/farm_state.dart';
import 'taniin_theme.dart';

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({
    required this.farmState,
    required this.onClose,
    super.key,
  });

  final FarmStateController farmState;
  final VoidCallback onClose;

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.farmState.playerName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 28).clamp(320.0, 920.0);
        final height = (constraints.maxHeight - 28).clamp(420.0, 720.0);
        return Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C7),
              border: Border.all(color: TaniinColors.darkSoil, width: 5),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                _header(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) {
                      return FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: bodyConstraints.maxWidth,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                            child: _profileContent(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _identityCard(),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, bodyConstraints) {
          if (bodyConstraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _questSection(),
                const SizedBox(height: 20),
                _achievementSection(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: _questSection()),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _achievementSection()),
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      _wardrobeSection(),
    ],
  );

  Widget _header() => Container(
    height: 68,
    padding: const EdgeInsets.only(left: 20, right: 10),
    decoration: const BoxDecoration(
      color: TaniinColors.leafDark,
      border: Border(bottom: BorderSide(color: Color(0xFF163F25), width: 4)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TaniinColors.wheat,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TaniinColors.darkSoil, width: 2),
          ),
          child: const Icon(Icons.person, color: TaniinColors.darkSoil),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PROFIL PETANI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Text(
                'Perjalanan, pencapaian, dan koleksimu',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFC8E2C3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF173F27),
            foregroundColor: Colors.white,
          ),
          tooltip: 'Tutup',
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _identityCard() {
    final state = widget.farmState;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF315F38), Color(0xFF244B2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF193A23), width: 3),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 5)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final avatar = _avatar(state);
          final details = _identityDetails(state);
          return compact
              ? Column(
                  children: <Widget>[
                    avatar,
                    const SizedBox(height: 14),
                    details,
                  ],
                )
              : Row(
                  children: <Widget>[
                    avatar,
                    const SizedBox(width: 20),
                    Expanded(child: details),
                  ],
                );
        },
      ),
    );
  }

  Widget _avatar(FarmStateController state) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: state.equippedCosmetic.color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: TaniinColors.wheat, width: 4),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x55000000), offset: Offset(0, 5)),
          ],
        ),
        child: const Icon(
          Icons.agriculture,
          color: TaniinColors.darkSoil,
          size: 52,
        ),
      ),
      Positioned(
        right: -9,
        bottom: -9,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: TaniinColors.wheat,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TaniinColors.darkSoil, width: 2),
          ),
          child: Text(
            'LV ${state.playerLevel}',
            style: const TextStyle(
              color: TaniinColors.darkSoil,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _identityDetails(FarmStateController state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Text(
        'NAMA PETANI',
        style: TextStyle(
          color: Color(0xFFC8E2C3),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: _nameController,
        maxLength: 24,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          filled: true,
          fillColor: const Color(0x44203124),
          contentPadding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF7DA66F), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: TaniinColors.wheat, width: 2),
          ),
          suffixIcon: IconButton(
            tooltip: 'Simpan nama',
            icon: const Icon(Icons.check, color: TaniinColors.wheat),
            onPressed: () {
              state.setPlayerName(_nameController.text);
              setState(() {});
            },
          ),
        ),
        onSubmitted: (_) {
          state.setPlayerName(_nameController.text);
          setState(() {});
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Text(
            '${state.xpInLevel} XP',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            '${100 - state.xpInLevel} XP lagi ke Level ${state.playerLevel + 1}',
            style: const TextStyle(
              color: Color(0xFFC8E2C3),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: state.levelProgress,
          minHeight: 13,
          color: TaniinColors.wheat,
          backgroundColor: const Color(0xFF173F27),
        ),
      ),
    ],
  );

  Widget _questSection() => _section(
    icon: Icons.event_available,
    title: 'QUEST HARIAN',
    subtitle: 'Selesaikan target dan kumpulkan XP',
    child: Column(
      children: widget.farmState.dailyQuests
          .map((quest) => _questCard(quest))
          .toList(),
    ),
  );

  Widget _questCard(DailyQuest quest) {
    final progress = quest.target == 0 ? 0.0 : quest.progress / quest.target;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: quest.completed
            ? const Color(0xFFDDECC8)
            : const Color(0xFFFFF7DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: quest.completed
              ? const Color(0xFF75A058)
              : const Color(0xFFD8B96C),
          width: 2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: quest.completed
                  ? TaniinColors.leaf
                  : const Color(0xFFF2D184),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              quest.completed ? Icons.check : Icons.spa,
              color: quest.completed ? Colors.white : TaniinColors.darkSoil,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quest.title,
                  style: const TextStyle(
                    color: TaniinColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: TaniinColors.leaf,
                    backgroundColor: const Color(0xFFE5D7AE),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${quest.progress}/${quest.target}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '+${quest.xpReward} XP',
                style: const TextStyle(
                  color: TaniinColors.leafDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achievementSection() {
    final achievements = widget.farmState.unlockedAchievements;
    return _section(
      icon: Icons.emoji_events,
      title: 'PENCAPAIAN',
      subtitle: '${achievements.length}/3 berhasil dibuka',
      child: achievements.isEmpty
          ? Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8B96C), width: 2),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.lock_outline, color: Color(0xFF9B7540)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selesaikan quest pertama untuk membuka pencapaian.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: achievements
                  .map(
                    (achievement) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE9A5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TaniinColors.panelDeep,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.workspace_premium,
                            size: 18,
                            color: Color(0xFF9A541E),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            achievement,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _wardrobeSection() => _section(
    icon: Icons.checkroom,
    title: 'WARDROBE',
    subtitle: 'Pilih gaya petani yang sudah kamu buka',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 450
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: FarmStateController.cosmeticCatalog
              .map(
                (item) =>
                    SizedBox(width: cardWidth, child: _cosmeticCard(item)),
              )
              .toList(),
        );
      },
    ),
  );

  Widget _cosmeticCard(CosmeticItem item) {
    final state = widget.farmState;
    final owned = state.ownedCosmeticIds.contains(item.id);
    final equipped = state.equippedCosmeticId == item.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: equipped ? const Color(0xFFDDECC8) : const Color(0xFFFFF7DE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: equipped ? TaniinColors.leaf : const Color(0xFFD8B96C),
          width: equipped ? 3 : 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33704427), width: 2),
            ),
            child: Stack(
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.agriculture,
                    color: TaniinColors.darkSoil,
                    size: 42,
                  ),
                ),
                if (!owned)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x77000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock, color: Colors.white),
                    ),
                  ),
                if (equipped)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: TaniinColors.leaf,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF67513B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: equipped
                    ? TaniinColors.leafDark
                    : TaniinColors.soil,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBBAA85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: owned && !equipped
                  ? () {
                      state.equipCosmetic(item.id);
                      setState(() {});
                    }
                  : null,
              icon: Icon(
                equipped
                    ? Icons.check_circle
                    : owned
                    ? Icons.checkroom
                    : Icons.lock,
                size: 17,
              ),
              label: Text(
                equipped
                    ? 'DIPAKAI'
                    : owned
                    ? 'PAKAI'
                    : 'BUKA DI LV ${item.unlockLevel}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: TaniinColors.wheat,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: TaniinColors.soil, width: 2),
            ),
            child: Icon(icon, size: 19, color: TaniinColors.darkSoil),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: TaniinColors.darkSoil,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF806044),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}
