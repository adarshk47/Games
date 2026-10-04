/// Pure-Dart merge of two snapshots of a user's Storage keys (local device vs
/// the cloud copy). No Flutter / Firebase imports so it is fully unit-testable.
///
/// Keys are the *stripped* Storage keys (without the per-user `u123.` prefix).
///
/// Rules, by key (first match wins):
///  * `cloud.*`                       -> never synced (local bookkeeping).
///  * `coins`, `coins.earned`, `coins.spent` -> earned = max, spent = max,
///    coins = earned - spent (each side is first normalised so that an
///    untracked spend/earn is inferred from its balance).
///  * saved games (`*.save`, `*.save.*` or a JSON object/array string)
///    -> keep local unless the remote `updatedAt` meta is newer.
///  * booleans                        -> OR.
///  * lower-is-better records (`*.bestTime*`, `*.bestMoves*`, `sudoku.best.*`,
///    `mines.<tier>.best`, `*.moves.*`, `ball_sort.<d>.best.*`)
///    -> min of the non-zero values.
///  * `*.stars.*`, `*.best*`          -> max.
///  * counters (`plays`, `wins`, `levels`, `completed`, `unlocked`, `level`,
///    `sessions`, `minutes`, `played`, `last`) -> max.
///  * everything else                 -> local wins.
/// A key present on only one side is always taken from that side (union),
/// except saved games, which follow their updatedAt meta (deletions win when
/// they are newer).
library;

/// Per-key timestamp info for saved-game keys.
class KeyMeta {
  const KeyMeta(this.t, {this.h, this.deleted = false});

  /// Last change, epoch milliseconds.
  final int t;

  /// Content hash (local bookkeeping only, used to detect changes).
  final String? h;

  /// The key was removed at [t] (e.g. a finished game cleared its save).
  final bool deleted;

  Map<String, Object> toJson({bool withHash = true}) => {
        't': t,
        if (withHash && h != null) 'h': h!,
        if (deleted) 'd': true,
      };

