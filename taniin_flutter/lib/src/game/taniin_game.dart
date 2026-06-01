import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/farm_state.dart';
import '../ui/taniin_theme.dart';
import 'tmx_map.dart';

class TaniinGame extends FlameGame {
  TaniinGame(this.farmState);

  static const double _tile = 128;
  static const double _playerSpeed = _tile * 3.9;
  static const double _shopLeftTile = 13.8;
  static const double _shopRightTile = 26.4;
  static const double _shopTopTile = 16.6;
  static const double _shopBottomTile = 31.2;
  static const double _shopSignXTile = 18.5;
  static const double _shopSignYTile = 22.35;
  static const double _shopNpcXTile = 19.18;
  static const double _shopNpcYTile = 25.88;
  static const double _sellLeftTile = 27.0;
  static const double _sellRightTile = 35.4;
  static const double _sellTopTile = 8.7;
  static const double _sellBottomTile = 17.1;
  static const double _sellSignXTile = 31.0;
  static const double _sellSignYTile = 13.35;
  static const double _swapLeftTile = 8.2;
  static const double _swapRightTile = 14.0;
  static const double _swapTopTile = 8.4;
  static const double _swapBottomTile = 16.5;
  static const double _swapSignXTile = 10.85;
  static const double _swapSignYTile = 13.15;
  static const int _miniMapRasterScale = 1;
  static const int _dirRight = 0;
  static const int _dirUp = 1;
  static const int _dirDown = 2;
  static const int _dirLeft = 3;

  final FarmStateController farmState;
  final ValueNotifier<int> hudNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> miniMapNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> loadingComplete = ValueNotifier<bool>(false);
  final ValueNotifier<bool> walkingNotifier = ValueNotifier<bool>(false);
  final Paint _paint = Paint()..isAntiAlias = false;
  final Paint _pixelPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _miniMapPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final Paint _miniMapMarkerPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final List<Rect> _collisionRects = <Rect>[];

  TmxMap? _tmxMap;
  ui.Image? _idleSheet;
  ui.Image? _walkSheet;
  ui.Image? _cropSheet;
  ui.Image? _chicken;
  ui.Image? _babyChicken;
  ui.Image? _cow;
  ui.Image? _maleCow;
  ui.Image? _chickenRed;
  ui.Image? _shopNpcSheet;

  double _clock = 0;
  double _cameraX = 0;
  double _cameraY = 0;
  double _playerX = 18.5 * _tile;
  double _playerY = 28.5 * _tile;
  Offset _inputVector = Offset.zero;
  bool _moving = false;
  int _facingDirection = _dirDown;
  int _walkFrame = 0;
  double _walkTick = 0;
  double _lastPlayerMoveClock = -999;
  double _hudTick = 0;
  Size _visibleViewport = Size.zero;
  ui.Image? _miniMapImage;
  Size _miniMapImageSize = Size.zero;
  bool _miniMapImagePending = false;

  @override
  Color backgroundColor() => TaniinColors.grass;

  void setInputVector(Offset vector) {
    final distance = vector.distance;
    _inputVector = distance > 1 ? vector / distance : vector;
    if (distance <= 0.08) {
      _setWalking(false);
    }
  }

  Offset get playerWorldPosition => Offset(_playerX, _playerY);

  double get miniMapAspectRatio =>
      (_worldHeight / math.max(1, _worldWidth)).clamp(0.82, 0.92).toDouble();

  int? get selectedPlotIndex => _nearestPlotIndex();

  ({GameInteraction interaction, int? plotIndex}) interactionAtScreenPosition(
    Offset screenPosition,
  ) {
    final worldPosition = screenPosition + Offset(_cameraX, _cameraY);
    final plotIndex = _plotIndexAtWorldPosition(worldPosition);
    if (plotIndex != null) {
      return (
        interaction: farmState.plotInteraction(plotIndex),
        plotIndex: plotIndex,
      );
    }
    if (_isNearShop() &&
        (_shopTapBounds().contains(worldPosition) ||
            _signTapBounds(
              _shopSignXTile,
              _shopSignYTile,
              190,
              68,
            ).contains(worldPosition) ||
            _shopNpcTapBounds().contains(worldPosition))) {
      return (interaction: GameInteraction.shop, plotIndex: null);
    }
    if (_isNearSellHouse() &&
        (_houseTapBounds(
              _sellLeftTile,
              _sellTopTile,
              _sellRightTile,
              _sellBottomTile,
            ).contains(worldPosition) ||
            _signTapBounds(
              _sellSignXTile,
              _sellSignYTile,
              230,
              64,
            ).contains(worldPosition))) {
      return (interaction: GameInteraction.sellHarvest, plotIndex: null);
    }
    if (_isNearSwapHouse() &&
        (_houseTapBounds(
              _swapLeftTile,
              _swapTopTile,
              _swapRightTile,
              _swapBottomTile,
            ).contains(worldPosition) ||
            _signTapBounds(
              _swapSignXTile,
              _swapSignYTile,
              230,
              64,
            ).contains(worldPosition))) {
      return (interaction: GameInteraction.swapToken, plotIndex: null);
    }
    return (interaction: GameInteraction.none, plotIndex: null);
  }

