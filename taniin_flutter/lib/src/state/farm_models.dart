part of 'farm_state.dart';

enum GamePanel { profile, history, backpack, settings }

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

enum SwapAsset { gameCoin, taniSepolia, ethSepolia }

enum ServiceState { unknown, online, offline }

class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.unlockLevel,
  });

  final String id;
  final String name;
  final String description;
  final Color color;
  final int unlockLevel;
}

class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.xpReward,
  });

  final String id;
  final String title;
  final int target;
  final int progress;
  final int xpReward;

  bool get completed => progress >= target;

  DailyQuest copyWith({int? progress}) => DailyQuest(
    id: id,
    title: title,
    target: target,
    progress: progress ?? this.progress,
    xpReward: xpReward,
  );
}

extension SwapAssetText on SwapAsset {
  String get label {
    return switch (this) {
      SwapAsset.gameCoin => 'GAME COIN',
      SwapAsset.taniSepolia => 'TANI SEPOLIA',
      SwapAsset.ethSepolia => 'ETH SEPOLIA',
    };
  }

  String get shortLabel {
    return switch (this) {
      SwapAsset.gameCoin => 'coin',
      SwapAsset.taniSepolia => 'TANI',
      SwapAsset.ethSepolia => 'ETH',
    };
  }
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
    this.errorMessage = '',
  });

  final int id;
  final String title;
  final String status;
  final String timeLabel;
  final String valueLabel;
  final String txHash;
  final String errorMessage;

  bool get hasTxHash => isValidTransactionHash(txHash);

  HistoryRecord copyWith({
    String? status,
    String? txHash,
    String? errorMessage,
  }) {
    return HistoryRecord(
      id: id,
      title: title,
      status: status ?? this.status,
      timeLabel: timeLabel,
      valueLabel: valueLabel,
      txHash: txHash ?? this.txHash,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
