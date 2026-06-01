import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chain/chain_client.dart';

enum GamePanel { history, backpack, settings }

enum PlotStatus { empty, growing }

enum GameInteraction {
  none,
  shop,
  sellHarvest,
  swapToken,
  buyLand,
  plant,
  sellLand,
  waitCrop,
  harvest,
}

class SeedStack {
  const SeedStack({
    required this.name,
    required this.quantity,
    required this.price,
    required this.color,
  });

  final String name;
  final int quantity;
  final int price;
  final Color color;

  SeedStack copyWith({int? quantity}) {
    return SeedStack(
      name: name,
      quantity: quantity ?? this.quantity,
      price: price,
      color: color,
    );
  }
}

class CropStack {
  const CropStack({
    required this.name,
    required this.quantity,
    required this.color,
  });

  final String name;
  final int quantity;
  final Color color;

  CropStack copyWith({int? quantity}) {
    return CropStack(
      name: name,
      quantity: quantity ?? this.quantity,
      color: color,
    );
  }
}

class FarmPlotData {
  FarmPlotData({
    required this.tileX,
    required this.tileY,
    required this.tileWidth,
    required this.tileHeight,
    required this.owned,
    this.seedIndex = 0,
    this.status = PlotStatus.empty,
    this.plantedAt,
  });

  final int tileX;
  final int tileY;
  final int tileWidth;
  final int tileHeight;
  bool owned;
  int seedIndex;
  PlotStatus status;
  DateTime? plantedAt;

  bool isReady(DateTime now) {
    final planted = plantedAt;
    return status == PlotStatus.growing &&
        planted != null &&
        now.difference(planted) >= FarmStateController.growDuration;
  }

  double growthProgress(DateTime now) {
    final planted = plantedAt;
    if (status != PlotStatus.growing || planted == null) {
      return 0;
    }
    return (now.difference(planted).inMilliseconds /
            FarmStateController.growDuration.inMilliseconds)
        .clamp(0, 1)
        .toDouble();
  }
}

class HistoryRecord {
  const HistoryRecord({
    required this.title,
    required this.status,
    required this.timeLabel,
    required this.valueLabel,
    this.id = 0,
    this.txHash = '',
  });

  final int id;
  final String title;
  final String status;
  final String timeLabel;
  final String valueLabel;
  final String txHash;

  bool get hasTxHash => isValidTransactionHash(txHash);

  HistoryRecord copyWith({String? status, String? txHash}) {
    return HistoryRecord(
      id: id,
      title: title,
      status: status ?? this.status,
      timeLabel: timeLabel,
      valueLabel: valueLabel,
      txHash: txHash ?? this.txHash,
    );
  }
}

class FarmStateController extends ChangeNotifier {
  FarmStateController({this.onSfx});

  static const Duration growDuration = Duration(seconds: 12);
  static const int landBuyPrice = 250;
  static const int landSellPrice = 175;
  static const int harvestSellPrice = 35;
  static const int seedBundleAmount = 3;
  static const int maxShopBundleQuantity = 9;

