import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/sync_merge.dart';
import 'package:puzzle_hub/core/cloud/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Firestore `users/{uid}`.
class FakeRemote implements RemoteStore {
  final docs = <String, RemoteDoc>{};
  final countries = <String, String?>{};
  int saves = 0;

  @override
  Future<RemoteDoc> load(String uid) async => docs[uid] ?? const RemoteDoc();

  @override
  Future<void> save(String uid, {required bool exists, required String name, String? country, required Map<String, Object> data, required Map<String, KeyMeta> meta}) async {
    countries[uid] = country;
    expect(exists, docs.containsKey(uid), reason: 'create vs update must match the document state');
    saves++;
    docs[uid] = RemoteDoc(
      exists: true,
      data: Map.of(data),
      meta: {for (final e in meta.entries) e.key: KeyMeta(e.value.t, deleted: e.value.deleted)},
      pendingCredits: docs[uid]?.pendingCredits ?? 0,
    );
  }

  @override
  Future<int> consumePendingCredits(String uid) async {
    final d = docs[uid];
    if (d == null) return 0;
    docs[uid] = RemoteDoc(exists: true, data: d.data, meta: d.meta);
    return d.pendingCredits;
  }

  @override
  Future<void> delete(String uid) async => docs.remove(uid);
}

void main() {
  var now = 1000;
  late SharedPreferences prefs;
  late FakeRemote remote;
  SyncEngine engine() => SyncEngine(kv: LocalKv(prefs), remote: remote, clock: () => now);

  setUp(() async {
    now = 1000;
    remote = FakeRemote();
  });

  Future<void> boot(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  test('first sync uploads only the current user\'s keys, prefix stripped', () async {
    await boot({
      'u1.rec.sudoku.plays': 3,
      'u1.coins': 40,
      'u1.coins.earned': 40,
      'u1.sudoku.save': '{"g":1}',
      'u2.rec.sudoku.plays': 99,
      'acct.name': 'Asha',
      'u1.cloud.lb.game_2048': 500,
    });
    final credits = await engine().sync(uid: 'A', prefix: 'u1.', name: 'Asha');
    expect(credits, 0);
    final d = remote.docs['A']!;
    expect(d.data['rec.sudoku.plays'], 3);
    expect(d.data['coins'], 40);
    expect(d.data['coins.spent'], 0);
    expect(d.data['sudoku.save'], '{"g":1}');
    expect(d.data.keys.any((k) => k.startsWith('u2') || k.startsWith('acct') || k.startsWith('cloud.')), isFalse);
    expect(d.meta['sudoku.save']!.t, 1000);
    // Other users / global keys untouched.
    expect(prefs.getInt('u2.rec.sudoku.plays'), 99);
    expect(prefs.getString('acct.name'), 'Asha');
  });

  test('second phone pulls and merges with its own (guest) progress', () async {
    remote.docs['A'] = RemoteDoc(exists: true, data: {
      'rec.sudoku.plays': 10,
      'arrows.easy.stars.1': 3,
      'coins': 90,
      'coins.earned': 100,
      'coins.spent': 10,
      'g2048.classic.save': '{"cloud":true}',
    }, meta: {
      'g2048.classic.save': const KeyMeta(500),
    });
    await boot({
      'u_guest.rec.sudoku.plays': 2,
      'u_guest.arrows.easy.stars.2': 1,
      'u_guest.coins': 20,
      'u_guest.coins.earned': 20,
    });
    await engine().sync(uid: 'A', prefix: 'u_guest.', name: 'Guest');
    expect(prefs.getInt('u_guest.rec.sudoku.plays'), 10);
    expect(prefs.getInt('u_guest.arrows.easy.stars.1'), 3);
    expect(prefs.getInt('u_guest.arrows.easy.stars.2'), 1);
    expect(prefs.getInt('u_guest.coins'), 90);
    expect(prefs.getString('u_guest.g2048.classic.save'), '{"cloud":true}');
    // Cloud now has the union too.
    expect(remote.docs['A']!.data['arrows.easy.stars.2'], 1);
  });

  test('a finished (removed) save is deleted in the cloud and stays deleted', () async {
    await boot({'u1.sudoku.save': '{"g":1}'});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(remote.docs['A']!.data['sudoku.save'], isNotNull);

    await prefs.remove('u1.sudoku.save');
    now = 2000;
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(remote.docs['A']!.data.containsKey('sudoku.save'), isFalse);
    expect(remote.docs['A']!.meta['sudoku.save']!.deleted, isTrue);
    expect(prefs.containsKey('u1.sudoku.save'), isFalse);

    now = 3000;
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(prefs.containsKey('u1.sudoku.save'), isFalse);
  });

  test('newer save from another phone replaces the local one; older does not', () async {
    await boot({'u1.sudoku.save': '{"phone":1}'});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x'); // local meta t=1000
    final d = remote.docs['A']!;
    remote.docs['A'] = RemoteDoc(exists: true, data: {...d.data, 'sudoku.save': '{"phone":2}'}, meta: {'sudoku.save': const KeyMeta(1500)});
    now = 1600;
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(prefs.getString('u1.sudoku.save'), '{"phone":2}');

    // Older remote change loses against a newer local edit.
    await prefs.setString('u1.sudoku.save', '{"phone":1,"move":2}');
    now = 5000;
    remote.docs['A'] = RemoteDoc(exists: true, data: {'sudoku.save': '{"stale":true}'}, meta: {'sudoku.save': const KeyMeta(4000)});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(prefs.getString('u1.sudoku.save'), '{"phone":1,"move":2}');
    expect(remote.docs['A']!.data['sudoku.save'], '{"phone":1,"move":2}');
  });

  test('pending referral credits are consumed once', () async {
    remote.docs['A'] = const RemoteDoc(exists: true, pendingCredits: 200);
    await boot({'u1.coins': 5});
    expect(await engine().sync(uid: 'A', prefix: 'u1.', name: 'x'), 200);
    expect(await engine().sync(uid: 'A', prefix: 'u1.', name: 'x'), 0);
  });

  test('int values that come back as doubles are stored as ints', () async {
    remote.docs['A'] = const RemoteDoc(exists: true, data: {'rec.x.plays': 4.0});
    await boot({});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(prefs.get('u1.rec.x.plays'), 4);
  });

  test('sync is stable: repeating it changes nothing', () async {
    await boot({'u1.rec.x.plays': 4, 'u1.coins': 10, 'u1.coins.earned': 30, 'u1.a.save': '{"z":0}'});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    final first = Map.of(remote.docs['A']!.data);
    final firstMeta = Map.of(remote.docs['A']!.meta);
    now = 9999;
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'x');
    expect(remote.docs['A']!.data, first);
    expect(remote.docs['A']!.meta, firstMeta);
    expect(prefs.getInt('u1.coins'), 10);
    expect(prefs.getInt('u1.coins.spent'), 20);
  });

  test('country is saved with users/{uid} (normalized, invalid dropped)', () async {
    await boot({'u1.coins': 5});
    await engine().sync(uid: 'A', prefix: 'u1.', name: 'Asha', country: 'in');
    expect(remote.countries['A'], 'IN');
    await engine().sync(uid: 'B', prefix: 'u1.', name: 'Ben', country: 'India');
    expect(remote.countries['B'], isNull);
  });
}
