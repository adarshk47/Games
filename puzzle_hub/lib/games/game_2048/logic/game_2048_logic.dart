import 'dart:convert';
import 'dart:math';

enum Dir { up, down, left, right }

class Tile {
  Tile(this.id, this.value, this.r, this.c);
  final int id;
  int value;
  int r;
  int c;

  Tile copy() => Tile(id, value, r, c);
  List<int> toJson() => [id, value, r, c];
  factory Tile.fromJson(List<dynamic> j) => Tile(j[0] as int, j[1] as int, j[2] as int, j[3] as int);
}

class MoveResult {
  MoveResult(this.gained, this.merged, this.removed, this.spawned);
  final int gained;

  /// Ids of tiles whose value doubled this move.
  final Set<int> merged;

  /// Tiles that slid into a survivor and must disappear (at their final cell).
  final List<Tile> removed;
  final Tile? spawned;
}

class _Snap {
  _Snap(this.tiles, this.score, this.nextId);
  final List<Tile> tiles;
  final int score;
  final int nextId;
}

/// Difficulty tiers.
enum Tier2048 {
  easy('Easy', 5, 5, 2048, 0, 0.10),
  medium('Medium', 4, 3, 2048, 0, 0.10),
  hard('Hard', 4, 1, 1024, 2, 0.25),
  extreme('Extreme', 4, 0, 256, 3, 0.30),

  /// Plain original rules. Declared last so saved tier indices stay valid;
  /// the UI shows it as a hero card above the four difficulty tiers.
  classic('Classic 2048', 4, 3, 2048, 0, 0.10);

  const Tier2048(this.label, this.size, this.undos, this.target, this.stones, this.fourChance);
  final String label;
  final int size;
  final int undos;
  final int target;
  final int stones;
  final double fourChance;
}

/// Pure 2048 engine with stable tile ids (for animation), undo and JSON save.
class Game2048 {
  Game2048(this.size,
      {Random? rng, this.maxUndos = 3, this.stoneCount = 0, this.fourChance = 0.1, int? target, this.tier = Tier2048.medium})
      : rng = rng ?? Random(),
        _target = target ?? 2048 {
    undosLeft = maxUndos;
  }

  factory Game2048.forTier(Tier2048 t, {Random? rng}) => Game2048(t.size,
      rng: rng, maxUndos: t.undos, stoneCount: t.stones, fourChance: t.fourChance, target: t.target, tier: t);

  final Tier2048 tier;
  final int size;
  final int stoneCount;
  final double fourChance;
  final int _target;

  /// Immovable blocked cells (index = r * size + c).
  Set<int> stones = {};
  final Random rng;
  final int maxUndos;
  List<Tile> tiles = [];
  int score = 0;
  int nextId = 1;
  int undosLeft = 0;
  bool keepGoing = false;

  /// True once the one-per-game paid "continue" at game over was used.
  bool continued = false;
  final List<_Snap> _history = [];

  /// Snapshots kept for undo: at least [minHistory] so paid undos work even on
  /// tiers without free undos.
  static const minHistory = 3;
  int get _historyCap => max(maxUndos, minHistory);

  /// Whether a previous board is available (free or paid undo).
  bool get hasHistory => _history.isNotEmpty;

  int get target => _target;
  bool isStone(int r, int c) => stones.contains(r * size + c);
  bool get canUndo => undosLeft > 0 && _history.isNotEmpty;
  int get maxTile => tiles.fold(0, (m, t) => t.value > m ? t.value : m);
  bool get reachedTarget => maxTile >= target;

  void reset() {
    tiles = [];
    score = 0;
    nextId = 1;
    undosLeft = maxUndos;
    keepGoing = false;
    continued = false;
    _history.clear();
    stones = {};
    while (stones.length < stoneCount) {
      stones.add(rng.nextInt(size * size));
    }
    spawn();
    spawn();
  }

  Tile? tileAt(int r, int c) {
    for (final t in tiles) {
      if (t.r == r && t.c == c) return t;
    }
    return null;
  }

  int nextSpawnValue() => rng.nextDouble() < fourChance ? 4 : 2;

  Tile? spawn() {
    final taken = {for (final t in tiles) t.r * size + t.c};
    final free = [for (var i = 0; i < size * size; i++) if (!taken.contains(i) && !stones.contains(i)) i];
    if (free.isEmpty) return null;
    final i = free[rng.nextInt(free.length)];
    final t = Tile(nextId++, nextSpawnValue(), i ~/ size, i % size);
    tiles.add(t);
    return t;
  }