  static KeyMeta? fromJson(Object? v) {
    if (v is int) return KeyMeta(v);
    if (v is Map) {
      final t = v['t'];
      if (t is! num) return null;
      return KeyMeta(t.toInt(), h: v['h'] as String?, deleted: v['d'] == true);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is KeyMeta && other.t == t && other.h == h && other.deleted == deleted;

  @override
  int get hashCode => Object.hash(t, h, deleted);

  @override
  String toString() => 'KeyMeta($t${deleted ? ', deleted' : ''})';
}

Map<String, KeyMeta> metaFromJson(Object? v) {
  final out = <String, KeyMeta>{};
  if (v is Map) {
    v.forEach((k, e) {
      final m = KeyMeta.fromJson(e);
      if (m != null) out['$k'] = m;
    });
  }
  return out;
}

Map<String, Object> metaToJson(Map<String, KeyMeta> m, {bool withHash = true}) =>
    {for (final e in m.entries) e.key: e.value.toJson(withHash: withHash)};

class MergeResult {
  const MergeResult({required this.values, required this.meta});

  /// The merged key/value map (to write locally AND to the cloud).
  final Map<String, Object> values;

  /// Merged updatedAt meta for saved-game keys.
  final Map<String, KeyMeta> meta;
}

class SyncMerge {
  SyncMerge._();

  static const coinKeys = {'coins', 'coins.earned', 'coins.spent'};
  static const _counters = {'plays', 'wins', 'levels', 'completed', 'unlocked', 'level', 'sessions', 'minutes', 'played', 'last'};

  static final _minesBest = RegExp(r'^mines\.[^.]+\.best$');
  static final _ballSortBest = RegExp(r'^ball_sort\.[^.]+\.best\.');
  static final _bestSeg = RegExp(r'(^|\.)best');

  /// Local-only bookkeeping keys that are never uploaded.
  static bool isExcluded(String k) => k.startsWith('cloud.');

  static bool isSaveKey(String k, [Object? v]) {
    if (k.endsWith('.save') || k == 'save' || k.contains('.save.')) return true;
    if (v is String) {
      final s = v.trimLeft();
      return s.startsWith('{') || s.startsWith('[');
    }
    return false;
  }

  static bool isLowerBetter(String k) =>
      k.contains('.bestTime') ||
      k.contains('.bestMoves') ||
      k.startsWith('sudoku.best.') ||
      _minesBest.hasMatch(k) ||
      k.contains('.moves.') ||
      _ballSortBest.hasMatch(k);

  static bool isHigherBetter(String k) => k.contains('.stars.') || k.endsWith('.stars') || _bestSeg.hasMatch(k);

  static bool isCounter(String k) => _counters.contains(k.split('.').last);

  /// Min of the non-zero values (0 = "no record yet").
  static num minNonZero(num a, num b) {
    if (a == 0) return b;
    if (b == 0) return a;
    return a < b ? a : b;
  }

  static num _max(num a, num b) => a > b ? a : b;

  /// Merges one key present on both sides (not coins / saves).
  static Object mergeValue(String k, Object local, Object remote) {
    if (local is bool && remote is bool) return local || remote;
    if (local is num && remote is num) {
      if (isLowerBetter(k)) return minNonZero(local, remote);
      if (isHigherBetter(k) || isCounter(k)) return _max(local, remote);
    }
    return local;
  }

  static int _i(Map<String, Object> m, String k) {
    final v = m[k];
    return v is num ? v.toInt() : 0;
  }

  /// Returns (earned, spent) for one side with untracked earn/spend inferred
  /// from the balance, so that `coins == earned - spent` holds.
  static (int, int) normaliseCoins(Map<String, Object> m) {
    var e = _i(m, 'coins.earned');
    var s = _i(m, 'coins.spent');
    final c = _i(m, 'coins');
    if (c > e - s) e = c + s; // coins earned before the ledger existed
    if (c < e - s) s = e - c; // spends not recorded in coins.spent
    return (e, s);
  }

  /// Updates the local saved-game meta: a changed value gets [now], a removed
  /// value becomes a deletion tombstone at [now].
  static Map<String, KeyMeta> refreshMeta(Map<String, Object> local, Map<String, KeyMeta> old, int now) {
    final out = <String, KeyMeta>{};
    for (final e in local.entries) {
      if (isExcluded(e.key) || !isSaveKey(e.key, e.value)) continue;
      final h = fnv1a('${e.value}');
      final prev = old[e.key];
      out[e.key] = (prev != null && !prev.deleted && prev.h == h) ? prev : KeyMeta(now, h: h);
    }
    for (final e in old.entries) {
      if (out.containsKey(e.key)) continue;
      out[e.key] = e.value.deleted ? e.value : KeyMeta(now, deleted: true);
    }
    return out;
  }

  /// Merges the local snapshot with the remote one. [localMeta] should come
  /// from [refreshMeta]. Returns the values both sides should end up with.
  static MergeResult merge({
    required Map<String, Object> local,
    required Map<String, Object> remote,
    Map<String, KeyMeta> localMeta = const {},
    Map<String, KeyMeta> remoteMeta = const {},
  }) {
    final values = <String, Object>{};
    final meta = <String, KeyMeta>{};
    final keys = <String>{...local.keys, ...remote.keys, ...localMeta.keys, ...remoteMeta.keys};

    for (final k in keys) {
      if (isExcluded(k) || coinKeys.contains(k)) continue;
      final l = local[k];
      final r = remote[k];
      final save = isSaveKey(k, l ?? r) || localMeta.containsKey(k) || remoteMeta.containsKey(k);
      if (save) {
        final lt = localMeta[k]?.t ?? 0;
        final rm = remoteMeta[k];
        final rt = rm?.t ?? 0;
        if (rt > lt) {
          if (r != null && !(rm?.deleted ?? false)) values[k] = r;
          if (rm != null) meta[k] = rm;
        } else {
          if (l != null) values[k] = l;
          final lm = localMeta[k];
          if (lm != null) {
            meta[k] = lm;
          } else if (l == null && rm != null) {
            meta[k] = rm;
          }
          // Local has neither value nor meta: fall back to remote value.
          if (l == null && lm == null && r != null && !(rm?.deleted ?? false)) values[k] = r;
        }
        continue;
      }
      if (l != null && r != null) {
        values[k] = mergeValue(k, l, r);
      } else if (l != null) {
        values[k] = l;
      } else if (r != null) {
        values[k] = r;
      }
    }

    final hasCoins = coinKeys.any((k) => local.containsKey(k) || remote.containsKey(k));
    if (hasCoins) {
      final (le, ls) = normaliseCoins(local);
      final (re, rs) = normaliseCoins(remote);
      final e = le > re ? le : re;
      final s0 = ls > rs ? ls : rs;
      final s = s0 > e ? e : s0; // keeps coins == earned - spent >= 0
      values['coins.earned'] = e;
      values['coins.spent'] = s;
      values['coins'] = e - s;
    }
    return MergeResult(values: values, meta: meta);
  }

  /// [meta] with content hashes of [values] filled in, i.e. the local meta to
  /// store after applying a merge (so the next [refreshMeta] sees no change).
  static Map<String, KeyMeta> withHashes(Map<String, Object> values, Map<String, KeyMeta> meta) => {
        for (final e in meta.entries)
          e.key: values.containsKey(e.key) && !e.value.deleted
              ? KeyMeta(e.value.t, h: fnv1a('${values[e.key]}'))
              : KeyMeta(e.value.t, deleted: true),
      };

  /// Stable 32-bit FNV-1a hash (String.hashCode is not stable across runs).
  static String fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }
}
