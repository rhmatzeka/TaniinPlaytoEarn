import 'dart:math' as math;
import 'dart:ui';

/// Ambient life that makes the village feel inhabited: villagers walking the
/// roads, butterflies, passing birds, ducks and jumping fish. Positions are
/// world pixels (tile coordinates times [tile]); all of it is local only.
class FarmLife {
  FarmLife({required this.tile, int seed = 11}) : _random = math.Random(seed) {
    villagers = [
      for (final spec in _villagerSpecs)
        Villager(
          spec: spec,
          tile: tile,
          random: math.Random(_random.nextInt(1 << 30)),
        ),
    ];
    butterflies = [
      for (var i = 0; i < _butterflyHomes.length; i++)
        Butterfly(
          home: _at(_butterflyHomes[i]),
          color: i % 4,
          tile: tile,
          random: math.Random(_random.nextInt(1 << 30)),
        ),
    ];
    ducks = [
      for (var i = 0; i < 3; i++)
        Duck(
          waypoints: [for (final p in _lakePoints) _at(p)],
          tile: tile,
          random: math.Random(_random.nextInt(1 << 30)),
          female: i == 1,
          ducklings: i == 1 ? 3 : 0,
        ),
      Duck(
        waypoints: [for (final p in _riverPoints) _at(p)],
        tile: tile,
        random: math.Random(_random.nextInt(1 << 30)),
        female: true,
        ducklings: 2,
      ),
      Duck(
        waypoints: [for (final p in _riverPoints) _at(p)],
        tile: tile,
        random: math.Random(_random.nextInt(1 << 30)),
      ),
    ];
    fishShadows = [
      for (final points in [
        _lakePoints,
        _lakePoints,
        _riverPoints,
        _riverPoints,
      ])
        FishShadow(
          waypoints: [for (final p in points) _at(p)],
          tile: tile,
          random: math.Random(_random.nextInt(1 << 30)),
        ),
    ];
    dragonflies = [
      for (var i = 0; i < _dragonflyHomes.length; i++)
        Dragonfly(home: _at(_dragonflyHomes[i]), tile: tile, phase: i * 2.1),
    ];
    leaves = [
      for (var i = 0; i < 3; i++)
        DriftLeaf(tile: tile, start: _riverStartX + i * 9, phase: i * 1.7),
    ];
    _nextBird = 2 + _random.nextDouble() * 4;
    _nextFish = 1.5 + _random.nextDouble() * 3;
  }

  final double tile;
  final math.Random _random;
  late final List<Villager> villagers;
  late final List<Butterfly> butterflies;
  late final List<Duck> ducks;
  late final List<FishShadow> fishShadows;
  late final List<Dragonfly> dragonflies;
  late final List<DriftLeaf> leaves;
  final List<Bird> birds = [];
  final List<FishJump> fish = [];
  double _nextBird = 0;
  double _nextFish = 0;

  Offset _at(Offset tiles) => tiles * tile;