  /// Cell coordinates of line [i], ordered starting from the edge tiles move toward.
  List<List<int>> _line(Dir d, int i) => [
        for (var k = 0; k < size; k++)
          switch (d) {
            Dir.left => [i, k],
            Dir.right => [i, size - 1 - k],
            Dir.up => [k, i],
            Dir.down => [size - 1 - k, i],
          }
      ];

  /// Applies a move. Returns null when nothing changes.
  MoveResult? move(Dir d) {
    final snap = _Snap(tiles.map((t) => t.copy()).toList(), score, nextId);
    // Resolve on a lookup so tiles can be mutated freely.
    final grid = <int, Tile>{for (final t in tiles) t.r * size + t.c: t};
    final removed = <Tile>[];
    final merged = <int>{};
    var gained = 0;
    var changed = false;
    for (var i = 0; i < size; i++) {
      final line = _line(d, i);
      Tile? last;
      var pos = 0;
      for (var k = 0; k < line.length; k++) {
        final cell = line[k];
        if (stones.contains(cell[0] * size + cell[1])) {
          last = null;
          pos = k + 1;
          continue;
        }
        final t = grid[cell[0] * size + cell[1]];
        if (t == null) continue;
        if (last != null && last.value == t.value && !merged.contains(last.id)) {
          final dest = line[pos - 1];
          t.r = dest[0];
          t.c = dest[1];
          last.value *= 2;
          gained += last.value;
          merged.add(last.id);
          removed.add(t);
          changed = true;
        } else {
          final dest = line[pos++];
          if (t.r != dest[0] || t.c != dest[1]) changed = true;
          t.r = dest[0];
          t.c = dest[1];
          last = t;
        }
      }
    }
    if (!changed) return null;
    tiles.removeWhere(removed.contains);
    score += gained;
    _history.add(snap);
    if (_history.length > _historyCap) _history.removeAt(0);
    final spawned = spawn();
    return MoveResult(gained, merged, removed, spawned);
  }

  bool get hasMoves {
    if (tiles.length < size * size - stones.length) return true;
    for (final t in tiles) {
      for (final o in [tileAt(t.r + 1, t.c), tileAt(t.r, t.c + 1)]) {
        if (o != null && o.value == t.value) return true;
      }
    }
    return false;
  }

  bool undo() {
    if (!canUndo) return false;
    _restoreLast();
    undosLeft--;
    return true;
  }

  /// Undo bought with coins/ad: does not consume a free undo.
  bool paidUndo() {
    if (_history.isEmpty) return false;
    _restoreLast();
    return true;
  }

  void _restoreLast() {
    final s = _history.removeLast();
    tiles = s.tiles.map((t) => t.copy()).toList();
    score = s.score;
    nextId = max(nextId, s.nextId);
  }

  /// Paid "continue" at game over: removes the [n] smallest tiles so the
  /// board has room again. Returns false when nothing could be removed.
  bool removeSmallest([int n = 2]) {
    if (tiles.length <= 1) return false;
    final sorted = [...tiles]..sort((a, b) => a.value.compareTo(b.value));
    final drop = sorted.take(min(n, tiles.length - 1)).toSet();
    tiles.removeWhere(drop.contains);
    _history.clear();
    continued = true;
    return true;
  }

  String toJsonString() => jsonEncode({
        'size': size,
        'tier': tier.index,
        'stones': stones.toList(),
        'score': score,
        'nextId': nextId,
        'undos': undosLeft,
        'keep': keepGoing,
        'cont': continued,
        'tiles': tiles.map((t) => t.toJson()).toList(),
      });

  static Game2048? fromJsonString(String? s, {Random? rng}) {
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final t = Tier2048.values[m['tier'] as int];
      if (t.size != m['size']) return null;
      final g = Game2048.forTier(t, rng: rng);
      g.stones = {for (final x in m['stones'] as List) x as int};
      g.score = m['score'] as int;
      g.nextId = m['nextId'] as int;
      g.undosLeft = m['undos'] as int;
      g.keepGoing = m['keep'] as bool;
      g.continued = m['cont'] as bool? ?? false;
      g.tiles = [for (final t in m['tiles'] as List) Tile.fromJson(t as List)];
      for (final t in g.tiles) {
        if (t.r < 0 || t.c < 0 || t.r >= g.size || t.c >= g.size || g.isStone(t.r, t.c)) return null;
      }
      return g.tiles.isEmpty ? null : g;
    } catch (_) {
      return null;
    }
  }
}
