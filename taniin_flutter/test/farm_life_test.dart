import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:taniin_flutter/src/chain/multiplayer_client.dart';
import 'package:taniin_flutter/src/game/farm_life.dart';

const tile = 128.0;
const world = Size(40 * tile, 35 * tile);
const farAway = Offset(-9999, -9999);

void main() {
  test('villagers walk their road routes', () {
    final life = FarmLife(tile: tile);
    final start = {for (final v in life.villagers) v.spec.id: Offset(v.x, v.y)};
    for (var i = 0; i < 60 * 20; i++) {
      life.update(1 / 60, farAway, world);
    }
    for (final v in life.villagers) {
      expect(
        (Offset(v.x, v.y) - start[v.spec.id]!).distance,
        greaterThan(tile),
        reason: '${v.spec.name} should have moved',
      );
      // Every position stays on the axis-aligned route between waypoints.
      final onRoute = v.spec.route.any(
        (p) => (p.dx * tile - v.x).abs() < 1 || (p.dy * tile - v.y).abs() < 1,
      );
      expect(onRoute, isTrue, reason: '${v.spec.name} left the road');
    }
  });

  test('a villager stops and greets a nearby player', () {
    final life = FarmLife(tile: tile);
    final sari = life.villagers.first;
    life.update(1 / 60, Offset(sari.x + tile, sari.y), world);
    expect(sari.bubble, isNotNull);
    expect(sari.walking, isFalse);
    expect(sari.facing, Facing.right);
  });

  test('birds fly across and fish jumps finish', () {
    final life = FarmLife(tile: tile);
    var sawBird = false;
    var sawFish = false;
    for (var i = 0; i < 60 * 30; i++) {
      life.update(1 / 60, farAway, world);
      sawBird = sawBird || life.birds.isNotEmpty;
      sawFish = sawFish || life.fish.isNotEmpty;
      expect(life.birds.length, lessThanOrEqualTo(2));
    }
    expect(sawBird, isTrue);
    expect(sawFish, isTrue);
  });

  test('every decoration has a collision box', () {
    final life = FarmLife(tile: tile);
    expect(life.decorationBlocks(), hasLength(decorations.length));
  });

  test('offline AI walks roads around the seed shop', () {
    const shop = Rect.fromLTRB(15 * tile, 18 * tile, 21.7 * tile, 25.6 * tile);
    const sell = Offset(31.5 * tile, 16.6 * tile);
    const swap = Offset(11 * tile, 14.6 * tile);
    const plot = Offset(9 * tile, 23.7 * tile);
    for (final (start, target) in [(sell, swap), (swap, plot), (plot, sell)]) {
      final path = aiRoadPath(start, target);
      expect(path.last, target);
      var previous = start;
      for (final point in path) {
        for (var i = 0; i <= 20; i++) {
          final probe = Offset.lerp(previous, point, i / 20)!;
          expect(
            shop.contains(probe),
            isFalse,
            reason: 'crosses the shop between $previous and $point',
          );
        }
        previous = point;
      }
    }
  });
}
