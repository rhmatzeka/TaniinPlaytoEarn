import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chain/auth_session.dart';
import '../chain/chain_client.dart';
import '../chain/platform_bridge.dart';

part 'farm_models.dart';

class FarmStateController extends ChangeNotifier {
  static const int minEthSwapAmount = 100;
  static const int maxOnChainSwapAmount = 10000;
  FarmStateController({
    this.onSfx,
    ChainClient Function(ChainConfig)? chainClientFactory,
  }) : _chainClientFactory = chainClientFactory ?? _defaultChainClientFactory {
    _chainClient = _chainClientFactory(chainConfig);
  }

  static ChainClient _defaultChainClientFactory(ChainConfig config) {
    return ChainClient(config);
  }

  static const Duration growDuration = Duration(seconds: 12);
  static const int landBuyPrice = 1000;
  static const int landSellPrice = 750;
  static const int harvestSellPrice = 50;
  static const int seedBundleAmount = 3;
  static const int maxShopBundleQuantity = 9;
  static const String _saveKey = 'taniin.farmState.v1';
  static const String _playerSaveKey = 'taniin.farmState.player.v1';
  static const String _sessionKey = 'taniin.session.v1';
  static const String _pkceKey = 'taniin.pkce.v1';
  static const int _saveVersion = 1;
  static const Duration _payoutBalancePollDelay = Duration(seconds: 2);
  static const int _payoutBalancePollAttempts = 8;
  static final BigInt _weiPerEth = BigInt.parse('1000000000000000000');

  static const List<CosmeticItem> cosmeticCatalog = <CosmeticItem>[
    CosmeticItem(
      id: 'farmer_classic',
      name: 'Petani Klasik',
      description: 'Tampilan asli untuk memulai perjalanan.',
      color: Color(0xFFFFFFFF),
      unlockLevel: 1,
    ),
    CosmeticItem(
      id: 'farmer_nusantara',
      name: 'Petani Nusantara',
      description: 'Palet hangat terinspirasi panen Nusantara.',
      color: Color(0xFFFFC66D),
      unlockLevel: 2,
    ),
    CosmeticItem(
      id: 'forest_keeper',
      name: 'Penjaga Hutan',
      description: 'Palet hijau untuk sahabat alam.',
      color: Color(0xFF8FE39A),
      unlockLevel: 4,
    ),
  ];

  int coins = 620;
  int tani = 86;
  String playerName = 'Petani Baru';
  int playerXp = 0;
  String equippedCosmeticId = 'farmer_classic';
  final Set<String> ownedCosmeticIds = <String>{'farmer_classic'};
  final Set<String> unlockedAchievements = <String>{};
  List<DailyQuest> dailyQuests = <DailyQuest>[
    const DailyQuest(
      id: 'plant',
      title: 'Tanam 3 benih',
      target: 3,
      progress: 0,
      xpReward: 30,
    ),
    const DailyQuest(
      id: 'harvest',
      title: 'Panen 2 kali',
      target: 2,
      progress: 0,
      xpReward: 40,
    ),
    const DailyQuest(
      id: 'sell',
      title: 'Jual hasil panen',
      target: 1,
      progress: 0,
      xpReward: 30,
    ),
  ];
  int ownedLand = 1;
  int shopBundleQuantity = 1;
  int swapAmount = 0;
  SwapAsset swapFromAsset = SwapAsset.gameCoin;
  SwapAsset swapToAsset = SwapAsset.taniSepolia;
  int selectedSellCropIndex = 0;
  bool walletConnected = false;
  String walletAddress = '';
  AuthSession? session;
  ServiceState sepoliaState = ServiceState.unknown;
  ServiceState serverState = ServiceState.unknown;
  final math.Random _random = math.Random.secure();
  String walletNativeBalance = '';
  String walletNativeWei = '';
  String ethWeiPerCoin = '';
  String maxEthPayoutWei = '';
  String chainSignerAddress = '';
  bool walletTaniBalanceAvailable = false;
  bool checkingChain = false;
  int _walletRequestGeneration = 0;
  ChainConfig chainConfig = const ChainConfig();
  final ChainClient Function(ChainConfig) _chainClientFactory;
  late ChainClient _chainClient;
  ChainClient get chainClient => _chainClient;
  int _nextHistoryId = 1;
  Timer? _saveDebounce;
  final Set<int> _readyPlotIndexes = <int>{};
  bool _persistenceReady = false;
  bool _restoringPersistence = false;
  String chainStatus =
      'Mode lokal: aksi tersimpan di game sampai wallet disambungkan.';
  String statusTitle = 'Info';
  String statusMessage = '';
  DateTime? statusUntil;
  double musicVolume = 0.65;
  double sfxVolume = 0.8;
  bool musicEnabled = true;
  bool sfxEnabled = true;
  final VoidCallback? onSfx;

  final List<SeedStack> seeds = <SeedStack>[
    const SeedStack(
      name: 'Kentang',
      quantity: 6,
      price: 100,
      color: Color(0xFFAE61DE),
    ),
    const SeedStack(
      name: 'Bawang',
      quantity: 0,
      price: 140,
      color: Color(0xFF7ACD7E),
    ),
    const SeedStack(
      name: 'Stroberi',
      quantity: 0,
      price: 220,
      color: Color(0xFFEC4667),
    ),
    const SeedStack(
      name: 'Bit',
      quantity: 0,
      price: 180,
      color: Color(0xFFF79C58),
    ),
  ];

  final List<int> harvestYields = <int>[3, 4, 5, 4];

  final List<int> cropRows = <int>[5, 3, 1, 7];

  /// Row in spring_crops.png (16x32 cells) for the shop and inventory sprites.
  int cropSpriteRow(int seedIndex) => cropRows[seedIndex] ~/ 2;

  final List<FarmPlotData> plots = <FarmPlotData>[
    FarmPlotData(tileX: 4, tileY: 19, tileWidth: 2, tileHeight: 4, owned: true),
    FarmPlotData(
      tileX: 6,
      tileY: 19,
      tileWidth: 2,
      tileHeight: 4,
      owned: false,
    ),
    FarmPlotData(
      tileX: 8,
      tileY: 19,
      tileWidth: 2,
      tileHeight: 4,
      owned: false,
    ),
    FarmPlotData(
      tileX: 10,
      tileY: 19,
      tileWidth: 2,
      tileHeight: 4,
      owned: false,
    ),
    FarmPlotData(
      tileX: 12,
      tileY: 19,
      tileWidth: 2,
      tileHeight: 4,
      owned: false,
    ),
  ];

  final List<CropStack> crops = <CropStack>[
    const CropStack(name: 'Kentang', quantity: 0, color: Color(0xFFAE61DE)),
    const CropStack(name: 'Bawang', quantity: 0, color: Color(0xFF7ACD7E)),
    const CropStack(name: 'Stroberi', quantity: 0, color: Color(0xFFEC4667)),
    const CropStack(name: 'Bit', quantity: 0, color: Color(0xFFF79C58)),
  ];

  final List<HistoryRecord> history = <HistoryRecord>[
    const HistoryRecord(
      title: 'Game dimulai',
      status: 'Local saved',
      timeLabel: 'now',
      valueLabel: '+6 seed',
    ),
  ];

  int selectedSeedIndex = 0;

  SeedStack get selectedSeed => seeds[selectedSeedIndex];

  CropStack get selectedSellCrop => crops[selectedSellCropIndex];

  int get totalSeeds => seeds.fold(0, (total, seed) => total + seed.quantity);

  int get totalCrops => crops.fold(0, (total, crop) => total + crop.quantity);

  int get harvests => totalCrops;

  int get selectedSellCropValue => selectedSellCrop.quantity * harvestSellPrice;

  int get selectedSwapAmount => swapSourceBalance <= 0
      ? 0
      : swapAmount.clamp(0, swapSourceBalance).toInt();

  int get swapSourceBalance {
    if (swappingGameCoinToEth) {
      return gameCoinEthPayoutCapacity;
    }
    return balanceForSwapAsset(swapFromAsset);
  }

  int get swapTargetBalance => balanceForSwapAsset(swapToAsset);

  int get ethCoinCapacity {
    final nativeWei = _readWei(walletNativeWei);
    final weiPerCoin = _readWei(ethWeiPerCoin);
    if (nativeWei <= BigInt.zero || weiPerCoin <= BigInt.zero) {
      return 0;
    }
    var capacity = nativeWei ~/ weiPerCoin;
    final payoutLimit = _readWei(maxEthPayoutWei);
    if (payoutLimit > BigInt.zero) {
      final payoutCapacity = payoutLimit ~/ weiPerCoin;
      if (payoutCapacity < capacity) {
        capacity = payoutCapacity;
      }
    }
    return math.min(maxOnChainSwapAmount, _clampBigIntToGameInt(capacity));
  }

