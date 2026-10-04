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

/// A leaderboard. [gameId] null = the "Total stars" board.
@immutable
class Board {
  const Board(this.id, this.title, this.emoji, {this.gameId, required this.maxScore});
  final String id;
  final String title;
  final String emoji;
  final String? gameId;

  /// Must match the range check in firestore.rules.
  final int maxScore;
}

const totalStarsBoard = Board('total_stars', 'Total stars', '⭐', maxScore: 100000);

const List<Board> leaderboards = [
  Board('game_2048', '2048', '🔢', gameId: 'game_2048', maxScore: 10000000),
  Board('focus_color', 'Focus Color', '🎯', gameId: 'focus_color', maxScore: 1000000),
  Board('memory_boost', 'Memory Boost', '🧠', gameId: 'memory_boost', maxScore: 1000000),
  Board('block_puzzle', 'Block Puzzle', '🧱', gameId: 'block_puzzle', maxScore: 10000000),
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

@immutable
class LeaderEntry {
  const LeaderEntry({required this.uid, required this.name, required this.score});
  final String uid;
  final String name;
  final int score;
}

@immutable
class LeaderboardPage {
  const LeaderboardPage({required this.top, this.mine, this.myRank});
  final List<LeaderEntry> top;
  final LeaderEntry? mine;
  final int? myRank;
}

/// Firestore `leaderboards/{board}/entries/{uid}` = {name, score, updatedAt}.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService I = LeaderboardService._();

  static const topN = 50;

  StreamSubscription<RewardEvent>? _sub;
  Timer? _starsTimer;

  bool get canSubmit => CloudService.available && CloudAuth.I.user.value != null && AccountService.I.loggedIn;

  CollectionReference<Map<String, dynamic>> _entries(String board) =>
      FirebaseFirestore.instance.collection('leaderboards').doc(board).collection('entries');

  void start() {
    _sub ??= Rewards.events.listen((e) {
      final b = boardForGame(e.gameId);
      if (b != null && e.score != null) {
        final best = Rewards.best(e.gameId);
        submit(b, e.score! > best ? e.score! : best);
      }
      if (e.stars > 0) {
        _starsTimer?.cancel();
        _starsTimer = Timer(SyncService.debounce, submitTotalStars);
      }
    });
  }

  String _cacheKey(Board b) => 'cloud.lb.${b.id}';

  /// Submits [score] if it beats what we already have on the board.
  Future<void> submit(Board b, int score) async {
    if (!canSubmit || score <= 0) return;
    final uid = CloudAuth.I.user.value!.uid;
    final name = _name();
    final clamped = score > b.maxScore ? b.maxScore : score;
    final sentKey = _cacheKey(b);
    final nameKey = '$sentKey.name';
    if (clamped <= Storage.getInt(sentKey) && Storage.getString(nameKey) == name) return;
    try {
      final ref = _entries(b.id).doc(uid);
      final written = await FirebaseFirestore.instance.runTransaction<int>((tx) async {
        final s = await tx.get(ref);
        final old = (s.data()?['score'] as num?)?.toInt() ?? 0;
        final oldName = s.data()?['name'] as String?;
        final best = clamped > old ? clamped : old;
        if (s.exists && best == old && oldName == name) return old;
        tx.set(ref, {'name': name, 'score': best, 'updatedAt': FieldValue.serverTimestamp()});
        return best;
      });
      await Storage.setInt(sentKey, written);
      await Storage.setString(nameKey, name);
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
      if (b.gameId != null) await submit(b, Rewards.best(b.gameId!));
    }
    await submitTotalStars();
  }

  Future<LeaderboardPage> load(Board b) async {
    final uid = CloudAuth.I.user.value?.uid;
    final q = await _entries(b.id).orderBy('score', descending: true).limit(topN).get();
    final top = [
      for (final d in q.docs)
        LeaderEntry(uid: d.id, name: (d.data()['name'] as String?) ?? 'Player', score: (d.data()['score'] as num?)?.toInt() ?? 0),
    ];
    if (uid == null) return LeaderboardPage(top: top);
    final i = top.indexWhere((e) => e.uid == uid);
    if (i >= 0) return LeaderboardPage(top: top, mine: top[i], myRank: i + 1);
    final mine = await _entries(b.id).doc(uid).get();
    if (!mine.exists) return LeaderboardPage(top: top);
    final score = (mine.data()?['score'] as num?)?.toInt() ?? 0;
    final above = await _entries(b.id).where('score', isGreaterThan: score).count().get();
    return LeaderboardPage(
      top: top,
      mine: LeaderEntry(uid: uid, name: (mine.data()?['name'] as String?) ?? 'Player', score: score),
      myRank: (above.count ?? 0) + 1,
    );
  }

  /// Account deletion: remove this user's entries from every board.
  Future<void> deleteMine(String uid) async {
    for (final b in leaderboards) {
      await _entries(b.id).doc(uid).delete();
    }
  }
}