  void update(double dt, Offset player, Size world) {
    for (final villager in villagers) {
      villager.update(dt, player);
    }
    for (final butterfly in butterflies) {
      butterfly.update(dt);
    }
    for (final duck in ducks) {
      duck.update(dt);
    }
    for (final shadow in fishShadows) {
      shadow.update(dt);
    }
    for (final dragonfly in dragonflies) {
      dragonfly.update(dt);
    }
    for (final leaf in leaves) {
      leaf.update(dt);
    }

    _nextBird -= dt;
    if (_nextBird <= 0 && birds.length < 2) {
      final fromLeft = _random.nextBool();
      birds.add(
        Bird(
          start: Offset(
            fromLeft ? -tile : world.width + tile,
            (3 + _random.nextDouble() * (world.height / tile - 6)) * tile,
          ),
          direction: fromLeft ? 1 : -1,
          tile: tile,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      );
      _nextBird = 6 + _random.nextDouble() * 9;
    }
    for (final bird in birds) {
      bird.update(dt);
    }
    birds.removeWhere(
      (bird) => bird.x < -2 * tile || bird.x > world.width + 2 * tile,
    );

    _nextFish -= dt;
    if (_nextFish <= 0) {
      final spots = [..._lakePoints, ..._riverPoints];
      final spot = spots[_random.nextInt(spots.length)];
      fish.add(
        FishJump(origin: _at(spot), tile: tile, left: _random.nextBool()),
      );
      _nextFish = 2.5 + _random.nextDouble() * 4.5;
    }
    for (final jump in fish) {
      jump.update(dt);
    }
    fish.removeWhere((jump) => jump.done);
  }

  /// Footprints of [decorations] in world pixels, for collision.
  List<Rect> decorationBlocks() => [
    for (final deco in decorations)
      if (deco.block != null)
        Rect.fromLTRB(
          (deco.x + deco.block!.left) * tile,
          (deco.y + deco.block!.top) * tile,
          (deco.x + deco.block!.right) * tile,
          (deco.y + deco.block!.bottom) * tile,
        ),
  ];
}

/// A placed prop. [x], [y] are the tile coordinates of its bottom centre;
/// [block] is its collision box relative to that point, in tiles. Animated
/// props are a horizontal strip of [frameWidth] px frames played at [fps];
/// an image that isn't such a strip is drawn whole.
/// Sprite: `assets/images/dekor/<asset>.png`.
class Prop {
  const Prop(
    this.asset,
    this.x,
    this.y, {
    this.block,
    this.frameWidth = 0,
    this.fps = 0,
  });

  final String asset;
  final double x;
  final double y;
  final Rect? block;
  final int frameWidth;
  final double fps;
}

const decorations = <Prop>[
  // Scarecrow watching the plots, a crow on its arm.
  Prop(
    'orangan',
    14.5,
    22.4,
    block: Rect.fromLTRB(-0.2, -0.3, 0.2, 0),
    frameWidth: 26,
    fps: 3,
  ),
  // Haystack and stacked bales by the field yard.
  Prop('jerami', 5.8, 17.0, block: Rect.fromLTRB(-0.5, -0.5, 0.5, 0)),
  Prop('jerami_tumpuk', 7.6, 17.0, block: Rect.fromLTRB(-0.8, -0.6, 0.8, 0)),
  // A crate of produce and a rain barrel outside the buyer's house.
  Prop('peti', 28.4, 13.5, block: Rect.fromLTRB(-0.45, -0.6, 0.45, 0)),
  Prop(
    'tong',
    28.6,
    14.7,
    block: Rect.fromLTRB(-0.4, -0.5, 0.4, 0),
    frameWidth: 16,
    fps: 2.5,
  ),
  // Village well beside the swap house.
  Prop(
    'sumur',
    14.0,
    13.7,
    block: Rect.fromLTRB(-0.95, -0.7, 0.95, 0),
    frameWidth: 36,
    fps: 3,
  ),
  // Market stall on the south side of the main road.
  Prop(
    'kios',
    22.0,
    30.0,
    block: Rect.fromLTRB(-1.6, -0.8, 1.6, 0),
    frameWidth: 56,
    fps: 4,
  ),
  // Flower beds along the main road.
  Prop(
    'bunga',
    10.5,
    28.8,
    block: Rect.fromLTRB(-1.0, -0.5, 1.0, 0),
    frameWidth: 36,
    fps: 2.5,
  ),
  Prop(
    'bunga_2',
    29.5,
    28.9,
    block: Rect.fromLTRB(-1.0, -0.5, 1.0, 0),
    frameWidth: 36,
    fps: 2.5,
  ),
  // A cart of produce by the road, south of the plots.
  Prop('gerobak', 16.8, 29.9, block: Rect.fromLTRB(-0.9, -0.5, 1.0, 0)),
  // Notice board at the crossroads.
  Prop(
    'papan_pengumuman',
    29.5,
    25.9,
    block: Rect.fromLTRB(-0.7, -0.3, 0.7, 0),
    frameWidth: 28,
    fps: 2,
  ),
  // Washing drying in the east yard.
  Prop(
    'jemuran',
    38.3,
    17.8,
    block: Rect.fromLTRB(-1.3, -0.25, 1.3, 0),
    frameWidth: 44,
    fps: 2.5,
  ),
  // Chicken coop by the roadside hens.
  Prop('kandang_ayam', 38.5, 31.9, block: Rect.fromLTRB(-1.0, -0.6, 1.0, 0)),
  // Bamboo fence along the lake shore.
  Prop('pagar_bambu', 4.2, 29.7, block: Rect.fromLTRB(-0.62, -0.3, 0.62, 0)),
  Prop('pagar_bambu', 5.45, 29.7, block: Rect.fromLTRB(-0.62, -0.3, 0.62, 0)),
  Prop('pagar_bambu', 6.7, 29.7, block: Rect.fromLTRB(-0.62, -0.3, 0.62, 0)),
];

/// Something floating in or growing out of the water, drawn under the ducks.
/// [asset] is a path under assets/images/ without the extension.
class WaterProp {
  const WaterProp(
    this.asset,
    this.x,
    this.y, {
    this.frameWidth = 0,
    this.fps = 0,
  });

