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

/// Pure 2048 engine with stable tile ids (for animation), undo and JSON save.
class Game2048 {
  Game2048(this.size, {Random? rng, this.maxUndos = 3}) : rng = rng ?? Random() {
    undosLeft = maxUndos;
  }

  final int size;
  final Random rng;
  final int maxUndos;
  List<Tile> tiles = [];
  int score = 0;
  int nextId = 1;
  int undosLeft = 0;
  bool keepGoing = false;
  final List<_Snap> _history = [];

  int get target => size == 3 ? 256 : 2048;
  bool get canUndo => undosLeft > 0 && _history.isNotEmpty;
  int get maxTile => tiles.fold(0, (m, t) => t.value > m ? t.value : m);
  bool get reachedTarget => maxTile >= target;

  void reset() {
    tiles = [];
    score = 0;
    nextId = 1;
    undosLeft = maxUndos;
    keepGoing = false;
    _history.clear();
    spawn();
    spawn();
  }

  Tile? tileAt(int r, int c) {
    for (final t in tiles) {
      if (t.r == r && t.c == c) return t;
    }
    return null;
  }

  int nextSpawnValue() => rng.nextDouble() < 0.9 ? 2 : 4;

  Tile? spawn() {
    final taken = {for (final t in tiles) t.r * size + t.c};
    final free = [for (var i = 0; i < size * size; i++) if (!taken.contains(i)) i];
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
      for (final cell in line) {
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
    if (_history.length > maxUndos) _history.removeAt(0);
    final spawned = spawn();
    return MoveResult(gained, merged, removed, spawned);
  }

  bool get hasMoves {
    if (tiles.length < size * size) return true;
    for (final t in tiles) {
      for (final o in [tileAt(t.r + 1, t.c), tileAt(t.r, t.c + 1)]) {
        if (o != null && o.value == t.value) return true;
      }
    }
    return false;
  }

  bool undo() {
    if (!canUndo) return false;
    final s = _history.removeLast();
    tiles = s.tiles.map((t) => t.copy()).toList();
    score = s.score;
    nextId = max(nextId, s.nextId);
    undosLeft--;
    return true;
  }

  String toJsonString() => jsonEncode({
        'size': size,
        'score': score,
        'nextId': nextId,
        'undos': undosLeft,
        'keep': keepGoing,
        'tiles': tiles.map((t) => t.toJson()).toList(),
      });

  static Game2048? fromJsonString(String? s, {Random? rng}) {
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final g = Game2048(m['size'] as int, rng: rng);
      g.score = m['score'] as int;
      g.nextId = m['nextId'] as int;
      g.undosLeft = m['undos'] as int;
      g.keepGoing = m['keep'] as bool;
      g.tiles = [for (final t in m['tiles'] as List) Tile.fromJson(t as List)];
      for (final t in g.tiles) {
        if (t.r < 0 || t.c < 0 || t.r >= g.size || t.c >= g.size) return null;
      }
      return g.tiles.isEmpty ? null : g;
    } catch (_) {
      return null;
    }
  }
}
