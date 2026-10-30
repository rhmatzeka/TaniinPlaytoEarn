import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chain/multiplayer_client.dart';
import '../state/farm_state.dart';
import '../ui/taniin_theme.dart';
import 'farm_animals.dart';
import 'farm_life.dart';
import 'tmx_map.dart';

class TaniinGame extends FlameGame {
  TaniinGame(this.farmState, this.multiplayerClient);

  static const double _tile = 128;
  // Character sheets use 32 px frames and the map 16 px tiles, so two tiles
  // keeps characters at the same pixel size as the world.
  static const double _characterSize = _tile * 2;
  static const double _playerSpeed = _tile * 3.9;
  static const double _maxCollisionStep = _tile * 0.16;
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
  final MultiplayerClient multiplayerClient;
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
  final List<FarmAnimal> _animals = _spawnAnimals();
  final FarmLife _life = FarmLife(tile: _tile);
  // Sprites from assets/images/dunia/, keyed by file name.
  final Map<String, ui.Image> _dunia = {};
  ui.Image? _shopNpcSheet;

  double _clock = 0;
  double _cameraX = 0;
  double _cameraY = 0;
  double _playerX = 18.5 * _tile;
  double _playerY = 28.5 * _tile;
  Offset _lastSafePlayerPosition = const Offset(18.5 * _tile, 28.5 * _tile);
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
    final worldPosition =
        screenPosition / _renderScale + Offset(_cameraX, _cameraY);
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

    final ai = multiplayerClient.aiAgent;
    if (ai != null) {
      final aiX =
          bounds.left + (ai.x / math.max(1, _worldWidth)) * bounds.width;
      final aiY =
          bounds.top + (ai.y / math.max(1, _worldHeight)) * bounds.height;
      final aiCenter = Offset(aiX, aiY);
      final aiOuterRadius = markerOuterRadius * 0.92;
      final aiInnerRadius = aiOuterRadius * 0.62;

      _miniMapMarkerPaint
        ..style = PaintingStyle.fill
        ..color = const Color(0x66000000);
      canvas.drawCircle(
        aiCenter + Offset(0, aiOuterRadius * 0.26),
        aiOuterRadius * 1.04,
        _miniMapMarkerPaint,
      );
      _miniMapMarkerPaint.color = const Color(0xFFE8FFF0);
      canvas.drawCircle(aiCenter, aiOuterRadius, _miniMapMarkerPaint);
      _miniMapMarkerPaint.color = const Color(0xFF22D36B);
      canvas.drawCircle(aiCenter, aiInnerRadius, _miniMapMarkerPaint);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Bind AI Farmer Agent callbacks to local game actions
    multiplayerClient.onAiPlanted = (plotIndex, seedIndex) {
      if (plotIndex >= 0 && plotIndex < farmState.plots.length) {
        final plot = farmState.plots[plotIndex];
        plot.seedIndex = seedIndex;
        plot.status = PlotStatus.growing;
        plot.plantedAt = DateTime.now();
        farmState.notifyExternalChange();
      }
    };

    multiplayerClient.onAiHarvested = (plotIndex) {
      if (plotIndex >= 0 && plotIndex < farmState.plots.length) {
        final plot = farmState.plots[plotIndex];
        plot.status = PlotStatus.empty;
        plot.plantedAt = null;
        farmState.notifyExternalChange();
      }
    };

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
      final duniaNames = <String>{
        'kupu',
        'burung',
        'bebek',
        'ikan',
        for (final deco in decorations) deco.asset,
        for (final villager in _life.villagers) ...[
          'warga_${villager.spec.id}_jalan',
          'warga_${villager.spec.id}_diam',
        ],
      };
      for (final name in duniaNames) {
        final image = await _tryLoadImage('assets/images/dunia/$name.png');
        if (image != null) {
          _dunia[name] = image;
        }
      }
    } finally {
      loadingComplete.value = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;

    // Update the walk animation frame independently so that remote players
    // and AI agents animate their walking correctly even when the local player is still.
    _walkTick += dt;
    if (_walkTick > 0.02) {
      _walkFrame = (_walkFrame + 1) % 6;
      _walkTick = 0;
    }

    _updatePlayer(dt);
    for (final animal in _animals) {
      animal.update(dt, _animalBlocked);
    }
    _life.update(
      dt,
      Offset(_playerX, _playerY),
      Size(_worldWidth, _worldHeight),
    );

    // Broadcast player coordinates to WebSocket server
    multiplayerClient.sendMove(_playerX, _playerY, _moving ? 'walk' : 'idle');

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
    _updateCamera(viewport, scale);

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
    _drawActors(canvas);
    map?.drawForeground(canvas, _cameraX, _cameraY, _tile, viewport);
    _drawFlyers(canvas);
    _drawHouseSigns(canvas);
    _drawTags(canvas);
    canvas.restore();
  }

