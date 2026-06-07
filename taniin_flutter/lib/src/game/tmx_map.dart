import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

const int _gidMask = 0x1fffffff;

class TmxMap {
  TmxMap._();

  final List<_Tileset> _tilesets = <_Tileset>[];
  final List<_MapLayer> _layers = <_MapLayer>[];
  final Map<int, int> _bridgeTiles = <int, int>{};
  final Map<int, int> _waterTiles = <int, int>{};
  final Paint _pixelPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _miniPaint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.fill;
  final Paint _miniTilePaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  int tileWidth = 16;
  int tileHeight = 16;
  int minTileX = 0;
  int minTileY = 0;
  int maxTileX = 1;
  int maxTileY = 1;

  static Future<TmxMap> load(String assetPath) async {
    final map = TmxMap._();
    final basePath = _parentPath(assetPath);
    final document = XmlDocument.parse(await rootBundle.loadString(assetPath));
    final root = document.rootElement;
    map._readMapSize(root);
    await map._loadTilesets(root, basePath);
    map._loadLayers(root);
    return map;
  }

  @visibleForTesting
  static Future<TmxMap> loadCollisionDataForTesting(String assetPath) async {
    final map = TmxMap._();
    final document = XmlDocument.parse(await rootBundle.loadString(assetPath));
    final root = document.rootElement;
    map
      .._readMapSize(root)
      .._loadLayers(root);
    return map;
  }

  void _readMapSize(XmlElement root) {
    tileWidth = _intAttr(root, 'tilewidth', 16);
    tileHeight = _intAttr(root, 'tileheight', 16);
  }

  Future<void> _loadTilesets(XmlElement root, String basePath) async {
    for (final element in root.findElements('tileset')) {
      final source = element.getAttribute('source');
      if (source == null || source.isEmpty) {
        continue;
      }
      final firstGid = _intAttr(element, 'firstgid', 1);
      _tilesets.add(await _loadTileset(basePath, source, firstGid));
    }
    _tilesets.sort((a, b) => a.firstGid.compareTo(b.firstGid));
  }

  void _loadLayers(XmlElement root) {
    _layers.clear();
    var minX = 1 << 30;
    var minY = 1 << 30;
    var maxX = -(1 << 30);
    var maxY = -(1 << 30);

    for (final node in root.children.whereType<XmlElement>()) {
      if (node.name.local != 'layer') {
        continue;
      }
      final layer = _MapLayer(node.getAttribute('name') ?? '');
      for (final chunk in node.findAllElements('chunk')) {
        final chunkX = _intAttr(chunk, 'x', 0);
        final chunkY = _intAttr(chunk, 'y', 0);
        final chunkWidth = _intAttr(chunk, 'width', 0);
        if (chunkWidth <= 0) {
          continue;
        }
        var valueIndex = 0;
        for (final rawValue in chunk.innerText.split(',')) {
          final trimmed = rawValue.trim();
          if (trimmed.isEmpty) {
            continue;
          }
          final rawGid = int.parse(trimmed);
          final gid = rawGid & _gidMask;
          final localX = valueIndex % chunkWidth;
          final localY = valueIndex ~/ chunkWidth;
          valueIndex++;
          if (gid == 0) {
            continue;
          }
          final tileX = chunkX + localX;
          final tileY = chunkY + localY;
          layer.tiles.add(_Tile(tileX, tileY, gid));
          minX = math.min(minX, tileX);
          minY = math.min(minY, tileY);
          maxX = math.max(maxX, tileX);
          maxY = math.max(maxY, tileY);
        }
      }
      if (layer.tiles.isNotEmpty) {
        _layers.add(layer);
      }
    }

    if (minX == 1 << 30) {
      minX = 0;
      minY = 0;
      maxX = 1;
      maxY = 1;
    }
    this
      ..minTileX = minX
      ..minTileY = minY
      ..maxTileX = maxX
      ..maxTileY = maxY;
    _buildLayerIndexes();
    _buildCollisionTileIndexes();
  }

  double getWorldWidthPixels(double targetTileSize) {
    return (maxTileX - minTileX + 1) * targetTileSize;
  }

