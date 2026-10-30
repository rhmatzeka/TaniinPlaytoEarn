import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

const int _gidMask = 0x1fffffff;

/// Replacement art for one kind of map tile. A variant is picked by tile
/// position; its bottom centre sits on the bottom edge of the tile, [anchorDx]
/// tiles from the tile's left edge. A [skip] entry draws nothing because a
/// partner tile draws the whole object.
class TileArt {
  const TileArt(
    this.variants, {
    this.anchorDx = 0.5,
    this.frameWidth = 0,
    this.fps = 0,
  }) : skip = false;

  const TileArt.skip()
    : variants = const <ui.Image>[],
      anchorDx = 0,
      frameWidth = 0,
      fps = 0,
      skip = true;

  final List<ui.Image> variants;
  final double anchorDx;

  /// Variants that are strips of [frameWidth] px frames play at [fps].
  final int frameWidth;
  final double fps;
  final bool skip;
}

/// A map tile that stands on the ground (trees, lamps, rocks, house fronts),
/// drawn in depth order with the actors. [sortRow] is the row of the
/// object's foot, in tiles from the top of the map.
class MapSprite {
  const MapSprite(this.x, this.y, this.gid, this.sortRow, this.order);

  final int x;
  final int y;
  final int gid;
  final double sortRow;

  /// Paint order among sprites sharing a [sortRow] (layer, then row).
  final int order;
}

class TmxMap {
  TmxMap._();

  final List<_Tileset> _tilesets = <_Tileset>[];
  final List<_MapLayer> _layers = <_MapLayer>[];
  final Map<int, int> _bridgeTiles = <int, int>{};
  final Map<int, int> _waterTiles = <int, int>{};
  final List<MapSprite> _sprites = <MapSprite>[];
  final List<int> _firstGids = <int>[];

  /// Art drawn instead of the tileset image for some tile ids.
  final Map<int, TileArt> tileArt = <int, TileArt>{};
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
    _firstGids
      ..clear()
      ..addAll([
        for (final element in root.findElements('tileset'))
          _intAttr(element, 'firstgid', 1),
      ])
      ..sort();
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

  /// Water cells as (column, row) from the top-left of the map.
  Iterable<(int, int)> get waterCells sync* {
    for (final key in _waterTiles.keys) {
      if (!_bridgeTiles.containsKey(key)) {
        yield (key ~/ 1000000 - minTileX, key % 1000000 - minTileY);
      }
    }
  }

  bool isWaterCell(int column, int row) =>
      _waterTiles.containsKey(_tileKey(column + minTileX, row + minTileY));

  /// Standing tiles, in paint order.
  List<MapSprite> get sprites => _sprites;

  void forEachVisibleSprite(
    double cameraX,
    double cameraY,
    double targetTileSize,
    Size viewport,
    void Function(MapSprite sprite) visit,
  ) {
    final firstX = minTileX + (cameraX / targetTileSize).floor() - 3;
    final lastX =
        minTileX + ((cameraX + viewport.width) / targetTileSize).floor() + 3;
    final firstY = minTileY + (cameraY / targetTileSize).floor() - 2;
    final lastY =
        minTileY + ((cameraY + viewport.height) / targetTileSize).floor() + 6;
    for (final sprite in _sprites) {
      if (sprite.x >= firstX &&
          sprite.x <= lastX &&
          sprite.y >= firstY &&
          sprite.y <= lastY) {
        visit(sprite);
      }
    }
  }

  void drawSprite(
    Canvas canvas,
    MapSprite sprite,
    double cameraX,
    double cameraY,
    double targetTileSize, {
    double time = 0,
  }) {
    final left = (sprite.x - minTileX) * targetTileSize - cameraX;
    final top = (sprite.y - minTileY) * targetTileSize - cameraY;
    if (!_drawArt(
      canvas,
      sprite.gid,
      sprite.x,
      sprite.y,
      left,
      top,
      targetTileSize,
      time,
    )) {
      _drawTile(canvas, sprite.gid, left, top, targetTileSize);
    }
  }

