import 'package:flutter_test/flutter_test.dart';
import 'package:taniin_flutter/src/game/tmx_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a whole tree sorts by the row of its trunk foot', () async {
    final map = await TmxMap.loadCollisionDataForTesting('assets/game/map.tmx');
    final byCell = {
      for (final s in map.sprites)
        if (s.gid >= 1411 && s.gid <= 1430) (s.x, s.y): s,
    };
    // Oak trunk feet: every tile of the tree above shares their depth, so
    // someone standing in front of the trunk is drawn over the whole tree.
    final feet = map.sprites.where((s) => s.gid == 1428).toList();
    expect(feet, isNotEmpty);
    for (final foot in feet) {
      final footRow = foot.y - map.minTileY + 0.72;
      expect(foot.sortRow, closeTo(footRow, 1e-9));
      for (var dy = 1; dy <= 3; dy++) {
        for (var dx = -1; dx <= 2; dx++) {
          final tile = byCell[(foot.x + dx, foot.y - dy)];
          if (tile != null) {
            expect(tile.sortRow, closeTo(footRow, 1e-9));
          }
        }
      }
    }
  });

  test('lamps sort by their base', () async {
    final map = await TmxMap.loadCollisionDataForTesting('assets/game/map.tmx');
    final bases = map.sprites.where((s) => s.gid == 638).toList();
    expect(bases, isNotEmpty);
    for (final base in bases) {
      final head = map.sprites.where(
        (s) =>
            (s.gid == 624 || s.gid == 631) &&
            s.x == base.x &&
            s.y < base.y &&
            s.y >= base.y - 2,
      );
      for (final tile in head) {
        expect(tile.sortRow, base.sortRow);
      }
    }
  });
}