  double getWorldHeightPixels(double targetTileSize) {
    return (maxTileY - minTileY + 1) * targetTileSize;
  }

  int get tileColumns => maxTileX - minTileX + 1;

  int get tileRows => maxTileY - minTileY + 1;

  Size miniMapRasterSize({int scale = 1}) {
    final safeScale = math.max(1, scale);
    return Size(
      (tileColumns * tileWidth * safeScale).toDouble(),
      (tileRows * tileHeight * safeScale).toDouble(),
    );
  }

  List<Rect> collisionRects(double targetTileSize) {
    final rects = <Rect>[];
    for (final layer in _layers) {
      for (final tile in layer.tiles) {
        final key = _tileKey(tile.x, tile.y);
        final bridgeGid = _bridgeTiles[key];
        final left = (tile.x - minTileX) * targetTileSize;
        final top = (tile.y - minTileY) * targetTileSize;
        if (bridgeGid != null && _isWaterTile(tile.gid)) {
          _appendBridgeWaterGuardRects(
            rects,
            _bridgeTiles,
            tile.x,
            tile.y,
            bridgeGid,
            left,
            top,
            targetTileSize,
          );
          continue;
        }
        _appendCollisionRect(
          rects,
          layer.name,
          tile.gid,
          left,
          top,
          targetTileSize,
        );
      }
    }
    return rects;
  }

  bool blocksWaterHitbox(Rect hitbox, double targetTileSize) {
    if (targetTileSize <= 0 || _waterTiles.isEmpty) {
      return false;
    }

    const epsilon = 0.001;
    final firstColumn = math.max(0, (hitbox.left / targetTileSize).floor());
    final lastColumn = math.min(
      tileColumns - 1,
      ((hitbox.right - epsilon) / targetTileSize).floor(),
    );
    final firstRow = math.max(0, (hitbox.top / targetTileSize).floor());
    final lastRow = math.min(
      tileRows - 1,
      ((hitbox.bottom - epsilon) / targetTileSize).floor(),
    );
    if (lastColumn < firstColumn || lastRow < firstRow) {
      return false;
    }

    for (var row = firstRow; row <= lastRow; row++) {
      for (var column = firstColumn; column <= lastColumn; column++) {
        final tileX = minTileX + column;
        final tileY = minTileY + row;
        final key = _tileKey(tileX, tileY);
        if (!_waterTiles.containsKey(key)) {
          continue;
        }
        final left = column * targetTileSize;
        final top = row * targetTileSize;
        final bridgeGid = _bridgeTiles[key];
        if (bridgeGid == null) {
          if (hitbox.overlaps(
            Rect.fromLTWH(left, top, targetTileSize, targetTileSize),
          )) {
            return true;
          }
          continue;
        }

        final guards = <Rect>[];
        _appendBridgeWaterGuardRects(
          guards,
          _bridgeTiles,
          tileX,
          tileY,
          bridgeGid,
          left,
          top,
          targetTileSize,
        );
        if (guards.any(hitbox.overlaps)) {
          return true;
        }
      }
    }
    return false;
  }

  void drawBackground(
    Canvas canvas,
    double cameraX,
    double cameraY,
    double targetTileSize,
    Size viewport,
  ) {
    _drawLayers(canvas, cameraX, cameraY, targetTileSize, viewport, false);
  }

  void drawForeground(
    Canvas canvas,
    double cameraX,
    double cameraY,
    double targetTileSize,
    Size viewport,
  ) {
    _drawLayers(canvas, cameraX, cameraY, targetTileSize, viewport, true);
  }

