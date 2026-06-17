import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  });

  final String id;
  final String wallet;
  final String name;
  double x;
  double y;
  String anim;
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

  final Map<String, RemotePlayer> remotePlayers = <String, RemotePlayer>{};
  AiAgentState? aiAgent;
  Offset? aiTarget; // Track target coordinate to determine walking direction
  final List<ChatMessage> chatMessages = <ChatMessage>[];

  // Callbacks for game to react
  void Function(int plotIndex, int seedIndex)? onAiPlanted;
  void Function(int plotIndex)? onAiHarvested;

  void _onWalletAddressChanged() {
    if (farmState.walletAddress != _lastWalletAddress) {
      _lastWalletAddress = farmState.walletAddress;
      debugPrint('[multiplayer] Player wallet address changed, reconnecting...');
      reconnect();
    }
  }

  String _resolveHost() {
    final configured = farmState.chainConfig.gameApiUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    // On web with no explicit API URL, use the current site origin.
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file')) {
        return origin;
      }
    }
    return 'http://127.0.0.1:8787';
  }

  /// Reconnects using the latest chain config (call after chain config loads).
  void start() {
    final host = _resolveHost();
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

    debugPrint('[multiplayer] Connecting to WebSocket: $apiHost');

    try {
      _socket = io.io(
        apiHost,
        io.OptionBuilder()
            .setTransports(<String>['websocket'])
            .disableAutoConnect()
            .enableForceNew()
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
              x: (aiData['x'] as num?)?.toDouble() ?? 200.0,
              y: (aiData['y'] as num?)?.toDouble() ?? 350.0,
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
            p.x = (data['x'] as num?)?.toDouble() ?? p.x;
            p.y = (data['y'] as num?)?.toDouble() ?? p.y;
            p.anim = data['anim']?.toString() ?? p.anim;
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
          aiAgent!.x = (data['x'] as num?)?.toDouble() ?? aiAgent!.x;
          aiAgent!.y = (data['y'] as num?)?.toDouble() ?? aiAgent!.y;
          aiAgent!.anim = data['anim']?.toString() ?? aiAgent!.anim;
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
    final wallet = farmState.walletAddress.isNotEmpty
        ? farmState.walletAddress
        : 'local-wallet';
    final name = farmState.walletAddress.isNotEmpty
        ? 'Petani ${farmState.walletAddress.substring(0, 6)}'
        : 'Petani Lokal';

    _socket?.emit('join', <String, dynamic>{
      'wallet': wallet,
      'name': name,
      'x': 18.5 * 128,
      'y': 28.5 * 128,
      'anim': 'idle',
    });
  }

  void sendMove(double x, double y, String anim) {
    if (connected) {
      _socket?.emit('move', <String, dynamic>{
        'x': x,
        'y': y,
        'anim': anim,
      });
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
    _appendMessage(ChatMessage(
      sender: 'Kamu',
      wallet: farmState.walletAddress,
      text: trimmed,
      time: time,
    ));

    if (connected) {
      _socket?.emit('chat', <String, dynamic>{'text': trimmed});
    } else {
      // Offline mode: Simulate AI locally without posting offline alert messages.
      _simulateLocalAi(trimmed, time);
      reconnect();
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

    final clean = text.toLowerCase();
    
    // Parse plot number
    int plotNum = 1;
    final plotMatch = RegExp(r'lahan\s*([1-5])|plot\s*([1-5])|\b([1-5])\b').firstMatch(clean);
    if (plotMatch != null) {
      plotNum = int.tryParse(plotMatch.group(1) ?? plotMatch.group(2) ?? plotMatch.group(3) ?? '1') ?? 1;
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
    String intent = 'chat'; // plant, harvest, buy, sell, status, chat

    if (clean.contains('tanam') || clean.contains('plant')) {
      intent = 'plant';
      reply = 'Siap! Saya akan ke Lahan $plotNum untuk menanam benih $seed secara lokal.';
    } else if (clean.contains('panen') || clean.contains('harvest') || clean.contains('ambil')) {
      intent = 'harvest';
      reply = 'Oke, saya jalan ke Lahan $plotNum untuk memanen tanaman.';
    } else if (clean.contains('beli') || clean.contains('buy') || clean.contains('shop') || clean.contains('toko')) {
      intent = 'buy';
      reply = 'Baik, saya pergi ke Toko Ucup untuk membeli benih $seed.';
    } else if (clean.contains('jual') || clean.contains('sell')) {
      intent = 'sell';
      reply = 'Baik, saya jalan ke rumah pengepul untuk menjual hasil panen.';
    } else if (clean.contains('status') || clean.contains('koin') || clean.contains('benih')) {
      intent = 'status';
      reply = 'Status saya: Koin lokal aktif, benih & panen siap ditanam.';
    } else if (clean.contains('halo') || clean.contains('hai') || clean.contains('hi') || clean.contains('hello')) {
      reply = 'Halo! Saya Pak Tani AI. Saya bertani secara mandiri. Contoh: "tanam stroberi di lahan 2".';
    } else {
      reply = 'Perintah kurang jelas. Coba katakan: "tanam kentang di lahan 2", "panen lahan 1", atau "jual hasil".';
    }

    // AI agent responds conversationally
    _appendMessage(ChatMessage(
      sender: aiAgent!.name,
      wallet: aiAgent!.wallet,
      text: reply,
      time: time,
    ));

    if (intent == 'chat' || intent == 'status') return;

    // Define target position on map
    // Hotspots derived from TaniinGame tile coordinates:
    // Shop Sign: 18.5, 22.35
    // Sell Sign: 31.0, 13.35
    // Plots: 4, 6, 8, 10, 12 at Y=19
    Offset target = Offset(aiAgent!.x, aiAgent!.y);
    if (intent == 'buy') {
      target = const Offset(18.5 * 128, 22.35 * 128);
    } else if (intent == 'sell') {
      target = const Offset(31.0 * 128, 13.35 * 128);
    } else if (intent == 'plant' || intent == 'harvest') {
      final plotX = (4 + (plotNum - 1) * 2) * 128.0;
      target = Offset(plotX + 128, 19 * 128.0 + 128); // center of plot
    }

    // Move AI to target visually in client frame-rate
    _moveLocalAiTo(target, () async {
      _appendMessage(ChatMessage(
        sender: aiAgent!.name,
        wallet: aiAgent!.wallet,
        text: 'Tiba di tujuan. Sedang memproses transaksi di Sepolia...',
        time: time,
      ));

      // Call API serverless Vercel directly via HTTP POST
      try {
        final actionType = intent.toUpperCase() == 'BUY' ? 'BUY_SEED' : (intent.toUpperCase() == 'SELL' ? 'SELL_CROP' : intent.toUpperCase());
        final hasApi = farmState.chainConfig.hasGameApi;
        final res = hasApi 
          ? await farmState.submitChainActionDirectly(
              aiAgent!.wallet,
              actionType,
              plotNum,
              intent == 'buy' ? 3 : (intent == 'plant' ? (['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(seed) + 1) : 1)
            )
          : null;
        
        final tx = (res != null && res.isNotEmpty) ? res.substring(0, 8) : 'lokal';

        if (intent == 'plant') {
          onAiPlanted?.call(plotNum - 1, ['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(seed));
          _appendMessage(ChatMessage(
            sender: aiAgent!.name,
            wallet: aiAgent!.wallet,
            text: 'Bagus! Benih $seed ditanam di Lahan $plotNum. (Tx: $tx)',
            time: time,
          ));
        } else if (intent == 'harvest') {
          onAiHarvested?.call(plotNum - 1);
          _appendMessage(ChatMessage(
            sender: aiAgent!.name,
            wallet: aiAgent!.wallet,
            text: 'Sukses! Hasil panen berhasil diambil. (Tx: $tx)',
            time: time,
          ));
        } else if (intent == 'buy') {
          _appendMessage(ChatMessage(
            sender: aiAgent!.name,
            wallet: aiAgent!.wallet,
            text: 'Selesai! Saya membeli 3 benih $seed. (Tx: $tx)',
            time: time,
          ));
        } else if (intent == 'sell') {
          _appendMessage(ChatMessage(
            sender: aiAgent!.name,
            wallet: aiAgent!.wallet,
            text: 'Hore! Seluruh hasil panen terjual. (Tx: $tx)',
            time: time,
          ));
        }
      } catch (e) {
        _appendMessage(ChatMessage(
          sender: aiAgent!.name,
          wallet: aiAgent!.wallet,
          text: 'Transaksi selesai secara lokal. (Gagal Sepolia: ${e.toString().split('\n').first})',
          time: time,
        ));
        // Run visual fallback
        if (intent == 'plant') {
          onAiPlanted?.call(plotNum - 1, ['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(seed));
        } else if (intent == 'harvest') {
          onAiHarvested?.call(plotNum - 1);
        }
      }
    });
  }

  void _moveLocalAiTo(Offset finalTarget, VoidCallback onArrival) {
    if (aiAgent == null) return;

    // Generate waypoints path to follow the roads and avoid fences/obstacles
    final waypoints = _calculateAiPath(Offset(aiAgent!.x, aiAgent!.y), finalTarget);
    _followWaypoints(waypoints, 0, onArrival);
  }

  List<Offset> _calculateAiPath(Offset start, Offset target) {
    final path = <Offset>[];
    
    // Main Road Intersection (horizontal connector road)
    const mainCrossX = 18.5 * 128.0;
    const mainCrossY = 19.5 * 128.0;

    // Gate entry to the Farm Plots area
    const farmGateX = 10.0 * 128.0;
    const farmGateY = 19.5 * 128.0;

    // Check if target is a farm plot
    final isPlotTarget = target.dy > 18.0 * 128.0 && target.dx < 15.0 * 128.0;
    
    // Check if target is the sell crop house (Pengepul)
    final isSellTarget = (target.dx - 31.0 * 128.0).abs() < 128.0 && target.dy < 17.0 * 128.0;

    // Check if target is the shop (Toko Ucup)
    final isShopTarget = (target.dx - 18.5 * 128.0).abs() < 128.0 && target.dy > 21.0 * 128.0;

    // Routing Logic using Waypoints:
    if (isPlotTarget) {
      // Route: Start -> Main Crossroads -> Farm Gate -> Target Plot
      path.add(Offset(mainCrossX, start.dy)); // Go to main road x first
      path.add(const Offset(mainCrossX, mainCrossY)); // Move to crossroads
      path.add(const Offset(farmGateX, farmGateY)); // Walk along road to gate
      path.add(Offset(target.dx, farmGateY)); // Align with plot x
      path.add(target); // Enter plot
    } 
    else if (isSellTarget) {
      // Route: Start -> Main Crossroads -> Pengepul entry -> Target House
      path.add(Offset(mainCrossX, start.dy)); 
      path.add(const Offset(mainCrossX, mainCrossY));
      path.add(const Offset(31.0 * 128.0, mainCrossY)); // Move right to sell lane
      path.add(target); // Walk up to house
    }
    else if (isShopTarget) {
      // Route: Start -> Align X -> Walk down/up to Shop
      path.add(Offset(mainCrossX, start.dy));
      path.add(target);
    }
    else {
      // Direct path fallback for any other targets
      path.add(target);
    }

    return path;
  }

  void _followWaypoints(List<Offset> path, int index, VoidCallback onArrival) {
    if (aiAgent == null || index >= path.length) {
      aiTarget = null;
      onArrival();
      return;
    }

    final target = path[index];
    aiTarget = target;
    aiAgent!.anim = 'walk';
    notifyListeners();

    const speed = 12.0; // speed per step
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

        aiAgent!.x += (dx / distance) * speed;
        aiAgent!.y += (dy / distance) * speed;
        notifyListeners();
      } else {
        aiAgent!.x = target.dx;
        aiAgent!.y = target.dy;
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
    _socket?.disconnect();
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