  int get gameCoinEthPayoutCapacity {
    final weiPerCoin = _readWei(ethWeiPerCoin);
    final maxPayout = _readWei(maxEthPayoutWei);
    if (weiPerCoin <= BigInt.zero || maxPayout <= BigInt.zero) {
      return coins;
    }
    final cappedCoins = _clampBigIntToGameInt(maxPayout ~/ weiPerCoin);
    return math.min(coins, cappedCoins);
  }

  bool get swappingGameCoinToTani =>
      swapFromAsset == SwapAsset.gameCoin &&
      swapToAsset == SwapAsset.taniSepolia;

  bool get swappingTaniToGameCoin =>
      swapFromAsset == SwapAsset.taniSepolia &&
      swapToAsset == SwapAsset.gameCoin;

  bool get swappingEthToGameCoin =>
      swapFromAsset == SwapAsset.ethSepolia &&
      swapToAsset == SwapAsset.gameCoin;

  bool get swappingGameCoinToEth =>
      swapFromAsset == SwapAsset.gameCoin &&
      swapToAsset == SwapAsset.ethSepolia;

  String get swapVerb {
    if (swappingTaniToGameCoin) {
      return 'Deposit';
    }
    if (swappingEthToGameCoin) {
      return 'Beli';
    }
    if (swappingGameCoinToEth) {
      return 'Payout';
    }
    return 'Swap';
  }

  String get swapAmountUnitLabel {
    if (swappingEthToGameCoin || swappingGameCoinToEth) {
      return 'Game Coin';
    }
    return swapFromAsset.shortLabel;
  }

  String get swapAmountProgressLabel {
    final unit = swapAmountUnitLabel == 'Game Coin'
        ? 'coin'
        : swapAmountUnitLabel;
    return '$selectedSwapAmount / $swapSourceBalance $unit';
  }

  String get swapRateHintLabel {
    if (!swappingEthToGameCoin && !swappingGameCoinToEth) {
      return '';
    }
    final weiPerCoin = _readWei(ethWeiPerCoin);
    if (weiPerCoin <= BigInt.zero) {
      return 'Sync harga ETH Sepolia';
    }
    final rate = _formatEthWei(weiPerCoin);
    if (swappingGameCoinToEth) {
      final maxCoin = gameCoinEthPayoutCapacity;
      final maxEth = _formatEthWei(_ethWeiForCoinAmount(maxCoin));
      return 'Rate 1 coin = $rate ETH | minimum $minEthSwapAmount coin | max $maxCoin coin ($maxEth ETH)';
    }
    return 'Rate 1 coin = $rate ETH | minimum $minEthSwapAmount coin';
  }

  int balanceForSwapAsset(SwapAsset asset) {
    return switch (asset) {
      SwapAsset.gameCoin => coins,
      SwapAsset.taniSepolia => tani,
      SwapAsset.ethSepolia => ethCoinCapacity,
    };
  }

  String swapBalanceLabel(SwapAsset asset) {
    return switch (asset) {
      SwapAsset.gameCoin => 'Saldo $coins coin',
      SwapAsset.taniSepolia =>
        walletTaniBalanceAvailable
            ? 'Saldo $tani TANI'
            : 'Saldo lokal $tani TANI',
      SwapAsset.ethSepolia => _ethSwapBalanceLabel(),
    };
  }

  String swapCardAmountLabel(SwapAsset asset, int amount, {required bool to}) {
    if (amount <= 0) {
      return '0';
    }
    final sign = to ? '+' : '-';
    if (asset == SwapAsset.ethSepolia) {
      final ethAmount = _formatEthWei(_ethWeiForCoinAmount(amount));
      return ethAmount.isEmpty ? '${sign}ETH' : '$sign$ethAmount ETH';
    }
    return '$sign$amount ${asset.shortLabel}';
  }

  String _ethSwapBalanceLabel() {
    if (!onChainMode) {
      return 'Masuk dulu';
    }
    if (walletNativeWei.isEmpty || walletNativeBalance.isEmpty) {
      return 'Sync wallet ETH';
    }
    if (ethWeiPerCoin.isEmpty) {
      return 'Sync harga ETH';
    }
    final capacity = ethCoinCapacity;
    if (capacity <= 0) {
      return 'ETH $walletNativeBalance belum cukup';
    }
    return 'ETH $walletNativeBalance -> $capacity coin';
  }

