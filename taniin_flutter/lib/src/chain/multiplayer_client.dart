import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  });

  final String id;
  final String wallet;
  final String name;
  double x;
  double y;
  String anim;
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
    _initConnection();
  }

  final FarmStateController farmState;
  IO.Socket? _socket;
  bool connected = false;

  final Map<String, RemotePlayer> remotePlayers = <String, RemotePlayer>{};
  AiAgentState? aiAgent;
  final List<ChatMessage> chatMessages = <ChatMessage>[];

  // Callbacks for game to react
  void Function(int plotIndex, int seedIndex)? onAiPlanted;
  void Function(int plotIndex)? onAiHarvested;

  void _initConnection() {
    // Determine the API server URL
    String apiHost = 'http://127.0.0.1:8787';
    if (farmState.chainConfig.gameApiUrl.isNotEmpty) {
      apiHost = farmState.chainConfig.gameApiUrl;
    }
    
    debugPrint('[multiplayer] Connecting to WebSocket: $apiHost');

    try {
      _socket = IO.io(
        apiHost,
        IO.OptionBuilder()
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
    if (connected && text.trim().isNotEmpty) {
      _socket?.emit('chat', <String, dynamic>{
        'text': text.trim(),
      });
    }
  }

  void reconnect() {
    _socket?.disconnect();
    _initConnection();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
