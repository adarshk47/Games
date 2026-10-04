import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'leaderboard_service.dart';
import 'referral_service.dart';
import 'sync_merge.dart';

/// Reads/writes one local user's Storage keys (with the `u123.` prefix
/// stripped). Backed by SharedPreferences, so tests can use
/// `SharedPreferences.setMockInitialValues`.
class LocalKv {
  LocalKv(this.prefs);
  final SharedPreferences prefs;

  static const metaKey = 'cloud.meta';

  Map<String, Object> readAll(String prefix) {
    final out = <String, Object>{};
    for (final full in prefs.getKeys()) {
      if (!full.startsWith(prefix)) continue;
      final k = full.substring(prefix.length);
      if (k.isEmpty || SyncMerge.isExcluded(k)) continue;
      final v = prefs.get(full);
      if (v != null) out[k] = v;
    }
    return out;
  }

  /// Makes the user's keys equal to [values] (keys missing from [values] that
  /// exist locally are removed, except excluded `cloud.*` keys).
  Future<void> writeAll(String prefix, Map<String, Object> values) async {
    final current = readAll(prefix);
    for (final k in current.keys) {
      if (!values.containsKey(k)) await prefs.remove('$prefix$k');
    }
    for (final e in values.entries) {
      if (current[e.key] == e.value) continue;
      await _put('$prefix${e.key}', e.value);
    }
  }

  Future<void> _put(String key, Object v) async {
    if (v is bool) {
      await prefs.setBool(key, v);
    } else if (v is int) {
      await prefs.setInt(key, v);
    } else if (v is double) {
      // Firestore may hand back whole numbers as double; keep ints as ints.
      if (v == v.roundToDouble() && prefs.get(key) is! double) {
        await prefs.setInt(key, v.toInt());
      } else {
        await prefs.setDouble(key, v);
      }
    } else if (v is String) {
      await prefs.setString(key, v);
    } else if (v is List) {
      await prefs.setStringList(key, [for (final e in v) '$e']);
    }
  }

  Map<String, KeyMeta> readMeta(String prefix) {
    final s = prefs.getString('$prefix$metaKey');
    if (s == null) return {};
    try {
      return metaFromJson(jsonDecode(s));
    } catch (_) {
      return {};
    }
  }

  Future<void> writeMeta(String prefix, Map<String, KeyMeta> m) =>
      prefs.setString('$prefix$metaKey', jsonEncode(metaToJson(m)));
}

/// The cloud copy of one user (Firestore `users/{uid}`), abstracted for tests.
class RemoteDoc {
  const RemoteDoc({this.exists = false, this.data = const {}, this.meta = const {}, this.pendingCredits = 0});
  final bool exists;
  final Map<String, Object> data;
  final Map<String, KeyMeta> meta;
  final int pendingCredits;
}

abstract class RemoteStore {
  Future<RemoteDoc> load(String uid);
  Future<void> save(String uid, {required bool exists, required String name, required Map<String, Object> data, required Map<String, KeyMeta> meta});

  /// Atomically reads and zeroes `pendingCredits`; returns the amount.
  Future<int> consumePendingCredits(String uid);
  Future<void> delete(String uid);
}

class FirestoreRemoteStore implements RemoteStore {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  static Map<String, Object> _clean(Object? m) {
    final out = <String, Object>{};
    if (m is Map) {
      m.forEach((k, v) {
        if (v != null) out['$k'] = v as Object;
      });
    }
    return out;
  }