  BigInt _readWei(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || !RegExp(r'^\d+$').hasMatch(cleaned)) {
      return BigInt.zero;
    }
    return BigInt.tryParse(cleaned) ?? BigInt.zero;
  }

  BigInt _ethWeiForCoinAmount(int amount) {
    if (amount <= 0) {
      return BigInt.zero;
    }
    final weiPerCoin = _readWei(ethWeiPerCoin);
    if (weiPerCoin <= BigInt.zero) {
      return BigInt.zero;
    }
    return BigInt.from(amount) * weiPerCoin;
  }

  String _formatEthWei(BigInt wei) {
    if (wei <= BigInt.zero) {
      return '';
    }
    final whole = wei ~/ _weiPerEth;
    final fraction = wei.remainder(_weiPerEth);
    if (fraction == BigInt.zero) {
      return whole.toString();
    }
    final fractionText = fraction.toString().padLeft(18, '0').substring(0, 12);
    final compactFraction = fractionText.replaceFirst(RegExp(r'0+$'), '');
    return compactFraction.isEmpty
        ? whole.toString()
        : '$whole.$compactFraction';
  }

  int _clampBigIntToGameInt(BigInt value) {
    if (value <= BigInt.zero) {
      return 0;
    }
    final max = BigInt.from(0x7fffffff);
    return value > max ? 0x7fffffff : value.toInt();
  }

  int get growingPlotCount =>
      plots.where((plot) => plot.status == PlotStatus.growing).length;

  int get readyPlotCount {
    final now = DateTime.now();
    return plots.where((plot) => plot.isReady(now)).length;
  }

  String get walletLabel => isLoggedIn ? _shortAddress(walletAddress) : 'MASUK';

  bool get hasGameApi => chainConfig.hasGameApi;

  bool get isLoggedIn => session != null;

  /// Signed-in players send actions to the server; guests play locally.
  bool get onChainMode => isLoggedIn && chainConfig.hasGameApi;

  bool get canLogin => chainConfig.hasGameApi;

  bool get walletIsBackendSigner =>
      isValidAddress(walletAddress) &&
      isValidAddress(chainSignerAddress) &&
      walletAddress.toLowerCase() == chainSignerAddress.toLowerCase();

  bool get statusVisible {
    final until = statusUntil;
    return until != null &&
        DateTime.now().isBefore(until) &&
        statusMessage.isNotEmpty;
  }

  int get playerLevel => 1 + playerXp ~/ 100;
  int get xpInLevel => playerXp % 100;
  double get levelProgress => xpInLevel / 100;
  CosmeticItem get equippedCosmetic => cosmeticCatalog.firstWhere(
    (item) => item.id == equippedCosmeticId,
    orElse: () => cosmeticCatalog.first,
  );

  void setPlayerName(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return;
    playerName = cleaned.substring(0, math.min(24, cleaned.length));
    _commitState();
  }

  bool equipCosmetic(String id) {
    if (!ownedCosmeticIds.contains(id)) return false;
    equippedCosmeticId = id;
    _commitState();
    return true;
  }

  void _recordProgress(String questId, {int amount = 1}) {
    for (var i = 0; i < dailyQuests.length; i++) {
      final quest = dailyQuests[i];
      if (quest.id != questId || quest.completed) continue;
      final progress = math.min(quest.target, quest.progress + amount);
      dailyQuests[i] = quest.copyWith(progress: progress);
      if (progress >= quest.target) _addXp(quest.xpReward);
    }
    _unlockProgressRewards();
  }

  void _addXp(int amount) {
    playerXp = math.min(0x7fffffff, playerXp + amount);
  }

  void _unlockProgressRewards() {
    for (final item in cosmeticCatalog) {
      if (playerLevel >= item.unlockLevel) ownedCosmeticIds.add(item.id);
    }
    if (playerXp >= 30) unlockedAchievements.add('Langkah Pertama');
    if (playerLevel >= 2) unlockedAchievements.add('Petani Berkembang');
    if (ownedLand >= 5) unlockedAchievements.add('Juragan Lahan');
  }

  Future<void> loadSavedState() async {
    if (_persistenceReady) {
      return;
    }
    var restored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSession = _readSavedSession(prefs);
      if (savedSession != null) {
        _setSession(savedSession);
      }
      final raw = prefs.getString(isLoggedIn ? _playerSaveKey : _saveKey) ??
          prefs.getString(_saveKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        final data = _mapValue(decoded);
        if (data != null) {
          _restoreFromSave(data);
          restored = true;
        }
      }
    } on Object {
      restored = false;
    } finally {
      _persistenceReady = true;
    }
    if (restored) {
      notifyListeners();
    }
  }

  Future<void> saveNow() async {
    if (!_persistenceReady || _restoringPersistence) {
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _writeSavedState();
  }

  void _commitState() {
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    if (!_persistenceReady || _restoringPersistence) {
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      _saveDebounce = null;
      unawaited(_writeSavedState());
    });
  }

  Future<void> _writeSavedState() async {
    if (!_persistenceReady || _restoringPersistence) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        isLoggedIn ? _playerSaveKey : _saveKey,
        jsonEncode(_toSaveJson()),
      );
    } on Object {
      // Keep gameplay responsive even if Android storage is temporarily busy.
    }
  }

  Map<String, Object?> _toSaveJson() {
    return <String, Object?>{
      'version': _saveVersion,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'coins': coins,
      'tani': tani,
      'playerName': playerName,
      'playerXp': playerXp,
      'equippedCosmeticId': equippedCosmeticId,
      'ownedCosmeticIds': ownedCosmeticIds.toList(),
      'unlockedAchievements': unlockedAchievements.toList(),
      'dailyQuests': dailyQuests
          .map(
            (quest) => <String, Object?>{
              'id': quest.id,
              'progress': quest.progress,
            },
          )
          .toList(),
      'ownedLand': ownedLand,
      'shopBundleQuantity': shopBundleQuantity,
      'swapAmount': swapAmount,
      'swapFromAsset': swapFromAsset.name,
      'swapToAsset': swapToAsset.name,
      'selectedSeedIndex': selectedSeedIndex,
      'selectedSellCropIndex': selectedSellCropIndex,
      'musicVolume': musicVolume,
      'sfxVolume': sfxVolume,
      'musicEnabled': musicEnabled,
      'sfxEnabled': sfxEnabled,
      'seedQuantities': seeds.map((seed) => seed.quantity).toList(),
      'cropQuantities': crops.map((crop) => crop.quantity).toList(),
      'plots': plots
          .map(
            (plot) => <String, Object?>{
              'owned': plot.owned,
              'seedIndex': plot.seedIndex,
              'status': plot.status.name,
              'plantedAt': plot.plantedAt?.millisecondsSinceEpoch,
            },
          )
          .toList(),
      'nextHistoryId': _nextHistoryId,
      'history': history
          .map(
            (record) => <String, Object?>{
              'id': record.id,
              'title': record.title,
              'status': record.status,
              'timeLabel': record.timeLabel,
              'valueLabel': record.valueLabel,
              'txHash': record.txHash,
              'errorMessage': record.errorMessage,
            },
          )
          .toList(),
    };
  }

  void _restoreFromSave(Map<String, Object?> data) {
    _restoringPersistence = true;
    try {
      coins = _readInt(data['coins'], coins).clamp(0, 0x7fffffff).toInt();
      tani = _readInt(data['tani'], tani).clamp(0, 0x7fffffff).toInt();
      playerName = _readString(data['playerName'], playerName).trim();
      if (playerName.isEmpty) playerName = 'Petani Baru';
      playerXp = _readInt(
        data['playerXp'],
        playerXp,
      ).clamp(0, 0x7fffffff).toInt();
      final savedOwnedCosmetics = _listValue(data['ownedCosmeticIds']);
      if (savedOwnedCosmetics != null) {
        ownedCosmeticIds
          ..clear()
          ..add('farmer_classic')
          ..addAll(
            savedOwnedCosmetics
                .map((item) => item.toString())
                .where((id) => cosmeticCatalog.any((item) => item.id == id)),
          );
      }
      final savedAchievements = _listValue(data['unlockedAchievements']);
      if (savedAchievements != null) {
        unlockedAchievements
          ..clear()
          ..addAll(savedAchievements.map((item) => item.toString()));
      }
      _unlockProgressRewards();
      final savedEquipped = _readString(
        data['equippedCosmeticId'],
        'farmer_classic',
      );
      equippedCosmeticId = ownedCosmeticIds.contains(savedEquipped)
          ? savedEquipped
          : 'farmer_classic';
      final savedQuests = _listValue(data['dailyQuests']);
      if (savedQuests != null) {
        final progressById = <String, int>{};
        for (final value in savedQuests) {
          final quest = _mapValue(value);
          if (quest != null) {
            progressById[_readString(quest['id'], '')] = _readInt(
              quest['progress'],
              0,
            );
          }
        }
        dailyQuests = dailyQuests
            .map(
              (quest) => quest.copyWith(
                progress: (progressById[quest.id] ?? quest.progress).clamp(
                  0,
                  quest.target,
                ),
              ),
            )
            .toList();
      }
      shopBundleQuantity = _readInt(
        data['shopBundleQuantity'],
        shopBundleQuantity,
      ).clamp(1, maxShopBundleQuantity).toInt();
      selectedSeedIndex = _readIndex(data['selectedSeedIndex'], seeds.length);
      selectedSellCropIndex = _readIndex(
        data['selectedSellCropIndex'],
        crops.length,
      );
      swapFromAsset = _readSwapAsset(data['swapFromAsset'], SwapAsset.gameCoin);
      swapToAsset = _readSwapAsset(data['swapToAsset'], SwapAsset.taniSepolia);
      _normalizeSwapAssets();

      musicVolume = _readDouble(
        data['musicVolume'],
        musicVolume,
      ).clamp(0, 1).toDouble();
      sfxVolume = _readDouble(
        data['sfxVolume'],
        sfxVolume,
      ).clamp(0, 1).toDouble();
      musicEnabled = _readBool(data['musicEnabled'], musicEnabled);
      sfxEnabled = _readBool(data['sfxEnabled'], sfxEnabled);

      final seedQuantities = _listValue(data['seedQuantities']);
      if (seedQuantities != null) {
        for (
          var i = 0;
          i < math.min(seeds.length, seedQuantities.length);
          i++
        ) {
          seeds[i] = seeds[i].copyWith(
            quantity: math.max(
              0,
              _readInt(seedQuantities[i], seeds[i].quantity),
            ),
          );
        }
      }

      final cropQuantities = _listValue(data['cropQuantities']);
      if (cropQuantities != null) {
        for (
          var i = 0;
          i < math.min(crops.length, cropQuantities.length);
          i++
        ) {
          crops[i] = crops[i].copyWith(
            quantity: math.max(
              0,
              _readInt(cropQuantities[i], crops[i].quantity),
            ),
          );
        }
      }

      final savedPlots = _listValue(data['plots']);
      if (savedPlots != null) {
        for (var i = 0; i < math.min(plots.length, savedPlots.length); i++) {
          final savedPlot = _mapValue(savedPlots[i]);
          if (savedPlot == null) {
            continue;
          }
          final plot = plots[i];
          final status = _readPlotStatus(savedPlot['status'], plot.status);
          final plantedAtMs = _readNullableInt(savedPlot['plantedAt']);
          plot
            ..owned = _readBool(savedPlot['owned'], plot.owned)
            ..seedIndex = _readIndex(savedPlot['seedIndex'], seeds.length)
            ..status = status
            ..plantedAt = status == PlotStatus.growing && plantedAtMs != null
                ? DateTime.fromMillisecondsSinceEpoch(plantedAtMs)
                : null;
        }
      }
      ownedLand = _ownedLandCount();
      swapAmount = _readInt(
        data['swapAmount'],
        swapAmount,
      ).clamp(0, math.max(0, swapSourceBalance)).toInt();

      final savedHistory = _listValue(data['history']);
      if (savedHistory != null) {
        final parsedHistory = <HistoryRecord>[];
        var maxHistoryId = 0;
        for (final item in savedHistory.take(8)) {
          final record = _mapValue(item);
          if (record == null) {
            continue;
          }
          final id = _readInt(record['id'], 0);
          maxHistoryId = math.max(maxHistoryId, id);
          parsedHistory.add(
            HistoryRecord(
              id: id,
              title: _readString(record['title'], 'Aksi tersimpan'),
              status: _normalizeHistoryStatus(
                _readString(record['status'], 'lokal tersimpan'),
              ),
              timeLabel: _readString(record['timeLabel'], 'now'),
              valueLabel: _readString(record['valueLabel'], ''),
              txHash: _readString(record['txHash'], ''),
              errorMessage: _readString(record['errorMessage'], ''),
            ),
          );
        }
        if (parsedHistory.isNotEmpty) {
          history
            ..clear()
            ..addAll(parsedHistory);
          _nextHistoryId = math.max(
            _readInt(data['nextHistoryId'], maxHistoryId + 1),
            maxHistoryId + 1,
          );
        }
      }
    } finally {
      _restoringPersistence = false;
    }
  }

  Map<String, Object?>? _mapValue(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return null;
  }

  List<Object?>? _listValue(Object? value) {
    if (value is List) {
      return List<Object?>.from(value);
    }
    return null;
  }

  int _readInt(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    return _readInt(value, 0);
  }

  int _readIndex(Object? value, int length) {
    if (length <= 0) {
      return 0;
    }
    return _readInt(value, 0).clamp(0, length - 1).toInt();
  }

  double _readDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  bool _readBool(Object? value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true') {
        return true;
      }
      if (lower == 'false') {
        return false;
      }
    }
    return fallback;
  }

  String _readString(Object? value, String fallback) {
    if (value is String) {
      return value;
    }
    return fallback;
  }

  PlotStatus _readPlotStatus(Object? value, PlotStatus fallback) {
    if (value is String) {
      for (final status in PlotStatus.values) {
        if (status.name == value) {
          return status;
        }
      }
    }
    if (value is int && value >= 0 && value < PlotStatus.values.length) {
      return PlotStatus.values[value];
    }
    return fallback;
  }

  SwapAsset _readSwapAsset(Object? value, SwapAsset fallback) {
    if (value is String) {
      for (final asset in SwapAsset.values) {
        if (asset.name == value) {
          return asset;
        }
      }
    }
    if (value is int && value >= 0 && value < SwapAsset.values.length) {
      return SwapAsset.values[value];
    }
    return fallback;
  }

  /// Notifies listeners after an external (AI agent / multiplayer) change to
  /// plot state so the HUD and game can repaint.
  void notifyExternalChange() {
    _commitState();
  }

  void refreshGrowth() {
    final now = DateTime.now();
    var changed = false;
    for (var index = 0; index < plots.length; index += 1) {
      final ready = plots[index].isReady(now);
      if (ready && _readyPlotIndexes.add(index)) {
        changed = true;
      } else if (!ready) {
        _readyPlotIndexes.remove(index);
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void selectSeed(int index) {
    if (index == selectedSeedIndex || index < 0 || index >= seeds.length) {
      return;
    }
    playClick();
    selectedSeedIndex = index;
    showMessage('Benih dipilih: ${seeds[index].name}', notify: false);
    _commitState();
  }

  void selectSellCrop(int index) {
    if (index == selectedSellCropIndex || index < 0 || index >= crops.length) {
      return;
    }
    playClick();
    selectedSellCropIndex = index;
    showMessage('Panen dipilih: ${crops[index].name}', notify: false);
    _commitState();
  }

  void selectFirstSellableCrop() {
    final first = crops.indexWhere((crop) => crop.quantity > 0);
    selectedSellCropIndex = first < 0 ? 0 : first;
  }

  void configureChain(ChainConfig config) {
    _walletRequestGeneration += 1;
    checkingChain = false;
    chainConfig = config;
    _chainClient = _chainClientFactory(config);
    chainStatus = isLoggedIn
        ? 'Masuk sebagai ${shortAddress(walletAddress)}. Sync Sepolia...'
        : config.hasGameApi
        ? 'Main sebagai tamu. Masuk dengan Privy supaya panenmu tercatat di Sepolia.'
        : 'Main sebagai tamu. Progres tersimpan di perangkat ini.';
    _commitState();
    unawaited(refreshServiceStatus());
    if (isLoggedIn) {
      unawaited(_syncServerState());
      unawaited(refreshWalletState(revealMessage: false));
    }
  }

  Future<void> refreshServiceStatus() async {
    final client = _chainClient;
    final results = await Future.wait<bool>(<Future<bool>>[
      client.checkSepolia().then((result) => result.success),
      client.checkGameApi(),
    ]);
    if (!identical(client, _chainClient)) {
      return;
    }
    sepoliaState = results[0] ? ServiceState.online : ServiceState.offline;
    serverState = results[1] ? ServiceState.online : ServiceState.offline;
    notifyListeners();
  }

  /// Login page URL. The app adds a PKCE challenge and keeps the verifier, so a
  /// code intercepted from the taniin:// redirect is useless to other apps.
  Future<String> prepareLoginUrl({bool forApp = !kIsWeb}) async {
    if (!forApp) {
      return PlatformBridge.loginUrl(chainConfig, forApp: false);
    }
    final verifier = newCodeVerifier();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pkceKey, verifier);
    return PlatformBridge.loginUrl(
      chainConfig,
      forApp: true,
      challenge: codeChallengeFor(verifier),
    );
  }

  /// Handles the `#session=`, `#code=` or `#fundTx=` fragment from the login page.
  Future<void> handleAuthFragment(String fragment) async {
    final fund = FundCallback.fromFragment(fragment);
    if (fund != null) {
      await handleFundCallback(fund);
      return;
    }
    final codeCallback = AuthCodeCallback.fromFragment(fragment);
    if (codeCallback != null) {
      final prefs = await SharedPreferences.getInstance();
      final verifier = prefs.getString(_pkceKey) ?? '';
      await prefs.remove(_pkceKey);
      final redeemed = verifier.isEmpty
          ? null
          : await _chainClient.redeemLoginCode(codeCallback.code, verifier);
      if (redeemed == null) {
        showMessage('Login gagal atau kedaluwarsa. Coba masuk lagi.', success: false);
        return;
      }
      await applyAuthSession(redeemed);
      return;
    }
    final next = AuthSession.fromFragment(fragment, DateTime.now().toUtc());
    if (next == null) {
      showMessage('Login gagal atau kedaluwarsa. Coba masuk lagi.', success: false);
      return;
    }
    await applyAuthSession(next);
  }

  Future<void> applyAuthSession(AuthSession next) async {
    if (!isLoggedIn) {
      // Keep the guest farm so logout can return to it.
      await saveNow();
    }
    _setSession(next);
    await _writeSession();
    chainStatus = 'Masuk sebagai ${shortAddress(walletAddress)}. Memuat kebun...';
    notifyListeners();
    final player = await _chainClient.fetchPlayer(next);
    if (!identical(session, next)) {
      return;
    }
    if (player.unauthorized) {
      await _expireSession();
      return;
    }
    var state = player.state;
    if (player.success && !player.importedGuest) {
      final imported = await _chainClient.importGuest(next, _guestImportJson());
      if (imported.success) {
        state = imported.state;
      }
    }
    if (state != null) {
      applyServerState(state);
    }
    showMessage(
      player.success
          ? 'Masuk sebagai ${shortAddress(walletAddress)}.'
          : 'Masuk, tapi kebun server belum termuat: ${player.message}',
      success: player.success,
      notify: false,
    );
    _commitState();
    unawaited(refreshWalletState(revealMessage: false));
  }

  /// Server snapshot is the source of truth for a signed-in player's economy.
  void applyServerState(Map<String, Object?> state) {
    _restoreFromSave(state);
    _readyPlotIndexes.clear();
    ownedLand = _ownedLandCount();
    notifyListeners();
  }

  Future<void> logout() async {
    final current = session;
    playClick();
    if (current != null) {
      await saveNow();
      await _chainClient.logout(current);
    }
    await _clearSessionAndRestoreGuest();
    chainStatus = 'Keluar. Main sebagai tamu.';
    showMessage('Kamu sudah keluar.', notify: false);
    _commitState();
  }

  Future<void> handleFundCallback(FundCallback fund) async {
    if (!onChainMode) {
      showMessage('Masuk dulu supaya pembayaran ETH bisa dicatat.', success: false);
      return;
    }
    final action = ChainAction(
      type: 'SWAP_ETH_COIN',
      plotId: 0,
      amount: fund.amount,
      paymentTxHash: fund.txHash,
    );
    final entryId = _addHistory(
      'Beli Game Coin dari ETH',
      '+${fund.amount} coin',
      status: 'menunggu konfirmasi',
      txHash: fund.txHash,
    );
    showMessage('Pembayaran ETH diterima. Menunggu server...', notify: false);
    _commitState();
    await _submitChainAction(entryId, action);
  }

  void _setSession(AuthSession next) {
    session = next;
    walletConnected = true;
    walletAddress = next.wallet;
    walletNativeBalance = '';
    walletNativeWei = '';
    walletTaniBalanceAvailable = false;
  }

  Future<void> _syncServerState() async {
    final current = session;
    if (current == null) {
      return;
    }
    final player = await _chainClient.fetchPlayer(current);
    if (!identical(session, current)) {
      return;
    }
    if (player.unauthorized) {
      await _expireSession();
      return;
    }
    final state = player.state;
    if (player.success && state != null) {
      applyServerState(state);
      _commitState();
    }
  }

  Future<void> _expireSession() async {
    await _clearSessionAndRestoreGuest();
    chainStatus = 'Sesi habis, masuk lagi.';
    showMessage('Sesi habis, masuk lagi.', success: false, notify: false);
    _commitState();
  }

  Future<void> _clearSessionAndRestoreGuest() async {
    // Stop pending saves first: once the session is gone they would write the
    // player's server economy over the guest farm.
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _restoringPersistence = true;
    session = null;
    walletConnected = false;
    walletAddress = '';
    walletNativeBalance = '';
    walletNativeWei = '';
    walletTaniBalanceAvailable = false;
    chainSignerAddress = '';
    checkingChain = false;
    _walletRequestGeneration += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_playerSaveKey);
      final raw = prefs.getString(_saveKey);
      final data = raw == null ? null : _mapValue(jsonDecode(raw));
      _resetEconomyToGuestDefaults();
      if (data != null) {
        _restoreFromSave(data);
      }
    } on Object {
      _resetEconomyToGuestDefaults();
    } finally {
      _restoringPersistence = false;
    }
    ownedLand = _ownedLandCount();
  }

  void _resetEconomyToGuestDefaults() {
    final defaults = FarmStateController();
    _restoreFromSave(defaults._toSaveJson());
    defaults.dispose();
  }

  Map<String, Object?> _guestImportJson() {
    final json = _toSaveJson();
    return <String, Object?>{
      for (final key in <String>[
        'coins',
        'playerXp',
        'seedQuantities',
        'cropQuantities',
        'plots',
      ])
        key: json[key],
    };
  }

  AuthSession? _readSavedSession(SharedPreferences prefs) {
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = _mapValue(jsonDecode(raw));
      final restored = data == null ? null : AuthSession.fromJson(data);
      return restored == null || restored.isExpired ? null : restored;
    } on Object {
      return null;
    }
  }

  Future<void> _writeSession() async {
    final current = session;
    if (current == null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(current.toJson()));
    } on Object {
      // Session stays in memory for this run.
    }
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> refreshWalletState({bool revealMessage = true}) async {
    if (checkingChain) {
      return;
    }
    if (!walletConnected || walletAddress.isEmpty) {
      chainStatus = 'Masuk dengan Privy dulu untuk sync saldo.';
      if (revealMessage) {
        showMessage(chainStatus, success: false);
      } else {
        notifyListeners();
      }
      return;
    }
    checkingChain = true;
    final requestGeneration = ++_walletRequestGeneration;
    final requestedWallet = walletAddress;
    final requestedClient = _chainClient;
    chainStatus = 'Sync wallet Sepolia...';
    notifyListeners();
    late final ChainWalletState state;
    try {
      state = await requestedClient.loadWalletState(requestedWallet);
    } on Object {
      state = chainConfig.hasGameApi
          ? ChainWalletState.ok(
              message:
                  'Wallet tersambung. API Sepolia aktif; saldo RPC belum kebaca di device.',
              coinBalance: 0,
              coinBalanceAvailable: false,
              nativeEth: '',
              nativeWei: '',
              signerAddress: '',
              ethWeiPerCoin: '',
              maxEthPayoutWei: '',
            )
          : ChainWalletState.error('Gagal sync wallet.');
    }
    if (requestGeneration != _walletRequestGeneration ||
        requestedWallet != walletAddress ||
        !walletConnected) {
      return;
    }
    checkingChain = false;
    _applyWalletState(state);
    if (revealMessage) {
      showMessage(
        state.success ? 'Wallet tersync Sepolia.' : state.message,
        success: state.success,
        notify: false,
      );
    }
    _commitState();
  }

  void _applyWalletState(
    ChainWalletState state, {
    bool updateChainStatus = true,
  }) {
    chainSignerAddress = state.signerAddress;
    walletNativeBalance = state.nativeEth;
    walletNativeWei = state.nativeWei;
    ethWeiPerCoin = state.ethWeiPerCoin;
    maxEthPayoutWei = state.maxEthPayoutWei;
    if (state.success && state.coinBalanceAvailable) {
      tani = state.coinBalance;
      walletTaniBalanceAvailable = true;
    } else if (state.success) {
      walletTaniBalanceAvailable = false;
    }
    if (!updateChainStatus) {
      return;
    }
    chainStatus = state.message;
    if (state.success && walletIsBackendSigner) {
      chainStatus =
          '${state.message} Wallet ini signer backend; pakai wallet pemain untuk payout ETH.';
    }
  }

  void setShopBundleQuantity(int quantity) {
    playClick();
    shopBundleQuantity = quantity.clamp(1, maxShopBundleQuantity);
    showMessage(
      'Jumlah paket: x$shopBundleQuantity (${seedBundleAmount * shopBundleQuantity} benih)',
      notify: false,
    );
    _commitState();
  }

  void adjustShopBundleQuantity(int delta) {
    setShopBundleQuantity(shopBundleQuantity + delta);
  }

  int seedTotalPrice(int seedIndex) =>
      seeds[seedIndex].price * shopBundleQuantity;

  int seedTotalAmount() => seedBundleAmount * shopBundleQuantity;

  GameInteraction plotInteraction(int plotIndex) {
    if (plotIndex < 0 || plotIndex >= plots.length) {
      return GameInteraction.none;
    }
    final plot = plots[plotIndex];
    if (!plot.owned) {
      return GameInteraction.buyLand;
    }
    if (plot.status == PlotStatus.empty) {
      return GameInteraction.plant;
    }
    return plot.isReady(DateTime.now())
        ? GameInteraction.harvest
        : GameInteraction.waitCrop;
  }

  String interactionTitle(GameInteraction interaction) {
    return switch (interaction) {
      GameInteraction.shop => 'Ucup',
      GameInteraction.sellHarvest => 'Jual Panen',
      GameInteraction.swapToken => 'Swap Token',
      GameInteraction.buyLand => 'Lahan',
      GameInteraction.plant => 'Tanam',
      GameInteraction.sellLand => 'Jual Lahan',
      GameInteraction.waitCrop => 'Tumbuh',
      GameInteraction.harvest => 'Panen',
      _ => 'Interaksi',
    };
  }

  String interactionBody(GameInteraction interaction, {int? plotIndex}) {
    return switch (interaction) {
      GameInteraction.shop => 'Pilih benih yang mau dibeli memakai Game Coin.',
      GameInteraction.sellHarvest =>
        harvests > 0
            ? 'Pilih tanaman yang mau dijual. ${selectedSellCrop.name} x${selectedSellCrop.quantity} bernilai $selectedSellCropValue coin.'
            : 'Belum ada hasil panen untuk dijual.',
      GameInteraction.swapToken =>
        'Pilih aset dan jumlah untuk Game Coin, TANI Sepolia, atau ETH Sepolia.',
      GameInteraction.buyLand =>
        'Lahan ini bisa dibeli seharga $landBuyPrice coin.',
      GameInteraction.plant =>
        selectedSeed.quantity > 0
            ? 'Tanam ${selectedSeed.name} atau jual lahan kosong +$landSellPrice coin.'
            : 'Benih habis. Buka toko atau jual lahan kosong +$landSellPrice coin.',
      GameInteraction.sellLand =>
        'Jual lahan kosong ini? Coin akan bertambah +$landSellPrice.',
      GameInteraction.waitCrop =>
        'Tanaman siap dalam ${_remainingSeconds(plotIndex)} detik.',
      GameInteraction.harvest => 'Tanaman sudah siap. Panen sekarang?',
      _ => 'Dekati lahan, shop, rumah jual, atau rumah swap dulu.',
    };
  }

  String contextText(GameInteraction interaction, {int? plotIndex}) {
    if (statusVisible) {
      return statusMessage;
    }
    return switch (interaction) {
      GameInteraction.shop => 'Tap toko: beli benih pakai Game Coin.',
      GameInteraction.sellHarvest =>
        harvests > 0
            ? 'Tap rumah jual: pilih panen untuk dijual jadi Game Coin.'
            : 'Rumah jual: belum ada hasil panen.',
      GameInteraction.swapToken =>
        'Tap rumah swap: tukar Game Coin, TANI Sepolia, dan ETH Sepolia.',
      GameInteraction.buyLand => 'Tap tanda BELI: beli $landBuyPrice coin.',
      GameInteraction.plant => 'Tap tanda TANAM: tanam atau jual lahan kosong.',
      GameInteraction.sellLand =>
        'Tap lahan kosong: jual +$landSellPrice coin.',
      GameInteraction.waitCrop => 'Tanaman masih tumbuh.',
      GameInteraction.harvest => 'Tap lahan: panen tanaman.',
      _ => 'Dekati lahan atau toko.',
    };
  }

  bool performPlotAction(int plotIndex) {
    playClick();
    if (plotIndex < 0 || plotIndex >= plots.length) {
      showMessage('Dekati lahan dulu.', success: false);
      return false;
    }
    final plot = plots[plotIndex];
    final interaction = plotInteraction(plotIndex);
    switch (interaction) {
      case GameInteraction.buyLand:
        if (coins < landBuyPrice) {
          showMessage('Coin belum cukup untuk beli tanah.', success: false);
          return false;
        }
        coins -= landBuyPrice;
        plot.owned = true;
        ownedLand = _ownedLandCount();
        _queueChainAction(
          ChainAction(type: 'BUY_LAND', plotId: plotIndex + 1, amount: 1),
          valueLabel: '-$landBuyPrice coin',
        );
        showMessage('Tanah berhasil dibeli.');
        _commitState();
        return true;
      case GameInteraction.plant:
        final seed = selectedSeed;
        if (seed.quantity <= 0) {
          showMessage(
            'Benih ${seed.name} habis. Buka toko dulu.',
            success: false,
          );
          return false;
        }
        seeds[selectedSeedIndex] = seed.copyWith(quantity: seed.quantity - 1);
        _recordProgress('plant');
        plot
          ..seedIndex = selectedSeedIndex
          ..status = PlotStatus.growing
          ..plantedAt = DateTime.now();
        _readyPlotIndexes.remove(plotIndex);
        _queueChainAction(
          ChainAction(
            type: 'PLANT',
            plotId: plotIndex + 1,
            amount: 1,
            seedIndex: selectedSeedIndex,
          ),
          title: 'Tanam ${seed.name}',
          valueLabel: 'plot ${plotIndex + 1}',
        );
        showMessage('Benih ${seed.name} berhasil ditanam.');
        _commitState();
        return true;
      case GameInteraction.harvest:
        final seedIndex = plot.seedIndex.clamp(0, harvestYields.length - 1);
        final amount = harvestYields[seedIndex];
        crops[seedIndex] = crops[seedIndex].copyWith(
          quantity: crops[seedIndex].quantity + amount,
        );
        _recordProgress('harvest');
        selectedSellCropIndex = seedIndex;
        plot
          ..status = PlotStatus.empty
          ..plantedAt = null;
        _readyPlotIndexes.remove(plotIndex);
        _queueChainAction(
          ChainAction(type: 'HARVEST', plotId: plotIndex + 1, amount: amount),
          title: 'Panen ${seeds[seedIndex].name}',
          valueLabel: '+$amount panen',
        );
        showMessage('Panen ${seeds[seedIndex].name} +$amount masuk inventory.');
        _commitState();
        return true;
      case GameInteraction.waitCrop:
        showMessage('Tanaman belum siap panen.', success: false);
        return false;
      default:
        return false;
    }
  }

  bool sellLand(int plotIndex) {
    playClick();
    if (plotIndex < 0 || plotIndex >= plots.length) {
      return false;
    }
    final plot = plots[plotIndex];
    if (!plot.owned ||
        plot.status != PlotStatus.empty ||
        _ownedLandCount() <= 1) {
      showMessage(
        'Lahan terakhir atau lahan berisi tanaman tidak bisa dijual.',
        success: false,
      );
      return false;
    }
    plot
      ..owned = false
      ..seedIndex = 0
      ..plantedAt = null;
    _readyPlotIndexes.remove(plotIndex);
    coins += landSellPrice;
    ownedLand = _ownedLandCount();
    _queueChainAction(
      ChainAction(
        type: 'SELL_LAND',
        plotId: plotIndex + 1,
        amount: landSellPrice,
      ),
      valueLabel: '+$landSellPrice coin',
    );
    showMessage('Lahan terjual. Coin +$landSellPrice.');
    _commitState();
    return true;
  }

  bool buySeeds(int seedIndex) {
    playClick();
    if (seedIndex < 0 || seedIndex >= seeds.length) {
      return false;
    }
    final price = seedTotalPrice(seedIndex);
    if (coins < price) {
      showMessage('Koin belum cukup. Butuh $price koin.', success: false);
      return false;
    }
    final total = seedTotalAmount();
    coins -= price;
    selectedSeedIndex = seedIndex;
    seeds[seedIndex] = seeds[seedIndex].copyWith(
      quantity: seeds[seedIndex].quantity + total,
    );
    _queueChainAction(
      ChainAction(
        type: 'BUY_SEED',
        plotId: 0,
        amount: total,
        seedIndex: seedIndex,
        quantity: shopBundleQuantity,
      ),
      title: 'Beli ${seeds[seedIndex].name}',
      valueLabel: '-$price koin',
    );
    showMessage(
      onChainMode
          ? 'Pembelian $total benih ${seeds[seedIndex].name} dikirim ke Sepolia.'
          : 'Kamu membeli $total benih ${seeds[seedIndex].name}.',
    );
    _commitState();
    return true;
  }

  bool sellHarvest() {
    playClick();
    if (harvests <= 0) {
      showMessage('Belum ada hasil panen untuk dijual.', success: false);
      return false;
    }
    final cropIndex = selectedSellCropIndex.clamp(0, crops.length - 1);
    final crop = crops[cropIndex];
    if (crop.quantity <= 0) {
      showMessage('Pilih tanaman yang stok panennya tersedia.', success: false);
      return false;
    }
    final sold = crop.quantity;
    final earned = sold * harvestSellPrice;
    crops[cropIndex] = crop.copyWith(quantity: 0);
    coins += earned;
    _recordProgress('sell');
    _queueChainAction(
      ChainAction(
        type: 'SELL_CROP',
        plotId: 0,
        amount: sold,
        cropIndex: cropIndex,
      ),
      title: 'Jual panen ${crop.name}',
      valueLabel: '+$earned coin',
    );
    selectFirstSellableCrop();
    showMessage('Terjual $sold ${crop.name}. Coin +$earned.');
    _commitState();
    return true;
  }

  Future<bool> swapSelectedAssets() async {
    playClick();
    _normalizeSwapAssets(preferFrom: true);
    final fromAsset = swapFromAsset;
    final toAsset = swapToAsset;
    final amount = selectedSwapAmount;
    if (fromAsset == toAsset) {
      showMessage('Pilih dua aset yang berbeda untuk swap.', success: false);
      return false;
    }
    if (amount <= 0) {
      showMessage(
        'Saldo ${fromAsset.label} belum cukup untuk swap.',
        success: false,
      );
      return false;
    }
    if (swappingGameCoinToTani) {
      return _swapGameCoinToTani(amount);
    }
    if (swappingTaniToGameCoin) {
      return _swapTaniToGameCoin(amount);
    }
    if (swappingEthToGameCoin) {
      return _swapEthToGameCoin(amount);
    }
    if (swappingGameCoinToEth) {
      return _swapGameCoinToEth(amount);
    }
    showMessage('Pasangan swap belum tersedia.', success: false);
    return false;
  }

  Future<bool> swapCoinsToTani() => swapSelectedAssets();

  bool _swapGameCoinToTani(int amount) {
    coins -= amount;
    if (!onChainMode) {
      tani += amount;
    }
    _clampSwapAmountToSource();
    _queueChainAction(
      ChainAction(type: 'SWAP_COIN', plotId: 0, amount: amount),
      title: 'Swap Game Coin ke TANI',
      valueLabel: '-$amount coin',
    );
    showMessage(
      onChainMode
          ? 'Mengirim swap $amount coin ke Sepolia.'
          : 'Swap $amount coin ke TANI tersimpan lokal.',
    );
    _commitState();
    return true;
  }

  bool _swapTaniToGameCoin(int amount) {
    tani -= amount;
    if (!onChainMode) {
      coins += amount;
    }
    _clampSwapAmountToSource();
    _queueChainAction(
      ChainAction(type: 'SWAP_TANI_COIN', plotId: 0, amount: amount),
      title: 'Deposit TANI ke Game Coin',
      valueLabel: '+$amount coin',
    );
    showMessage(
      onChainMode
          ? 'Mengirim deposit $amount TANI ke Game Coin.'
          : 'Deposit $amount TANI jadi Game Coin tersimpan lokal.',
    );
    _commitState();
    return true;
  }

  // Paying ETH needs the player's own Privy wallet, so it happens on the web
  // `/masuk?aksi=isi-eth` page; the game resumes in handleFundCallback.
  Future<bool> _swapEthToGameCoin(int amount) async {
    if (!onChainMode) {
      showMessage('Masuk dengan Privy dulu untuk pakai ETH Sepolia.', success: false);
      return false;
    }
    if (amount < minEthSwapAmount) {
      showMessage(
        'Isi ETH minimal $minEthSwapAmount coin supaya saldo wallet terlihat berubah.',
        success: false,
      );
      return false;
    }
    final url = PlatformBridge.loginUrl(chainConfig, aksi: 'isi-eth', jumlah: amount);
    final opened = await PlatformBridge.openUrl(url, sameTab: true);
    showMessage(
      opened ? 'Lanjutkan pembayaran ETH di halaman Privy.' : 'Halaman pembayaran gagal dibuka.',
      success: opened,
    );
    return opened;
  }

  bool _swapGameCoinToEth(int amount) {
    if (!onChainMode) {
      showMessage('Masuk dengan Privy dulu untuk payout ETH Sepolia.', success: false);
      return false;
    }
    if (walletNativeWei.isEmpty || walletNativeBalance.isEmpty) {
      showMessage('Sync wallet dulu supaya saldo ETH kebaca.', success: false);
      return false;
    }
    if (ethWeiPerCoin.isEmpty) {
      showMessage('Sync wallet dulu supaya rate ETH kebaca.', success: false);
      return false;
    }
    final payoutCapacity = gameCoinEthPayoutCapacity;
    if (payoutCapacity <= 0) {
      showMessage('Limit payout ETH Sepolia belum tersedia.', success: false);
      return false;
    }
    if (amount > payoutCapacity) {
      showMessage(
        'Payout ETH maksimal $payoutCapacity coin sekali swap.',
        success: false,
      );
      return false;
    }
    if (amount < minEthSwapAmount) {
      showMessage(
        'Payout ETH minimal $minEthSwapAmount coin supaya saldo wallet terlihat berubah.',
        success: false,
      );
      return false;
    }
    coins -= amount;
    _clampSwapAmountToSource();
    final payoutEth = _formatEthWei(_ethWeiForCoinAmount(amount));
    _queueChainAction(
      ChainAction(type: 'SWAP_COIN_ETH', plotId: 0, amount: amount),
      title: 'Payout Game Coin ke ETH',
      valueLabel: payoutEth.isEmpty ? '-$amount coin' : '+$payoutEth ETH',
    );
    showMessage(
      payoutEth.isEmpty
          ? 'Mengirim payout ETH Sepolia dari $amount Game Coin.'
          : 'Mengirim payout +$payoutEth ETH Sepolia dari $amount Game Coin.',
    );
    _commitState();
    return true;
  }

  void setSwapFromAsset(SwapAsset asset) {
    if (asset == swapFromAsset) {
      return;
    }
    playClick();
    final previousFrom = swapFromAsset;
    swapFromAsset = asset;
    if (swapToAsset == asset) {
      swapToAsset = previousFrom;
    }
    _normalizeSwapAssets(preferFrom: true);
    _clampSwapAmountToSource();
    showMessage(
      'Swap ${swapFromAsset.label} ke ${swapToAsset.label}.',
      notify: false,
    );
    _commitState();
  }

  void setSwapToAsset(SwapAsset asset) {
    if (asset == swapToAsset) {
      return;
    }
    playClick();
    final previousTo = swapToAsset;
    swapToAsset = asset;
    if (swapFromAsset == asset) {
      swapFromAsset = previousTo;
    }
    _normalizeSwapAssets(preferFrom: false);
    _clampSwapAmountToSource();
    showMessage(
      'Swap ${swapFromAsset.label} ke ${swapToAsset.label}.',
      notify: false,
    );
    _commitState();
  }

  void reverseSwapAssets() {
    playClick();
    final previousFrom = swapFromAsset;
    swapFromAsset = swapToAsset;
    swapToAsset = previousFrom;
    _normalizeSwapAssets();
    _clampSwapAmountToSource();
    showMessage(
      'Swap dibalik: ${swapFromAsset.label} ke ${swapToAsset.label}.',
      notify: false,
    );
    _commitState();
  }

  void setSwapAmount(int amount) {
    swapAmount = amount.clamp(0, math.max(0, swapSourceBalance)).toInt();
    _commitState();
  }

  void prepareSwapAmount() {
    _normalizeSwapAssets();
    final sourceBalance = swapSourceBalance;
    final nextAmount = sourceBalance <= 0
        ? 0
        : (swapAmount <= 0 || swapAmount > sourceBalance
              ? sourceBalance
              : swapAmount);
    if (swapAmount == nextAmount) {
      return;
    }
    swapAmount = nextAmount;
    _commitState();
  }

  void _normalizeSwapAssets({bool preferFrom = true}) {
    if (swapFromAsset == swapToAsset) {
      if (preferFrom) {
        swapToAsset = _defaultTargetForSwap(swapFromAsset);
      } else {
        swapFromAsset = _defaultSourceForSwap(swapToAsset);
      }
    }
    if (_isSupportedSwapPair(swapFromAsset, swapToAsset)) {
      return;
    }
    if (preferFrom) {
      swapToAsset = _defaultTargetForSwap(swapFromAsset);
    } else {
      swapFromAsset = _defaultSourceForSwap(swapToAsset);
    }
  }

  bool _isSupportedSwapPair(SwapAsset from, SwapAsset to) {
    return (from == SwapAsset.gameCoin && to == SwapAsset.taniSepolia) ||
        (from == SwapAsset.taniSepolia && to == SwapAsset.gameCoin) ||
        (from == SwapAsset.ethSepolia && to == SwapAsset.gameCoin) ||
        (from == SwapAsset.gameCoin && to == SwapAsset.ethSepolia);
  }

  SwapAsset _defaultTargetForSwap(SwapAsset asset) {
    return switch (asset) {
      SwapAsset.gameCoin => SwapAsset.taniSepolia,
      SwapAsset.taniSepolia => SwapAsset.gameCoin,
      SwapAsset.ethSepolia => SwapAsset.gameCoin,
    };
  }

  SwapAsset _defaultSourceForSwap(SwapAsset asset) {
    return switch (asset) {
      SwapAsset.gameCoin => SwapAsset.taniSepolia,
      SwapAsset.taniSepolia => SwapAsset.gameCoin,
      SwapAsset.ethSepolia => SwapAsset.gameCoin,
    };
  }

  void _clampSwapAmountToSource() {
    swapAmount = swapAmount.clamp(0, math.max(0, swapSourceBalance)).toInt();
  }

  void showMessage(String text, {bool success = true, bool notify = true}) {
    statusTitle = success ? 'Berhasil' : 'Perlu aksi';
    statusMessage = text;
    statusUntil = DateTime.now().add(const Duration(seconds: 3));
    if (notify) {
      notifyListeners();
    }
  }

  void setMusicEnabled(bool value) {
    playClick();
    musicEnabled = value;
    _commitState();
  }

  void setSfxEnabled(bool value) {
    playClick();
    sfxEnabled = value;
    _commitState();
  }

  void setMusicVolume(double value) {
    musicVolume = value;
    _commitState();
  }

  void setSfxVolume(double value) {
    sfxVolume = value;
    _commitState();
  }

  void playClick() {
    if (sfxEnabled) {
      onSfx?.call();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_persistenceReady && !_restoringPersistence) {
      unawaited(_writeSavedState());
    }
    super.dispose();
  }

  int _ownedLandCount() => plots.where((plot) => plot.owned).length;

  int _remainingSeconds(int? plotIndex) {
    if (plotIndex == null || plotIndex < 0 || plotIndex >= plots.length) {
      return 0;
    }
    final planted = plots[plotIndex].plantedAt;
    if (planted == null) {
      return 0;
    }
    final remaining = growDuration - DateTime.now().difference(planted);
    return math.max(0, remaining.inSeconds);
  }

  void _queueChainAction(
    ChainAction action, {
    required String valueLabel,
    String? title,
  }) {
    final entryId = _addHistory(
      title ?? action.label,
      valueLabel,
      status: _initialChainHistoryStatus(),
    );
    if (!onChainMode) {
      chainStatus = _localChainStatus(action);
      return;
    }
    unawaited(_submitChainAction(entryId, action));
  }

  // Signed-in flow: the local change is optimistic; the server's state wins.
  Future<void> _submitChainAction(int entryId, ChainAction action) async {
    final current = session;
    if (current == null) {
      return;
    }
    final nativeWeiBeforeAction = action.type == 'SWAP_COIN_ETH'
        ? _readWei(walletNativeWei)
        : BigInt.zero;
    final result = await _chainClient.submitGameAction(
      current,
      action,
      _newIdempotencyKey(),
    );
    if (!identical(session, current)) {
      return;
    }
    if (result.unauthorized) {
      updateHistoryStatus(entryId, status: 'gagal', errorMessage: result.message);
      await _expireSession();
      return;
    }
    if (!result.success) {
      _handleChainActionFailure(entryId, action, result.message);
      await _syncServerState();
      return;
    }
    final state = result.state;
    if (state != null) {
      applyServerState(state);
    }
    if (!isValidTransactionHash(result.txHash)) {
      updateHistoryStatus(entryId, status: 'tersimpan server');
      chainStatus = result.message;
      _commitState();
      return;
    }
    updateHistoryStatus(
      entryId,
      status: 'menunggu konfirmasi',
      txHash: result.txHash,
    );
    chainStatus =
        'Transaksi ${shortTransactionHash(result.txHash)} terkirim. Menunggu konfirmasi Sepolia...';
    _commitState();
    final receipt = await _chainClient.waitForTransaction(result.txHash);
    if (!receipt.confirmed) {
      chainStatus = receipt.message;
      showMessage(
        'Transaksi masih menunggu konfirmasi Sepolia.',
        success: false,
        notify: false,
      );
      _commitState();
      return;
    }
    if (!receipt.success) {
      updateHistoryStatus(
        entryId,
        status: 'gagal on-chain',
        errorMessage: _conciseChainError(receipt.message),
      );
      chainStatus = '${action.label} gagal on-chain.';
      showMessage('Transaksi Sepolia gagal.', success: false, notify: false);
      _commitState();
      return;
    }
    chainStatus = receipt.message;
    if (action.type == 'SWAP_COIN_ETH') {
      final payoutVisible = await _confirmEthPayoutBalance(
        entryId,
        action,
        result.txHash,
        nativeWeiBeforeAction,
      );
      if (payoutVisible) {
        updateHistoryStatus(entryId, status: 'on-chain', txHash: result.txHash);
      }
      _commitState();
      return;
    }
    updateHistoryStatus(entryId, status: 'on-chain', txHash: result.txHash);
    if (_actionUpdatesCoinBalance(action)) {
      await refreshWalletState(revealMessage: false);
    }
    _commitState();
  }

  Future<bool> _confirmEthPayoutBalance(
    int entryId,
    ChainAction action,
    String txHash,
    BigInt nativeWeiBeforeAction,
  ) async {
    final expectedWei = _ethWeiForCoinAmount(action.amount);
    for (var attempt = 0; attempt < _payoutBalancePollAttempts; attempt += 1) {
      try {
        final state = await _chainClient.loadWalletState(walletAddress);
        if (!state.success) {
          continue;
        }
        _applyWalletState(state, updateChainStatus: false);
        final nativeWeiAfterAction = _readWei(state.nativeWei);
        if (nativeWeiAfterAction > nativeWeiBeforeAction) {
          final deltaWei = nativeWeiAfterAction - nativeWeiBeforeAction;
          final deltaEth = _formatEthWei(deltaWei);
          final expectedEth = _formatEthWei(expectedWei);
          updateHistoryStatus(entryId, status: 'on-chain', txHash: txHash);
          chainStatus = expectedEth.isEmpty
              ? 'Payout ETH confirmed. Saldo wallet naik ke ${state.nativeEth} ETH.'
              : 'Payout +$deltaEth ETH confirmed. Saldo wallet ${state.nativeEth} ETH.';
          showMessage(
            expectedEth.isEmpty
                ? 'Payout ETH masuk ke wallet.'
                : 'Payout +$expectedEth ETH masuk ke wallet.',
            notify: false,
          );
          return true;
        }
      } on Object {
        // Receipt sudah confirmed; RPC balance bisa tertinggal beberapa detik.
      }
      if (attempt < _payoutBalancePollAttempts - 1) {
        await Future<void>.delayed(_payoutBalancePollDelay);
      }
    }
    final expectedEth = _formatEthWei(expectedWei);
    updateHistoryStatus(entryId, status: 'menunggu saldo ETH', txHash: txHash);
    chainStatus = expectedEth.isEmpty
        ? 'Receipt Sepolia confirmed, tapi saldo ETH wallet belum naik. Tap Sync Wallet atau cek Etherscan ${shortTransactionHash(txHash)}.'
        : 'Receipt confirmed untuk +$expectedEth ETH, tapi saldo wallet belum naik di RPC. Tap Sync Wallet atau cek Etherscan ${shortTransactionHash(txHash)}.';
    showMessage(
      'Receipt confirmed, menunggu saldo ETH wallet naik.',
      success: false,
      notify: false,
    );
    return false;
  }

  void _handleChainActionFailure(
    int entryId,
    ChainAction action,
    String reason,
  ) {
    final cleanReason = _conciseChainError(reason);
    updateHistoryStatus(entryId, status: 'gagal', errorMessage: cleanReason);
    chainStatus = '${action.label} gagal: $cleanReason';
    showMessage(cleanReason, success: false, notify: false);
    _commitState();
  }

  int addExternalHistory(
    String title,
    String valueLabel,
    String status, {
    String txHash = '',
  }) {
    final now = DateTime.now();
    final id = _nextHistoryId++;
    history.insert(
      0,
      HistoryRecord(
        id: id,
        title: title,
        status: _normalizeHistoryStatus(status),
        timeLabel:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        valueLabel: valueLabel,
        txHash: txHash,
      ),
    );
    if (history.length > 8) {
      history.removeRange(8, history.length);
    }
    _commitState();
    return id;
  }

  void deleteHistoryItem(int id) {
    history.removeWhere((record) => record.id == id);
    _commitState();
  }

  void clearAllHistory() {
    history.clear();
    _commitState();
  }

  int _addHistory(
    String title,
    String valueLabel, {
    required String status,
    String txHash = '',
  }) {
    final now = DateTime.now();
    final id = _nextHistoryId++;
    history.insert(
      0,
      HistoryRecord(
        id: id,
        title: title,
        status: _normalizeHistoryStatus(status),
        timeLabel:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        valueLabel: valueLabel,
        txHash: txHash,
      ),
    );
    if (history.length > 8) {
      history.removeRange(8, history.length);
    }
    return id;
  }

  void updateHistoryStatus(
    int entryId, {
    String? status,
    String? txHash,
    String? errorMessage,
  }) {
    final index = history.indexWhere((record) => record.id == entryId);
    if (index < 0) {
      return;
    }
    history[index] = history[index].copyWith(
      status: status == null ? null : _normalizeHistoryStatus(status),
      txHash: txHash,
      errorMessage: errorMessage,
    );
    _commitState();
  }

  String _initialChainHistoryStatus() => onChainMode ? 'dikirim' : 'lokal tersimpan';

  String _localChainStatus(ChainAction action) {
    return chainConfig.hasGameApi
        ? '${action.label} tersimpan lokal. Masuk dengan Privy supaya tercatat di Sepolia.'
        : '${action.label} tersimpan lokal.';
  }

  bool _actionUpdatesCoinBalance(ChainAction action) {
    return action.type == 'SELL_LAND' ||
        action.type == 'SELL_CROP' ||
        action.type == 'SWAP_CROP' ||
        action.type == 'SWAP_COIN' ||
        action.type == 'SWAP_TANI_COIN' ||
        action.type == 'SWAP_ETH_COIN' ||
        action.type == 'SWAP_COIN_ETH';
  }

  String _normalizeHistoryStatus(String status) {
    final lower = status.trim().toLowerCase();
    if (lower.contains('gagal kirim') || lower.contains('gagal sync')) {
      return 'gagal sync';
    }
    if (lower == 'pending signer' || lower == 'pending lokal') {
      return 'belum on-chain';
    }
    if (lower == 'pending wallet') {
      return 'butuh wallet';
    }
    if (lower == 'local saved' || lower == 'lokal' || lower == 'berhasil') {
      return 'lokal tersimpan';
    }
    if (lower == 'ready to sync') {
      return 'belum sync';
    }
    if (lower == 'dikirim') {
      return 'terkirim signer';
    }
    return status.trim();
  }

  String _conciseChainError(String message) {
    var cleaned = message.trim();
    const prefix = 'Gagal kirim aksi chain:';
    if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
      cleaned = cleaned.substring(prefix.length).trim();
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^HTTP\s+\d+\s*'), '').trim();
    cleaned = cleaned
        .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
        .trim();
    final lower = cleaned.toLowerCase();
    if (lower.contains('timeout') ||
        lower.contains('network error') ||
        lower.contains('tidak terjangkau')) {
      cleaned = 'Server lambat atau offline. Coba lagi sebentar.';
    } else if (lower.contains('wallet penerima sama dengan signer')) {
      cleaned = 'Wallet ini milik server; pakai akun pemain lain.';
    }
    return cleaned.length > 96 ? '${cleaned.substring(0, 93)}...' : cleaned;
  }

  String _shortAddress(String address) {
    return shortAddress(address);
  }
}
