import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/leaderboard_service.dart';

/// In-memory stand-in for Firestore `leaderboards/{board}/entries/{uid}`,
/// mirroring the queries (where country == cc, orderBy score desc, limit).
class FakeLeaderboardStore implements LeaderboardStore {
  final boards = <String, Map<String, LeaderEntry>>{};
  final raw = <String, Map<String, Map<String, Object>>>{};

  Iterable<LeaderEntry> _scoped(String board, String? country) =>
      (boards[board] ?? const {}).values.where((e) => country == null || e.country == country);

  @override
  Future<List<LeaderEntry>> top(String board, {String? country, required int limit}) async =>
      (_scoped(board, country).toList()..sort((a, b) => b.score.compareTo(a.score))).take(limit).toList();

  @override
  Future<LeaderEntry?> entry(String board, String uid) async => boards[board]?[uid];

  @override
  Future<int> countAbove(String board, int score, {String? country}) async =>
      _scoped(board, country).where((e) => e.score > score).length;

  @override
  Future<int> put(String board, String uid, {required String name, required int score, String? country}) async {
    final old = boards[board]?[uid]?.score ?? 0;
    final best = score > old ? score : old;
    final body = entryData(name: name, score: best, country: country);
    (raw[board] ??= {})[uid] = body;
    (boards[board] ??= {})[uid] = LeaderEntry(uid: uid, name: name, score: best, country: body['country'] as String?);
    return best;
  }

  @override
  Future<void> delete(String board, String uid) async => boards[board]?.remove(uid);
}

void main() {
  const board = Board('game_2048', '2048', '🔢', gameId: 'game_2048', maxScore: 10000000);
  late FakeLeaderboardStore store;

  setUp(() async {
    store = FakeLeaderboardStore();
    // 3 Indians, 2 Americans, one entry without a country (older client).
    await store.put('game_2048', 'in1', name: 'Asha', score: 900, country: 'IN');
    await store.put('game_2048', 'in2', name: 'Ravi', score: 500, country: 'IN');
    await store.put('game_2048', 'in3', name: 'Meera', score: 100, country: 'in');
    await store.put('game_2048', 'us1', name: 'Bob', score: 1000, country: 'US');
    await store.put('game_2048', 'us2', name: 'Ann', score: 700, country: 'US');
    await store.put('game_2048', 'xx', name: 'Old', score: 800);
  });

  test('country codes are normalized and validated', () {
    expect(normalizeCountry('in'), 'IN');
    expect(normalizeCountry(' us '), 'US');
    expect(normalizeCountry('IND'), isNull);
    expect(normalizeCountry('1N'), isNull);
    expect(normalizeCountry(null), isNull);
    expect(hasCountryScope('IN'), isTrue);
    expect(hasCountryScope('ZZ'), isFalse, reason: 'Other has no country board');
    expect(hasCountryScope(null), isFalse);
  });

  test('India players start on the country board, others on Global', () {
    expect(defaultScope('IN'), LeaderboardScope.country);
    expect(defaultScope('US'), LeaderboardScope.global);
    expect(defaultScope(null), LeaderboardScope.global);
    expect(scopeCountry(LeaderboardScope.country, 'in'), 'IN');
    expect(scopeCountry(LeaderboardScope.global, 'IN'), isNull);
    expect(scopeCountry(LeaderboardScope.country, 'ZZ'), isNull);
  });

  test('country is stored with each entry (2-letter, uppercase)', () async {
    expect(store.raw['game_2048']!['in3'], {'name': 'Meera', 'score': 100, 'country': 'IN'});
    expect(store.raw['game_2048']!['xx']!.containsKey('country'), isFalse);
    expect(entryData(name: 'A', score: 1, country: 'India'), {'name': 'A', 'score': 1});
    // A lower score keeps the best one but still updates the country.
    expect(await store.put('game_2048', 'in2', name: 'Ravi', score: 10, country: 'NP'), 500);
    expect(store.boards['game_2048']!['in2']!.country, 'NP');
  });

  test('global scope lists everyone by score', () async {
    final p = await loadLeaderboard(store, board, uid: 'in2', scope: LeaderboardScope.global, country: 'IN');
    expect(p.top.map((e) => e.uid), ['us1', 'in1', 'xx', 'us2', 'in2', 'in3']);
    expect(p.myRank, 5);
    expect(p.mine!.score, 500);
  });

  test('country scope only lists that country', () async {
    final p = await loadLeaderboard(store, board, uid: 'in2', scope: LeaderboardScope.country, country: 'IN');
    expect(p.top.map((e) => e.uid), ['in1', 'in2', 'in3']);
    expect(p.top.every((e) => e.country == 'IN'), isTrue);
    expect(p.myRank, 2);
    final us = await loadLeaderboard(store, board, uid: 'us2', scope: LeaderboardScope.country, country: 'US');
    expect(us.top.map((e) => e.uid), ['us1', 'us2']);
    expect(us.myRank, 2);
  });

  test('rank in scope beyond the top N is counted, not listed', () async {
    final g = await loadLeaderboard(store, board, uid: 'in3', scope: LeaderboardScope.global, country: 'IN', limit: 2);
    expect(g.top.length, 2);
    expect(g.myRank, 6);
    final c = await loadLeaderboard(store, board, uid: 'in3', scope: LeaderboardScope.country, country: 'IN', limit: 2);
    expect(c.top.map((e) => e.uid), ['in1', 'in2']);
    expect(c.myRank, 3);
    expect(c.mine!.name, 'Meera');
  });

  test('no rank when not on the board or listed under another country', () async {
    final none = await loadLeaderboard(store, board, uid: 'nobody', scope: LeaderboardScope.global);
    expect(none.mine, isNull);
    expect(none.myRank, isNull);
    final other = await loadLeaderboard(store, board, uid: 'us2', scope: LeaderboardScope.country, country: 'IN', limit: 1);
    expect(other.mine, isNull);
    final anon = await loadLeaderboard(store, board, uid: null, scope: LeaderboardScope.country, country: 'IN');
    expect(anon.top.length, 3);
    expect(anon.myRank, isNull);
  });
}
