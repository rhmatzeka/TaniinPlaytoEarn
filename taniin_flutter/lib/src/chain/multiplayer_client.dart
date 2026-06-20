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
const double _shopLeft = 1.1 * _tileSize;
const double _shopRight = 5.25 * _tileSize;
const double _shopTop = 16.2 * _tileSize;
const double _shopBottom = 23.95 * _tileSize;
const double _shopSafeX = 5.95 * _tileSize;
const double _shopFrontY = 26.85 * _tileSize;
const double _shopDoorX = 3.35 * _tileSize;

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
      debugPrint(
        '[multiplayer] Player wallet address changed, reconnecting...',
      );
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
      target = const Offset(_shopDoorX, _shopFrontY);
    } else if (action.intent == 'sell') {
      target = const Offset(31.0 * 128, 13.35 * 128);
    } else if (action.intent == 'withdraw') {
      target = const Offset(10.85 * 128, 13.15 * 128);
    } else if (action.intent == 'plant' || action.intent == 'harvest') {
      final plotX = (4 + (action.plotNum - 1) * 2) * 128.0;
      target = Offset(plotX + 128, 19 * 128.0 + 128); // center of plot
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

      // Call API serverless Vercel directly via HTTP POST
      try {
        final hasApi = farmState.chainConfig.hasGameApi;
        String actionType = '';
        int amount = 1;

        if (action.intent == 'buy') {
          actionType = 'BUY_SEED';
          amount = 3;
        } else if (action.intent == 'sell') {
          actionType = 'SELL_CROP';
          amount = 3;
        } else if (action.intent == 'withdraw') {
          actionType = 'SWAP_COIN_ETH';
          // Withdraw 50 game coin or current coin balance if lower
          amount = math.min(50, farmState.coins);
        } else if (action.intent == 'plant') {
          actionType = 'PLANT';
          amount =
              (['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(action.seed) +
              1);
        } else if (action.intent == 'harvest') {
          actionType = 'HARVEST';
          amount = 1;
        }

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

        final res = hasApi
            ? await _submitChainActionWithRetry(
                aiAgent!.wallet,
                actionType,
                action.plotNum,
                amount,
              )
            : null;

        final tx = (res != null && res.isNotEmpty)
            ? res.substring(0, 8)
            : 'lokal';

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
                  'Bagus! Benih ${action.seed} ditanam di Lahan ${action.plotNum}. (Tx: $tx)',
              time: time,
            ),
          );
          final entryId = farmState.addExternalHistory(
            'Tanam ${action.seed}',
            'plot ${action.plotNum}',
            tx != 'lokal' ? 'menunggu konfirmasi' : 'lokal tersimpan',
            txHash: tx != 'lokal' ? res ?? '' : '',
          );
          if (tx != 'lokal') {
            unawaited(() async {
              try {
                final receipt = await farmState.chainClient.waitForTransaction(
                  res!,
                );
                if (receipt.confirmed && receipt.success) {
                  farmState.updateHistoryStatus(entryId, status: 'on-chain');
                } else {
                  farmState.updateHistoryStatus(
                    entryId,
                    status: 'gagal on-chain',
                    errorMessage: receipt.message,
                  );
                }
              } catch (_) {}
            }());
          }
        } else if (action.intent == 'harvest') {
          onAiHarvested?.call(action.plotNum - 1);
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Sukses! Hasil panen berhasil diambil. (Tx: $tx)',
              time: time,
            ),
          );
          final entryId = farmState.addExternalHistory(
            'Panen ${['Kentang', 'Bawang', 'Stroberi', 'Bit'][['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(action.seed) != -1 ? ['Kentang', 'Bawang', 'Stroberi', 'Bit'].indexOf(action.seed) : 0]}',
            '+3 panen',
            tx != 'lokal' ? 'menunggu konfirmasi' : 'lokal tersimpan',
            txHash: tx != 'lokal' ? res ?? '' : '',
          );
          if (tx != 'lokal') {
            unawaited(() async {
              try {
                final receipt = await farmState.chainClient.waitForTransaction(
                  res!,
                );
                if (receipt.confirmed && receipt.success) {
                  farmState.updateHistoryStatus(entryId, status: 'on-chain');
                } else {
                  farmState.updateHistoryStatus(
                    entryId,
                    status: 'gagal on-chain',
                    errorMessage: receipt.message,
                  );
                }
              } catch (_) {}
            }());
          }
        } else if (action.intent == 'buy') {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Selesai! Saya membeli 3 benih ${action.seed}. (Tx: $tx)',
              time: time,
            ),
          );
          final entryId = farmState.addExternalHistory(
            'Beli ${action.seed}',
            '-60 coin',
            tx != 'lokal' ? 'menunggu konfirmasi' : 'lokal tersimpan',
            txHash: tx != 'lokal' ? res ?? '' : '',
          );
          if (tx != 'lokal') {
            unawaited(() async {
              try {
                final receipt = await farmState.chainClient.waitForTransaction(
                  res!,
                );
                if (receipt.confirmed && receipt.success) {
                  farmState.updateHistoryStatus(entryId, status: 'on-chain');
                } else {
                  farmState.updateHistoryStatus(
                    entryId,
                    status: 'gagal on-chain',
                    errorMessage: receipt.message,
                  );
                }
              } catch (_) {}
            }());
          }
        } else if (action.intent == 'sell') {
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text: 'Hore! Seluruh hasil panen terjual. (Tx: $tx)',
              time: time,
            ),
          );
          final entryId = farmState.addExternalHistory(
            'Jual panen Kentang',
            '+105 coin',
            tx != 'lokal' ? 'menunggu konfirmasi' : 'lokal tersimpan',
            txHash: tx != 'lokal' ? res ?? '' : '',
          );
          if (tx != 'lokal') {
            unawaited(() async {
              try {
                final receipt = await farmState.chainClient.waitForTransaction(
                  res!,
                );
                if (receipt.confirmed && receipt.success) {
                  farmState.updateHistoryStatus(entryId, status: 'on-chain');
                } else {
                  farmState.updateHistoryStatus(
                    entryId,
                    status: 'gagal on-chain',
                    errorMessage: receipt.message,
                  );
                }
              } catch (_) {}
            }());
          }
        } else if (action.intent == 'withdraw') {
          // Subtract coins locally since it's simulated in Local AI Mode
          if (farmState.coins >= amount) {
            farmState.coins -= amount;
            farmState.notifyExternalChange();
          }
          _appendMessage(
            ChatMessage(
              sender: aiAgent!.name,
              wallet: aiAgent!.wallet,
              text:
                  'Withdraw $amount Game Coin ke ETH Sepolia berhasil! (Tx: $tx)',
              time: time,
            ),
          );
          final entryId = farmState.addExternalHistory(
            'Payout Game Coin ke ETH',
            '-$amount coin',
            tx != 'lokal' ? 'menunggu konfirmasi' : 'lokal tersimpan',
            txHash: tx != 'lokal' ? res ?? '' : '',
          );
          if (tx != 'lokal') {
            unawaited(() async {
              try {
                final receipt = await farmState.chainClient.waitForTransaction(
                  res!,
                );
                if (receipt.confirmed && receipt.success) {
                  farmState.updateHistoryStatus(entryId, status: 'on-chain');
                } else {
                  farmState.updateHistoryStatus(
                    entryId,
                    status: 'gagal on-chain',
                    errorMessage: receipt.message,
                  );
                }
              } catch (_) {}
            }());
          }
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
        } else if (action.intent == 'withdraw') {
          final amount = math.min(50, farmState.coins);
          if (farmState.coins >= amount) {
            farmState.coins -= amount;
            farmState.notifyExternalChange();
          }
          farmState.addExternalHistory(
            'Payout Game Coin ke ETH',
            '-$amount coin',
            'lokal tersimpan',
          );
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

  Future<String> _submitChainActionWithRetry(
    String wallet,
    String actionType,
    int plotNum,
    int amount,
  ) async {
    try {
      return await farmState.submitChainActionDirectly(
        wallet,
        actionType,
        plotNum,
        amount,
      );
    } catch (e) {
      if (!e.toString().toLowerCase().contains('replacement fee too low')) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      return farmState.submitChainActionDirectly(
        wallet,
        actionType,
        plotNum,
        amount,
      );
    }
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

    final current = Offset(aiAgent!.x, aiAgent!.y);
    final safeCurrent = _pushOutOfShopBounds(current);
    if (safeCurrent != current) {
      aiAgent!
        ..x = safeCurrent.dx
        ..y = safeCurrent.dy;
      notifyListeners();
    }

    // Generate waypoints path to follow the roads and avoid fences/obstacles
    final waypoints = _calculateAiPath(
      Offset(aiAgent!.x, aiAgent!.y),
      finalTarget,
    );
    _followWaypoints(waypoints, 0, onArrival);
  }

  List<Offset> _calculateAiPath(Offset start, Offset target) {
    final path = <Offset>[];

    const innerY = 21.65 * 128.0; // Inner corridor below field decorations.
    const outerY = _shopFrontY; // Front road below the shop and fence
    const gateX =
        5.0 * 128.0; // Gate X coordinate (below Plot 1, next to lake/lake-path)
    const mainRoadX = 18.5 * 128.0; // Vertical main road X

    final safeStart = _moveOutOfShopBounds(start, path);

    // Define areas based on the horizontal fence at Y = 23.0 * 128 and vertical fence at X = 14.0 * 128.
    // Use safeStart so a character already clipped into the shop routes from the escape point.
    final startInside =
        safeStart.dx < 14.0 * 128.0 && safeStart.dy < 23.0 * 128.0;
    final targetInside = target.dx < 14.0 * 128.0 && target.dy < 23.0 * 128.0;

    if (startInside && targetInside) {
      // Both inside the fence: walk along the lower inner corridor.
      path.add(Offset(safeStart.dx, innerY));
      path.add(Offset(target.dx, innerY));
      path.add(target);
    } else if (startInside && !targetInside) {
      if (_isShopFrontTarget(target)) {
        return _calculateShopPathFromInside(safeStart, target);
      }

      // Inside to outside: use the gate, then the nearest outside road.
      path.add(Offset(safeStart.dx, innerY));
      path.add(const Offset(gateX, innerY));
      path.add(const Offset(gateX, outerY));
      path.add(const Offset(mainRoadX, outerY));
      path.add(Offset(mainRoadX, target.dy));
      path.add(target);
    } else if (!startInside && targetInside) {
      // Outside to Inside: go to main road, walk left along road to gateX, go up, then to target
      path.add(Offset(safeStart.dx, outerY));
      path.add(const Offset(mainRoadX, outerY));
      path.add(const Offset(gateX, outerY));
      path.add(const Offset(gateX, innerY));
      path.add(Offset(target.dx, innerY));
      path.add(target);
    } else {
      // Both outside: walk along the front road and avoid crossing the shop.
      path.add(Offset(safeStart.dx, outerY));
      if (target.dy == outerY && target.dx < _shopRight) {
        path.add(const Offset(_shopSafeX, outerY));
      } else {
        path.add(const Offset(mainRoadX, outerY));
        path.add(Offset(mainRoadX, target.dy));
      }
      path.add(target);
    }

    return path;
  }

  List<Offset> _calculateShopPathFromInside(Offset start, Offset target) {
    const upperSafeY = 18.35 * _tileSize;
    const shopBypassX = 6.25 * _tileSize;

    return <Offset>[
      Offset(start.dx, upperSafeY),
      const Offset(shopBypassX, upperSafeY),
      const Offset(shopBypassX, _shopFrontY),
      Offset(target.dx, _shopFrontY),
      target,
    ];
  }

  bool _isShopFrontTarget(Offset target) {
    return target.dx >= _shopLeft &&
        target.dx <= _shopRight &&
        (target.dy - _shopFrontY).abs() < 2.0;
  }

  Offset _moveOutOfShopBounds(Offset start, List<Offset> path) {
    if (!_isInsideShopBounds(start)) {
      return start;
    }

    final safe = _pushOutOfShopBounds(start);
    path.add(safe);
    return safe;
  }

  bool _isInsideShopBounds(Offset point) {
    return point.dx >= _shopLeft &&
        point.dx <= _shopRight &&
        point.dy >= _shopTop &&
        point.dy <= _shopBottom;
  }

  Offset _pushOutOfShopBounds(Offset point) {
    if (!_isInsideShopBounds(point)) {
      return point;
    }

    const padding = 10.0;
    final leftDistance = (point.dx - _shopLeft).abs();
    final rightDistance = (_shopRight - point.dx).abs();
    final topDistance = (point.dy - _shopTop).abs();
    final bottomDistance = (_shopBottom - point.dy).abs();
    final nearest = math.min(
      math.min(leftDistance, rightDistance),
      math.min(topDistance, bottomDistance),
    );

    if (nearest == bottomDistance) {
      return Offset(point.dx, _shopBottom + padding);
    }
    if (nearest == rightDistance) {
      return Offset(_shopRight + padding, point.dy);
    }
    if (nearest == leftDistance) {
      return Offset(_shopLeft - padding, point.dy);
    }
    return Offset(point.dx, _shopTop - padding);
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

        final nextPosition = _pushOutOfShopBounds(
          Offset(
            aiAgent!.x + (dx / distance) * speed,
            aiAgent!.y + (dy / distance) * speed,
          ),
        );
        aiAgent!
          ..x = nextPosition.dx
          ..y = nextPosition.dy;
        notifyListeners();
      } else {
        final safeTarget = _pushOutOfShopBounds(target);
        aiAgent!
          ..x = safeTarget.dx
          ..y = safeTarget.dy;
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
