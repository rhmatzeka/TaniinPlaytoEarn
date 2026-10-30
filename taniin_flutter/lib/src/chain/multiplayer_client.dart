import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../state/farm_state.dart';

class RemotePlayer {
  RemotePlayer({
    required this.id,
    required this.wallet,
    required this.name,
    required this.x,
    required this.y,
    required this.anim,
    this.skinId = 'farmer_classic',
  });

  final String id;
  final String wallet;
  final String name;
  double x;
  double y;
  String anim;
  String skinId;
  int facingDirection = 0; // 0: down, 1: up, 2: side
  bool flipLeft = false;
}

/// Sprite row (0 down, 1 up, 2 side) and mirroring for a move of (dx, dy);
/// null when the move is too small to tell.
({int row, bool flipLeft})? _facingFor(double dx, double dy) {
  if (dx.abs() < 0.5 && dy.abs() < 0.5) {
    return null;
  }
  if (dy.abs() > dx.abs()) {
    return (row: dy < 0 ? 1 : 0, flipLeft: false);
  }
  return (row: 2, flipLeft: dx < 0);
}

class AiAgentState {
  AiAgentState({
    required this.id,
    required this.wallet,
    required this.name,
    required this.x,
    required this.y,
    required this.anim,
    this.facingDirection = 2, // 0: down, 1: up, 2: side
    this.flipLeft = false,
  });

  final String id;
  final String wallet;
  final String name;
  double x;
  double y;
  String anim;
  int facingDirection;
  bool flipLeft;
}

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.wallet,
    required this.text,
    required this.time,
  });

  final String sender;
  final String wallet;
  final String text;
  final String time;
}

class LocalAiAction {
  LocalAiAction({
    required this.intent,
    required this.plotNum,
    required this.seed,
    required this.reply,
  });

  final String intent;
  final int plotNum;
  final String seed;
  final String reply;
}

const double _tileSize = 128.0;
const double _shopFrontY = 26.85 * _tileSize;

// Village roads as junctions (tiles) and the straight segments between them,
// traced from assets/game/map.tmx. Mirrors ROAD_NODES / ROAD_EDGES in
// contracts/lib/multiplayer-service.cjs so offline and online AI walk alike.
const Map<String, Offset> _roadNodes = {
  'mainWest': Offset(5, 26.85),
  'mainMid': Offset(26.5, 26.85),
  'mainEast': Offset(34.6, 26.85),
  'buyerRoad': Offset(26.5, 16.6),
  'eastRoad': Offset(34.6, 16.6),
  'middleEast': Offset(26.5, 14.6),
  'bridgeSouth': Offset(23.5, 14.6),
  'middleWest': Offset(5.5, 14.6),
  'northMid': Offset(23.5, 4.6),
  'northWest': Offset(5, 4.6),
  'northEast': Offset(34.6, 3.6),
};
const List<(String, String)> _roadEdges = [
  ('mainWest', 'mainMid'),
  ('mainMid', 'mainEast'),
  ('mainMid', 'buyerRoad'),
  ('buyerRoad', 'eastRoad'),
  ('mainEast', 'eastRoad'),
  ('buyerRoad', 'middleEast'),
  ('middleEast', 'bridgeSouth'),
  ('bridgeSouth', 'middleWest'),
  ('bridgeSouth', 'northMid'),
  ('northMid', 'northWest'),
  ('eastRoad', 'northEast'),
];

Offset _roadPoint(String name) => _roadNodes[name]! * _tileSize;

/// Closest point on the road network to [point], with its segment.
({Offset point, String from, String to, double gap}) _nearestRoad(
  Offset point,
) {
  ({Offset point, String from, String to, double gap})? best;
  for (final (from, to) in _roadEdges) {
    final a = _roadPoint(from);
    final b = _roadPoint(to);
    final d = b - a;
    final t =
        (((point.dx - a.dx) * d.dx + (point.dy - a.dy) * d.dy) /
                (d.dx * d.dx + d.dy * d.dy))
            .clamp(0.0, 1.0);
    final onRoad = a + d * t;
    final gap = (point - onRoad).distance;
    if (best == null || gap < best.gap) {
      best = (point: onRoad, from: from, to: to, gap: gap);
    }
  }
  return best!;
}