  void drawMiniMap(Canvas canvas, Rect bounds, double targetTileSize) {
    final columns = math.max(1, tileColumns);
    final rows = math.max(1, tileRows);
    final tileW = bounds.width / columns;
    final tileH = bounds.height / rows;
    final bleedX = math.min(0.45, tileW * 0.08);
    final bleedY = math.min(0.45, tileH * 0.08);

    _miniPaint.color = const Color(0xFF69B84E);
    canvas.drawRect(bounds, _miniPaint);
    canvas.save();
    canvas.clipRect(bounds);
    for (final layer in _layers) {
      for (final tile in layer.tiles) {
        final tileset = _findTileset(tile.gid);
        if (tileset == null) {
          continue;
        }
        final localId = tile.gid - tileset.firstGid;
        final sourceX = (localId % tileset.columns) * tileset.tileWidth;
        final sourceY = (localId ~/ tileset.columns) * tileset.tileHeight;
        final sourceInset = math.min(
          0.25,
          math.min(tileset.tileWidth, tileset.tileHeight) * 0.04,
        );
        final src = Rect.fromLTRB(
          sourceX + sourceInset,
          sourceY + sourceInset,
          sourceX + tileset.tileWidth - sourceInset,
          sourceY + tileset.tileHeight - sourceInset,
        );
        final column = tile.x - minTileX;
        final row = tile.y - minTileY;
        final left = bounds.left + column * tileW;
        final top = bounds.top + row * tileH;
        final right = bounds.left + (column + 1) * tileW;
        final bottom = bounds.top + (row + 1) * tileH;
        final dst = Rect.fromLTRB(
          left - bleedX,
          top - bleedY,
          right + bleedX,
          bottom + bleedY,
        );
        canvas.drawImageRect(tileset.image, src, dst, _miniTilePaint);
      }
    }
    canvas.restore();
  }

  void _buildLayerIndexes() {
    for (final layer in _layers) {
      layer.buildDrawIndex(minTileY, maxTileY);
    }
  }

  void _buildCollisionTileIndexes() {
    _bridgeTiles.clear();
    _waterTiles.clear();
    for (final layer in _layers) {
      for (final tile in layer.tiles) {
        final key = _tileKey(tile.x, tile.y);
        if (_isBridgeTile(tile.gid)) {
          _bridgeTiles[key] = tile.gid;
        }
        if (_isWaterTile(tile.gid)) {
          _waterTiles[key] = tile.gid;
        }
      }
    }
  }

  void _drawLayers(
    Canvas canvas,
    double cameraX,
    double cameraY,
    double targetTileSize,
    Size viewport,
    bool foreground,
  ) {
    final scale = targetTileSize / tileWidth;
    final firstTileX = math.max(
      minTileX,
      minTileX + (cameraX / targetTileSize).floor() - 2,
    );
    final firstTileY = math.max(
      minTileY,
      minTileY + (cameraY / targetTileSize).floor() - 2,
    );
    final lastTileX = math.min(
      maxTileX,
      minTileX + ((cameraX + viewport.width) / targetTileSize).floor() + 3,
    );
    final lastTileY = math.min(
      maxTileY,
      minTileY + ((cameraY + viewport.height) / targetTileSize).floor() + 3,
    );

    for (final layer in _layers) {
      final rows = layer.rowsFor(foreground);
      if (rows.isEmpty) {
        continue;
      }
      final firstRow = math.max(0, firstTileY - minTileY);
      final lastRow = math.min(rows.length - 1, lastTileY - minTileY);
      if (lastRow < firstRow) {
        continue;
      }
      for (var rowIndex = firstRow; rowIndex <= lastRow; rowIndex++) {
        for (final tile in rows[rowIndex]) {
          if (tile.x < firstTileX) {
            continue;
          }
          if (tile.x > lastTileX) {
            break;
          }
          final tileset = _findTileset(tile.gid);
          if (tileset == null) {
            continue;
          }
          final localId = tile.gid - tileset.firstGid;
          final sourceX = (localId % tileset.columns) * tileset.tileWidth;
          final sourceY = (localId ~/ tileset.columns) * tileset.tileHeight;
          final src = Rect.fromLTWH(
            sourceX.toDouble(),
            sourceY.toDouble(),
            tileset.tileWidth.toDouble(),
            tileset.tileHeight.toDouble(),
          );
          final screenX = (tile.x - minTileX) * targetTileSize - cameraX;
          final screenY = (tile.y - minTileY) * targetTileSize - cameraY;
          final dst = Rect.fromLTWH(
            screenX,
            screenY,
            tileset.tileWidth * scale,
            tileset.tileHeight * scale,
          );
          canvas.drawImageRect(tileset.image, src, dst, _pixelPaint);
        }
      }
    }
  }