  int coins = 620;
  int tani = 86;
  int ownedLand = 1;
  int shopBundleQuantity = 1;
  int swapAmount = 0;
  int selectedSellCropIndex = 0;
  bool walletConnected = false;
  String walletAddress = '';
  String walletNativeBalance = '';
  String chainSignerAddress = '';
  bool walletTaniBalanceAvailable = false;
  bool checkingChain = false;
  ChainConfig chainConfig = const ChainConfig();
  late ChainClient _chainClient = ChainClient(chainConfig);
  int _nextHistoryId = 1;
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
      price: 60,
      color: Color(0xFFAE61DE),
    ),
    const SeedStack(
      name: 'Bawang',
      quantity: 0,
      price: 75,
      color: Color(0xFF7ACD7E),
    ),
    const SeedStack(
      name: 'Stroberi',
      quantity: 0,
      price: 110,
      color: Color(0xFFEC4667),
    ),
    const SeedStack(
      name: 'Bit',
      quantity: 0,
      price: 90,
      color: Color(0xFFF79C58),
    ),
  ];

  final List<int> harvestYields = <int>[3, 4, 5, 4];

  final List<int> cropRows = <int>[5, 3, 1, 7];

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

  int get selectedSwapAmount =>
      coins <= 0 ? 0 : swapAmount.clamp(0, coins).toInt();

  int get growingPlotCount =>
      plots.where((plot) => plot.status == PlotStatus.growing).length;

  int get readyPlotCount {
    final now = DateTime.now();
    return plots.where((plot) => plot.isReady(now)).length;
  }

  String get walletLabel =>
      walletConnected ? _shortAddress(walletAddress) : 'CONNECT WALLET';

  bool get hasGameApi => chainConfig.hasGameApi;

  bool get hasWalletConnect => chainConfig.walletConnectUrl.isNotEmpty;

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

  void refreshGrowth() {
    final now = DateTime.now();
    var changed = false;
    for (final plot in plots) {
      if (plot.isReady(now)) {
        changed = true;
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
    notifyListeners();
  }

  void selectSellCrop(int index) {
    if (index == selectedSellCropIndex || index < 0 || index >= crops.length) {
      return;
    }
    playClick();
    selectedSellCropIndex = index;
    showMessage('Panen dipilih: ${crops[index].name}', notify: false);
    notifyListeners();
  }

  void selectFirstSellableCrop() {
    final first = crops.indexWhere((crop) => crop.quantity > 0);
    selectedSellCropIndex = first < 0 ? 0 : first;
  }

  void configureChain(ChainConfig config) {
    chainConfig = config;
    _chainClient = ChainClient(config);
    if (isValidAddress(config.defaultWalletAddress) && !walletConnected) {
      _storeWalletAddress(config.defaultWalletAddress);
      chainStatus =
          'Wallet default tersambung: ${shortAddress(walletAddress)}. Sync Sepolia...';
      notifyListeners();
      refreshWalletState(revealMessage: false);
      return;
    }
    chainStatus = config.hasGameApi
        ? 'Signer Sepolia siap. Connect wallet supaya aksi punya tx hash.'
        : 'Mode lokal: signer backend belum diset.';
    notifyListeners();
  }

  Future<void> connectWallet(String address) async {
    playClick();
    final cleaned = address.trim();
    if (!isValidAddress(cleaned)) {
      showMessage('Wallet address tidak valid.', success: false);
      return;
    }
    final changed = _storeWalletAddress(cleaned);
    showMessage(
      '${changed ? 'Wallet diganti' : 'Wallet tersimpan'}: ${shortAddress(walletAddress)}',
    );
    await refreshWalletState(revealMessage: true);
  }

  Future<void> connectWalletFromDeepLink(String address) async {
    final cleaned = address.trim();
    if (!isValidAddress(cleaned)) {
      showMessage('Wallet dari wallet app tidak valid.', success: false);
      return;
    }
    _storeWalletAddress(cleaned);
    showMessage('Wallet tersambung: ${shortAddress(walletAddress)}');
    await refreshWalletState(revealMessage: true);
  }

  void disconnectWallet() {
    playClick();
    walletConnected = false;
    walletAddress = '';
    walletNativeBalance = '';
    chainSignerAddress = '';
    walletTaniBalanceAvailable = false;
    checkingChain = false;
    chainStatus = chainConfig.hasGameApi
        ? 'Wallet dilepas. Connect lagi supaya aksi terkirim on-chain.'
        : 'Mode lokal: signer backend belum diset.';
    showMessage('Wallet dilepas.');
    notifyListeners();
  }

  Future<void> refreshWalletState({bool revealMessage = true}) async {
    if (checkingChain) {
      return;
    }
    if (!walletConnected || walletAddress.isEmpty) {
      chainStatus = 'Connect wallet dulu untuk sync saldo.';
      if (revealMessage) {
        showMessage(chainStatus, success: false);
      } else {
        notifyListeners();
      }
      return;
    }
    checkingChain = true;
    chainStatus = 'Sync wallet Sepolia...';
    notifyListeners();
    late final ChainWalletState state;
    try {
      state = await _chainClient.loadWalletState(walletAddress);
    } on Object {
      state = chainConfig.hasGameApi
          ? ChainWalletState.ok(
              message:
                  'Wallet tersambung. API Sepolia aktif; saldo RPC belum kebaca di device.',
              coinBalance: 0,
              coinBalanceAvailable: false,
              nativeEth: '',
              signerAddress: '',
            )
          : ChainWalletState.error('Gagal sync wallet.');
    }
    checkingChain = false;
    chainSignerAddress = state.signerAddress;
    chainStatus = state.message;
    walletNativeBalance = state.nativeEth;
    if (state.success && state.coinBalanceAvailable) {
      tani = state.coinBalance;
      walletTaniBalanceAvailable = true;
    } else if (state.success) {
      walletTaniBalanceAvailable = false;
    }
    if (state.success && walletIsBackendSigner) {
      chainStatus =
          '${state.message} Wallet ini signer backend; pakai wallet pemain untuk payout ETH.';
    }
    if (revealMessage) {
      showMessage(
        state.success ? 'Wallet tersync Sepolia.' : state.message,
        success: state.success,
        notify: false,
      );
    }
    notifyListeners();
  }

  void setShopBundleQuantity(int quantity) {
    playClick();
    shopBundleQuantity = quantity.clamp(1, maxShopBundleQuantity);
    showMessage(
      'Jumlah paket: x$shopBundleQuantity (${seedBundleAmount * shopBundleQuantity} benih)',
      notify: false,
    );
    notifyListeners();
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
        coins > 0
            ? 'Pilih jumlah Game Coin yang mau ditukar ke TANI Sepolia.'
            : 'Coin belum ada untuk diswap.',
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
        coins > 0
            ? 'Tap rumah swap: tukar coin ke TANI.'
            : 'Rumah swap: coin belum ada.',
      GameInteraction.buyLand => 'Tap tanda lahan: beli $landBuyPrice coin.',
      GameInteraction.plant => 'Tap tanda lahan: tanam atau jual lahan kosong.',
      GameInteraction.sellLand =>
        'Tap tanda lahan: jual lahan kosong +$landSellPrice coin.',
      GameInteraction.waitCrop => 'Tanaman masih tumbuh.',
      GameInteraction.harvest => 'Tap tanda lahan: panen tanaman.',
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
        notifyListeners();
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
        plot
          ..seedIndex = selectedSeedIndex
          ..status = PlotStatus.growing
          ..plantedAt = DateTime.now();
        _queueChainAction(
          ChainAction(
            type: 'PLANT',
            plotId: plotIndex + 1,
            amount: selectedSeedIndex + 1,
          ),
          title: 'Tanam ${seed.name}',
          valueLabel: 'plot ${plotIndex + 1}',
        );
        showMessage('Benih ${seed.name} berhasil ditanam.');
        notifyListeners();
        return true;
      case GameInteraction.harvest:
        final seedIndex = plot.seedIndex.clamp(0, harvestYields.length - 1);
        final amount = harvestYields[seedIndex];
        crops[seedIndex] = crops[seedIndex].copyWith(
          quantity: crops[seedIndex].quantity + amount,
        );
        selectedSellCropIndex = seedIndex;
        plot
          ..status = PlotStatus.empty
          ..plantedAt = null;
        _queueChainAction(
          ChainAction(type: 'HARVEST', plotId: plotIndex + 1, amount: amount),
          title: 'Panen ${seeds[seedIndex].name}',
          valueLabel: '+$amount panen',
        );
        showMessage('Panen ${seeds[seedIndex].name} +$amount masuk inventory.');
        notifyListeners();
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
    notifyListeners();
    return true;
  }

  bool buySeeds(int seedIndex) {
    playClick();
    if (seedIndex < 0 || seedIndex >= seeds.length) {
      return false;
    }
    if (chainConfig.hasGameApi && !walletConnected) {
      showMessage(
        'Connect wallet dulu supaya pembelian benih punya tx hash.',
        success: false,
      );
      return false;
    }
    final price = seedTotalPrice(seedIndex);
    if (coins < price) {
      showMessage(
        'Coin belum cukup untuk beli $shopBundleQuantity paket ${seeds[seedIndex].name}.',
        success: false,
      );
      return false;
    }
    final total = seedTotalAmount();
    coins -= price;
    selectedSeedIndex = seedIndex;
    seeds[seedIndex] = seeds[seedIndex].copyWith(
      quantity: seeds[seedIndex].quantity + total,
    );
    _queueChainAction(
      ChainAction(type: 'BUY_SEED', plotId: seedIndex + 1, amount: total),
      title: 'Beli ${seeds[seedIndex].name}',
      valueLabel: '-$price coin',
    );
    showMessage('Berhasil membeli $total benih ${seeds[seedIndex].name}.');
    notifyListeners();
    return true;
  }

  bool sellHarvest() {
    playClick();
    if (harvests <= 0) {
      showMessage('Belum ada hasil panen untuk dijual.', success: false);
      return false;
    }
    if (chainConfig.hasGameApi && !walletConnected) {
      showMessage('Connect wallet dulu sebelum jual panen.', success: false);
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
    _queueChainAction(
      ChainAction(type: 'SELL_CROP', plotId: cropIndex + 1, amount: sold),
      title: 'Jual panen ${crop.name}',
      valueLabel: '+$earned coin',
    );
    selectFirstSellableCrop();
    showMessage('Terjual $sold ${crop.name}. Coin +$earned.');
    notifyListeners();
    return true;
  }

  bool swapCoinsToTani() {
    playClick();
    final amount = selectedSwapAmount;
    if (amount <= 0) {
      showMessage('Masukkan jumlah coin yang mau diswap.', success: false);
      return false;
    }
    if (chainConfig.hasGameApi && !walletConnected) {
      showMessage(
        'Connect wallet dulu sebelum swap ke Sepolia.',
        success: false,
      );
      return false;
    }
    coins -= amount;
    if (!chainConfig.hasGameApi) {
      tani += amount;
    }
    swapAmount = coins;
    _queueChainAction(
      ChainAction(type: 'SWAP_COIN', plotId: 0, amount: amount),
      title: 'Swap coin ke TANI',
      valueLabel: '-$amount coin',
      refundCoinsOnFailure: amount,
      requiresTxHash: true,
    );
    showMessage(
      chainConfig.hasGameApi
          ? 'Mengirim swap $amount coin ke Sepolia.'
          : 'Swap $amount coin ke TANI tersimpan lokal.',
    );
    notifyListeners();
    return true;
  }

  void setSwapAmount(int amount) {
    swapAmount = amount.clamp(0, math.max(0, coins)).toInt();
    notifyListeners();
  }

  void prepareSwapAmount() {
    final nextAmount = coins <= 0
        ? 0
        : (swapAmount <= 0 || swapAmount > coins ? coins : swapAmount);
    if (swapAmount == nextAmount) {
      return;
    }
    swapAmount = nextAmount;
    notifyListeners();
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
    notifyListeners();
  }

  void setSfxEnabled(bool value) {
    playClick();
    sfxEnabled = value;
    notifyListeners();
  }

  void setMusicVolume(double value) {
    musicVolume = value;
    notifyListeners();
  }

  void setSfxVolume(double value) {
    sfxVolume = value;
    notifyListeners();
  }

  void playClick() {
    if (sfxEnabled) {
      onSfx?.call();
    }
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
    int refundCoinsOnFailure = 0,
    bool requiresTxHash = false,
  }) {
    final entryId = _addHistory(
      title ?? action.label,
      valueLabel,
      status: _initialChainHistoryStatus(),
    );
    if (!walletConnected || !chainConfig.hasGameApi) {
      chainStatus = _localChainStatus(action);
      return;
    }
    unawaited(
      _submitChainAction(
        entryId,
        action,
        refundCoinsOnFailure: refundCoinsOnFailure,
        requiresTxHash: requiresTxHash,
      ),
    );
  }

  Future<void> _submitChainAction(
    int entryId,
    ChainAction action, {
    required int refundCoinsOnFailure,
    required bool requiresTxHash,
  }) async {
    final result = await _chainClient.submitGameAction(walletAddress, action);
    if (result.success) {
      if (requiresTxHash && !isValidTransactionHash(result.txHash)) {
        _handleChainActionFailure(
          entryId,
          action,
          refundCoinsOnFailure,
          'Backend tidak mengembalikan tx hash.',
        );
        return;
      }
      _updateHistory(
        entryId,
        status: isValidTransactionHash(result.txHash) ? 'on-chain' : 'dikirim',
        txHash: result.txHash,
      );
      chainStatus = result.message;
      if (action.type == 'SWAP_COIN' && isValidTransactionHash(result.txHash)) {
        tani += action.amount;
      }
      if (_actionUpdatesCoinBalance(action)) {
        unawaited(refreshWalletState(revealMessage: false));
      }
      notifyListeners();
      return;
    }
    _handleChainActionFailure(
      entryId,
      action,
      refundCoinsOnFailure,
      result.message,
    );
  }

  void _handleChainActionFailure(
    int entryId,
    ChainAction action,
    int refundCoinsOnFailure,
    String reason,
  ) {
    if (refundCoinsOnFailure > 0) {
      coins = math.min(0x7fffffff, coins + refundCoinsOnFailure);
      swapAmount = coins;
      _updateHistory(entryId, status: 'gagal; coin kembali');
      chainStatus =
          '${action.label} gagal; coin dikembalikan +$refundCoinsOnFailure: ${_conciseChainError(reason)}';
      showMessage('Swap gagal, coin dikembalikan.', success: false);
      return;
    }
    _updateHistory(entryId, status: 'belum sync');
    chainStatus =
        '${action.label} tersimpan lokal. ${_conciseChainError(reason)}';
    notifyListeners();
  }

  int _addHistory(String title, String valueLabel, {required String status}) {
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
      ),
    );
    if (history.length > 8) {
      history.removeRange(8, history.length);
    }
    return id;
  }

  void _updateHistory(int entryId, {String? status, String? txHash}) {
    final index = history.indexWhere((record) => record.id == entryId);
    if (index < 0) {
      return;
    }
    history[index] = history[index].copyWith(
      status: status == null ? null : _normalizeHistoryStatus(status),
      txHash: txHash,
    );
  }

  String _initialChainHistoryStatus() {
    if (!walletConnected) {
      return 'butuh wallet';
    }
    if (chainConfig.hasGameApi) {
      return 'mengirim';
    }
    if (chainConfig.hasCoinContract) {
      return 'belum on-chain';
    }
    return 'lokal tersimpan';
  }

  String _localChainStatus(ChainAction action) {
    if (!walletConnected) {
      return '${action.label} tersimpan lokal. Connect wallet untuk sync chain.';
    }
    if (!chainConfig.hasGameApi) {
      return 'Signer backend belum diset; ${action.label} baru tersimpan lokal.';
    }
    return '${action.label} tersimpan lokal.';
  }

  bool _actionUpdatesCoinBalance(ChainAction action) {
    return action.type == 'SELL_LAND' ||
        action.type == 'SELL_CROP' ||
        action.type == 'SWAP_CROP' ||
        action.type == 'SWAP_COIN' ||
        action.type == 'SWAP_ETH_COIN' ||
        action.type == 'SWAP_COIN_ETH';
  }

  String _normalizeHistoryStatus(String status) {
    final lower = status.trim().toLowerCase();
    if (lower.contains('gagal kirim') || lower.contains('gagal sync')) {
      return 'belum sync';
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

  bool _storeWalletAddress(String address) {
    final cleaned = address.trim();
    final changed = cleaned.toLowerCase() != walletAddress.toLowerCase();
    walletConnected = true;
    walletAddress = cleaned;
    if (changed) {
      walletNativeBalance = '';
      chainSignerAddress = '';
      walletTaniBalanceAvailable = false;
      chainStatus =
          'Wallet pemain diganti: ${shortAddress(walletAddress)}. Sync Sepolia...';
    }
    return changed;
  }

  String _conciseChainError(String message) {
    var cleaned = message.trim();
    const prefix = 'Gagal kirim aksi chain:';
    if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
      cleaned = cleaned.substring(prefix.length).trim();
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^HTTP\s+\d+\s*'), '').trim();
    final lower = cleaned.toLowerCase();
    if (lower.contains('wallet penerima eth sama dengan signer backend')) {
      cleaned = 'wallet sama signer; ganti wallet pemain';
    } else if (lower.contains('saldo eth signer backend tidak cukup')) {
      cleaned = 'saldo ETH signer backend kurang';
    } else if (lower.contains('tipe aksi tidak dikenal')) {
      cleaned = 'backend belum support aksi ini';
    } else if (lower.contains('tidak mengembalikan tx hash')) {
      cleaned = 'backend belum mengembalikan tx hash';
    }
    return cleaned.length > 96 ? '${cleaned.substring(0, 93)}...' : cleaned;
  }

  String _shortAddress(String address) {
    return shortAddress(address);
  }
}