/// Waypoints from [start] to [target]: onto the nearest road, along the
/// shortest road route, then off the road to the target.
@visibleForTesting
List<Offset> aiRoadPath(Offset start, Offset target) {
  final from = _nearestRoad(start);
  final to = _nearestRoad(target);
  final path = <Offset>[if (from.gap > 1) from.point];
  final sameSegment =
      (from.from == to.from && from.to == to.to) ||
      (from.from == to.to && from.to == to.from);
  if (!sameSegment) {
    final dist = {for (final name in _roadNodes.keys) name: double.infinity};
    final prev = <String, String>{};
    final open = {..._roadNodes.keys};
    dist[from.from] = (from.point - _roadPoint(from.from)).distance;
    dist[from.to] = (from.point - _roadPoint(from.to)).distance;
    while (open.isNotEmpty) {
      final current = open.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      open.remove(current);
      for (final (a, b) in _roadEdges) {
        final next = a == current ? b : (b == current ? a : null);
        if (next == null || !open.contains(next)) {
          continue;
        }
        final via =
            dist[current]! + (_roadPoint(current) - _roadPoint(next)).distance;
        if (via < dist[next]!) {
          dist[next] = via;
          prev[next] = current;
        }
      }
    }
    final exitA = dist[to.from]! + (_roadPoint(to.from) - to.point).distance;
    final exitB = dist[to.to]! + (_roadPoint(to.to) - to.point).distance;
    String? node = exitA <= exitB ? to.from : to.to;
    final junctions = <Offset>[];
    while (node != null) {
      junctions.insert(0, _roadPoint(node));
      node = prev[node];
    }
    path.addAll(junctions);
  }
  path
    ..add(to.point)
    ..add(target);
  return path;
}

class MultiplayerClient extends ChangeNotifier {
  MultiplayerClient(this.farmState) {
    _lastWalletAddress = farmState.walletAddress;
    farmState.addListener(_onWalletAddressChanged);
    _initConnection();
  }

  final FarmStateController farmState;
  io.Socket? _socket;
  bool connected = false;
  String _connectedHost = '';
  late String _lastWalletAddress;
  late String _lastPlayerName = farmState.playerName;
  late String _lastSkinId = farmState.equippedCosmeticId;

  final Map<String, RemotePlayer> remotePlayers = <String, RemotePlayer>{};
  AiAgentState? aiAgent;
  Offset? aiTarget; // Track target coordinate to determine walking direction
  final List<ChatMessage> chatMessages = <ChatMessage>[];

  // Callbacks for game to react
  void Function(int plotIndex, int seedIndex)? onAiPlanted;
  void Function(int plotIndex)? onAiHarvested;

  void _onWalletAddressChanged() {
    if (farmState.walletAddress != _lastWalletAddress ||
        farmState.playerName != _lastPlayerName ||
        farmState.equippedCosmeticId != _lastSkinId) {
      _lastWalletAddress = farmState.walletAddress;
      _lastPlayerName = farmState.playerName;
      _lastSkinId = farmState.equippedCosmeticId;
      debugPrint(
        '[multiplayer] Player wallet address changed, reconnecting...',
      );
      reconnect();
    }
  }

  // Multiplayer runs on its own always-on server (srv), not on Vercel.
  String _resolveHost() => farmState.chainConfig.multiplayerUrl.trim();

  /// Reconnects using the latest chain config (call after chain config loads).
  void start() {
    final host = _resolveHost();
    if (host.isEmpty) {
      _socket?.dispose();
      _socket = null;
      _connectedHost = '';
      if (connected) {
        connected = false;
        notifyListeners();
      }
      return;
    }
    if (connected && host == _connectedHost) {
      return;
    }
    _socket?.dispose();
    _socket = null;
    _initConnection();
  }

