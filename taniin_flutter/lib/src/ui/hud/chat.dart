part of '../game_hud.dart';

class _ChatHud extends StatefulWidget {
  const _ChatHud({
    required this.multiplayerClient,
    required this.compact,
    required this.maxHeight,
    this.lift = 0,
    this.onTypingChanged,
  });

  final MultiplayerClient multiplayerClient;
  final bool compact;

  /// Room for the open panel, from the widget's top down to the bottom bar.
  final double maxHeight;

  /// Space above the collapsed button. The open panel starts at the top
  /// instead, so on sideways phones it covers the minimap and keeps a usable
  /// message list.
  final double lift;
  final ValueChanged<bool>? onTypingChanged;

  @override
  State<_ChatHud> createState() => _ChatHudState();
}

class _ChatHudState extends State<_ChatHud> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  bool _expanded = false;
  int _lastSeenCount = 0;

  static const Color _kAi = Color(0xFF52E07A);
  static const Color _kPlayer = Color(0xFF6FB7FF);
  static const Color _kPanel = Color(0xF21B2418);
  static const Color _kBorder = Color(0xFF7A5430);
  static const Color _kAccent = Color(0xFFE9C67B);

  @override
  void initState() {
    super.initState();
    widget.multiplayerClient.addListener(_onChat);
    _inputFocus.addListener(_onInputFocusChange);
    _lastSeenCount = widget.multiplayerClient.chatMessages.length;
  }

  void _onInputFocusChange() {
    widget.onTypingChanged?.call(_inputFocus.hasFocus);
  }

  void _onChat() {
    if (!mounted) return;
    if (_expanded) {
      _lastSeenCount = widget.multiplayerClient.chatMessages.length;
      _scrollToBottom();
    } else {
      setState(() {}); // refresh unread badge
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _lastSeenCount = widget.multiplayerClient.chatMessages.length;
        _scrollToBottom();
        // Focus the input shortly after the panel expands.
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _expanded) _inputFocus.requestFocus();
        });
      } else {
        _inputFocus.unfocus();
        widget.onTypingChanged?.call(false);
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submitMessage() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      widget.multiplayerClient.sendChat(text);
      _textController.clear();
      _lastSeenCount = widget.multiplayerClient.chatMessages.length;
      _scrollToBottom();
    }
    _inputFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.multiplayerClient.removeListener(_onChat);
    _inputFocus.removeListener(_onInputFocusChange);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topLeft,
        child: _expanded
            ? _buildExpanded(context)
            : Padding(
                padding: EdgeInsets.only(top: widget.lift),
                child: _buildCollapsed(),
              ),
      ),
    );
  }

  // Compact floating button with unread badge.
  Widget _buildCollapsed() {
    final unread =
        (widget.multiplayerClient.chatMessages.length - _lastSeenCount).clamp(
          0,
          99,
        );
    final compact = widget.compact;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PixelFrame(
            tone: PixelFrameTone.gelap,
            padding: EdgeInsets.fromLTRB(10, 6, compact ? 14 : 18, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/iconaplikasi.png',
                    width: compact ? 44 : 50,
                    height: compact ? 44 : 50,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pak Tani AI', style: Kayu.judul(compact ? 19 : 22, color: Kayu.krem)),
                    Text('Ketuk untuk ngobrol', style: Kayu.teks(compact ? 13 : 14, color: Kayu.kremRedup)),
                  ],
                ),
                const SizedBox(width: 10),
                PixelIcon('chat', size: compact ? 30 : 34),
              ],
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3453B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final messages = widget.multiplayerClient.chatMessages;
    final compact = widget.compact;
    // Further enlarged for mobile readability (compact: 400, desktop: 460)
    final width = compact ? 400.0 : 460.0;
    // Header and input take about 140 px; the list gets the rest.
    final listHeight = (widget.maxHeight - 140).clamp(
      110.0,
      compact ? 260.0 : 300.0,
    );
    final connected = widget.multiplayerClient.connected;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border.all(color: _kBorder, width: 2.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
              14,
              compact ? 12 : 14,
              10,
              compact ? 12 : 14,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3A24),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _AiAvatar(size: compact ? 32 : 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pak Tani AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 19 : 21,
                    ),
                  ),
                ),
                Container(
                  width: compact ? 11 : 13,
                  height: compact ? 11 : 13,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? _kAi : const Color(0xFFB55555),
                  ),
                ),
                GestureDetector(
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: const Color(0xFFE9C67B),
                      size: compact ? 24 : 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Messages
          SizedBox(
            height: listHeight,
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Suruh AI bertani!\nContoh: "tanam stroberi di lahan 2"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF9DAE8B),
                          fontFamily: 'monospace',
                          fontSize: compact ? 15 : 17,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isAi = msg.sender == 'Pak Tani AI';
                      final isSystem = msg.sender == 'Sistem';
                      if (isSystem) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: Text(
                              msg.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFE0A24B),
                                fontFamily: 'monospace',
                                fontSize: compact ? 14 : 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      }
                      final accent = isAi ? _kAi : _kPlayer;
                      return Align(
                        alignment: isAi
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          constraints: BoxConstraints(maxWidth: width * 0.82),
                          decoration: BoxDecoration(
                            color: isAi
                                ? const Color(0xFF24351F)
                                : const Color(0xFF1E2C3A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.sender,
                                style: TextStyle(
                                  color: accent,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: compact ? 13 : 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: compact ? 15 : 17,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: compact ? 48 : 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12160F),
                      border: Border.all(color: _kBorder, width: 1.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _textController,
                      focusNode: _inputFocus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 15 : 17,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: 'Ketik perintah ke AI...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF6F7B62),
                          fontSize: compact ? 14 : 16,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitMessage,
                  child: Container(
                    height: compact ? 48 : 54,
                    width: compact ? 52 : 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A5E32), Color(0xFF6B4527)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: _kAccent, width: 1.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: compact ? 20 : 23,
                    ),
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

// Small pixel-styled avatar for the AI agent (green farmer badge).
class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF52E07A),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: const Color(0xFF1B2A16), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.smart_toy,
        color: const Color(0xFF15240F),
        size: size * 0.62,
      ),
    );
  }
}
