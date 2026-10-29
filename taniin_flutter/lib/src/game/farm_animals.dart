import 'dart:math' as math;
import 'dart:ui';

/// The animal sprite sheets in assets/images. Every sheet's first row walks
/// sideways facing left; [idleRow] is what the animal does while it rests.
enum AnimalKind {
  chicken('assets/images/chicken_blonde_green.png', 16, 4, 0.9, 1),
  chickenRed('assets/images/chicken_red.png', 16, 4, 0.9, 1),
  babyChicken('assets/images/baby_chicken_yellow.png', 16, 4, 1.1, 1),
  cow('assets/images/female_cow_brown.png', 32, 4, 0.5, 1),
  maleCow('assets/images/male_cow_brown.png', 32, 4, 0.5, 1);

  const AnimalKind(
    this.asset,
    this.frameSize,
    this.columns,
    this.tilesPerSecond,
    this.idleRow,
  );

  final String asset;

  /// Frame edge in art pixels.
  final int frameSize;
  final int columns;
  final double tilesPerSecond;
  final int idleRow;

  bool get isCow => this == cow || this == maleCow;

  /// Cows have front (row 1) and back (row 2) walks for vertical moves.
  bool get hasVerticalRows => isCow;
}

enum AnimalFacing { left, right, down, up }

/// One wandering farm animal. Positions are world pixels at the animal's
/// feet. It rests, picks a spot near [home], walks there and rests again;
/// with a [parent] it trails that animal instead (chicks after hens).
class FarmAnimal {
  FarmAnimal({
    required this.kind,
    required Offset home,
    required this.roam,
    required this.tile,
    required int seed,
    this.parent,
  }) : _home = home,
       x = home.dx,
       y = home.dy,
       _random = math.Random(seed) {
    _restFor = 0.4 + _random.nextDouble() * 2.5;
  }

  final AnimalKind kind;

  /// How far from home it wanders, in world pixels.
  final double roam;
  final double tile;
  final FarmAnimal? parent;
  Offset _home;
  final math.Random _random;

  double x;
  double y;
  AnimalFacing facing = AnimalFacing.left;
  bool walking = false;
  double _restFor = 0;
  double _animClock = 0;
  Offset? _target;

  /// Drawn size in world pixels. Cows keep the map's pixel scale (two tiles,
  /// about as tall as a farmer); chicken art fills its whole 16 px frame, so
  /// at that scale a hen stands chest-high to a person. Hens are drawn
  /// knee-high instead and chicks smaller still.
  double get size => switch (kind) {
    AnimalKind.cow || AnimalKind.maleCow => tile * 2,
    AnimalKind.chicken || AnimalKind.chickenRed => tile * 0.62,
    AnimalKind.babyChicken => tile * 0.42,
  };

  /// Box around the feet that must stay clear of fences, houses and water.
  Rect footprint(double atX, double atY) {
    final halfW = kind.isCow ? tile * 0.42 : tile * 0.14;
    final halfH = kind.isCow ? tile * 0.16 : tile * 0.08;
    return Rect.fromLTRB(atX - halfW, atY - halfH, atX + halfW, atY + halfH);
  }

  /// Moves home to the nearest clear spot if it starts inside an obstacle,
  /// which would otherwise pin the animal in place.
  void settle(bool Function(Rect footprint) blocked) {
    if (!blocked(footprint(_home.dx, _home.dy))) {
      return;
    }
    for (var ring = 1; ring <= 8; ring++) {
      final radius = ring * tile * 0.25;
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        final spot = Offset(
          _home.dx + math.cos(angle) * radius,
          _home.dy + math.sin(angle) * radius,
        );
        if (!blocked(footprint(spot.dx, spot.dy))) {
          _home = spot;
          x = spot.dx;
          y = spot.dy;
          return;
        }
      }
    }
  }

  void update(double dt, bool Function(Rect footprint) blocked) {
    _animClock += dt;
    final parent = this.parent;
    if (parent != null) {
      _followParent(parent);
    } else if (!walking) {
      _restFor -= dt;
      if (_restFor <= 0) {
        _pickTarget();
      }
    }
    final target = _target;
    if (!walking || target == null) {
      return;
    }
    final dx = target.dx - x;
    final dy = target.dy - y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final step = kind.tilesPerSecond * tile * dt;
    if (distance <= step) {
      _stop(arrived: true);
      return;
    }
    final nextX = x + dx / distance * step;
    final nextY = y + dy / distance * step;
    if (blocked(footprint(nextX, nextY))) {
      _stop(arrived: false);
      return;
    }
    x = nextX;
    y = nextY;
    if (kind.hasVerticalRows && dy.abs() > dx.abs() * 1.4) {
      facing = dy > 0 ? AnimalFacing.down : AnimalFacing.up;
    } else if (dx.abs() > 0.5) {
      facing = dx < 0 ? AnimalFacing.left : AnimalFacing.right;
    }
  }

  void _pickTarget() {
    final angle = _random.nextDouble() * math.pi * 2;
    final distance = roam * (0.35 + _random.nextDouble() * 0.65);
    _target = Offset(
      _home.dx + math.cos(angle) * distance,
      _home.dy + math.sin(angle) * distance * 0.7,
    );
    walking = true;
  }

  void _followParent(FarmAnimal parent) {
    final dx = parent.x - x;
    final dy = parent.y - y;
    final gap = math.sqrt(dx * dx + dy * dy);
    if (!walking && gap > tile * 0.7) {
      final side = parent.facing == AnimalFacing.right ? -1 : 1;
      _target = Offset(
        parent.x + side * tile * 0.4,
        parent.y + tile * 0.15 * (_random.nextBool() ? 1 : -1),
      );
      walking = true;
    }
  }

  void _stop({required bool arrived}) {
    walking = false;
    _target = null;
    _animClock = 0;
    final base = kind.isCow ? 2.5 : 1.0;
    _restFor = base + _random.nextDouble() * (kind.isCow ? 4.0 : 3.0);
    if (!arrived) {
      // Bumped into something: rest a little, then try another direction.
      _restFor *= 0.5;
    }
    if (kind.isCow && _random.nextDouble() < 0.5) {
      facing = AnimalFacing.down;
    }
  }

  /// Sheet row and column to draw now, and whether to mirror it.
  ({int row, int column, bool flip}) frame() {
    if (walking) {
      final column =
          (_animClock / (kind.isCow ? 0.2 : 0.12)).floor() % kind.columns;
      return switch (facing) {
        AnimalFacing.down when kind.hasVerticalRows => (
          row: 1,
          column: column,
          flip: false,
        ),
        AnimalFacing.up when kind.hasVerticalRows => (
          row: 2,
          column: column,
          flip: false,
        ),
        _ => (row: 0, column: column, flip: facing == AnimalFacing.right),
      };
    }
    if (kind.isCow) {
      // Resting cows stand still, sometimes turned towards the camera.
      return facing == AnimalFacing.down
          ? (row: 1, column: 0, flip: false)
          : (row: 0, column: 0, flip: facing == AnimalFacing.right);
    }
    // Chickens peck in short bursts while resting.
    final pecking = (_animClock % 2.4) < 1.2;
    final column = pecking ? (_animClock / 0.18).floor() % kind.columns : 0;
    return (
      row: pecking ? kind.idleRow : 0,
      column: column,
      flip: facing == AnimalFacing.right,
    );
  }
}
