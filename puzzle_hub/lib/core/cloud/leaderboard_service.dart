import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_service.dart';
import '../rewards.dart';
import '../storage.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'sync_service.dart';

/// What a board ranks.
enum BoardMetric {
  /// The game's best score (`rec.<game>.best`).
  best,

  /// Number of wins (`rec.<game>.wins`), e.g. chess.
  wins,

  /// Sum of all stars over every game.
  totalStars,
}

/// A leaderboard. [gameId] null = the "Total stars" board.
@immutable
class Board {
  const Board(this.id, this.title, this.emoji, {this.gameId, required this.maxScore, this.metric = BoardMetric.best});
  final String id;
  final String title;
  final String emoji;
  final String? gameId;
  final BoardMetric metric;

  /// Must match the range check in firestore.rules.
  final int maxScore;
}

const totalStarsBoard = Board('total_stars', 'Total stars', '⭐', maxScore: 100000, metric: BoardMetric.totalStars);

const List<Board> leaderboards = [
  Board('game_2048', '2048', '🔢', gameId: 'game_2048', maxScore: 10000000),
  Board('focus_color', 'Focus Color', '🎯', gameId: 'focus_color', maxScore: 1000000),
  Board('memory_boost', 'Memory Boost', '🧠', gameId: 'memory_boost', maxScore: 1000000),
  Board('block_puzzle', 'Block Puzzle', '🧱', gameId: 'block_puzzle', maxScore: 10000000),
  Board('chess', 'Chess', '♟️', gameId: 'chess', maxScore: 1000000, metric: BoardMetric.wins),
  totalStarsBoard,
];

Board? boardForGame(String gameId) {
  for (final b in leaderboards) {
    if (b.gameId == gameId) return b;
  }
  return null;
}

/// Sum of every `*.stars.*` / `*.stars` value in a user's (stripped) keys.
int totalStarsOf(Map<String, Object> keys) {
  var sum = 0;
  keys.forEach((k, v) {
    if (v is int && v > 0 && (k.contains('.stars.') || k.endsWith('.stars'))) sum += v;
  });
  return sum;
}

// ------------------------------------------------------------------ country

/// Which players a board shows: everybody, or only the player's country.
enum LeaderboardScope { global, country }

/// Normalises an ISO country code ('in' -> 'IN'); null unless it is exactly
/// two letters (the same check firestore.rules does).
String? normalizeCountry(String? code) {
  final c = code?.trim().toUpperCase();
  if (c == null || !RegExp(r'^[A-Z]{2}$').hasMatch(c)) return null;
  return c;
}

/// True when [code] is a real country a "My country" board makes sense for
/// ('ZZ' = "Other" in the country picker).
bool hasCountryScope(String? code) {
  final c = normalizeCountry(code);
  return c != null && c != 'ZZ';
}

/// Scope the leaderboard opens with: India-first, so Indian players see the
/// India board by default; everyone else starts on Global.
LeaderboardScope defaultScope(String? country) =>
    normalizeCountry(country) == 'IN' ? LeaderboardScope.country : LeaderboardScope.global;

/// The country filter for [scope] (null = no filter / global).
String? scopeCountry(LeaderboardScope scope, String? country) =>
    scope == LeaderboardScope.country && hasCountryScope(country) ? normalizeCountry(country) : null;

/// Document body for `leaderboards/{board}/entries/{uid}` (without `updatedAt`).
Map<String, Object> entryData({required String name, required int score, String? country}) {
  final cc = normalizeCountry(country);
  return {'name': name, 'score': score, 'country': ?cc};
}

@immutable
class LeaderEntry {
  const LeaderEntry({required this.uid, required this.name, required this.score, this.country});
  final String uid;
  final String name;
  final int score;
  final String? country;
}

@immutable
class LeaderboardPage {
  const LeaderboardPage({required this.top, this.mine, this.myRank});
  final List<LeaderEntry> top;
  final LeaderEntry? mine;
  final int? myRank;
}

// -------------------------------------------------------------------- store

/// Storage of leaderboard entries, abstracted so ranking logic can be tested
/// without Firebase. Firestore: `leaderboards/{board}/entries/{uid}`.
abstract class LeaderboardStore {
  /// Highest scores first; only entries of [country] when it is set.
  Future<List<LeaderEntry>> top(String board, {String? country, required int limit});
  Future<LeaderEntry?> entry(String board, String uid);

  /// Number of entries with a higher score (within [country] when set).
  Future<int> countAbove(String board, int score, {String? country});

  /// Writes max(old, [score]) with [name] and [country]. Returns the stored score.
  Future<int> put(String board, String uid, {required String name, required int score, String? country});
  Future<void> delete(String board, String uid);
}

LeaderEntry _fromDoc(String uid, Map<String, dynamic>? d) => LeaderEntry(
      uid: uid,
      name: (d?['name'] as String?) ?? 'Player',
      score: (d?['score'] as num?)?.toInt() ?? 0,
      country: d?['country'] as String?,
    );

class FirestoreLeaderboardStore implements LeaderboardStore {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _entries(String board) =>
      _db.collection('leaderboards').doc(board).collection('entries');

  Query<Map<String, dynamic>> _scoped(String board, String? country) {
    final q = _entries(board);
    // Needs the composite index (country ASC, score DESC) - firestore.indexes.json.
    return country == null ? q : q.where('country', isEqualTo: country);
  }

  @override
  Future<List<LeaderEntry>> top(String board, {String? country, required int limit}) async {
    final q = await _scoped(board, country).orderBy('score', descending: true).limit(limit).get();
    return [for (final d in q.docs) _fromDoc(d.id, d.data())];
  }