  void _initConnection() {
    // Determine the API server URL
    final apiHost = _resolveHost();
    _connectedHost = apiHost;
    if (apiHost.isEmpty) {
      // Chain config not loaded yet (or no server): start() connects later.
      // An empty URL makes socket.io throw on a null hostname.
      return;
    }

    debugPrint('[multiplayer] Connecting to WebSocket: $apiHost');

    try {
      _socket = io.io(
        apiHost,
        io.OptionBuilder()
            .setTransports(<String>['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .build(),
      );

      _socket?.onConnect((_) {
        debugPrint('[multiplayer] Connected to server.');
        connected = true;
        notifyListeners();
        _joinGame();
      });

      _socket?.onDisconnect((_) {
        debugPrint('[multiplayer] Disconnected from server.');
        connected = false;
        remotePlayers.clear();
        notifyListeners();
      });

      _socket?.onConnectError((err) {
        debugPrint('[multiplayer] Connection error: $err');
      });

      _socket?.on('init', (data) {
        if (data is Map) {
          final playersData = data['players'];
          if (playersData is Map) {
            playersData.forEach((key, val) {
              if (val is Map) {
                remotePlayers[key.toString()] = RemotePlayer(
                  id: key.toString(),
                  wallet: val['wallet']?.toString() ?? '',
                  name: val['name']?.toString() ?? 'Player',
                  x: (val['x'] as num?)?.toDouble() ?? 0.0,
                  y: (val['y'] as num?)?.toDouble() ?? 0.0,
                  anim: val['anim']?.toString() ?? 'idle',
                  skinId: val['skinId']?.toString() ?? 'farmer_classic',
                );
              }
            });
          }

          final aiData = data['ai'];
          if (aiData is Map) {
            aiAgent = AiAgentState(
              id: aiData['id']?.toString() ?? 'ai-agent',
              wallet: aiData['wallet']?.toString() ?? '',
              name: aiData['name']?.toString() ?? 'Pak Tani AI',
              x: (aiData['x'] as num?)?.toDouble() ?? 18.18 * _tileSize,
              y: (aiData['y'] as num?)?.toDouble() ?? _shopFrontY,
              anim: aiData['anim']?.toString() ?? 'idle',
            );
          }
          notifyListeners();
        }
      });

      _socket?.on('player_joined', (data) {
        if (data is Map) {
          final id = data['id']?.toString() ?? '';
          final player = data['player'];
          if (id.isNotEmpty && player is Map) {
            remotePlayers[id] = RemotePlayer(
              id: id,
              wallet: player['wallet']?.toString() ?? '',
              name: player['name']?.toString() ?? 'Player',
              x: (player['x'] as num?)?.toDouble() ?? 0.0,
              y: (player['y'] as num?)?.toDouble() ?? 0.0,
              anim: player['anim']?.toString() ?? 'idle',
              skinId: player['skinId']?.toString() ?? 'farmer_classic',
            );
            notifyListeners();
          }
        }
      });

      _socket?.on('player_moved', (data) {
        if (data is Map) {
          final id = data['id']?.toString() ?? '';
          if (remotePlayers.containsKey(id)) {
            final p = remotePlayers[id]!;
            final x = (data['x'] as num?)?.toDouble() ?? p.x;
            final y = (data['y'] as num?)?.toDouble() ?? p.y;
            final facing = _facingFor(x - p.x, y - p.y);
            if (facing != null) {
              p
                ..facingDirection = facing.row
                ..flipLeft = facing.flipLeft;
            }
            p
              ..x = x
              ..y = y
              ..anim = data['anim']?.toString() ?? p.anim;
            notifyListeners();
          }
        }
      });

      _socket?.on('player_left', (data) {
        if (data is Map) {
          final id = data['id']?.toString() ?? '';
          if (remotePlayers.containsKey(id)) {
            remotePlayers.remove(id);
            notifyListeners();
          }
        }
      });

      _socket?.on('ai_moved', (data) {
        if (data is Map && aiAgent != null) {
          final ai = aiAgent!;
          final x = (data['x'] as num?)?.toDouble() ?? ai.x;
          final y = (data['y'] as num?)?.toDouble() ?? ai.y;
          ai.anim = data['anim']?.toString() ?? ai.anim;
          final facing = _facingFor(x - ai.x, y - ai.y);
          if (facing != null) {
            ai
              ..facingDirection = facing.row
              ..flipLeft = facing.flipLeft;
          } else if (ai.anim == 'idle') {
            // Arrived: face the camera like the offline AI does.
            ai
              ..facingDirection = 0
              ..flipLeft = false;
          }
          ai
            ..x = x
            ..y = y;
          notifyListeners();
        }
      });

      _socket?.on('ai_planted', (data) {
        if (data is Map) {
          final plotIndex = (data['plotIndex'] as num?)?.toInt() ?? 0;
          final seedIndex = (data['seedIndex'] as num?)?.toInt() ?? 0;
          onAiPlanted?.call(plotIndex, seedIndex);
        }
      });

      _socket?.on('ai_harvested', (data) {
        if (data is Map) {
          final plotIndex = (data['plotIndex'] as num?)?.toInt() ?? 0;
          onAiHarvested?.call(plotIndex);
        }
      });

      _socket?.on('chat_message', (data) {
        if (data is Map) {
          final msg = ChatMessage(
            sender: data['sender']?.toString() ?? 'System',
            wallet: data['wallet']?.toString() ?? '',
            text: data['text']?.toString() ?? '',
            time: data['time']?.toString() ?? '',
          );
          chatMessages.add(msg);
          if (chatMessages.length > 50) {
            chatMessages.removeAt(0);
          }
          notifyListeners();
        }
      });

      _socket?.connect();
    } catch (e) {
      debugPrint('[multiplayer] Init error: $e');
    }
  }

  void _joinGame() {
    // The server derives the wallet from the session; guests get a Tamu name.
    _socket?.emit('join', <String, dynamic>{
      'session': ?farmState.session?.token,
      'name': farmState.playerName,
      'x': 18.5 * 128,
      'y': 28.5 * 128,
      'anim': 'idle',
      'skinId': farmState.equippedCosmeticId,
    });
  }

  final List<LocalAiAction> _localAiActionQueue = [];
  bool _isProcessingLocalAi = false;

  void sendMove(double x, double y, String anim) {
    if (connected) {
      _socket?.emit('move', <String, dynamic>{'x': x, 'y': y, 'anim': anim});
    }
  }

  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Optimistic local echo so the player always sees their own message,
    // even before the server round-trip (or if offline).
    _appendMessage(
      ChatMessage(
        sender: 'Kamu',
        wallet: farmState.walletAddress,
        text: trimmed,
        time: time,
      ),
    );

    if (connected) {
      _socket?.emit('chat', <String, dynamic>{'text': trimmed});
    } else {
      // Offline: answer with the local AI. Socket.IO keeps retrying on its own,
      // so a message must not tear the connection down and start over.
      _simulateLocalAi(trimmed, time);
    }
  }

  void _simulateLocalAi(String text, String time) async {
    // 1. Initialize local AI agent state if not already done
    if (aiAgent == null) {
      aiAgent = AiAgentState(
        id: 'local-ai-agent',
        wallet: '0x000000000000000000000000000000000000dEaD',
        name: 'Pak Tani AI',
        x: 18.18 * 128,
        y: 25.88 * 128,
        anim: 'idle',
      );
      notifyListeners();
    }

    // Determine a shared/default plot number from the entire instruction text first
    int defaultPlotNum = 1;
    final mainPlotMatch = RegExp(
      r'lahan\s*([1-5])|plot\s*([1-5])|\b([1-5])\b',
    ).firstMatch(text.toLowerCase());
    if (mainPlotMatch != null) {
      defaultPlotNum =
          int.tryParse(
            mainPlotMatch.group(1) ??
                mainPlotMatch.group(2) ??
                mainPlotMatch.group(3) ??
                '1',
          ) ??
          1;
    }

    final commands = text.split(
      RegExp(r'\bkemudian\b|\blalu\b|\bdan\b|\bterus\b|;|\||,'),
    );
    for (final cmd in commands) {
      final clean = cmd.trim().toLowerCase();
      if (clean.isEmpty) continue;

      // Parse plot number for this specific command, defaulting to defaultPlotNum if not specified
      int plotNum = defaultPlotNum;
      final plotMatch = RegExp(
        r'lahan\s*([1-5])|plot\s*([1-5])|\b([1-5])\b',
      ).firstMatch(clean);
      if (plotMatch != null) {
        plotNum =
            int.tryParse(
              plotMatch.group(1) ??
                  plotMatch.group(2) ??
                  plotMatch.group(3) ??
                  '1',
            ) ??
            1;
      }

      // Parse crop type
      String seed = 'Kentang';
      if (clean.contains('bawang')) {
        seed = 'Bawang';
      } else if (clean.contains('stroberi') || clean.contains('strawberry')) {
        seed = 'Stroberi';
      } else if (clean.contains('bit') || clean.contains('beet')) {
        seed = 'Bit';
      }

      String reply = '';
      String intent =
          'chat'; // plant, harvest, buy, sell, status, withdraw, chat

      // Check intents in prioritized order to avoid noun matching conflicts (e.g. "jual hasil panen" matching panen)
      if (clean.contains('jual') || clean.contains('sell')) {
        intent = 'sell';
        reply = 'Baik, saya jalan ke rumah pengepul untuk menjual hasil panen.';
      } else if (clean.contains('beli') ||
          clean.contains('buy') ||
          clean.contains('shop') ||
          clean.contains('toko')) {
        intent = 'buy';
        reply = 'Baik, saya pergi ke Toko Ucup untuk membeli benih $seed.';
      } else if (clean.contains('withdraw') ||
          clean.contains('payout') ||
          clean.contains('swap') ||
          clean.contains('tukar') ||
          clean.contains('tarik')) {
        intent = 'withdraw';
        reply =
            'Baik, saya jalan ke rumah swap untuk withdraw koin ke ETH Sepolia.';
      } else if (clean.contains('panen') ||
          clean.contains('harvest') ||
          clean.contains('ambil')) {
        final plotIdx = plotNum - 1;
        if (plotIdx >= 0 && plotIdx < farmState.plots.length) {
          final plot = farmState.plots[plotIdx];
          if (!plot.owned) {
            reply = 'Lahan $plotNum belum dibeli, tidak ada yang bisa dipanen.';
            intent = 'chat';
          } else if (plot.status == PlotStatus.empty) {
            reply = 'Lahan $plotNum kosong, tidak ada tanaman untuk dipanen.';
            intent = 'chat';
          } else if (!plot.isReady(DateTime.now())) {
            reply =
                'Tanaman di Lahan $plotNum masih tumbuh dan belum siap dipanen.';
            intent = 'chat';
          } else {
            intent = 'harvest';
            reply = 'Oke, saya jalan ke Lahan $plotNum untuk memanen tanaman.';
          }
        } else {
          reply = 'Nomor lahan $plotNum tidak valid.';
          intent = 'chat';
        }
      } else if (clean.contains('tanam') || clean.contains('plant')) {
        // Double check it's not matching the noun "tanaman" as a verb instruction "tanam"
        // If the clean string has "tanam" but it was part of "tanaman" and there's no other tanam/plant verb, we check:
        final hasTanamVerb = RegExp(
          r'\btanam\b|\btanamkan\b|\bplant\b',
        ).hasMatch(clean);
        if (hasTanamVerb) {
          final plotIdx = plotNum - 1;
          if (plotIdx >= 0 && plotIdx < farmState.plots.length) {
            final plot = farmState.plots[plotIdx];
            if (!plot.owned) {
              reply =
                  'Saya tidak bisa menanam di Lahan $plotNum karena lahan tersebut belum dibeli.';
              intent =
                  'chat'; // Downgrade to chat to prevent movement and action
            } else if (plot.status == PlotStatus.growing) {
              reply =
                  'Lahan $plotNum sudah ditanami tanaman lain yang sedang tumbuh. Silakan panen atau pilih lahan kosong.';
              intent = 'chat';
            } else {
              intent = 'plant';
              reply =
                  'Siap! Saya akan ke Lahan $plotNum untuk menanam benih $seed secara lokal.';
            }
          } else {
            reply =
                'Nomor lahan $plotNum tidak valid. Lahan yang tersedia adalah 1 sampai 5.';
            intent = 'chat';
          }
        }
      } else if (clean.contains('status') ||
          clean.contains('koin') ||
          clean.contains('benih')) {
        intent = 'status';
        reply = 'Status saya: Koin lokal aktif, benih & panen siap ditanam.';
      }

      if (intent == 'chat' && reply.isEmpty) {
        if (clean.contains('halo') ||
            clean.contains('hai') ||
            clean.contains('hi') ||
            clean.contains('hello')) {
          reply =
              'Halo! Saya Pak Tani AI. Saya bertani secara mandiri. Contoh: "tanam stroberi di lahan 2".';
        } else if (_isHelpQuestion(clean)) {
          reply = _helpReply(clean);
        } else {
          reply =
              'Perintah kurang jelas. Coba katakan: "tanam kentang di lahan 2", "panen lahan 1", atau "jual hasil".';
        }
      }

      _localAiActionQueue.add(
        LocalAiAction(
          intent: intent,
          plotNum: plotNum,
          seed: seed,
          reply: reply,
        ),
      );
    }

    _processNextLocalAiAction(time);
  }

  bool _isHelpQuestion(String text) {
    return text.contains('cara') ||
        text.contains('main') ||
        text.contains('bermain') ||
        text.contains('bingung') ||
        text.contains('apa yang harus') ||
        text.contains('gimana') ||
        text.contains('bagaimana') ||
        text.contains('tutorial') ||
        text.contains('panduan') ||
        text.contains('help') ||
        text.contains('bantuan') ||
        text.contains('fungsi') ||
        text.contains('tujuan');
  }

  String _helpReply(String text) {
    if (text.contains('koin') || text.contains('coin')) {
      return 'Koin dipakai untuk beli benih, beli lahan, dan bisa ditukar lewat rumah swap. Kumpulkan koin dengan menjual hasil panen.';
    }
    if (text.contains('benih') ||
        text.contains('bibit') ||
        text.contains('toko')) {
      return 'Benih bisa dibeli di Toko Ucup. Kamu juga bisa suruh saya: "beli benih kentang", lalu pilih lahan kosong untuk menanam.';
    }
    if (text.contains('panen') ||
        text.contains('tanam') ||
        text.contains('lahan')) {
      return 'Alur bertani: beli benih, tanam di lahan kosong, tunggu sampai siap panen, panen, lalu jual hasilnya untuk dapat koin.';
    }
    if (text.contains('swap') ||
        text.contains('withdraw') ||
        text.contains('sepolia')) {
      return 'Rumah swap dipakai untuk menukar Game Coin dengan aset Sepolia. Pastikan wallet tersambung sebelum transaksi on-chain.';
    }
    return 'Cara main singkat: beli benih di toko, tanam di lahan kosong, tunggu tanaman siap, panen, lalu jual hasil panen untuk dapat koin. Kamu bisa tanya saya atau beri perintah seperti "tanam kentang di lahan 1".';
  }

  void _processNextLocalAiAction(String time) async {
    if (_isProcessingLocalAi || _localAiActionQueue.isEmpty) return;
    _isProcessingLocalAi = true;

    final action = _localAiActionQueue.removeAt(0);

    // AI agent responds conversationally
    _appendMessage(
      ChatMessage(
        sender: aiAgent!.name,
        wallet: aiAgent!.wallet,
        text: action.reply,
        time: time,
      ),
    );

    if (action.intent == 'chat' || action.intent == 'status') {
      _isProcessingLocalAi = false;
      // Schedule next action execution quickly
      Timer(
        const Duration(milliseconds: 500),
        () => _processNextLocalAiAction(time),
      );
      return;
    }

    // Define target position on map. Shop uses the front walkway, not the
    // sign/roof coordinate, so Pak Tani AI never cuts across the house sprite.
    // Sell Sign: 31.0, 13.35
    // Swap Sign: 10.85, 13.15
    // Plots: 4, 6, 8, 10, 12 at Y=19
    Offset target = Offset(aiAgent!.x, aiAgent!.y);
    if (action.intent == 'buy') {
      // Road in front of the seed shop gate, same spot as the server AI.
      target = const Offset(19.2 * _tileSize, _shopFrontY);
    } else if (action.intent == 'sell') {
      // Road in front of the buyer's red house.
      target = const Offset(31.5 * _tileSize, 16.6 * _tileSize);
    } else if (action.intent == 'withdraw') {
      // Middle road in front of the swap house.
      target = const Offset(11.0 * _tileSize, 14.6 * _tileSize);
    } else if (action.intent == 'plant' || action.intent == 'harvest') {
      // Bottom edge of the plot, reached from the main road.
      final plotX = (4 + (action.plotNum - 1) * 2) * _tileSize;
      target = Offset(plotX + _tileSize, 23.7 * _tileSize);
    }

    // Move AI to target visually in client frame-rate
    _moveLocalAiTo(target, () async {
      _appendMessage(
        ChatMessage(
          sender: aiAgent!.name,
          wallet: aiAgent!.wallet,
          text: 'Tiba di tujuan. Sedang memproses transaksi...',
          time: time,
        ),
      );

      // Offline AI helper only changes the local farm; chain actions go through the server.
      try {
        if (!_isLocalAiActionStillValid(action)) {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: _invalidLocalAiActionMessage(action),
              time: time,
            ),
          );
          _isProcessingLocalAi = false;
          Timer(
            const Duration(milliseconds: 1000),
            () => _processNextLocalAiAction(time),
          );
          return;
        }

        if (action.intent == 'plant') {
          onAiPlanted?.call(
            action.plotNum - 1,
            ['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(action.seed),
          );
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text:
                  'Bagus! Benih ${action.seed} ditanam di Lahan ${action.plotNum}.',
              time: time,
            ),
          );
          farmState.addExternalHistory(
            'Tanam ${action.seed}',
            'plot ${action.plotNum}',
            'lokal tersimpan',
            txHash: '',
          );
        } else if (action.intent == 'harvest') {
          onAiHarvested?.call(action.plotNum - 1);
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Sukses! Hasil panen berhasil diambil.',
              time: time,
            ),
          );
          farmState.addExternalHistory(
            'Panen ${const <String>['Kentang', 'Bawang', 'Stroberi', 'Bit'].contains(action.seed) ? action.seed : 'Kentang'}',
            '+3 panen',
            'lokal tersimpan',
            txHash: '',
          );
        } else if (action.intent == 'buy') {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Selesai! Saya membeli 3 benih ${action.seed}.',
              time: time,
            ),
          );
          farmState.addExternalHistory(
            'Beli ${action.seed}',
            '-60 coin',
            'lokal tersimpan',
            txHash: '',
          );
        } else if (action.intent == 'sell') {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Hore! Seluruh hasil panen terjual.',
              time: time,
            ),
          );
          farmState.addExternalHistory(
            'Jual panen Kentang',
            '+105 coin',
            'lokal tersimpan',
            txHash: '',
          );
        } else if (action.intent == 'withdraw') {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text:
                  'Payout ETH hanya bisa lewat Rumah Swap setelah kamu masuk dengan Privy.',
              time: time,
            ),
          );
        }
      } catch (e) {
        _appendMessage(
          ChatMessage(
            sender: aiAgent!.name,
            wallet: aiAgent!.wallet,
            text:
                'Transaksi selesai secara lokal. (Gagal Sepolia: ${e.toString().split('\n').first})',
            time: time,
          ),
        );
        // Run visual fallback only if the current local state still permits it.
        if (action.intent == 'plant') {
          if (_isLocalAiActionStillValid(action)) {
            onAiPlanted?.call(
              action.plotNum - 1,
              ['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(action.seed),
            );
            farmState.addExternalHistory(
              'Tanam ${action.seed}',
              'plot ${action.plotNum}',
              'lokal tersimpan',
            );
          }
        } else if (action.intent == 'harvest') {
          if (_isLocalAiActionStillValid(action)) {
            onAiHarvested?.call(action.plotNum - 1);
            farmState.addExternalHistory(
              'Panen Kentang',
              '+3 panen',
              'lokal tersimpan',
            );
          }
        }
      }

      // Finish this action and queue the next one
      _isProcessingLocalAi = false;
      Timer(
        const Duration(milliseconds: 1000),
        () => _processNextLocalAiAction(time),
      );
    });
  }

  bool _isLocalAiActionStillValid(LocalAiAction action) {
    if (action.intent != 'plant' && action.intent != 'harvest') {
      return true;
    }
    final plotIdx = action.plotNum - 1;
    if (plotIdx < 0 || plotIdx >= farmState.plots.length) {
      return false;
    }
    final plot = farmState.plots[plotIdx];
    if (!plot.owned) {
      return false;
    }
    if (action.intent == 'plant') {
      return plot.status == PlotStatus.empty;
    }
    return plot.status == PlotStatus.growing && plot.isReady(DateTime.now());
  }

  String _invalidLocalAiActionMessage(LocalAiAction action) {
    final plotNum = action.plotNum;
    if (action.intent == 'plant') {
      return 'Lahan $plotNum sudah terisi atau belum bisa ditanami. Saya batalkan supaya tidak menembus error Sepolia.';
    }
    if (action.intent == 'harvest') {
      return 'Lahan $plotNum belum siap dipanen. Saya batalkan supaya transaksi tidak gagal.';
    }
    return 'Aksi dibatalkan karena kondisi lahan berubah.';
  }

  void _moveLocalAiTo(Offset finalTarget, VoidCallback onArrival) {
    if (aiAgent == null) return;

    // Follow the roads so the AI never cuts through houses or fences.
    final waypoints = aiRoadPath(Offset(aiAgent!.x, aiAgent!.y), finalTarget);
    _followWaypoints(waypoints, 0, onArrival);
  }

  void _followWaypoints(List<Offset> path, int index, VoidCallback onArrival) {
    if (aiAgent == null) {
      aiTarget = null;
      return;
    }

    if (index >= path.length) {
      aiTarget = null;
      aiAgent!.anim = 'idle';
      aiAgent!.facingDirection = 0; // face down when arrived/idle
      aiAgent!.flipLeft = false;
      notifyListeners();
      onArrival();
      return;
    }

    final target = path[index];
    aiTarget = target;
    aiAgent!.anim = 'walk';
    notifyListeners();

    const speed = 12.0; // speed per step
    var stuckTicks = 0;
    var lastPosition = Offset(aiAgent!.x, aiAgent!.y);
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (aiAgent == null) {
        timer.cancel();
        aiTarget = null;
        return;
      }
      final dx = target.dx - aiAgent!.x;
      final dy = target.dy - aiAgent!.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance > speed) {
        // Calculate facing direction before moving
        if (dy.abs() > dx.abs()) {
          aiAgent!.facingDirection = dy < 0 ? 1 : 0; // 1: up, 0: down
          aiAgent!.flipLeft = false;
        } else {
          aiAgent!.facingDirection = 2; // 2: side
          aiAgent!.flipLeft = dx < 0;
        }

        final nextPosition = Offset(
          aiAgent!.x + (dx / distance) * speed,
          aiAgent!.y + (dy / distance) * speed,
        );
        if ((nextPosition - lastPosition).distance < 1.0) {
          stuckTicks++;
        } else {
          stuckTicks = 0;
        }
        lastPosition = nextPosition;

        if (stuckTicks >= 8) {
          timer.cancel();
          _followWaypoints(path, index + 1, onArrival);
          return;
        }

        aiAgent!
          ..x = nextPosition.dx
          ..y = nextPosition.dy;
        notifyListeners();
      } else {
        aiAgent!
          ..x = target.dx
          ..y = target.dy;
        notifyListeners();
        timer.cancel();

        // Move to the next waypoint in path
        _followWaypoints(path, index + 1, onArrival);
      }
    });
  }

  void _appendMessage(ChatMessage msg) {
    chatMessages.add(msg);
    if (chatMessages.length > 50) {
      chatMessages.removeAt(0);
    }
    notifyListeners();
  }

  void reconnect() {
    _socket?.dispose();
    _socket = null;
    _initConnection();
  }

  @override
  void dispose() {
    farmState.removeListener(_onWalletAddressChanged);
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