  _Tileset? _findTileset(int gid) {
    _Tileset? result;
    for (final tileset in _tilesets) {
      if (gid >= tileset.firstGid) {
        result = tileset;
      } else {
        break;
      }
    }
    return result;
  }
}

Future<_Tileset> _loadTileset(
  String mapBasePath,
  String tilesetSource,
  int firstGid,
) async {
  final tilesetPath = _joinAssetPath(mapBasePath, tilesetSource);
  final document = XmlDocument.parse(await rootBundle.loadString(tilesetPath));
  final root = document.rootElement;
  final imageElement = root.findElements('image').first;
  final imageSource = imageElement.getAttribute('source') ?? '';
  final imagePath = _joinAssetPath(_parentPath(tilesetPath), imageSource);
  final image = await _loadImage(imagePath);
  return _Tileset(
    firstGid: firstGid,
    tileWidth: _intAttr(root, 'tilewidth', 16),
    tileHeight: _intAttr(root, 'tileheight', 16),
    columns: math.max(1, _intAttr(root, 'columns', 1)),
    image: image,
  );
}

Future<ui.Image> _loadImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

int _intAttr(XmlElement element, String name, int fallback) {
  final value = element.getAttribute(name);
  if (value == null || value.isEmpty) {
    return fallback;
  }
  return int.parse(value);
}

String _parentPath(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '' : path.substring(0, slash);
}

String _joinAssetPath(String parent, String child) {
  if (parent.isEmpty) {
    return child;
  }
  return '$parent/$child';
}

bool _isWaterTile(int gid) {
  return switch (gid) {
    818 ||
    819 ||
    821 ||
    840 ||
    844 ||
    861 ||
    865 ||
    868 ||
    883 ||
    884 ||
    906 ||
    907 => true,
    _ => false,
  };
}

@visibleForTesting
bool isWaterTileForTesting(int gid) => _isWaterTile(gid);

bool _isBridgeTile(int gid) => gid >= 1396 && gid <= 1410;

bool _isVerticalBridgeTile(int gid) {
  return switch (gid) {
    1396 || 1397 || 1401 || 1402 || 1406 || 1407 => true,
    _ => false,
  };
}

bool _isHorizontalBridgeTile(int gid) {
  return switch (gid) {
    1398 || 1399 || 1400 || 1403 || 1404 || 1405 => true,
    _ => false,
  };
}

@visibleForTesting
List<Rect> bridgeWaterGuardRectsForTesting({
  required Map<(int, int), int> bridgeTiles,
  required int tileX,
  required int tileY,
  required int bridgeGid,
  required double left,
  required double top,
  required double size,
}) {
  final rects = <Rect>[];
  final keyedBridgeTiles = <int, int>{};
  for (final entry in bridgeTiles.entries) {
    keyedBridgeTiles[_tileKey(entry.key.$1, entry.key.$2)] = entry.value;
  }
  _appendBridgeWaterGuardRects(
    rects,
    keyedBridgeTiles,
    tileX,
    tileY,
    bridgeGid,
    left,
    top,
    size,
  );
  return rects;
}

bool _isHouseTile(int gid) => (gid >= 241 && gid < 339) || gid >= 1431;

bool _isHouseFrontEdgeTile(int gid) {
  return (gid >= 320 && gid <= 324) || (gid >= 2414 && gid <= 2417);
}

bool _isFenceTile(int gid) => gid >= 369 && gid < 384;

bool _isMapleTreeFootTile(int gid) => gid >= 363 && gid <= 368;

bool _isLeftTreeFootTile(int gid) {
  return switch (gid) {
    363 || 365 || 367 || 781 || 783 || 847 || 849 => true,
    _ => false,
  };
}

bool _isRightTreeFootTile(int gid) {
  return switch (gid) {
    364 || 366 || 368 || 782 || 784 || 848 || 850 => true,
    _ => false,
  };
}

bool _isOakTreeLeftOuterFootTile(int gid) => gid == 1427;

bool _isOakTreeLeftTrunkFootTile(int gid) => gid == 1428;

bool _isOakTreeRightTrunkFootTile(int gid) => gid == 1429;

bool _isOakTreeRightOuterFootTile(int gid) => gid == 1430;

bool _isMapleTreeTile(int gid) => gid >= 339 && gid < 369;