  GameInteraction get currentInteraction {
    final plotIndex = selectedPlotIndex;
    if (plotIndex != null) {
      return farmState.plotInteraction(plotIndex);
    }
    if (_isNearShop()) {
      return GameInteraction.shop;
    }
    if (_isNearSellHouse()) {
      return GameInteraction.sellHarvest;
    }
    if (_isNearSwapHouse()) {
      return GameInteraction.swapToken;
    }
    return GameInteraction.none;
  }

  void drawMiniMapPreview(Canvas canvas, Rect bounds) {
    final map = _tmxMap;
    if (map == null) {
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF69B84E);
      canvas.drawRect(bounds, _paint);
    } else {
      final cacheSize = map.miniMapRasterSize(scale: _miniMapRasterScale);
      final cacheWidth = math.max(1, cacheSize.width.round());
      final cacheHeight = math.max(1, cacheSize.height.round());
      final cached = _miniMapImage;
      if (cached != null &&
          _miniMapImageSize.width == cacheWidth &&
          _miniMapImageSize.height == cacheHeight) {
        canvas.drawImageRect(
          cached,
          Rect.fromLTWH(
            0,
            0,
            cached.width.toDouble(),
            cached.height.toDouble(),
          ),
          bounds,
          _miniMapPaint,
        );
      } else {
        map.drawMiniMap(canvas, bounds, _tile);
        _scheduleMiniMapCache(map, cacheWidth, cacheHeight);
      }
    }
    final x =
        bounds.left + (_playerX / math.max(1, _worldWidth)) * bounds.width;
    final y =
        bounds.top + (_playerY / math.max(1, _worldHeight)) * bounds.height;
    final markerCenter = Offset(x, y);
    final markerOuterRadius = (math.min(bounds.width, bounds.height) * 0.035)
        .clamp(7.2, 10.4)
        .toDouble();
    final markerInnerRadius = markerOuterRadius * 0.68;
    _miniMapMarkerPaint
      ..style = PaintingStyle.fill
      ..color = const Color(0x66000000);
    canvas.drawCircle(
      markerCenter + Offset(0, markerOuterRadius * 0.26),
      markerOuterRadius * 1.04,
      _miniMapMarkerPaint,
    );
    _miniMapMarkerPaint.color = Colors.white;
    canvas.drawCircle(markerCenter, markerOuterRadius, _miniMapMarkerPaint);
    _miniMapMarkerPaint.color = const Color(0xFFE12622);
    canvas.drawCircle(markerCenter, markerInnerRadius, _miniMapMarkerPaint);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _tmxMap = await _tryLoadMap();
      _buildCollisionRects();
      _idleSheet = await _tryLoadImage('assets/images/idle.png');
      _walkSheet = await _tryLoadImage('assets/images/walk.png');
      _cropSheet = await _tryLoadImage('assets/images/spring_crops.png');
      _chicken = await _tryLoadImage('assets/images/chicken_blonde_green.png');
      _babyChicken = await _tryLoadImage(
        'assets/images/baby_chicken_yellow.png',
      );
      _cow = await _tryLoadImage('assets/images/female_cow_brown.png');
      _maleCow = await _tryLoadImage('assets/images/male_cow_brown.png');
      _chickenRed = await _tryLoadImage('assets/images/chicken_red.png');
      _shopNpcSheet = await _tryLoadImage(
        'assets/game/Tileset/Cute_Fantasy_Free/Player/Player.png',
      );
    } finally {
      loadingComplete.value = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    _updatePlayer(dt);
    _hudTick += dt;
    if (_hudTick >= 0.12) {
      _hudTick = 0;
      farmState.refreshGrowth();
      hudNotifier.value++;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = _renderScale;
    final viewport = Size(size.x / scale, size.y / scale);
    _visibleViewport = viewport;
    _updateCamera(viewport);

    canvas.drawColor(TaniinColors.grass, BlendMode.src);
    canvas.save();
    canvas.scale(scale);
    final map = _tmxMap;
    if (map == null) {
      _drawFallbackWorld(canvas, viewport);
    } else {
      map.drawBackground(canvas, _cameraX, _cameraY, _tile, viewport);
    }

    _drawBackgroundDecorations(canvas);
    _drawFarmPlots(canvas);
    _drawPlotActionMarkers(canvas);
    _drawShopNpc(canvas);
    _drawPlayer(canvas);
    map?.drawForeground(canvas, _cameraX, _cameraY, _tile, viewport);
    _drawHouseSigns(canvas);
    canvas.restore();
  }

  double get _renderScale {
    final views = ui.PlatformDispatcher.instance.views;
    final ratio = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
    return ratio <= 1 ? 1 : 1 / ratio;
  }

  Future<TmxMap?> _tryLoadMap() async {
    try {
      return await TmxMap.load('assets/game/map.tmx');
    } catch (error) {
      debugPrint('TMX map gagal dimuat: $error');
      return null;
    }
  }

  Future<ui.Image?> _tryLoadImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (error) {
      debugPrint('Asset gagal dimuat $assetPath: $error');
      return null;
    }
  }

  void _buildCollisionRects() {
    _collisionRects
      ..clear()
      ..addAll(_tmxMap?.collisionRects(_tile) ?? const <Rect>[]);
    if (_collisionRects.isEmpty) {
      _addFallbackCollisionRects(_collisionRects);
    }
  }

  void _updatePlayer(double dt) {
    final distance = _inputVector.distance;
    _moving = distance > 0.08;
    if (!_moving) {
      if (_clock - _lastPlayerMoveClock > 0.08) {
        _setWalking(false);
      }
      return;
    }
    final nx = _inputVector.dx / math.max(distance, 0.001);
    final ny = _inputVector.dy / math.max(distance, 0.001);
    _updateFacingDirection(nx, ny);
    final playerMoved = _movePlayer(
      _playerX + nx * _playerSpeed * dt,
      _playerY + ny * _playerSpeed * dt,
    );
    if (playerMoved) {
      _lastPlayerMoveClock = _clock;
      _setWalking(true);
      miniMapNotifier.value++;
    } else if (_clock - _lastPlayerMoveClock > 0.08) {
      _setWalking(false);
    }
    _walkTick += dt;
    if (_walkTick > 0.048) {
      _walkFrame = (_walkFrame + 1) % 6;
      _walkTick = 0;
    }
  }

  void _setWalking(bool walking) {
    if (walkingNotifier.value == walking) {
      return;
    }
    walkingNotifier.value = walking;
  }

  void _scheduleMiniMapCache(TmxMap map, int width, int height) {
    if (_miniMapImagePending) {
      return;
    }
    _miniMapImagePending = true;
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      map.drawMiniMap(
        canvas,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        _tile,
      );
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(width, height);
        _miniMapImage?.dispose();
        _miniMapImage = image;
        _miniMapImageSize = Size(width.toDouble(), height.toDouble());
        miniMapNotifier.value++;
        hudNotifier.value++;
      } finally {
        picture.dispose();
        _miniMapImagePending = false;
      }
    }();
  }

  void _updateFacingDirection(double nx, double ny) {
    final absX = nx.abs();
    final absY = ny.abs();
    if (absX >= 0.30 && absX >= absY * 0.70) {
      _facingDirection = nx < 0 ? _dirLeft : _dirRight;
    } else if (absY >= 0.30) {
      _facingDirection = ny < 0 ? _dirUp : _dirDown;
    }
  }

  bool _movePlayer(double targetX, double targetY) {
    final oldX = _playerX;
    final oldY = _playerY;
    final nextX = targetX
        .clamp(1.2 * _tile, _worldWidth - 1.2 * _tile)
        .toDouble();
    final nextY = targetY
        .clamp(1.2 * _tile, _worldHeight - 1.2 * _tile)
        .toDouble();
    if (!_collidesAt(nextX, _playerY)) {
      _playerX = nextX;
    }
    if (!_collidesAt(_playerX, nextY)) {
      _playerY = nextY;
    }
    return (_playerX - oldX).abs() > 0.5 || (_playerY - oldY).abs() > 0.5;
  }

  bool _collidesAt(double x, double y) {
    final hitbox = _playerHitbox(x, y);
    for (final obstacle in _collisionRects) {
      if (hitbox.overlaps(obstacle)) {
        return true;
      }
    }
    return false;
  }

  Rect _playerHitbox(double x, double y) {
    final halfW = _tile * 0.22;
    return Rect.fromLTRB(
      x - halfW,
      y - _tile * 0.18,
      x + halfW,
      y + _tile * 0.16,
    );
  }

  void _updateCamera(Size viewport) {
    _cameraX = (_playerX - viewport.width * 0.5)
        .clamp(0, math.max(0, _worldWidth - viewport.width))
        .roundToDouble();
    _cameraY = (_playerY - viewport.height * 0.56)
        .clamp(0, math.max(0, _worldHeight - viewport.height))
        .roundToDouble();
  }

  double get _worldWidth => _tmxMap?.getWorldWidthPixels(_tile) ?? 72 * _tile;

  double get _worldHeight => _tmxMap?.getWorldHeightPixels(_tile) ?? 52 * _tile;

  int? _nearestPlotIndex() {
    final player = Offset(_playerX, _playerY);
    return _nearestPlotIndexFor(player);
  }

  int? _nearestPlotIndexFor(Offset position) {
    var nearestIndex = -1;
    var nearestDistance = double.infinity;
    for (var i = 0; i < farmState.plots.length; i++) {
      final plot = farmState.plots[i];
      final rect = Rect.fromLTWH(
        plot.tileX * _tile,
        plot.tileY * _tile,
        plot.tileWidth * _tile,
        plot.tileHeight * _tile,
      ).inflate(_tile * 0.72);
      if (!rect.contains(position)) {
        continue;
      }
      final center = rect.center;
      final distance = (position - center).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex < 0 ? null : nearestIndex;
  }

  int? _plotIndexAtWorldPosition(Offset position) {
    for (var i = 0; i < farmState.plots.length; i++) {
      final plot = farmState.plots[i];
      final directRect = Rect.fromLTWH(
        plot.tileX * _tile,
        plot.tileY * _tile,
        plot.tileWidth * _tile,
        plot.tileHeight * _tile,
      ).inflate(_tile * 0.22);
      final signRect = Rect.fromCenter(
        center: Offset(
          (plot.tileX + plot.tileWidth * 0.5) * _tile,
          (plot.tileY - 0.34) * _tile,
        ),
        width: 190,
        height: 92,
      ).inflate(24);
      if (directRect.contains(position) || signRect.contains(position)) {
        return i;
      }
    }
    return null;
  }

  Rect _shopTapBounds() => _houseTapBounds(
    _shopLeftTile,
    _shopTopTile,
    _shopRightTile,
    _shopBottomTile,
  );

  Rect _houseTapBounds(
    double leftTile,
    double topTile,
    double rightTile,
    double bottomTile,
  ) {
    return Rect.fromLTRB(
      leftTile * _tile,
      topTile * _tile,
      rightTile * _tile,
      bottomTile * _tile,
    ).inflate(_tile * 0.35);
  }

  Rect _signTapBounds(double tileX, double tileY, double width, double height) {
    return Rect.fromCenter(
      center: Offset(tileX * _tile, tileY * _tile),
      width: width + 54,
      height: height + 48,
    );
  }

  Rect _shopNpcTapBounds() {
    final npcSize = _tile * 1.16;
    return Rect.fromCenter(
      center: Offset(_shopNpcXTile * _tile, (_shopNpcYTile - 0.38) * _tile),
      width: npcSize * 0.95,
      height: npcSize * 1.25,
    );
  }

  bool _isNearShop() => _isPlayerInTileRect(
    _shopLeftTile,
    _shopTopTile,
    _shopRightTile,
    _shopBottomTile,
  );

  bool _isNearSellHouse() => _isPlayerInTileRect(
    _sellLeftTile,
    _sellTopTile,
    _sellRightTile,
    _sellBottomTile,
  );

  bool _isNearSwapHouse() => _isPlayerInTileRect(
    _swapLeftTile,
    _swapTopTile,
    _swapRightTile,
    _swapBottomTile,
  );

  bool _isPlayerInTileRect(
    double leftTile,
    double topTile,
    double rightTile,
    double bottomTile,
  ) {
    return _playerX > (leftTile - 1.4) * _tile &&
        _playerX < (rightTile + 1.4) * _tile &&
        _playerY > (topTile - 0.8) * _tile &&
        _playerY < (bottomTile + 2.2) * _tile;
  }

  void _drawFallbackWorld(Canvas canvas, Size viewport) {
    _paint.color = TaniinColors.grass;
    canvas.drawRect(Offset.zero & viewport, _paint);
    _drawWorldRect(
      canvas,
      0,
      26 * _tile,
      72 * _tile,
      2.0 * _tile,
      const Color(0xFFEE9E4E),
    );
    _drawWorldRect(
      canvas,
      44 * _tile,
      5 * _tile,
      2 * _tile,
      24 * _tile,
      const Color(0xFFEE9E4E),
    );
    for (final x in <double>[6, 15, 28, 42, 58]) {
      _drawTree(canvas, x * _tile, 12 * _tile, 1.2);
    }
    _drawWoodHouse(canvas, 16 * _tile, 16 * _tile, true);
    _drawWoodHouse(canvas, 48 * _tile, 10 * _tile, false);
  }

  void _drawBackgroundDecorations(Canvas canvas) {
    final now = (_clock * 1000).round();
    _drawFieldEdgeAnimals(canvas, now);
    _drawOpenMeadowAnimals(canvas, now);
    _drawRoadsideAnimals(canvas, now);
    _drawShopPenAnimals(canvas, now);
  }

  void _drawFarmPlots(Canvas canvas) {
    final cropSheet = _cropSheet;
    final now = DateTime.now();
    final selected = selectedPlotIndex;
    for (var i = 0; i < farmState.plots.length; i++) {
      final plot = farmState.plots[i];
      final rect = _worldRect(
        plot.tileX * _tile,
        plot.tileY * _tile,
        plot.tileWidth * _tile,
        plot.tileHeight * _tile,
      );
      _paint
        ..style = PaintingStyle.fill
        ..color = plot.owned
            ? const Color(0xC1A76431)
            : const Color(0xA04C3325);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        _paint,
      );
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected == i ? 5 : 3
        ..color = selected == i
            ? const Color(0xFFFFE652)
            : plot.owned
            ? const Color(0x88316F3E)
            : const Color(0x995B3923);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        _paint,
      );
      if (plot.status == PlotStatus.growing && cropSheet != null) {
        _drawPlotCrops(canvas, plot, cropSheet, now);
      }
    }
    _paint.style = PaintingStyle.fill;
  }

  void _drawPlotCrops(
    Canvas canvas,
    FarmPlotData plot,
    ui.Image cropSheet,
    DateTime now,
  ) {
    const cell = 16.0;
    final progress = plot.growthProgress(now);
    final stageColumn = plot.isReady(now)
        ? 5
        : (2 + (progress * 3).floor()).clamp(2, 4);
    final cropRow =
        farmState.cropRows[plot.seedIndex
            .clamp(0, farmState.cropRows.length - 1)
            .toInt()];
    for (var row = 0; row < plot.tileHeight; row++) {
      for (var col = 0; col < plot.tileWidth; col++) {
        final source = Rect.fromLTWH(
          stageColumn * cell,
          cropRow * cell,
          cell,
          cell,
        );
        final centerX =
            plot.tileX * _tile + col * _tile + _tile * 0.5 - _cameraX;
        final baseY = plot.tileY * _tile + row * _tile + _tile * 0.9 - _cameraY;
        final size = _tile * 0.62;
        final target = Rect.fromLTWH(
          centerX - size * 0.5,
          baseY - size,
          size,
          size,
        );
        _paint
          ..style = PaintingStyle.fill
          ..color = const Color(0x302D1E12);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX, baseY - size * 0.1),
            width: size * 0.72,
            height: size * 0.16,
          ),
          _paint,
        );
        canvas.drawImageRect(cropSheet, source, target, _pixelPaint);
      }
    }
  }

  void _drawPlotActionMarkers(Canvas canvas) {
    final plotIndex = selectedPlotIndex;
    if (plotIndex == null) {
      return;
    }
    final plot = farmState.plots[plotIndex];
    final label = switch (farmState.plotInteraction(plotIndex)) {
      GameInteraction.buyLand => 'BELI',
      GameInteraction.plant => 'TANAM',
      GameInteraction.waitCrop => 'TUNGGU',
      GameInteraction.harvest => 'PANEN',
      _ => '',
    };
    if (label.isEmpty) {
      return;
    }
    final centerX = (plot.tileX + plot.tileWidth * 0.5) * _tile - _cameraX;
    final centerY = (plot.tileY - 0.34) * _tile - _cameraY;
    final sign = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: label == 'TUNGGU' ? 172 : 148,
      height: 58,
    );
    _drawSignPosts(canvas, sign, 20);
    _drawWoodSignBoard(canvas, sign, label, label == 'TUNGGU' ? 25 : 29, true);
  }

  void _drawShopPenAnimals(Canvas canvas, int now) {
    final chickenFrame = (now ~/ 440) % 4;
    final babyFrame = (now ~/ 520) % 4;
    final cowFrame = (now ~/ 620) % 4;
    final chickenWiggleA = math.sin(now / 360.0) * _tile * 0.025;
    final chickenWiggleB = math.sin(now / 430.0 + 1.7) * _tile * 0.025;
    final babyWiggle = math.sin(now / 390.0 + 2.4) * _tile * 0.020;
    final cowWiggle = math.sin(now / 720.0 + 0.8) * _tile * 0.018;

    _drawSpriteWithShadowWorld(
      _chicken,
      chickenFrame,
      16,
      16,
      4,
      22.38 * _tile + chickenWiggleA,
      18.08 * _tile,
      _tile * 0.50,
      _tile * 0.50,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      (chickenFrame + 1) % 4,
      16,
      16,
      4,
      23.34 * _tile + chickenWiggleB,
      18.42 * _tile,
      _tile * 0.50,
      _tile * 0.50,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _cow,
      cowFrame,
      32,
      32,
      4,
      22.82 * _tile + cowWiggle,
      20.04 * _tile,
      _tile,
      _tile,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      (chickenFrame + 2) % 4,
      16,
      16,
      4,
      23.58 * _tile - chickenWiggleA,
      21.68 * _tile,
      _tile * 0.50,
      _tile * 0.50,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      babyFrame,
      16,
      16,
      4,
      22.42 * _tile + babyWiggle,
      22.00 * _tile,
      _tile * 0.38,
      _tile * 0.38,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      (chickenFrame + 3) % 4,
      16,
      16,
      4,
      22.98 * _tile - chickenWiggleB,
      22.50 * _tile,
      _tile * 0.50,
      _tile * 0.50,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      (babyFrame + 1) % 4,
      16,
      16,
      4,
      23.66 * _tile - babyWiggle,
      22.34 * _tile,
      _tile * 0.38,
      _tile * 0.38,
      canvas,
    );
  }

  void _drawFieldEdgeAnimals(Canvas canvas, int now) {
    final chickenFrame = (now ~/ 440) % 4;
    final babyFrame = (now ~/ 520) % 4;
    _drawSpriteWithShadowWorld(
      _chicken,
      chickenFrame,
      16,
      16,
      4,
      10.86 * _tile,
      24.54 * _tile,
      _tile * 0.50,
      _tile * 0.50,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      babyFrame,
      16,
      16,
      4,
      11.62 * _tile,
      24.92 * _tile,
      _tile * 0.37,
      _tile * 0.37,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      (chickenFrame + 2) % 4,
      16,
      16,
      4,
      13.74 * _tile,
      24.64 * _tile,
      _tile * 0.48,
      _tile * 0.48,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      (babyFrame + 1) % 4,
      16,
      16,
      4,
      14.42 * _tile,
      24.96 * _tile,
      _tile * 0.35,
      _tile * 0.35,
      canvas,
    );
  }

  void _drawOpenMeadowAnimals(Canvas canvas, int now) {
    final chickenFrame = (now ~/ 430) % 4;
    final babyFrame = (now ~/ 510) % 4;
    final cowFrame = (now ~/ 660) % 4;
    final swayA = math.sin(now / 520.0) * _tile * 0.018;
    final swayB = math.sin(now / 610.0 + 1.8) * _tile * 0.018;
    _drawSpriteWithShadowWorld(
      _chickenRed,
      chickenFrame,
      16,
      16,
      4,
      19.70 * _tile + swayA,
      28.24 * _tile,
      _tile * 0.54,
      _tile * 0.54,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      babyFrame,
      16,
      16,
      4,
      20.38 * _tile - swayB,
      28.68 * _tile,
      _tile * 0.38,
      _tile * 0.38,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _maleCow,
      cowFrame,
      32,
      32,
      4,
      24.10 * _tile + swayB,
      28.14 * _tile,
      _tile * 1.04,
      _tile * 1.04,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      (chickenFrame + 2) % 4,
      16,
      16,
      4,
      24.18 * _tile - swayA,
      30.22 * _tile,
      _tile * 0.52,
      _tile * 0.52,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _babyChicken,
      (babyFrame + 1) % 4,
      16,
      16,
      4,
      24.82 * _tile + swayA,
      30.58 * _tile,
      _tile * 0.38,
      _tile * 0.38,
      canvas,
    );
  }

  void _drawRoadsideAnimals(Canvas canvas, int now) {
    final chickenFrame = (now ~/ 470) % 4;
    final cowFrame = (now ~/ 690) % 4;
    final drift = math.sin(now / 720.0) * _tile * 0.016;
    _drawSpriteWithShadowWorld(
      _cow,
      cowFrame,
      32,
      32,
      4,
      31.18 * _tile + drift,
      29.22 * _tile,
      _tile * 1.02,
      _tile * 1.02,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chicken,
      chickenFrame,
      16,
      16,
      4,
      34.62 * _tile - drift,
      31.48 * _tile,
      _tile * 0.52,
      _tile * 0.52,
      canvas,
    );
    _drawSpriteWithShadowWorld(
      _chickenRed,
      (chickenFrame + 1) % 4,
      16,
      16,
      4,
      35.20 * _tile + drift,
      31.82 * _tile,
      _tile * 0.52,
      _tile * 0.52,
      canvas,
    );
  }

  void _drawShopNpc(Canvas canvas) {
    final sheet = _shopNpcSheet;
    if (sheet == null) {
      return;
    }
    final footWorldX = 19.18 * _tile;
    final footWorldY = 25.88 * _tile;
    final npcSize = _tile * 1.16;
    final footX = footWorldX - _cameraX;
    final footY = footWorldY - _cameraY;
    if (_isOffscreen(
      Rect.fromCenter(
        center: Offset(footX, footY),
        width: npcSize,
        height: npcSize,
      ),
    )) {
      return;
    }
    final sway = math.sin((_clock * 1000) / 620.0) * 1.2;
    final worldX = footWorldX - npcSize * 0.5 + sway;
    final worldY = footWorldY - npcSize * (25 / 32);
    final frame = ((_clock * 1000) ~/ 340) % 6;
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x52000000);
    canvas.drawOval(
      Rect.fromLTRB(
        footX - npcSize * 0.18,
        footY - npcSize * 0.045,
        footX + npcSize * 0.18,
        footY + npcSize * 0.055,
      ),
      _paint,
    );
    _drawSpriteWorld(
      sheet,
      frame,
      32,
      32,
      6,
      worldX,
      worldY,
      npcSize,
      npcSize,
      canvas,
    );
  }

  void _drawSpriteWithShadowWorld(
    ui.Image? image,
    int frame,
    int frameW,
    int frameH,
    int columns,
    double worldX,
    double worldY,
    double width,
    double height,
    Canvas canvas,
  ) {
    if (image == null) {
      return;
    }
    final centerX = worldX + width * 0.5 - _cameraX;
    final centerY = worldY + height * 0.87 - _cameraY;
    if (_isOffscreen(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height,
      ),
    )) {
      return;
    }
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x3E000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width * 0.72,
        height: math.max(5, height * 0.16),
      ),
      _paint,
    );
    _drawSpriteWorld(
      image,
      frame,
      frameW,
      frameH,
      columns,
      worldX,
      worldY,
      width,
      height,
      canvas,
    );
  }

  void _drawSpriteWorld(
    ui.Image image,
    int frame,
    int frameW,
    int frameH,
    int columns,
    double worldX,
    double worldY,
    double width,
    double height,
    Canvas canvas,
  ) {
    final sourceX = (frame % columns) * frameW;
    final sourceY = (frame ~/ columns) * frameH;
    final source = Rect.fromLTWH(
      sourceX.toDouble(),
      sourceY.toDouble(),
      frameW.toDouble(),
      frameH.toDouble(),
    );
    final target = Rect.fromLTWH(
      worldX - _cameraX,
      worldY - _cameraY,
      width,
      height,
    );
    canvas.drawImageRect(image, source, target, _pixelPaint);
  }

  void _drawPlayer(Canvas canvas) {
    final sheet = _moving ? (_walkSheet ?? _idleSheet) : _idleSheet;
    final playerSize = _tile * 1.35;
    final footX = _playerX - _cameraX;
    final footY = _playerY - _cameraY + _tile * 0.05;
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x50000000);
    canvas.drawOval(
      Rect.fromLTRB(
        footX - _tile * 0.22,
        footY - _tile * 0.06,
        footX + _tile * 0.22,
        footY + _tile * 0.07,
      ),
      _paint,
    );

    if (sheet == null) {
      _paint.color = TaniinColors.blue;
      canvas.drawCircle(
        Offset(footX, footY - playerSize * 0.5),
        playerSize * 0.28,
        _paint,
      );
      return;
    }

    const frameW = 32;
    const frameH = 32;
    final columns = math.max(1, sheet.width ~/ frameW);
    final frame = _moving ? _walkFrame : ((_clock * 1000) ~/ 240) % 6;
    final frameIndex = frame % columns;
    final row = _spriteRowForDirection();
    final source = Rect.fromLTWH(
      (frameIndex * frameW).toDouble(),
      (row * frameH).toDouble(),
      frameW.toDouble(),
      frameH.toDouble(),
    );
    final screenX = _playerX - _cameraX - playerSize * 0.5;
    final screenY = _playerY - _cameraY - playerSize * 0.78;
    final target = Rect.fromLTWH(screenX, screenY, playerSize, playerSize);
    if (_facingDirection == _dirLeft) {
      canvas.save();
      canvas.translate(target.center.dx, target.center.dy);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
        sheet,
        source,
        Rect.fromCenter(
          center: Offset.zero,
          width: playerSize,
          height: playerSize,
        ),
        _pixelPaint,
      );
      canvas.restore();
    } else {
      canvas.drawImageRect(sheet, source, target, _pixelPaint);
    }
  }

  int _spriteRowForDirection() {
    if (_facingDirection == _dirUp) {
      return 1;
    }
    if (_facingDirection == _dirDown) {
      return 0;
    }
    return 2;
  }

  void _drawHouseSigns(Canvas canvas) {
    _drawWoodSignBoard(
      canvas,
      _signBounds(18.5, 22.35, 190, 68),
      'SHOP',
      36,
      true,
    );
    _drawSignPosts(canvas, _signBounds(31.0, 13.35, 230, 64), 22);
    _drawWoodSignBoard(
      canvas,
      _signBounds(31.0, 13.35, 230, 64),
      'JUAL PANEN',
      28,
      true,
    );
    _drawSignPosts(canvas, _signBounds(10.85, 13.15, 230, 64), 22);
    _drawWoodSignBoard(
      canvas,
      _signBounds(10.85, 13.15, 230, 64),
      'SWAP TANI',
      31,
      true,
    );
  }

  Rect _signBounds(double tileX, double tileY, double width, double height) {
    final centerX = tileX * _tile - _cameraX;
    final centerY = tileY * _tile - _cameraY;
    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
  }

  void _drawSignPosts(Canvas canvas, Rect sign, double height) {
    if (_isOffscreen(sign.inflate(height))) {
      return;
    }
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF533113);
    const postW = 9.0;
    canvas.drawRect(
      Rect.fromLTWH(
        sign.left + sign.width * 0.26 - postW * 0.5,
        sign.bottom - 2,
        postW,
        height,
      ),
      _paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        sign.right - sign.width * 0.26 - postW * 0.5,
        sign.bottom - 2,
        postW,
        height,
      ),
      _paint,
    );
  }

  void _drawWoodSignBoard(
    Canvas canvas,
    Rect sign,
    String label,
    double textSize,
    bool highlighted,
  ) {
    if (_isOffscreen(sign)) {
      return;
    }
    _paint
      ..style = PaintingStyle.fill
      ..color = highlighted ? const Color(0x8C000000) : const Color(0x69000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        sign.shift(const Offset(8, 9)),
        const Radius.circular(8),
      ),
      _paint,
    );
    _paint.color = highlighted
        ? const Color(0xFF894E1C)
        : const Color(0xFF714118);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sign, const Radius.circular(8)),
      _paint,
    );
    _paint.color = const Color(0x78B16929);
    canvas.drawRect(
      Rect.fromLTWH(sign.left + 10, sign.top + 9, sign.width - 20, 9),
      _paint,
    );
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 5 : 4
      ..color = highlighted ? const Color(0xFFFFDD79) : const Color(0xFF4F2D11);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sign, const Radius.circular(8)),
      _paint,
    );
    _paint.style = PaintingStyle.fill;
    _drawCenteredText(canvas, label, sign.center, textSize, sign.width - 22);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double preferredSize,
    double maxWidth,
  ) {
    final size = _fitTextSize(text, preferredSize, maxWidth);
    final strokePainter = _textPainter(
      text,
      size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF3F2410),
    );
    final fillPainter = _textPainter(
      text,
      size,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFEFCC),
    );
    final offset = Offset(
      center.dx - strokePainter.width * 0.5,
      center.dy - strokePainter.height * 0.5,
    );
    strokePainter.paint(canvas, offset);
    fillPainter.paint(canvas, offset);
  }

  TextPainter _textPainter(String text, double size, Paint foreground) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          fontWeight: FontWeight.w900,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  double _fitTextSize(String text, double preferredSize, double maxWidth) {
    final painter = _textPainter(
      text,
      preferredSize,
      Paint()..color = Colors.white,
    );
    if (painter.width <= maxWidth) {
      return preferredSize;
    }
    return math.max(15, preferredSize * maxWidth / math.max(1, painter.width));
  }

  void _drawWorldRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRect(_worldRect(x, y, w, h), _paint);
  }

  void _drawTree(Canvas canvas, double x, double y, double scale) {
    final s = _tile * scale;
    _drawWorldRect(
      canvas,
      x + s * 0.42,
      y + s * 0.78,
      s * 0.16,
      s * 0.45,
      const Color(0xFF5C301F),
    );
    _drawWorldRRect(
      canvas,
      x,
      y + s * 0.2,
      s,
      s * 0.7,
      s * 0.18,
      const Color(0xFF28813E),
    );
    _drawWorldRRect(
      canvas,
      x + s * 0.15,
      y,
      s * 0.72,
      s * 0.58,
      s * 0.18,
      const Color(0xFF3EB348),
    );
  }

  void _drawWoodHouse(Canvas canvas, double x, double y, bool shopHouse) {
    _drawWorldRect(
      canvas,
      x + 16,
      y + 58,
      7 * _tile - 32,
      7 * _tile - 62,
      const Color(0xFF65352A),
    );
    _drawWorldRect(
      canvas,
      x + 28,
      y + 72,
      7 * _tile - 56,
      7 * _tile - 92,
      const Color(0xFFF4C9A6),
    );
    _drawWorldRect(
      canvas,
      x + 4,
      y + 42,
      7 * _tile - 8,
      30,
      const Color(0xFF772618),
    );
    _drawWorldRect(
      canvas,
      x + 70,
      y + 7 * _tile - 100,
      44,
      82,
      const Color(0xFF46221F),
    );
    if (shopHouse) {
      _drawWorldRect(canvas, x + 34, y + 100, 36, 20, const Color(0xFFFFDB5F));
    }
  }

  void _drawWorldRRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double radius,
    Color color,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(_worldRect(x, y, w, h), Radius.circular(radius)),
      _paint,
    );
  }

  Rect _worldRect(double x, double y, double w, double h) {
    return Rect.fromLTWH(x - _cameraX, y - _cameraY, w, h);
  }

  bool _isOffscreen(Rect bounds) {
    final viewport = _visibleViewport == Size.zero
        ? Size(size.x / _renderScale, size.y / _renderScale)
        : _visibleViewport;
    return bounds.right < 0 ||
        bounds.left > viewport.width ||
        bounds.bottom < 0 ||
        bounds.top > viewport.height;
  }

  void _addFallbackCollisionRects(List<Rect> rects) {
    _addCollisionRect(rects, 0, 7 * _tile, 44 * _tile, 4 * _tile);
    _addCollisionRect(rects, 0, 0, 3 * _tile, 52 * _tile);
    _addCollisionRect(rects, 0, 45 * _tile, 34 * _tile, 7 * _tile);
    _addCollisionRect(rects, 52 * _tile, 0, 4 * _tile, 19 * _tile);

    _addFenceCollision(rects, 27 * _tile, 22 * _tile, 22 * _tile, 11 * _tile);
    _addFenceCollision(rects, 6 * _tile, 23 * _tile, 20 * _tile, 9 * _tile);

    _addHouseCollision(rects, 32 * _tile, 24 * _tile, 7 * _tile, 7 * _tile);
    _addHouseCollision(rects, 56 * _tile, 10 * _tile, 7 * _tile, 7 * _tile);
    _addCollisionRect(rects, 39 * _tile, 29 * _tile, 4.6 * _tile, 1.3 * _tile);

    for (final tree in <(double, double, double)>[
      (6, 15, 1.2),
      (14, 13, 1.0),
      (23, 13, 1.0),
      (42, 13, 1.0),
      (62, 5, 1.05),
      (58, 22, 1.0),
      (31, 43, 1.3),
      (37, 43, 1.3),
      (43, 43, 1.3),
      (49, 43, 1.3),
    ]) {
      _addTreeCollision(rects, tree.$1 * _tile, tree.$2 * _tile, tree.$3);
    }

    _addCollisionRect(rects, 17 * _tile, 16 * _tile + 12, 58, 30);
    _addCollisionRect(rects, 31 * _tile, 15 * _tile + 12, 58, 30);
    _addCollisionRect(rects, 13 * _tile, 10 * _tile + 9, 24, 18);
    _addCollisionRect(rects, 54 * _tile, 32 * _tile + 9, 24, 18);
    _addCollisionRect(rects, 65 * _tile, 29 * _tile + 9, 24, 18);
    _addCollisionRect(rects, 40 * _tile, 30 * _tile, 42, 42);
    _addCollisionRect(rects, 29 * _tile, 32 * _tile, 64, 32);
    _addCollisionRect(rects, 45 * _tile, 30 * _tile, 86, 64);
  }

  void _addFenceCollision(
    List<Rect> rects,
    double x,
    double y,
    double w,
    double h,
  ) {
    final rail = _tile * 0.24;
    _addCollisionRect(rects, x, y, w, rail);
    _addCollisionRect(rects, x, y + h - rail, w, rail);
    _addCollisionRect(rects, x, y, rail, h);
    _addCollisionRect(rects, x + w - rail, y, rail, h);
  }

  void _addHouseCollision(
    List<Rect> rects,
    double x,
    double y,
    double w,
    double h,
  ) {
    _addCollisionRect(
      rects,
      x + _tile * 0.18,
      y + _tile * 0.48,
      w - _tile * 0.36,
      h - _tile * 0.64,
    );
    _addCollisionRect(
      rects,
      x + _tile * 0.45,
      y + h - _tile * 1.02,
      _tile * 0.62,
      _tile * 0.72,
    );
  }

  void _addTreeCollision(List<Rect> rects, double x, double y, double scale) {
    final s = _tile * scale;
    _addCollisionRect(rects, x + s * 0.16, y + s * 0.62, s * 0.68, s * 0.55);
  }

  void _addCollisionRect(
    List<Rect> rects,
    double x,
    double y,
    double w,
    double h,
  ) {
    rects.add(Rect.fromLTWH(x, y, w, h));
  }
}
