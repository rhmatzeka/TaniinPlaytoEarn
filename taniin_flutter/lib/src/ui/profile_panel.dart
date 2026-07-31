import 'package:flutter/material.dart';

import '../state/farm_state.dart';

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
    final state = widget.farmState;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFFF3D58D),
          border: Border.all(color: const Color(0xFF6A3217), width: 6),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            _header(state),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _identity(state),
                    const SizedBox(height: 16),
                    _sectionTitle('QUEST HARIAN'),
                    const SizedBox(height: 8),
                    ...state.dailyQuests.map(_questCard),
                    const SizedBox(height: 16),
                    _sectionTitle('WARDROBE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: FarmStateController.cosmeticCatalog
                          .map((item) => _cosmeticCard(state, item))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('ACHIEVEMENT'),
                    const SizedBox(height: 8),
                    Text(
                      state.unlockedAchievements.isEmpty
                          ? 'Selesaikan quest pertama untuk membuka achievement.'
                          : state.unlockedAchievements.join('  •  '),
                      style: const TextStyle(
                        color: Color(0xFF4C2A16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FarmStateController state) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
    decoration: const BoxDecoration(
      color: Color(0xFFA94E1C),
      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.person, color: Color(0xFFFFD52A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PROFIL PETANI  •  LEVEL ${state.playerLevel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _identity(FarmStateController state) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: state.equippedCosmetic.color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6A3217), width: 4),
        ),
        child: const Icon(
          Icons.agriculture,
          color: Color(0xFF3F2414),
          size: 44,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          children: <Widget>[
            TextField(
              controller: _nameController,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: 'Nama petani',
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () {
                    state.setPlayerName(_nameController.text);
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.levelProgress,
              minHeight: 12,
              color: const Color(0xFF4D9A4A),
              backgroundColor: const Color(0x55704427),
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${state.xpInLevel}/100 XP menuju level berikutnya'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _questCard(DailyQuest quest) => Card(
    color: quest.completed ? const Color(0xFFCDE8B2) : const Color(0xFFFFE8B2),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(
            quest.completed ? Icons.check_circle : Icons.radio_button_unchecked,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quest.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text('${quest.progress}/${quest.target}  +${quest.xpReward} XP'),
        ],
      ),
    ),
  );

  Widget _cosmeticCard(FarmStateController state, CosmeticItem item) {
    final owned = state.ownedCosmeticIds.contains(item.id);
    final equipped = state.equippedCosmeticId == item.id;
    return SizedBox(
      width: 215,
      child: Card(
        color: equipped ? const Color(0xFFCDE8B2) : const Color(0xFFFFE8B2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 42,
                color: item.color,
                child: const Icon(Icons.agriculture),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: owned && !equipped
                    ? () {
                        state.equipCosmetic(item.id);
                        setState(() {});
                      }
                    : null,
                child: Text(
                  equipped
                      ? 'DIPAKAI'
                      : owned
                      ? 'PAKAI'
                      : 'LEVEL ${item.unlockLevel}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF6A3217),
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ),
  );
}
