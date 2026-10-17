import 'dart:convert';

import 'storage.dart';

/// Saves the moves of the level being played so it can be continued after
/// leaving the game (or the app). Level games are deterministic, so the
/// level is rebuilt and the moves are played again on resume.
///
/// Stored per game + difficulty as `{"l": level, "m": [moves...]}`; a move is
/// any JSON value (an id, or a small list such as `[from, to]`).
class MoveLog {
  MoveLog(this.key);

  /// Storage key, e.g. `screw_jam.easy.inprogress`.
  final String key;

  int _level = 0;
  final List<Object?> moves = [];

  /// Moves saved for [level], or null when there is no game to continue.
  List<Object?>? savedFor(int level) {
    final raw = Storage.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['l'] != level) return null;
      final m = (j['m'] as List).cast<Object?>();
      return m.isEmpty ? null : m;
    } catch (_) {
      return null;
    }
  }

  /// Level number that has a game to continue, or null.
  int? get savedLevel {
    final raw = Storage.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (j['m'] as List).isEmpty ? null : j['l'] as int;
    } catch (_) {
      return null;
    }
  }

  /// A new attempt at [level] (keeps nothing).
  void start(int level) {
    _level = level;
    moves.clear();
    _write();
  }

  /// Continue [level] with [saved] moves already applied by the game.
  void resume(int level, List<Object?> saved) {
    _level = level;
    moves
      ..clear()
      ..addAll(saved);
    _write();
  }

  void add(Object? move) {
    moves.add(move);
    _write();
  }

  /// Undo: forget the last [n] moves.
  void pop([int n = 1]) {
    for (var k = 0; k < n && moves.isNotEmpty; k++) {
      moves.removeLast();
    }
    _write();
  }

  /// Level finished (won or lost for good): nothing to continue.
  void clear() {
    moves.clear();
    Storage.remove(key);
  }

  void _write() {
    if (moves.isEmpty) {
      Storage.remove(key);
    } else {
      Storage.setString(key, jsonEncode({'l': _level, 'm': moves}));
    }
  }
}
