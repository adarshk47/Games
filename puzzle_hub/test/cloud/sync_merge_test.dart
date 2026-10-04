import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/sync_merge.dart';

Map<String, Object> m(Map<String, Object> local, Map<String, Object> remote,
        {Map<String, KeyMeta> lm = const {}, Map<String, KeyMeta> rm = const {}}) =>
    SyncMerge.merge(local: local, remote: remote, localMeta: lm, remoteMeta: rm).values;

void main() {
  group('key classification', () {
    test('lower-is-better keys', () {
      for (final k in [
        'sliding.easy.bestTime.3',
        'sliding.easy.bestMoves.3',
        'sudoku.best.easy',
        'sudoku.best.expert',
        'mines.beginner.best',
        'memory.cards.easy.moves.4',
        'mom.match.moves.2',
        'ball_sort.easy.best.7',
      ]) {
        expect(SyncMerge.isLowerBetter(k), isTrue, reason: k);
      }
      for (final k in ['rec.game_2048.best', 'g2048.classic.best', 'arrows.easy.stars.3', 'mines.beginner.wins', 'block.classic.best']) {
        expect(SyncMerge.isLowerBetter(k), isFalse, reason: k);
      }
    });

    test('higher-is-better keys', () {
      for (final k in ['rec.focus_color.best', 'g2048.classic.best', 'arrows.easy.stars.3', 'memory.simon.easy.best', 'mom.bag.best']) {
        expect(SyncMerge.isHigherBetter(k), isTrue, reason: k);
      }
      expect(SyncMerge.isHigherBetter('g2048.tier'), isFalse);
      expect(SyncMerge.isHigherBetter('arrow_maze.theme'), isFalse);
    });

    test('counters', () {
      for (final k in ['rec.sudoku.plays', 'rec.sudoku.wins', 'rec.sudoku.levels', 'arrows.easy.completed', 'ball_sort.easy.unlocked', 'mom.bag.level', 'mom.breath.sessions']) {
        expect(SyncMerge.isCounter(k), isTrue, reason: k);
      }
      expect(SyncMerge.isCounter('arrow_maze.palette'), isFalse);
    });

    test('saved games', () {
      expect(SyncMerge.isSaveKey('sudoku.save'), isTrue);
      expect(SyncMerge.isSaveKey('g2048.classic.save'), isTrue);
      expect(SyncMerge.isSaveKey('x.save.1'), isTrue);
      expect(SyncMerge.isSaveKey('foo.state', '{"a":1}'), isTrue);
      expect(SyncMerge.isSaveKey('foo.list', '[1,2]'), isTrue);
      expect(SyncMerge.isSaveKey('mom.lastDay', '2026-10-04'), isFalse);
      expect(SyncMerge.isSaveKey('savedTheme'), isFalse);
    });

    test('cloud.* is excluded', () {
      expect(SyncMerge.isExcluded('cloud.meta'), isTrue);
      expect(SyncMerge.isExcluded('cloud.lb.game_2048'), isTrue);
      expect(SyncMerge.isExcluded('coins'), isFalse);
    });
  });

  group('merge values', () {
    test('stars and best scores keep the max', () {
      final r = m(
        {'arrows.easy.stars.1': 2, 'rec.game_2048.best': 5000, 'g2048.classic.best': 100},
        {'arrows.easy.stars.1': 3, 'rec.game_2048.best': 4000, 'g2048.classic.best': 900},
      );
      expect(r['arrows.easy.stars.1'], 3);
      expect(r['rec.game_2048.best'], 5000);
      expect(r['g2048.classic.best'], 900);
    });

    test('times / moves keep the min of non-zero values', () {
      final r = m(
        {'sudoku.best.easy': 300, 'mines.beginner.best': 0, 'sliding.easy.bestTime.1': 40, 'sliding.easy.bestMoves.1': 0, 'ball_sort.easy.best.2': 30},
        {'sudoku.best.easy': 250, 'mines.beginner.best': 77, 'sliding.easy.bestTime.1': 55, 'sliding.easy.bestMoves.1': 0, 'ball_sort.easy.best.2': 25},
      );
      expect(r['sudoku.best.easy'], 250);
      expect(r['mines.beginner.best'], 77);
      expect(r['sliding.easy.bestTime.1'], 40);
      expect(r['sliding.easy.bestMoves.1'], 0);
      expect(r['ball_sort.easy.best.2'], 25);
    });

    test('counters keep the max', () {
      final r = m(
        {'rec.sudoku.plays': 10, 'rec.sudoku.wins': 2, 'rec.sudoku.levels': 7, 'arrows.easy.completed': 4},
        {'rec.sudoku.plays': 8, 'rec.sudoku.wins': 5, 'rec.sudoku.levels': 7, 'arrows.easy.completed': 9},
      );
      expect(r['rec.sudoku.plays'], 10);
      expect(r['rec.sudoku.wins'], 5);
      expect(r['rec.sudoku.levels'], 7);
      expect(r['arrows.easy.completed'], 9);
    });

    test('done flags and other booleans are ORed', () {
      final r = m(
        {'rec.sudoku.done.easy': false, 'sliding.picture': true, 'rec.flow.done.a': true},
        {'rec.sudoku.done.easy': true, 'sliding.picture': false, 'rec.flow.done.a': false},
      );
      expect(r['rec.sudoku.done.easy'], true);
      expect(r['sliding.picture'], true);
      expect(r['rec.flow.done.a'], true);
    });

    test('everything else: local wins', () {
      final r = m(
        {'g2048.tier': 1, 'arrow_maze.theme': 3, 'mom.lastDay': '2026-10-04', 'mom.streak': 2},
        {'g2048.tier': 2, 'arrow_maze.theme': 0, 'mom.lastDay': '2026-10-01', 'mom.streak': 9},
      );
      expect(r['g2048.tier'], 1);
      expect(r['arrow_maze.theme'], 3);
      expect(r['mom.lastDay'], '2026-10-04');
      expect(r['mom.streak'], 2);
    });

    test('keys on only one side are kept (union)', () {
      final r = m({'a.stars.1': 1, 'rec.x.done.l1': true}, {'b.stars.2': 3, 'g2048.tier': 2});
      expect(r, containsPair('a.stars.1', 1));
      expect(r, containsPair('b.stars.2', 3));
      expect(r, containsPair('rec.x.done.l1', true));
      expect(r, containsPair('g2048.tier', 2));
    });

    test('type mismatch falls back to local', () {
      expect(m({'rec.x.best': 'oops'}, {'rec.x.best': 5})['rec.x.best'], 'oops');
    });

    test('doubles from Firestore merge like ints', () {
      expect(m({'rec.x.best': 5}, {'rec.x.best': 7.0})['rec.x.best'], 7.0);
      expect(m({'sudoku.best.easy': 50}, {'sudoku.best.easy': 70.0})['sudoku.best.easy'], 50);
    });

    test('cloud.* keys are never merged or uploaded', () {
      final r = m({'cloud.meta': '{}', 'cloud.lb.x': 5}, {'cloud.lb.x': 9});
      expect(r.keys.where((k) => k.startsWith('cloud.')), isEmpty);
    });

    test('empty remote returns local unchanged (first upload)', () {
      final local = <String, Object>{'rec.x.plays': 3, 'arrows.easy.stars.1': 2, 'g2048.tier': 1};
      expect(m(local, {}), local);
    });

    test('empty local takes everything from remote (new phone)', () {
      final remote = <String, Object>{'rec.x.plays': 3, 'coins': 40, 'coins.earned': 50, 'coins.spent': 10, 'g2048.tier': 1};
      expect(m({}, remote), remote);
    });
  });

  group('coins', () {
    test('earned and spent take the max, coins = earned - spent', () {
      final r = m(
        {'coins': 70, 'coins.earned': 100, 'coins.spent': 30},
        {'coins': 100, 'coins.earned': 150, 'coins.spent': 50},
      );
      expect(r['coins.earned'], 150);
      expect(r['coins.spent'], 50);
      expect(r['coins'], 100);
    });

    test('untracked spend is inferred from the balance', () {
      // Local spent 40 without recording coins.spent.
      final r = m({'coins': 60, 'coins.earned': 100}, {'coins': 100, 'coins.earned': 100, 'coins.spent': 0});
      expect(r['coins.spent'], 40);
      expect(r['coins'], 60);
    });

    test('coins without an earned ledger are not lost', () {
      final r = m({'coins': 80}, {});
      expect(r['coins'], 80);
      expect(r['coins.earned'], 80);
      expect(r['coins.spent'], 0);
    });

    test('never negative', () {
      final r = m({'coins': 0, 'coins.earned': 10, 'coins.spent': 10}, {'coins': 0, 'coins.earned': 5, 'coins.spent': 50});
      expect(r['coins'], 0);
    });

    test('merge is idempotent', () {
      final local = <String, Object>{'coins': 70, 'coins.earned': 100, 'coins.spent': 30};
      final remote = <String, Object>{'coins': 100, 'coins.earned': 150, 'coins.spent': 50};
      final once = m(local, remote);
      expect(m(once, once), once);
      expect(m(once, remote), once);
    });

    test('no coin keys anywhere -> no coin keys written', () {
      expect(m({'a.stars.1': 1}, {'b.stars.1': 1}).keys, isNot(contains('coins')));
    });
  });

  group('saved games', () {
    const save = 'sudoku.save';

    test('local kept when remote is not newer', () {
      final r = m({save: '{"v":"local"}'}, {save: '{"v":"remote"}'},
          lm: {save: const KeyMeta(200)}, rm: {save: const KeyMeta(100)});
      expect(r[save], '{"v":"local"}');
    });

    test('equal timestamps keep local', () {
      final r = m({save: '{"v":"local"}'}, {save: '{"v":"remote"}'},
          lm: {save: const KeyMeta(100)}, rm: {save: const KeyMeta(100)});
      expect(r[save], '{"v":"local"}');
    });

    test('remote wins when its updatedAt is newer', () {
      final res = SyncMerge.merge(
          local: {save: '{"v":"local"}'},
          remote: {save: '{"v":"remote"}'},
          localMeta: {save: const KeyMeta(100)},
          remoteMeta: {save: const KeyMeta(300)});
      expect(res.values[save], '{"v":"remote"}');
      expect(res.meta[save]!.t, 300);
    });

    test('newer remote deletion removes the local save', () {
      final r = m({save: '{"v":"local"}'}, {}, lm: {save: const KeyMeta(100)}, rm: {save: const KeyMeta(300, deleted: true)});
      expect(r.containsKey(save), isFalse);
    });

    test('newer local deletion is not resurrected by the remote copy', () {
      final res = SyncMerge.merge(
          local: {},
          remote: {save: '{"v":"remote"}'},
          localMeta: {save: const KeyMeta(500, deleted: true)},
          remoteMeta: {save: const KeyMeta(300)});
      expect(res.values.containsKey(save), isFalse);
      expect(res.meta[save]!.deleted, isTrue);
    });

    test('new phone (no local value or meta) takes the remote save', () {
      expect(m({}, {save: '{"v":"remote"}'}, rm: {save: const KeyMeta(300)})[save], '{"v":"remote"}');
      expect(m({}, {save: '{"v":"remote"}'})[save], '{"v":"remote"}');
    });

    test('JSON-looking strings are treated as saves', () {
      final r = m({'x.state': '{"a":1}'}, {'x.state': '{"a":2}'}, lm: {'x.state': const KeyMeta(1)}, rm: {'x.state': const KeyMeta(2)});
      expect(r['x.state'], '{"a":2}');
    });
  });

  group('meta', () {
    test('refreshMeta stamps new / changed saves and tombstones removed ones', () {
      final m1 = SyncMerge.refreshMeta({'sudoku.save': '{"a":1}', 'rec.x.plays': 2}, {}, 100);
      expect(m1.keys, ['sudoku.save']);
      expect(m1['sudoku.save']!.t, 100);

      final same = SyncMerge.refreshMeta({'sudoku.save': '{"a":1}'}, m1, 200);
      expect(same['sudoku.save']!.t, 100, reason: 'unchanged value keeps its timestamp');

      final changed = SyncMerge.refreshMeta({'sudoku.save': '{"a":2}'}, m1, 300);
      expect(changed['sudoku.save']!.t, 300);

      final gone = SyncMerge.refreshMeta({}, changed, 400);
      expect(gone['sudoku.save']!.deleted, isTrue);
      expect(gone['sudoku.save']!.t, 400);

      final still = SyncMerge.refreshMeta({}, gone, 500);
      expect(still['sudoku.save']!.t, 400, reason: 'tombstone keeps its time');
    });

    test('json round trip', () {
      final meta = {'a.save': const KeyMeta(5, h: 'ff'), 'b.save': const KeyMeta(7, deleted: true)};
      expect(metaFromJson(metaToJson(meta)), meta);
      expect(metaFromJson(metaToJson(meta, withHash: false))['a.save'], const KeyMeta(5));
      expect(metaFromJson({'c.save': 9})['c.save'], const KeyMeta(9));
      expect(metaFromJson('garbage'), isEmpty);
    });

    test('withHashes makes the next refresh a no-op', () {
      final values = <String, Object>{'sudoku.save': '{"x":1}'};
      final meta = SyncMerge.withHashes(values, {'sudoku.save': const KeyMeta(42), 'old.save': const KeyMeta(10, deleted: true)});
      final again = SyncMerge.refreshMeta(values, meta, 999);
      expect(again['sudoku.save']!.t, 42);
      expect(again['old.save']!.deleted, isTrue);
    });

    test('fnv1a is stable', () {
      expect(SyncMerge.fnv1a(''), '811c9dc5');
      expect(SyncMerge.fnv1a('a'), 'e40c292c');
      expect(SyncMerge.fnv1a('{"a":1}'), SyncMerge.fnv1a('{"a":1}'));
      expect(SyncMerge.fnv1a('{"a":1}'), isNot(SyncMerge.fnv1a('{"a":2}')));
    });
  });

  test('minNonZero', () {
    expect(SyncMerge.minNonZero(0, 5), 5);
    expect(SyncMerge.minNonZero(5, 0), 5);
    expect(SyncMerge.minNonZero(3, 5), 3);
    expect(SyncMerge.minNonZero(0, 0), 0);
  });
}
