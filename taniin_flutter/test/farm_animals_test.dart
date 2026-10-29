import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:taniin_flutter/src/game/farm_animals.dart';

const tile = 128.0;

bool open(Rect _) => false;

void main() {
  test('cows draw at twice the size of chickens, matching the map pixels', () {
    final cow = FarmAnimal(
      kind: AnimalKind.cow,
      home: Offset.zero,
      roam: 0,
      tile: tile,
      seed: 1,
    );
    final hen = FarmAnimal(
      kind: AnimalKind.chicken,
      home: Offset.zero,
      roam: 0,
      tile: tile,
      seed: 1,
    );
    expect(cow.size, tile * 2);
    expect(hen.size, tile);
  });

  test('wanders away from home and stays within its roam radius', () {
    const home = Offset(2000, 2000);
    final hen = FarmAnimal(
      kind: AnimalKind.chicken,
      home: home,
      roam: tile * 1.5,
      tile: tile,
      seed: 3,
    );
    var moved = false;
    var farthest = 0.0;
    for (var i = 0; i < 60 * 30; i++) {
      hen.update(1 / 60, open);
      final distance = (Offset(hen.x, hen.y) - home).distance;
      moved = moved || distance > tile * 0.3;
      farthest = math.max(farthest, distance);
    }
    expect(moved, isTrue);
    expect(farthest, lessThanOrEqualTo(tile * 1.5 + 1));
  });

  test('never steps into an obstacle', () {
    const home = Offset(1000, 1000);
    final wall = Rect.fromLTWH(1000 + tile * 0.8, 0, tile, 4000);
    final cow = FarmAnimal(
      kind: AnimalKind.cow,
      home: home,
      roam: tile * 3,
      tile: tile,
      seed: 5,
    );
    for (var i = 0; i < 60 * 60; i++) {
      cow.update(1 / 60, (box) => box.overlaps(wall));
      expect(cow.footprint(cow.x, cow.y).overlaps(wall), isFalse);
    }
  });

  test('settle moves an animal out of an obstacle it spawned in', () {
    final fence = Rect.fromLTWH(950, 950, 100, 100);
    final hen = FarmAnimal(
      kind: AnimalKind.chicken,
      home: const Offset(1000, 1000),
      roam: tile,
      tile: tile,
      seed: 2,
    )..settle((box) => box.overlaps(fence));
    expect(hen.footprint(hen.x, hen.y).overlaps(fence), isFalse);
  });

  test('chicks follow their mother', () {
    final hen = FarmAnimal(
      kind: AnimalKind.chicken,
      home: const Offset(3000, 3000),
      roam: tile * 3,
      tile: tile,
      seed: 9,
    );
    final chick = FarmAnimal(
      kind: AnimalKind.babyChicken,
      home: const Offset(3000, 3000),
      roam: 0,
      tile: tile,
      seed: 10,
      parent: hen,
    );
    for (var i = 0; i < 60 * 40; i++) {
      hen.update(1 / 60, open);
      chick.update(1 / 60, open);
    }
    expect(
      (Offset(hen.x, hen.y) - Offset(chick.x, chick.y)).distance,
      lessThan(tile * 2.5),
    );
  });

  test('walking right mirrors the left-facing walk row', () {
    final hen =
        FarmAnimal(
            kind: AnimalKind.chicken,
            home: Offset.zero,
            roam: 0,
            tile: tile,
            seed: 4,
          )
          ..walking = true
          ..facing = AnimalFacing.right;
    final frame = hen.frame();
    expect(frame.row, 0);
    expect(frame.flip, isTrue);
  });
}