  final String asset;
  final double x;
  final double y;
  final int frameWidth;
  final double fps;
}

const waterProps = <WaterProp>[
  // Lily pads, some in bloom.
  WaterProp('alam/teratai_1', 6.0, 10.4),
  WaterProp('alam/teratai_1', 21.0, 9.8),
  WaterProp('alam/teratai_1', 12.0, 33.8),
  WaterProp('alam/teratai_2', 15.0, 10.6),
  WaterProp('alam/teratai_2', 3.0, 30.6),
  WaterProp('alam/teratai_2', 30.6, 6.2),
  WaterProp('alam/teratai_3', 19.0, 10.6),
  WaterProp('alam/teratai_3', 9.0, 31.4),
  // Frogs sitting on their pads.
  WaterProp('satwa/katak', 17.0, 10.4, frameWidth: 16, fps: 1.2),
  WaterProp('satwa/katak', 2.6, 33.2, frameWidth: 16, fps: 1.2),
  // Reeds and cattails at the banks.
  WaterProp('alam/alang_1', 8.5, 8.7, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 20.5, 8.6, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 14.5, 10.95, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 28.4, 10.9, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 6.5, 30.9, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 1.6, 29.6, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_1', 29.4, 6.0, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_2', 3.5, 10.9, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_2', 17.8, 8.6, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_2', 12.8, 32.6, frameWidth: 16, fps: 2.5),
  WaterProp('alam/alang_2', 31.4, 7.0, frameWidth: 16, fps: 2.5),
];

class VillagerSpec {
  const VillagerSpec({
    required this.id,
    required this.name,
    required this.route,
    required this.lines,
    this.speed = 1.6,
  });

  /// Sprite id: `assets/images/dunia/warga_<id>_{jalan,diam}.png`.
  final String id;
  final String name;

  /// Road waypoints in tiles, walked back and forth.
  final List<Offset> route;
  final List<String> lines;