bool _isWoodTreeTile(int gid) {
  if (gid >= 1411 && gid <= 1430) {
    return true;
  }
  if (gid >= 693 && gid <= 696) {
    return true;
  }
  if (gid >= 715 && gid <= 718) {
    return true;
  }
  if (gid >= 737 && gid <= 740) {
    return true;
  }
  if (gid >= 759 && gid <= 762) {
    return true;
  }
  if (gid >= 781 && gid <= 784) {
    return true;
  }
  return switch (gid) {
    803 || 804 || 825 || 826 || 827 || 828 || 847 || 848 || 849 || 850 => true,
    _ => false,
  };
}

bool _isWoodTreeFootTile(int gid) {
  if (gid >= 1427 && gid <= 1430) {
    return true;
  }
  return switch (gid) {
    781 || 782 || 783 || 784 || 847 || 848 || 849 || 850 => true,
    _ => false,
  };
}

bool _isLampTile(int gid) => gid == 624 || gid == 631 || gid == 638;

bool _isSmallObstacleTile(int gid) {
  return switch (gid) {
    606 ||
    607 ||
    608 ||
    643 ||
    800 ||
    801 ||
    823 ||
    827 ||
    828 ||
    866 ||
    867 ||
    887 => true,
    _ => false,
  };
}

bool _isRockTile(int gid) =>
    gid == 643 || gid == 866 || gid == 867 || gid == 887;

bool _isLogTile(int gid) => gid == 606 || gid == 607 || gid == 608;

void _appendCollisionRect(
  List<Rect> rects,
  String layerName,
  int gid,
  double left,
  double top,
  double size,
) {
  if (_isBridgeTile(gid)) {
    return;
  }
  if (_isWaterTile(gid)) {
    rects.add(Rect.fromLTWH(left, top, size, size));
    return;
  }
  if (layerName == 'Tile Layer 1') {
    return;
  }
  if (_isHouseTile(gid)) {
    _appendHouseCollision(rects, gid, left, top, size);
    return;
  }
  if (_isFenceTile(gid)) {
    rects.add(Rect.fromLTWH(left, top, size, size));
    return;
  }
  if (_isMapleTreeFootTile(gid) || _isWoodTreeFootTile(gid)) {
    _appendTreeFootCollision(rects, gid, left, top, size);
    return;
  }
  if (_isLampTile(gid)) {
    _appendLampCollision(rects, gid, left, top, size);
    return;
  }
  if (_isSmallObstacleTile(gid)) {
    _appendSmallObstacleCollision(rects, gid, left, top, size);
  }
}

void _appendBridgeWaterGuardRects(
  List<Rect> rects,
  Map<int, int> bridgeTiles,
  int tileX,
  int tileY,
  int bridgeGid,
  double left,
  double top,
  double size,
) {
  const guardInset = 0.20;
  if (_isVerticalBridgeTile(bridgeGid)) {
    if (!bridgeTiles.containsKey(_tileKey(tileX - 1, tileY))) {
      _addInsetRect(rects, left, top, size, 0.0, 0.0, guardInset, 1.0);
    }
    if (!bridgeTiles.containsKey(_tileKey(tileX + 1, tileY))) {
      _addInsetRect(rects, left, top, size, 1.0 - guardInset, 0.0, 1.0, 1.0);
    }
    return;
  }

  if (_isHorizontalBridgeTile(bridgeGid)) {
    if (!bridgeTiles.containsKey(_tileKey(tileX, tileY - 1))) {
      _addInsetRect(rects, left, top, size, 0.0, 0.0, 1.0, guardInset);
    }
    if (!bridgeTiles.containsKey(_tileKey(tileX, tileY + 1))) {
      _addInsetRect(rects, left, top, size, 0.0, 1.0 - guardInset, 1.0, 1.0);
    }
  }
}

void _addInsetRect(
  List<Rect> rects,
  double left,
  double top,
  double size,
  double leftInset,
  double topInset,
  double rightInset,
  double bottomInset,
) {
  rects.add(
    Rect.fromLTRB(
      left + size * leftInset,
      top + size * topInset,
      left + size * rightInset,
      top + size * bottomInset,
    ),
  );
}