  // About 15 tiles across the short side of the screen, at least 34 logical
  // pixels per tile on phones. Snapped to whole multiples of the 16 px art in
  // physical pixels so every art pixel stays the same size.
  double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 1.0 : math.max(1.0, views.first.devicePixelRatio);
  }

  double get _renderScale {
    final ratio = _devicePixelRatio;
    final shortSide = math.min(size.x, size.y);
    if (shortSide <= 0) {
      return 1 / ratio;
    }
    final logicalTile = math.max(34.0, shortSide / 15);
    final physicalTile = math.max(
      16.0,
      (logicalTile * ratio / 16).round() * 16,
    );
    return physicalTile / ratio / _tile;
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
    _collisionRects.addAll(_life.decorationBlocks());
    for (final animal in _animals) {
      animal.settle(_animalBlocked);
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
    if (_collidesAt(_playerX, _playerY) &&
        !_collidesAt(_lastSafePlayerPosition.dx, _lastSafePlayerPosition.dy)) {
      _playerX = _lastSafePlayerPosition.dx;
      _playerY = _lastSafePlayerPosition.dy;
    }
    final nextX = targetX
        .clamp(1.2 * _tile, _worldWidth - 1.2 * _tile)
        .toDouble();
    final nextY = targetY
        .clamp(1.2 * _tile, _worldHeight - 1.2 * _tile)
        .toDouble();

    final stepCount = math.max(
      1,
      (math.max((nextX - _playerX).abs(), (nextY - _playerY).abs()) /
              _maxCollisionStep)
          .ceil(),
    );
    final stepX = (nextX - _playerX) / stepCount;
    final stepY = (nextY - _playerY) / stepCount;
    for (var step = 0; step < stepCount; step++) {
      final horizontalTarget = _playerX + stepX;
      if (!_collidesAt(horizontalTarget, _playerY)) {
        _playerX = horizontalTarget;
      }
      final verticalTarget = _playerY + stepY;
      if (!_collidesAt(_playerX, verticalTarget)) {
        _playerY = verticalTarget;
      }
    }

    if (_collidesAt(_playerX, _playerY) &&
        !_collidesAt(_lastSafePlayerPosition.dx, _lastSafePlayerPosition.dy)) {
      _playerX = _lastSafePlayerPosition.dx;
      _playerY = _lastSafePlayerPosition.dy;
    } else if (!_collidesAt(_playerX, _playerY)) {
      _lastSafePlayerPosition = Offset(_playerX, _playerY);
    }
    return (_playerX - oldX).abs() > 0.5 || (_playerY - oldY).abs() > 0.5;
  }

  bool _collidesAt(double x, double y) {
    if (_tmxMap?.blocksWaterHitbox(_playerWaterHitbox(x, y), _tile) ?? false) {
      return true;
    }
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

  Rect _playerWaterHitbox(double x, double y) {
    return Rect.fromLTRB(
      x - _tile * 0.30,
      y - _tile * 0.24,
      x + _tile * 0.30,
      y + _tile * 0.22,
    );
  }

  void _updateCamera(Size viewport, double scale) {
    // Round in physical pixels so tiles land on whole pixels at any zoom.
    final physical = scale * _devicePixelRatio;
    _cameraX =
        ((_playerX - viewport.width * 0.5).clamp(
                  0,
                  math.max(0, _worldWidth - viewport.width),
                ) *
                physical)
            .roundToDouble() /
        physical;
    _cameraY =
        ((_playerY - viewport.height * 0.56).clamp(
                  0,
                  math.max(0, _worldHeight - viewport.height),
                ) *
                physical)
            .roundToDouble() /
        physical;
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
    const npcSize = _characterSize;
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
    _drawWaterLife(canvas);
    _drawBirdShadows(canvas);
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
      if (!plot.owned) {
        final lockedPlot = RRect.fromRectAndRadius(
          rect,
          const Radius.circular(8),
        );
        _paint
          ..style = PaintingStyle.fill
          ..color = const Color(0x704C3325);
        canvas.drawRRect(lockedPlot, _paint);
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected == i ? 4 : 3
          ..color = selected == i
              ? const Color(0xE6FFE652)
              : const Color(0x885B3923);
        canvas.drawRRect(lockedPlot, _paint);
        _drawLockedPlotBadge(canvas, rect, selected == i);
      }
      if (plot.status == PlotStatus.growing && cropSheet != null) {
        _drawPlotCrops(canvas, plot, cropSheet, now);
      }
    }
    _paint.style = PaintingStyle.fill;
  }

  void _drawLockedPlotBadge(Canvas canvas, Rect plotRect, bool highlighted) {
    if (_isOffscreen(plotRect)) {
      return;
    }
    final center = plotRect.center;
    final size = math.min(plotRect.width, plotRect.height) * 0.34;
    final body = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size * 0.12),
      width: size * 0.92,
      height: size * 0.70,
    );
    final shackle = Rect.fromCenter(
      center: Offset(center.dx, center.dy - size * 0.20),
      width: size * 0.62,
      height: size * 0.66,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x66000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.shift(Offset(size * 0.10, size * 0.12)),
        Radius.circular(size * 0.10),
      ),
      _paint,
    );
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5.0, size * 0.11)
      ..strokeCap = StrokeCap.round
      ..color = highlighted ? const Color(0xFFFFE77C) : const Color(0xFFE9C67B);
    canvas.drawArc(shackle, math.pi, math.pi, false, _paint);
    _paint
      ..style = PaintingStyle.fill
      ..color = highlighted ? const Color(0xFFD99331) : const Color(0xFF9B6426);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(size * 0.10)),
      _paint,
    );
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3.0, size * 0.045)
      ..color = highlighted ? const Color(0xFFFFF0A6) : const Color(0xFF5B3718);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(size * 0.10)),
      _paint,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF422817);
    canvas.drawCircle(center.translate(0, size * 0.08), size * 0.085, _paint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size * 0.22),
        width: size * 0.08,
        height: size * 0.20,
      ),
      _paint,
    );
    _paint.strokeCap = StrokeCap.butt;
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
    final selected = selectedPlotIndex;
    for (var i = 0; i < farmState.plots.length; i++) {
      final plot = farmState.plots[i];
      final interaction = farmState.plotInteraction(i);
      final label = switch (interaction) {
        GameInteraction.buyLand => 'BELI',
        GameInteraction.plant => 'TANAM',
        GameInteraction.harvest => 'PANEN',
        _ => '',
      };
      if (label.isEmpty) {
        continue;
      }
      final centerX = (plot.tileX + plot.tileWidth * 0.5) * _tile - _cameraX;
      final centerY = (plot.tileY - 0.34) * _tile - _cameraY;
      final sign = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: label == 'PANEN' || label == 'TANAM' ? 164 : 148,
        height: 58,
      );
      final highlighted =
          selected == i || interaction == GameInteraction.harvest;
      _drawSignPosts(canvas, sign, highlighted ? 22 : 18);
      _drawWoodSignBoard(canvas, sign, label, 29, highlighted);
    }
  }

  void _drawAnimal(Canvas canvas, FarmAnimal animal) {
    {
      final sheet = switch (animal.kind) {
        AnimalKind.chicken => _chicken,
        AnimalKind.chickenRed => _chickenRed,
        AnimalKind.babyChicken => _babyChicken,
        AnimalKind.cow => _cow,
        AnimalKind.maleCow => _maleCow,
      };
      if (sheet == null) {
        return;
      }
      final size = animal.size;
      // Feet sit near the bottom of each frame; the sheets carry their own
      // ground shadow.
      final target = Rect.fromLTWH(
        animal.x - size * 0.5 - _cameraX,
        animal.y - size * 0.9 - _cameraY,
        size,
        size,
      );
      if (_isOffscreen(target)) {
        return;
      }
      final frame = animal.frame();
      final edge = animal.kind.frameSize.toDouble();
      final source = Rect.fromLTWH(
        frame.column * edge,
        frame.row * edge,
        edge,
        edge,
      );
      if (frame.flip) {
        canvas.save();
        canvas.translate(target.center.dx, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(
          sheet,
          source,
          target.shift(Offset(-target.center.dx, 0)),
          _pixelPaint,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(sheet, source, target, _pixelPaint);
      }
    }
  }

  /// Draws [source] of [image] with its bottom centre at world ([x], [y]).
  /// [scale] is world px per art px; the map uses 8 (16 px art per tile).
  void _drawSpriteAt(
    Canvas canvas,
    ui.Image image,
    Rect source,
    double x,
    double y, {
    double scale = _tile / 16,
    bool flip = false,
    double angle = 0,
  }) {
    final width = source.width * scale;
    final height = source.height * scale;
    final target = Rect.fromLTWH(
      x - width / 2 - _cameraX,
      y - height - _cameraY,
      width,
      height,
    );
    if (_isOffscreen(target)) {
      return;
    }
    if (!flip && angle == 0) {
      canvas.drawImageRect(image, source, target, _pixelPaint);
      return;
    }
    canvas.save();
    canvas.translate(target.center.dx, target.center.dy);
    if (angle != 0) {
      canvas.rotate(angle);
    }
    if (flip) {
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      _pixelPaint,
    );
    canvas.restore();
  }

  void _drawDecoration(Canvas canvas, Prop deco) {
    {
      final image = _dunia[deco.asset];
      if (image == null) {
        return;
      }
      _drawSpriteAt(
        canvas,
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        deco.x * _tile,
        deco.y * _tile,
      );
    }
  }

  void _drawWaterLife(Canvas canvas) {
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tile * 0.035;
    for (final jump in _life.fish) {
      // Splash rings where the fish leaves and re-enters the water.
      for (final start in const [0.0, 0.75]) {
        final age = jump.t - start;
        if (age < 0 || age > 0.45) {
          continue;
        }
        final grow = age / 0.45;
        ripple.color = Color.fromRGBO(235, 248, 255, 0.85 * (1 - grow));
        final centre = jump.origin - Offset(_cameraX, _cameraY);
        canvas.drawOval(
          Rect.fromCenter(
            center: centre,
            width: _tile * (0.25 + grow * 0.6),
            height: _tile * (0.1 + grow * 0.22),
          ),
          ripple,
        );
      }
      final fish = _dunia['ikan'];
      if (fish != null && jump.arc < 1) {
        final at = jump.position;
        _drawSpriteAt(
          canvas,
          fish,
          const Rect.fromLTWH(0, 0, 8, 5),
          at.dx,
          at.dy,
          flip: !jump.left,
          angle: jump.angle,
        );
      }
    }
    final duck = _dunia['bebek'];
    if (duck != null) {
      for (final d in _life.ducks) {
        _drawSpriteAt(
          canvas,
          duck,
          Rect.fromLTWH(d.frame * 14.0, 0, 14, 11),
          d.x,
          d.y + _tile * 0.2,
          flip: d.facingRight,
        );
      }
    }
  }

  void _drawBirdShadows(Canvas canvas) {
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x2E000000);
    for (final bird in _life.birds) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bird.x - _cameraX, bird.y - _cameraY),
          width: _tile * 0.5,
          height: _tile * 0.14,
        ),
        _paint,
      );
    }
  }

  void _drawVillager(Canvas canvas, Villager villager) {
    const size = _characterSize;
    {
      final sheet = villager.walking
          ? _dunia['warga_${villager.spec.id}_jalan']
          : _dunia['warga_${villager.spec.id}_diam'];
      if (sheet == null) {
        return;
      }
      final footX = villager.x - _cameraX;
      final footY = villager.y - _cameraY;
      final target = Rect.fromLTWH(
        footX - size * 0.5,
        footY - size * 0.78,
        size,
        size,
      );
      if (_isOffscreen(target)) {
        return;
      }
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x50000000);
      canvas.drawOval(
        Rect.fromLTRB(
          footX - _tile * 0.32,
          footY - _tile * 0.03,
          footX + _tile * 0.32,
          footY + _tile * 0.14,
        ),
        _paint,
      );
      final columns = math.max(1, sheet.width ~/ 32);
      final frame = villager.walking
          ? (villager.animClock * 10).floor() % columns
          : (villager.animClock * 4).floor() % columns;
      final row = switch (villager.facing) {
        Facing.down => 0,
        Facing.up => 1,
        Facing.left || Facing.right => 2,
      };
      _drawSpriteAt(
        canvas,
        sheet,
        Rect.fromLTWH(frame * 32.0, row * 32.0, 32, 32),
        villager.x,
        villager.y + size * 0.22,
        scale: size / 32,
        flip: villager.facing == Facing.left,
      );
    }
  }

  /// Everything that stands on the ground, drawn back to front by the y of
  /// its feet so nearer things cover farther ones.
  void _drawActors(Canvas canvas) {
    final actors = <(double, VoidCallback)>[
      for (final deco in decorations)
        (deco.y * _tile, () => _drawDecoration(canvas, deco)),
      for (final animal in _animals)
        (animal.y, () => _drawAnimal(canvas, animal)),
      for (final villager in _life.villagers)
        (villager.y, () => _drawVillager(canvas, villager)),
      for (final player in multiplayerClient.remotePlayers.values)
        (player.y, () => _drawRemotePlayer(canvas, player)),
      if (multiplayerClient.aiAgent case final ai?)
        (ai.y, () => _drawAiAgent(canvas)),
      (_shopNpcYTile * _tile, () => _drawShopNpc(canvas)),
      (_playerY, () => _drawPlayer(canvas)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in actors) {
      draw();
    }
  }

  void _drawFlyers(Canvas canvas) {
    final butterfly = _dunia['kupu'];
    if (butterfly != null) {
      for (final b in _life.butterflies) {
        _drawSpriteAt(
          canvas,
          butterfly,
          Rect.fromLTWH(b.wingsOpen ? 0 : 8, b.color * 8.0, 8, 8),
          b.x,
          b.y - _tile * 0.55 + b.lift,
          scale: _tile / 26,
          flip: b.flipped,
        );
      }
    }
    final bird = _dunia['burung'];
    if (bird != null) {
      for (final b in _life.birds) {
        _drawSpriteAt(
          canvas,
          bird,
          Rect.fromLTWH(b.wingsUp ? 0 : 12, 0, 12, 7),
          b.x,
          b.y - b.altitude,
          flip: b.direction < 0,
        );
      }
    }
  }

  /// Name tags and speech bubbles, drawn after everything else so no sprite
  /// covers them.
  void _drawTags(Canvas canvas) {
    multiplayerClient.remotePlayers.forEach((_, player) {
      _drawNameTag(
        canvas,
        player.name,
        player.x,
        player.y - _characterSize * 0.7,
        const Color(0xFF6FB7FF),
      );
    });
    final ai = multiplayerClient.aiAgent;
    if (ai != null) {
      _drawNameTag(
        canvas,
        ai.name,
        ai.x,
        ai.y - _characterSize * 0.7,
        const Color(0xFF52E07A),
      );
    }
    for (final villager in _life.villagers) {
      final bubble = villager.bubble;
      if (!villager.near && bubble == null) {
        continue;
      }
      final tagY = villager.y - _characterSize * 0.7;
      _drawNameTag(
        canvas,
        villager.spec.name,
        villager.x,
        tagY,
        const Color(0xFFFFDE19),
      );
      if (bubble != null) {
        _drawSpeechBubble(canvas, bubble, villager.x, tagY - _tile * 0.4);
      }
    }
  }

  /// Cream speech bubble whose tail points down at world ([x], [bottom]).
  void _drawSpeechBubble(Canvas canvas, String text, double x, double bottom) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF3A1E0C),
          fontSize: 30,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _tile * 4.2);
    final width = painter.width + 36;
    final height = painter.height + 24;
    final left = x - width / 2 - _cameraX;
    final top = bottom - height - _cameraY;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(14),
    );
    final tail = Path()
      ..moveTo(x - _cameraX - 14, top + height - 2)
      ..lineTo(x - _cameraX, top + height + 18)
      ..lineTo(x - _cameraX + 14, top + height - 2)
      ..close();
    final border = Paint()
      ..color = const Color(0xFF4A1D08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final fill = Paint()..color = const Color(0xFFFFF0D4);
    canvas.drawRRect(box, border);
    canvas.drawPath(tail, border);
    canvas.drawRRect(box, fill);
    canvas.drawPath(tail, fill);
    painter.paint(canvas, Offset(left + 18, top + 12));
  }

  bool _animalBlocked(Rect footprint) {
    if (footprint.left < 0 ||
        footprint.top < 0 ||
        footprint.right > _worldWidth ||
        footprint.bottom > _worldHeight) {
      return true;
    }
    if (_tmxMap?.blocksWaterHitbox(footprint, _tile) ?? false) {
      return true;
    }
    for (final obstacle in _collisionRects) {
      if (footprint.overlaps(obstacle)) {
        return true;
      }
    }
    return false;
  }

  static List<FarmAnimal> _spawnAnimals() {
    var seed = 7;
    FarmAnimal at(
      AnimalKind kind,
      double tileX,
      double tileY,
      double roamTiles, {
      FarmAnimal? parent,
    }) => FarmAnimal(
      kind: kind,
      home: Offset(tileX * _tile, tileY * _tile),
      roam: roamTiles * _tile,
      tile: _tile,
      seed: seed++,
      parent: parent,
    );

    // Shop pen.
    final penHen = at(AnimalKind.chicken, 22.6, 18.5, 0.7);
    final penHenB = at(AnimalKind.chicken, 23.2, 22.9, 0.6);
    // Field edge.
    final fieldHen = at(AnimalKind.chicken, 11.1, 25.0, 1.4);
    final fieldHenB = at(AnimalKind.chicken, 14.0, 25.1, 1.4);
    // Open meadow.
    final meadowHen = at(AnimalKind.chickenRed, 20.0, 28.7, 1.6);
    final meadowHenB = at(AnimalKind.chicken, 24.4, 30.7, 1.6);
    // Roadside.
    final roadHen = at(AnimalKind.chicken, 34.9, 31.9, 1.4);
    return [
      penHen,
      at(AnimalKind.chicken, 23.6, 18.9, 0.6),
      at(AnimalKind.cow, 23.3, 20.9, 0.6),
      penHenB,
      at(AnimalKind.babyChicken, 22.6, 22.3, 0, parent: penHenB),
      at(AnimalKind.babyChicken, 23.8, 22.7, 0, parent: penHenB),
      fieldHen,
      at(AnimalKind.babyChicken, 11.8, 25.2, 0, parent: fieldHen),
      fieldHenB,
      at(AnimalKind.babyChicken, 14.6, 25.3, 0, parent: fieldHenB),
      meadowHen,
      at(AnimalKind.babyChicken, 20.6, 29.0, 0, parent: meadowHen),
      at(AnimalKind.maleCow, 24.6, 28.8, 2.2),
      meadowHenB,
      at(AnimalKind.babyChicken, 25.0, 30.9, 0, parent: meadowHenB),
      at(AnimalKind.cow, 31.7, 30.0, 2.4),
      roadHen,
      at(AnimalKind.chickenRed, 35.5, 32.3, 1.4),
    ];
  }

  void _drawShopNpc(Canvas canvas) {
    final sheet = _shopNpcSheet;
    if (sheet == null) {
      return;
    }
    final footWorldX = 19.18 * _tile;
    final footWorldY = 25.88 * _tile;
    const npcSize = _characterSize;
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
    const playerSize = _characterSize;
    final footX = _playerX - _cameraX;
    final footY = _playerY - _cameraY + _tile * 0.05;
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x50000000);
    canvas.drawOval(
      Rect.fromLTRB(
        footX - _tile * 0.32,
        footY - _tile * 0.08,
        footX + _tile * 0.32,
        footY + _tile * 0.09,
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
        _skinPaint(farmState.equippedCosmeticId),
      );
      canvas.restore();
    } else {
      canvas.drawImageRect(
        sheet,
        source,
        target,
        _skinPaint(farmState.equippedCosmeticId),
      );
    }
    _drawSkinBadge(canvas, target, farmState.equippedCosmeticId);
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

  void _drawRemotePlayer(Canvas canvas, RemotePlayer player) {
    const playerSize = _characterSize;
    final idleS = _idleSheet;
    final walkS = _walkSheet;

    if (idleS == null) return;

    {
      final isWalking = player.anim == 'walk';
      final sheet = isWalking ? (walkS ?? idleS) : idleS;

      final screenX = player.x - _cameraX - playerSize * 0.5;
      final screenY = player.y - _cameraY - playerSize * 0.78;
      final target = Rect.fromLTWH(screenX, screenY, playerSize, playerSize);

      if (_isOffscreen(target)) return;

      // Draw shadow
      final footX = player.x - _cameraX;
      final footY = player.y - _cameraY + _tile * 0.05;
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x50000000);
      canvas.drawOval(
        Rect.fromLTRB(
          footX - _tile * 0.32,
          footY - _tile * 0.08,
          footX + _tile * 0.32,
          footY + _tile * 0.09,
        ),
        _paint,
      );

      // Draw sprite solid (no transparent color filter)
      final remotePaint = _skinPaint(player.skinId);

      const frameW = 32;
      const frameH = 32;
      final columns = math.max(1, sheet.width ~/ frameW);
      final frame = isWalking ? _walkFrame : ((_clock * 1000) ~/ 240) % 6;
      final frameIndex = frame % columns;

      final source = Rect.fromLTWH(
        (frameIndex * frameW).toDouble(),
        (player.facingDirection * frameH).toDouble(),
        frameW.toDouble(),
        frameH.toDouble(),
      );

      if (player.flipLeft) {
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
          remotePaint,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(sheet, source, target, remotePaint);
      }
      _drawSkinBadge(canvas, target, player.skinId);
    }
  }

  Paint _skinPaint(String skinId) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    final color = switch (skinId) {
      'farmer_nusantara' => const Color(0xFFFFC66D),
      'forest_keeper' => const Color(0xFF8FE39A),
      _ => Colors.white,
    };
    if (skinId != 'farmer_classic') {
      paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
    }
    return paint;
  }

  void _drawSkinBadge(Canvas canvas, Rect target, String skinId) {
    if (skinId == 'farmer_classic') return;
    final color = skinId == 'forest_keeper'
        ? const Color(0xFF2F8B57)
        : const Color(0xFFE78A2D);
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(
      Offset(
        target.right - target.width * 0.12,
        target.top + target.height * 0.14,
      ),
      target.width * 0.09,
      _paint,
    );
  }

  void _drawAiAgent(Canvas canvas) {
    final ai = multiplayerClient.aiAgent;
    if (ai == null) return;

    const playerSize = _characterSize;
    final idleS = _idleSheet;
    final walkS = _walkSheet;

    if (idleS == null) return;

    final isWalking = ai.anim == 'walk';
    final sheet = isWalking ? (walkS ?? idleS) : idleS;

    final screenX = ai.x - _cameraX - playerSize * 0.5;
    final screenY = ai.y - _cameraY - playerSize * 0.78;
    final target = Rect.fromLTWH(screenX, screenY, playerSize, playerSize);

    if (_isOffscreen(target)) return;

    // Draw shadow
    final footX = ai.x - _cameraX;
    final footY = ai.y - _cameraY + _tile * 0.05;
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x50000000);
    canvas.drawOval(
      Rect.fromLTRB(
        footX - _tile * 0.32,
        footY - _tile * 0.08,
        footX + _tile * 0.32,
        footY + _tile * 0.09,
      ),
      _paint,
    );

    const frameW = 32;
    const frameH = 32;
    final columns = math.max(1, sheet.width ~/ frameW);
    // Use walk frame index for walking, idle frame index for idle
    final frame = isWalking ? _walkFrame : ((_clock * 1000) ~/ 240) % 6;
    final frameIndex = frame % columns;

    // Determine dynamically facing direction row for AI agent (down=0, up=1, side=2)
    int row = ai.facingDirection;
    bool flipLeft = ai.flipLeft;

    final source = Rect.fromLTWH(
      (frameIndex * frameW).toDouble(),
      (row * frameH).toDouble(),
      frameW.toDouble(),
      frameH.toDouble(),
    );

    canvas.save();
    if (flipLeft) {
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
    } else {
      canvas.drawImageRect(sheet, source, target, _pixelPaint);
    }
    canvas.restore();
  }

  void _drawNameTag(
    Canvas canvas,
    String name,
    double worldX,
    double worldY,
    Color tagColor,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: 'Pixelify',
          fontSize: 30,
          height: 1,
          color: tagColor,
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = worldX - _cameraX - painter.width * 0.5;
    final y = worldY - _cameraY - painter.height * 0.5;
    final tag = Rect.fromLTWH(
      x - 12,
      y - 7,
      painter.width + 24,
      painter.height + 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tag, const Radius.circular(8)),
      Paint()..color = const Color(0xE60F1A12),
    );
    // Coloured accent along the bottom of the tag.
    canvas.drawRect(
      Rect.fromLTWH(tag.left + 8, tag.bottom - 4, tag.width - 16, 4),
      Paint()..color = tagColor,
    );

    painter.paint(canvas, Offset(x, y));
  }
}