  /// Tiles per second.
  final double speed;
}

const _villagerSpecs = <VillagerSpec>[
  VillagerSpec(
    id: 'sari',
    name: 'Bu Sari',
    route: [
      Offset(6, 26.6),
      Offset(16, 26.6),
      Offset(26.5, 26.6),
      Offset(33, 26.6),
    ],
    lines: [
      'Pagi! Toko benih ada di rumah berpagar itu.',
      'Kentang paling murah buat mulai bertani.',
      'Jangan lupa jual panenmu di rumah pengepul ya.',
    ],
  ),
  VillagerSpec(
    id: 'budi',
    name: 'Pak Budi',
    route: [
      Offset(34.6, 2),
      Offset(34.6, 10),
      Offset(34.6, 17),
      Offset(34.6, 25),
      Offset(34.6, 29),
    ],
    lines: [
      'Rumah merah di sana itu pengepul hasil panen.',
      'Stroberi mahal, tapi untungnya besar.',
      'Hati-hati, jalanan ini ramai gerobak.',
    ],
    speed: 1.4,
  ),
  VillagerSpec(
    id: 'rani',
    name: 'Dek Rani',
    route: [
      Offset(5.5, 14.6),
      Offset(15, 14.6),
      Offset(26.5, 14.6),
      Offset(26.5, 20),
      Offset(26.5, 25.8),
    ],
    lines: [
      'Halo, petani baru! Lahanmu di sebelah kiri.',
      'Aku suka lihat kupu-kupu di dekat bunga.',
      'Coba tanya Pak Tani AI, dia pintar lho.',
    ],
    speed: 1.8,
  ),
  VillagerSpec(
    id: 'karto',
    name: 'Mbah Karto',
    route: [
      Offset(5, 4.6),
      Offset(14, 4.6),
      Offset(23.5, 4.6),
      Offset(23.5, 8),
      Offset(23.5, 12.5),
    ],
    lines: [
      'Dulu sawah di sini luas sekali, Nak.',
      'Bertani itu soal sabar.',
      'Rumah tukar ada di seberang sungai.',
    ],
    speed: 1.0,
  ),
];

enum Facing { down, up, left, right }

class Villager {
  Villager({required this.spec, required this.tile, required this.random}) {
    _index = random.nextInt(spec.route.length);
    final start = spec.route[_index] * tile;
    x = start.dx;
    y = start.dy;
    _pickNext();
    _pause = random.nextDouble() * 2;
  }

  final VillagerSpec spec;
  final double tile;
  final math.Random random;

  double x = 0;
  double y = 0;
  Facing facing = Facing.down;
  bool walking = false;
  int _index = 0;
  int _step = 1;
  double _pause = 0;
  double _greetCooldown = 0;
  double _clock = 0;

  /// Speech bubble text, shown while [bubbleTime] counts down.
  String? bubble;
  double bubbleTime = 0;

  /// True while the player stands close enough to read the name tag.
  bool near = false;

  double get animClock => _clock;

  void _pickNext() {
    if (_index + _step < 0 || _index + _step >= spec.route.length) {
      _step = -_step;
    }
    _index += _step;
  }

  void update(double dt, Offset player) {
    _clock += dt;
    _greetCooldown = math.max(0, _greetCooldown - dt);
    if (bubbleTime > 0) {
      bubbleTime -= dt;
      if (bubbleTime <= 0) {
        bubble = null;
      }
    }

    final toPlayer = player - Offset(x, y);
    near = toPlayer.distance < tile * 2.6;
    if (near && _greetCooldown <= 0) {
      bubble = spec.lines[random.nextInt(spec.lines.length)];
      bubbleTime = 4;
      _greetCooldown = 18;
    }

    // Stop and look at the player while talking.
    if (bubble != null && near) {
      walking = false;
      facing = toPlayer.dy.abs() > toPlayer.dx.abs()
          ? (toPlayer.dy > 0 ? Facing.down : Facing.up)
          : (toPlayer.dx > 0 ? Facing.right : Facing.left);
      return;
    }

    if (_pause > 0) {
      _pause -= dt;
      walking = false;
      return;
    }

    final target = spec.route[_index] * tile;
    final delta = target - Offset(x, y);
    final distance = delta.distance;
    final step = spec.speed * tile * dt;
    walking = true;
    if (distance <= step) {
      x = target.dx;
      y = target.dy;
      _pickNext();
      if (random.nextDouble() < 0.5) {
        _pause = 1 + random.nextDouble() * 3;
      }
      return;
    }
    x += delta.dx / distance * step;
    y += delta.dy / distance * step;
    facing = delta.dy.abs() > delta.dx.abs()
        ? (delta.dy > 0 ? Facing.down : Facing.up)
        : (delta.dx > 0 ? Facing.right : Facing.left);
  }
}

const _butterflyHomes = <Offset>[
  Offset(8, 24.6),
  Offset(12.5, 24.8),
  Offset(19.5, 28.6),
  Offset(24.5, 20.5),
  Offset(26.3, 12.2),
  Offset(6, 2.6),
  Offset(37, 6.2),
  Offset(31, 28.6),
];

class Butterfly {
  Butterfly({
    required this.home,
    required this.color,
    required this.tile,
    required this.random,
  }) : x = home.dx,
       y = home.dy {
    _target = home;
  }