  @override
  Future<LeaderEntry?> entry(String board, String uid) async {
    final s = await _entries(board).doc(uid).get();
    return s.exists ? _fromDoc(uid, s.data()) : null;
  }

  @override
  Future<int> countAbove(String board, int score, {String? country}) async {
    // Needs the composite index (country ASC, score ASC) for country scope.
    final r = await _scoped(board, country).where('score', isGreaterThan: score).count().get();
    return r.count ?? 0;
  }

  @override
  Future<int> put(String board, String uid, {required String name, required int score, String? country}) {
    final ref = _entries(board).doc(uid);
    return _db.runTransaction<int>((tx) async {
      final s = await tx.get(ref);
      final old = s.data();
      final oldScore = (old?['score'] as num?)?.toInt() ?? 0;
      final best = score > oldScore ? score : oldScore;
      final body = entryData(name: name, score: best, country: country);
      if (s.exists && best == oldScore && old?['name'] == body['name'] && old?['country'] == body['country']) return oldScore;
      tx.set(ref, {...body, 'updatedAt': FieldValue.serverTimestamp()});
      return best;
    });
  }

  @override
  Future<void> delete(String board, String uid) => _entries(board).doc(uid).delete();
}

/// Loads the top [limit] of [board] in [scope] plus the player's own rank.
/// Free of Firebase (works with any [LeaderboardStore]).
Future<LeaderboardPage> loadLeaderboard(
  LeaderboardStore store,
  Board board, {
  required String? uid,
  LeaderboardScope scope = LeaderboardScope.global,
  String? country,
  int limit = LeaderboardService.topN,
}) async {
  final cc = scopeCountry(scope, country);
  final top = await store.top(board.id, country: cc, limit: limit);
  if (uid == null) return LeaderboardPage(top: top);
  final i = top.indexWhere((e) => e.uid == uid);
  if (i >= 0) return LeaderboardPage(top: top, mine: top[i], myRank: i + 1);
  final mine = await store.entry(board.id, uid);
  // Not on this board, or (country scope) listed under another country.
  if (mine == null || (cc != null && mine.country != cc)) return LeaderboardPage(top: top);
  final above = await store.countAbove(board.id, mine.score, country: cc);
  return LeaderboardPage(top: top, mine: mine, myRank: above + 1);
}

// ------------------------------------------------------------------ service

/// Submits the player's records and reads boards. Every entry carries the
/// player's country so boards can be shown Global or per country.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService I = LeaderboardService._();

  static const topN = 50;

  LeaderboardStore store = FirestoreLeaderboardStore();

  StreamSubscription<RewardEvent>? _sub;
  Timer? _starsTimer;

  bool get canSubmit => CloudService.available && CloudAuth.I.user.value != null && AccountService.I.loggedIn;

  void start() {
    _sub ??= Rewards.events.listen((e) {
      final b = boardForGame(e.gameId);
      if (b != null) {
        if (b.metric == BoardMetric.wins && e.won) {
          submit(b, Rewards.wins(e.gameId));
        } else if (b.metric == BoardMetric.best && e.score != null) {
          final best = Rewards.best(e.gameId);
          submit(b, e.score! > best ? e.score! : best);
        }
      }
      if (e.stars > 0) {
        _starsTimer?.cancel();
        _starsTimer = Timer(SyncService.debounce, submitTotalStars);
      }
    });
  }

  String _cacheKey(Board b) => 'cloud.lb.${b.id}';

  /// The local value for a per-game board.
  static int localScore(Board b) => switch (b.metric) {
        BoardMetric.best => Rewards.best(b.gameId!),
        BoardMetric.wins => Rewards.wins(b.gameId!),
        BoardMetric.totalStars => 0,
      };

  /// Submits [score] if it beats what we already have on the board (or the
  /// name / country changed).
  Future<void> submit(Board b, int score) async {
    if (!canSubmit || score <= 0) return;
    final uid = CloudAuth.I.user.value!.uid;
    final name = _name();
    final country = normalizeCountry(AccountService.I.country) ?? '';
    final clamped = score > b.maxScore ? b.maxScore : score;
    final sentKey = _cacheKey(b);
    final tagKey = '$sentKey.tag';
    final tag = '$country|$name';
    if (clamped <= Storage.getInt(sentKey) && Storage.getString(tagKey) == tag) return;
    try {
      final written = await store.put(b.id, uid, name: name, score: clamped, country: country);
      await Storage.setInt(sentKey, written);
      await Storage.setString(tagKey, tag);
    } catch (e) {
      debugPrint('leaderboard submit ${b.id}: $e');
    }
  }

  String _name() {
    final n = AccountService.I.name.trim();
    if (n.isEmpty) return 'Player';
    return n.length > 24 ? n.substring(0, 24) : n;
  }

  Future<void> submitTotalStars() async {
    if (!canSubmit) return;
    final prefs = await SharedPreferences.getInstance();
    await submit(totalStarsBoard, totalStarsOf(LocalKv(prefs).readAll(Storage.userPrefix)));
  }

  /// Submits the current records for every board (after login / sync).
  Future<void> submitAll() async {
    if (!canSubmit) return;
    for (final b in leaderboards) {
      if (b.gameId != null) await submit(b, localScore(b));
    }
    await submitTotalStars();
  }

  Future<LeaderboardPage> load(Board b, {LeaderboardScope scope = LeaderboardScope.global}) =>
      loadLeaderboard(store, b, uid: CloudAuth.I.user.value?.uid, scope: scope, country: AccountService.I.country);

  /// Account deletion: remove this user's entries from every board.
  Future<void> deleteMine(String uid) async {
    for (final b in leaderboards) {
      await store.delete(b.id, uid);
    }
  }
}