void _appendHouseCollision(
  List<Rect> rects,
  int gid,
  double left,
  double top,
  double size,
) {
  if (_isHouseFrontEdgeTile(gid)) {
    _addInsetRect(rects, left, top, size, 0, 0, 1, 0.42);
    return;
  }
  rects.add(Rect.fromLTWH(left, top, size, size));
}

void _appendLampCollision(
  List<Rect> rects,
  int gid,
  double left,
  double top,
  double size,
) {
  if (gid == 624 || gid == 631) {
    return;
  }
  _addInsetRect(rects, left, top, size, 0.40, 0.66, 0.60, 0.92);
}

void _appendTreeFootCollision(
  List<Rect> rects,
  int gid,
  double left,
  double top,
  double size,
) {
  if (_isOakTreeLeftOuterFootTile(gid) || _isOakTreeRightOuterFootTile(gid)) {
    return;
  }
  if (_isOakTreeLeftTrunkFootTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.50, 0.52, 1.00, 0.95);
    return;
  }
  if (_isOakTreeRightTrunkFootTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.00, 0.52, 0.50, 0.95);
    return;
  }
  if (_isLeftTreeFootTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.55, 0.50, 1.00, 0.95);
    return;
  }
  if (_isRightTreeFootTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.00, 0.50, 0.45, 0.95);
    return;
  }
  _addInsetRect(rects, left, top, size, 0.34, 0.50, 0.66, 0.95);
}

void _appendSmallObstacleCollision(
  List<Rect> rects,
  int gid,
  double left,
  double top,
  double size,
) {
  if (_isRockTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.28, 0.54, 0.76, 0.83);
    return;
  }
  if (_isLogTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.05, 0.52, 0.95, 0.84);
    return;
  }
  _addInsetRect(rects, left, top, size, 0.24, 0.42, 0.76, 0.82);
}

int _tileKey(int x, int y) => x * 1000000 + y;

bool _isForegroundLayer(String layerName) {
  return layerName.toLowerCase().contains('depan');
}

bool _isDrawnInForeground(String layerName, int gid) {
  if (_isBridgeTile(gid)) {
    return false;
  }
  return _isLampTile(gid) ||
      _isMapleTreeTile(gid) ||
      _isWoodTreeTile(gid) ||
      _isSmallObstacleTile(gid) ||
      (_isForegroundLayer(layerName) && gid >= 241 && !_isWaterTile(gid));
}

class _Tileset {
  const _Tileset({
    required this.firstGid,
    required this.tileWidth,
    required this.tileHeight,
    required this.columns,
    required this.image,
  });

  final int firstGid;
  final int tileWidth;
  final int tileHeight;
  final int columns;
  final ui.Image image;
}

class _MapLayer {
  _MapLayer(this.name);

  final String name;
  final List<_Tile> tiles = <_Tile>[];
  final List<List<_Tile>> backgroundRows = <List<_Tile>>[];
  final List<List<_Tile>> foregroundRows = <List<_Tile>>[];

  void buildDrawIndex(int minTileY, int maxTileY) {
    final rowCount = math.max(1, maxTileY - minTileY + 1);
    backgroundRows
      ..clear()
      ..addAll(List<List<_Tile>>.generate(rowCount, (_) => <_Tile>[]));
    foregroundRows
      ..clear()
      ..addAll(List<List<_Tile>>.generate(rowCount, (_) => <_Tile>[]));

    for (final tile in tiles) {
      final row = tile.y - minTileY;
      if (row < 0 || row >= rowCount) {
        continue;
      }
      final target = _isDrawnInForeground(name, tile.gid)
          ? foregroundRows[row]
          : backgroundRows[row];
      target.add(tile);
    }
    _sortRows(backgroundRows);
    _sortRows(foregroundRows);
  }

  List<List<_Tile>> rowsFor(bool foreground) {
    return foreground ? foregroundRows : backgroundRows;
  }

  void _sortRows(List<List<_Tile>> rows) {
    for (final row in rows) {
      row.sort((a, b) => a.x.compareTo(b.x));
    }
  }
}

class _Tile {
  const _Tile(this.x, this.y, this.gid);

  final int x;
  final int y;
  final int gid;
}