  final Offset home;

  /// Row of assets/images/satwa/kupu_kupu.png.
  final int color;
  final double tile;
  final math.Random random;
  double x;
  double y;
  late Offset _target;
  double _clock = 0;

  /// Column of satwa/kupu_kupu.png: open, half, closed, half.
  int get wingFrame => (_clock * 12).floor() % 4;
  bool get flipped => _target.dx < x;

  /// Small bob so the flight looks fluttery.
  double get lift => math.sin(_clock * 6) * tile * 0.08;

  void update(double dt) {
    _clock += dt;
    final delta = _target - Offset(x, y);
    if (delta.distance < tile * 0.1) {
      final angle = random.nextDouble() * math.pi * 2;
      final reach = tile * (0.3 + random.nextDouble() * 1.4);
      _target = home + Offset(math.cos(angle), math.sin(angle) * 0.7) * reach;
      return;
    }
    final step = tile * 0.9 * dt;
    final move = delta / delta.distance * math.min(step, delta.distance);
    x += move.dx;
    y += move.dy;
  }
}

class Bird {
  Bird({
    required Offset start,
    required this.direction,
    required this.tile,
    required double phase,
  }) : x = start.dx,
       y = start.dy,
       _clock = phase;

  final int direction;
  final double tile;

  /// Ground position under the bird; it is drawn [altitude] higher.
  double x;
  double y;
  double _clock;

  double get altitude => tile * 2.6;

  /// Column of satwa/burung_terbang.png.
  int get wingFrame => (_clock * 8).floor() % 4;

  void update(double dt) {
    _clock += dt;
    x += direction * tile * 3.6 * dt;
    y += math.sin(_clock * 1.3) * tile * 0.25 * dt;
  }
}

const _lakePoints = <Offset>[
  Offset(2, 31.2),
  Offset(4, 32.6),
  Offset(6.5, 33.3),
  Offset(9, 33.6),
  Offset(11, 34.3),
  Offset(3.4, 34.1),
];

const _riverPoints = <Offset>[
  Offset(3, 9.15),
  Offset(8, 9.15),
  Offset(14, 9.15),
  Offset(19.5, 9.15),
];

class Duck {
  Duck({
    required this.waypoints,
    required this.tile,
    required this.random,
    this.female = false,
    this.ducklings = 0,
  }) {
    final start = waypoints[random.nextInt(waypoints.length)];
    x = start.dx;
    y = start.dy;
    _target = waypoints[random.nextInt(waypoints.length)];
  }

  final List<Offset> waypoints;
  final double tile;
  final math.Random random;

  /// Row 1 of satwa/bebek_renang.png (brown hen) instead of row 0 (drake).
  final bool female;

  /// How many ducklings paddle behind, along [trail].
  final int ducklings;
  double x = 0;
  double y = 0;
  late Offset _target;
  double _rest = 0;
  double _clock = 0;
  double _trailClock = 0;

  /// Where the duck has been, newest first, for the ducklings to follow.
  final List<Offset> trail = <Offset>[];

  /// The sheet faces left.
  bool facingRight = false;
  int get frame => (_clock * 3).floor() % 4;
  double get clock => _clock;

  /// Position of duckling [index], a few strokes behind the one before.
  Offset ducklingAt(int index) {
    final at = (index + 1) * 5;
    if (trail.isEmpty) {
      return Offset(x + (facingRight ? -1 : 1) * tile * 0.5 * (index + 1), y);
    }
    return trail[math.min(at, trail.length - 1)];
  }

