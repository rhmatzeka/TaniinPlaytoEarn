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
  final Paint _pixelPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _miniPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;
  final Paint _miniTilePaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;

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
    map.tileWidth = _intAttr(root, 'tilewidth', 16);
    map.tileHeight = _intAttr(root, 'tileheight', 16);

    for (final element in root.findElements('tileset')) {
      final source = element.getAttribute('source');
      if (source == null || source.isEmpty) {
        continue;
      }
      final firstGid = _intAttr(element, 'firstgid', 1);
      map._tilesets.add(await _loadTileset(basePath, source, firstGid));
    }
    map._tilesets.sort((a, b) => a.firstGid.compareTo(b.firstGid));

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
        map._layers.add(layer);
      }
    }

    if (minX == 1 << 30) {
      minX = 0;
      minY = 0;
      maxX = 1;
      maxY = 1;
    }
    map
      ..minTileX = minX
      ..minTileY = minY
      ..maxTileX = maxX
      ..maxTileY = maxY
      .._buildLayerIndexes();
    return map;
  }

  double getWorldWidthPixels(double targetTileSize) {
    return (maxTileX - minTileX + 1) * targetTileSize;
  }

  double getWorldHeightPixels(double targetTileSize) {
    return (maxTileY - minTileY + 1) * targetTileSize;
  }

  List<Rect> collisionRects(double targetTileSize) {
    final rects = <Rect>[];
    final bridgeTiles = <int>{};
    for (final layer in _layers) {
      for (final tile in layer.tiles) {
        if (_isBridgeTile(tile.gid)) {
          bridgeTiles.add(_tileKey(tile.x, tile.y));
        }
      }
    }

    for (final layer in _layers) {
      for (final tile in layer.tiles) {
        final key = _tileKey(tile.x, tile.y);
        if (bridgeTiles.contains(key) && _isWaterTile(tile.gid)) {
          continue;
        }
        final left = (tile.x - minTileX) * targetTileSize;
        final top = (tile.y - minTileY) * targetTileSize;
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
    final scaleX =
        bounds.width / math.max(1, getWorldWidthPixels(targetTileSize));
    final scaleY =
        bounds.height / math.max(1, getWorldHeightPixels(targetTileSize));
    final tileW = math.max(1.0, targetTileSize * scaleX);
    final tileH = math.max(1.0, targetTileSize * scaleY);

    _miniPaint.color = const Color(0xFF69B84E);
    canvas.drawRect(bounds, _miniPaint);
    for (final layer in _layers) {
      for (final tile in layer.tiles) {
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
        final x = bounds.left + (tile.x - minTileX) * targetTileSize * scaleX;
        final y = bounds.top + (tile.y - minTileY) * targetTileSize * scaleY;
        final dst = Rect.fromLTWH(x, y, tileW, tileH);
        canvas.drawImageRect(tileset.image, src, dst, _miniTilePaint);
      }
    }
  }

  void _buildLayerIndexes() {
    for (final layer in _layers) {
      layer.buildDrawIndex(minTileY, maxTileY);
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
    818 || 819 || 821 || 840 || 861 || 865 || 883 || 884 || 906 || 907 => true,
    _ => false,
  };
}

bool _isBridgeTile(int gid) => gid >= 1396 && gid <= 1410;

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

int _tileKey(int x, int y) => (x << 32) ^ (y & 0xffffffff);

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