  /// Draws [tileArt] for [gid] if there is any; false means draw the tile.
  bool _drawArt(
    Canvas canvas,
    int gid,
    int tileX,
    int tileY,
    double left,
    double top,
    double targetTileSize,
    double time,
  ) {
    final art = tileArt[gid];
    if (art == null) {
      return false;
    }
    if (art.skip || art.variants.isEmpty) {
      return true;
    }
    final hash = (tileX * 73856093) ^ (tileY * 19349663);
    final image = art.variants[hash.abs() % art.variants.length];
    final isStrip = art.frameWidth > 0 && image.width % art.frameWidth == 0;
    final frames = isStrip ? image.width ~/ art.frameWidth : 1;
    final sourceWidth = isStrip
        ? art.frameWidth.toDouble()
        : image.width.toDouble();
    final frame = frames > 1
        ? (time * art.fps + tileX * 0.37).floor() % frames
        : 0;
    final scale = targetTileSize / tileWidth;
    final width = sourceWidth * scale;
    final height = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        frame * sourceWidth,
        0,
        sourceWidth,
        image.height.toDouble(),
      ),
      Rect.fromLTWH(
        left + art.anchorDx * targetTileSize - width / 2,
        top + targetTileSize - height,
        width,
        height,
      ),
      _pixelPaint,
    );
    return true;
  }

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
    Size viewport, {
    double time = 0,
  }) {
    _drawLayers(
      canvas,
      cameraX,
      cameraY,
      targetTileSize,
      viewport,
      false,
      time,
    );
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
    _buildSprites();
  }

  /// Collects the standing tiles and gives each the row of its object's foot.
  /// Trees and lamps are followed down their column (through tiles of the
  /// same kind) to the trunk or base tile; canopy columns with no trunk of
  /// their own borrow the nearest trunk on the same row. Houses use the bottom
  /// of their column; anything else stands on its own row.
  void _buildSprites() {
    final entries = <(_Tile, int)>[];
    final cells = <int, List<int>>{};
    for (var index = 0; index < _layers.length; index++) {
      final layer = _layers[index];
      for (final tile in layer.tiles) {
        if (_isDrawnInForeground(layer.name, tile.gid)) {
          entries.add((tile, index));
          cells
              .putIfAbsent(_tileKey(tile.x, tile.y), () => <int>[])
              .add(tile.gid);
        }
      }
    }
    bool has(int x, int y, bool Function(int gid) test) =>
        cells[_tileKey(x, y)]?.any(test) ?? false;
    // Tiles of one object come from one tileset; overlapping objects from
    // other sheets must not join the column.
    int sheet(int gid) =>
        _firstGids.lastWhere((g) => g <= gid, orElse: () => 0);
    final bottoms = <(int, int, int), int>{};
    int columnBottom(int x, int y, int gid) {
      final kind = _standingKind(gid);
      final group = sheet(gid);
      bool same(int other) =>
          _standingKind(other) == kind && sheet(other) == group;
      bool foot(int other) => same(other) && _isFootTile(other);
      return bottoms.putIfAbsent((x, y, group), () {
        var bottom = y;
        while (!(kind != _Standing.house && has(x, bottom, foot)) &&
            has(x, bottom + 1, same)) {
          bottom++;
        }
        return bottom;
      });
    }

    entries.sort((a, b) {
      final byLayer = a.$2.compareTo(b.$2);
      if (byLayer != 0) {
        return byLayer;
      }
      final byRow = a.$1.y.compareTo(b.$1.y);
      return byRow != 0 ? byRow : a.$1.x.compareTo(b.$1.x);
    });
    _sprites.clear();
    for (var order = 0; order < entries.length; order++) {
      final tile = entries[order].$1;
      final kind = _standingKind(tile.gid);
      var foot = tile.y;
      if (kind != _Standing.alone) {
        final group = sheet(tile.gid);
        bool same(int other) =>
            _standingKind(other) == kind && sheet(other) == group;
        bool isFoot(int other) => same(other) && _isFootTile(other);
        foot = columnBottom(tile.x, tile.y, tile.gid);
        if (kind == _Standing.tree && !has(tile.x, foot, isFoot)) {
          search:
          for (var step = 1; step <= 2; step++) {
            for (final direction in const [-1, 1]) {
              final x = tile.x + direction * step;
              final bottom = columnBottom(x, tile.y, tile.gid);
              if (has(x, tile.y, same) && has(x, bottom, isFoot)) {
                foot = bottom;
                break search;
              }
            }
          }
        }
      }
      _sprites.add(
        MapSprite(tile.x, tile.y, tile.gid, foot - minTileY + 0.72, order),
      );
    }
  }

  void _drawTile(
    Canvas canvas,
    int gid,
    double left,
    double top,
    double targetTileSize,
  ) {
    final tileset = _findTileset(gid);
    if (tileset == null) {
      return;
    }
    final scale = targetTileSize / tileWidth;
    final localId = gid - tileset.firstGid;
    final sourceX = (localId % tileset.columns) * tileset.tileWidth;
    final sourceY = (localId ~/ tileset.columns) * tileset.tileHeight;
    canvas.drawImageRect(
      tileset.image,
      Rect.fromLTWH(
        sourceX.toDouble(),
        sourceY.toDouble(),
        tileset.tileWidth.toDouble(),
        tileset.tileHeight.toDouble(),
      ),
      Rect.fromLTWH(
        left,
        top,
        tileset.tileWidth * scale,
        tileset.tileHeight * scale,
      ),
      _pixelPaint,
    );
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
    double time,
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
          final screenLeft = (tile.x - minTileX) * targetTileSize - cameraX;
          final screenTop = (tile.y - minTileY) * targetTileSize - cameraY;
          if (_drawArt(
            canvas,
            tile.gid,
            tile.x,
            tile.y,
            screenLeft,
            screenTop,
            targetTileSize,
            time,
          )) {
            continue;
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

/// Maple-sheet stumps, placed on their own rather than under a canopy.
bool _isStumpTile(int gid) => gid == 367 || gid == 368;

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

enum _Standing { tree, lamp, house, alone }

_Standing _standingKind(int gid) {
  if (_isMapleTreeTile(gid) || _isWoodTreeTile(gid)) {
    return _Standing.tree;
  }
  if (_isLampTile(gid)) {
    return _Standing.lamp;
  }
  if (_isHouseTile(gid)) {
    return _Standing.house;
  }
  return _Standing.alone;
}

bool _isFootTile(int gid) =>
    _isMapleTreeFootTile(gid) || _isWoodTreeFootTile(gid) || gid == 638;

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
  if (_isStumpTile(gid)) {
    _addInsetRect(rects, left, top, size, 0.22, 0.52, 0.78, 0.92);
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