  @override
  Future<RemoteDoc> load(String uid) async {
    final s = await _doc(uid).get(const GetOptions(source: Source.server));
    if (!s.exists) return const RemoteDoc();
    final d = s.data() ?? {};
    return RemoteDoc(
      exists: true,
      data: _clean(d['data']),
      meta: metaFromJson(d['meta']),
      pendingCredits: (d['pendingCredits'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> save(String uid, {required bool exists, required String name, required Map<String, Object> data, required Map<String, KeyMeta> meta}) async {
    final body = <String, Object>{
      'name': name,
      'data': data,
      'meta': metaToJson(meta, withHash: false),
      'schema': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // update() replaces the whole `data`/`meta` maps (set(merge) would deep
    // merge and resurrect removed keys).
    if (exists) {
      await _doc(uid).update(body);
    } else {
      await _doc(uid).set(body);
    }
  }

  @override
  Future<int> consumePendingCredits(String uid) => _db.runTransaction((tx) async {
        final s = await tx.get(_doc(uid));
        final n = (s.data()?['pendingCredits'] as num?)?.toInt() ?? 0;
        if (n > 0) tx.update(_doc(uid), {'pendingCredits': 0});
        return n;
      });

  @override
  Future<void> delete(String uid) => _doc(uid).delete();
}

/// One full pull -> merge -> write local -> push cycle. Free of Flutter
/// bindings and Firebase so it can be tested with fakes.
class SyncEngine {
  SyncEngine({required this.kv, required this.remote, int Function()? clock}) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final LocalKv kv;
  final RemoteStore remote;
  final int Function() _clock;

  /// Returns the pending referral credits that were consumed (to be added to
  /// the user's coins by the caller).
  Future<int> sync({required String uid, required String prefix, required String name}) async {
    final local = kv.readAll(prefix);
    final meta = SyncMerge.refreshMeta(local, kv.readMeta(prefix), _clock());
    await kv.writeMeta(prefix, meta);
    final doc = await remote.load(uid);
    final merged = SyncMerge.merge(local: local, remote: doc.data, localMeta: meta, remoteMeta: doc.meta);
    await kv.writeAll(prefix, merged.values);
    final newMeta = SyncMerge.withHashes(merged.values, merged.meta);
    await kv.writeMeta(prefix, newMeta);
    await remote.save(uid, exists: doc.exists, name: name, data: merged.values, meta: merged.meta);
    return doc.pendingCredits > 0 ? await remote.consumePendingCredits(uid) : 0;
  }
}

/// App-level sync orchestration: pull on login, debounced (5 s) push after
/// every reward event and an immediate sync when the app is paused.
class SyncService with WidgetsBindingObserver {
  SyncService._();
  static final SyncService I = SyncService._();

  static const debounce = Duration(seconds: 5);

  final ValueNotifier<DateTime?> lastSynced = ValueNotifier(null);
  final ValueNotifier<bool> syncing = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  RemoteStore remote = FirestoreRemoteStore();
  Timer? _timer;
  StreamSubscription<RewardEvent>? _sub;
  Future<void>? _running;
  bool _again = false;
  bool _started = false;

  bool get canSync => CloudService.available && CloudAuth.I.user.value != null && AccountService.I.loggedIn;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _sub = Rewards.events.listen((_) => schedule());
    _loadLastSynced();
  }

  void stop() {
    _timer?.cancel();
    _sub?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  void _loadLastSynced() {
    final ms = Storage.globalString('cloud.lastSync');
    lastSynced.value = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(int.tryParse(ms) ?? 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      syncNow();
    }
  }

  /// Debounced push (restarts the 5 s timer).
  void schedule() {
    if (!canSync) return;
    _timer?.cancel();
    _timer = Timer(debounce, syncNow);
  }

  /// Runs a full sync now. Concurrent calls are coalesced. Never throws.
  Future<void> syncNow() async {
    if (!canSync) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final f = _run();
    _running = f;
    try {
      await f;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  Future<void> _run() async {
    final uid = CloudAuth.I.user.value?.uid;
    final prefix = Storage.userPrefix;
    if (uid == null || prefix.isEmpty) return;
    syncing.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final engine = SyncEngine(kv: LocalKv(prefs), remote: remote);
      final credits = await engine.sync(uid: uid, prefix: prefix, name: AccountService.I.name);
      // The user may have locked/switched while we were busy.
      if (Storage.userPrefix != prefix) return;
      Rewards.reload();
      if (credits > 0) await Rewards.addCoins(credits, label: tr('cloud.invite_bonus'));
      final now = DateTime.now();
      lastSynced.value = now;
      lastError.value = null;
      await Storage.setGlobalString('cloud.lastSync', '${now.millisecondsSinceEpoch}');
      unawaited(LeaderboardService.I.submitAll());
      unawaited(ReferralService.I.tryCredit());
    } catch (e) {
      debugPrint('sync failed: $e');
      lastError.value = tr('cloud.sync_failed');
    } finally {
      syncing.value = false;
    }
  }

  Future<void> deleteRemote(String uid) => remote.delete(uid);
}