  void update(double dt) {
    _clock += dt;
    if (_rest > 0) {
      _rest -= dt;
      return;
    }
    final delta = _target - Offset(x, y);
    final step = tile * 0.45 * dt;
    if (delta.distance <= step) {
      _target = waypoints[random.nextInt(waypoints.length)];
      _rest = 1 + random.nextDouble() * 4;
      return;
    }
    x += delta.dx / delta.distance * step;
    y += delta.dy / delta.distance * step;
    if (delta.dx.abs() > 1) {
      facingRight = delta.dx > 0;
    }
    _trailClock += dt;
    if (ducklings > 0 && _trailClock > 0.12) {
      _trailClock = 0;
      trail.insert(0, Offset(x, y));
      if (trail.length > (ducklings + 1) * 5 + 1) {
        trail.removeLast();
      }
    }
  }
}

/// A fish gliding under the surface, seen only as a dark shape.
class FishShadow {
  FishShadow({
    required this.waypoints,
    required this.tile,
    required this.random,
  }) {
    final start = waypoints[random.nextInt(waypoints.length)];
    x = start.dx + (random.nextDouble() - 0.5) * tile;
    y = start.dy + (random.nextDouble() - 0.5) * tile * 0.4;
    _pick();
  }

  final List<Offset> waypoints;
  final double tile;
  final math.Random random;
  double x = 0;
  double y = 0;
  late Offset _target;
  double _clock = 0;
  bool facingRight = false;

  int get frame => (_clock * 4).floor() % 2;

  void _pick() {
    final base = waypoints[random.nextInt(waypoints.length)];
    _target =
        base +
        Offset(
          (random.nextDouble() - 0.5) * tile * 1.6,
          (random.nextDouble() - 0.5) * tile * 0.5,
        );
  }

  void update(double dt) {
    _clock += dt;
    final delta = _target - Offset(x, y);
    final step = tile * 0.7 * dt;
    if (delta.distance <= step) {
      _pick();
      return;
    }
    x += delta.dx / delta.distance * step;
    y += delta.dy / delta.distance * step;
    if (delta.dx.abs() > 1) {
      facingRight = delta.dx > 0;
    }
  }
}

/// A dragonfly hovering over the reeds, darting now and then.
class Dragonfly {
  Dragonfly({required this.home, required this.tile, required double phase})
    : _clock = phase;

  final Offset home;
  final double tile;
  double _clock;

  Offset get position {
    final dart = math.sin(_clock * 0.9) > 0.85 ? 0.6 : 0.0;
    return home +
        Offset(
          (math.sin(_clock * 0.7) * 1.3 + dart) * tile,
          math.cos(_clock * 1.1) * 0.5 * tile - tile * 0.6,
        );
  }

  int get frame => (_clock * 24).floor() % 2;
  bool get facingRight => math.cos(_clock * 0.7) > 0;

  void update(double dt) => _clock += dt;
}

/// A leaf floating down the river and starting again upstream.
class DriftLeaf {
  DriftLeaf({required this.tile, required double start, required double phase})
    : x = start * tile,
      _clock = phase;

  final double tile;
  double x;
  double _clock;

  double get y => (_riverY + math.sin(_clock * 0.8) * 0.35) * tile;
  double get spin => math.sin(_clock * 0.6) * 0.5;

  void update(double dt) {
    _clock += dt;
    x += tile * 0.32 * dt;
    if (x > _riverEndX * tile) {
      x = _riverStartX * tile;
    }
  }
}

const _riverY = 9.35;
const _riverStartX = 1.0;
const _riverEndX = 28.6;

const _dragonflyHomes = <Offset>[
  Offset(9, 9.6),
  Offset(18, 9.4),
  Offset(9.5, 31.8),
];

class FishJump {
  FishJump({required this.origin, required this.tile, required this.left});

  final Offset origin;
  final double tile;
  final bool left;
  double t = 0;

  static const duration = 1.1;

  bool get done => t >= duration;

  /// 0..1 through the jump itself (the rest is the splash settling).
  double get arc => (t / 0.8).clamp(0.0, 1.0);

  Offset get position {
    final across = (arc - 0.5) * tile * 0.9 * (left ? -1 : 1);
    final height = math.sin(arc * math.pi) * tile * 0.7;
    return origin + Offset(across, -height);
  }

  /// Angle of the fish along its arc.
  double get angle => (0.5 - arc) * math.pi * 0.9 * (left ? 1 : -1);

  void update(double dt) => t += dt;
}
