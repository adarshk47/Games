import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account_service.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';

/// A signed-in player as other players see them.
@immutable
class OnlinePlayer {
  const OnlinePlayer({required this.uid, required this.handle, required this.name, this.available = false, this.lastSeen, this.wins = 0, this.losses = 0});
  final String uid;
  final String handle;
  final String name;
  final bool available;
  final DateTime? lastSeen;
  final int wins, losses;

  bool get online => available && lastSeen != null && DateTime.now().difference(lastSeen!) < OnlineService.onlineWindow;

  static OnlinePlayer fromDoc(String uid, Map<String, dynamic> d) => OnlinePlayer(
        uid: uid,
        handle: d['handle'] as String? ?? '',
        name: d['name'] as String? ?? '',
        available: d['available'] as bool? ?? false,
        lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
        wins: (d['wins'] as num?)?.toInt() ?? 0,
        losses: (d['losses'] as num?)?.toInt() ?? 0,
      );
}

/// A game request from one player to another.
@immutable
class Challenge {
  const Challenge({required this.id, required this.from, required this.fromName, required this.to, required this.toName, required this.status, this.gameId, this.game = 'chess'});
  final String id, from, fromName, to, toName, status;
  final String? gameId;

  /// 'chess' or 'ludo'.
  final String game;

  static Challenge fromDoc(String id, Map<String, dynamic> d) => Challenge(
        id: id,
        from: d['from'] as String? ?? '',
        fromName: d['fromName'] as String? ?? '',
        to: d['to'] as String? ?? '',
        toName: d['toName'] as String? ?? '',
        status: d['status'] as String? ?? 'pending',
        gameId: d['gameId'] as String?,
        game: d['game'] as String? ?? 'chess',
      );
}

/// One live online game (moves in UCI, white moves first).
@immutable
class OnlineGame {
  const OnlineGame({
    required this.id,
    required this.white,
    required this.black,
    required this.whiteName,
    required this.blackName,
    required this.moves,
    required this.status,
    this.result,
    this.reason,
    this.updatedAt,
  });
  final String id, white, black, whiteName, blackName, status;
  final List<String> moves;

  /// 'white', 'black' or 'draw' once [status] is 'over'.
  final String? result;
  final String? reason;
  final DateTime? updatedAt;

  bool get over => status == 'over';
  bool get whiteToMove => moves.length.isEven;
  String turnUid() => whiteToMove ? white : black;

  static OnlineGame fromDoc(String id, Map<String, dynamic> d) => OnlineGame(
        id: id,
        white: d['white'] as String? ?? '',
        black: d['black'] as String? ?? '',
        whiteName: d['whiteName'] as String? ?? '',
        blackName: d['blackName'] as String? ?? '',
        moves: [for (final m in (d['moves'] as List? ?? const [])) '$m'],
        status: d['status'] as String? ?? 'active',
        result: d['result'] as String?,
        reason: d['reason'] as String?,
        updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      );
}

/// Online 2-player games for signed-in players (Chess for now; the game
/// field keeps it open for more 2-player games):
///  * a unique handle per player (`handles/{lowercase}` -> uid),
///  * an "available" switch (+ lastSeen heartbeat) so others see who is ready,
///  * quick match (a small waiting queue) and direct challenges by handle,
///  * live games whose moves sync through Firestore.
class OnlineService {
  OnlineService._();
  static final OnlineService I = OnlineService._();

  static const onlineWindow = Duration(minutes: 5);
  static const heartbeat = Duration(minutes: 2);

  /// A waiting quick-match entry older than this is ignored.
  static const queueWindow = Duration(minutes: 3);

  /// The opponent may claim the win when the player to move is silent this long.
  static const abandonAfter = Duration(minutes: 5);

  static final handlePattern = RegExp(r'^[a-z0-9_]{3,16}$');

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get ready => CloudService.available && CloudAuth.I.user.value != null;
  String? get uid => CloudAuth.I.user.value?.uid;

  /// My profile (null until loaded / no handle yet).
  final ValueNotifier<OnlinePlayer?> me = ValueNotifier(null);

  /// True once my profile was read at least once (it may still be null).
  final ValueNotifier<bool> meLoaded = ValueNotifier(false);

  /// Challenges sent to me that are still open.
  final ValueNotifier<List<Challenge>> incoming = ValueNotifier(const []);

  /// Called for every new incoming challenge (UI shows a dialog).
  void Function(Challenge c)? onIncoming;

  StreamSubscription? _meSub, _inSub;
  Timer? _beat;
  String? _startedFor;
  final Set<String> _seen = {};

  /// Starts presence + challenge listening for the signed-in player.
  void start() {
    CloudAuth.I.user.addListener(_onUser);
    _onUser();
  }

  void _onUser() {
    final u = uid;
    if (u == _startedFor) return;
    _stopListening();
    _startedFor = u;
    if (u == null || !CloudService.available) return;
    _meSub = _db.collection('players').doc(u).snapshots().listen((s) {
      me.value = s.exists ? OnlinePlayer.fromDoc(u, s.data()!) : null;
      meLoaded.value = true;
    }, onError: (e) => debugPrint('online me: $e'));
    _inSub = _db
        .collection('challenges')
        .where('to', isEqualTo: u)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((q) {
      final list = [for (final d in q.docs) Challenge.fromDoc(d.id, d.data())];
      incoming.value = list;
      for (final c in list) {
        if (_seen.add(c.id)) onIncoming?.call(c);
      }
    }, onError: (e) => debugPrint('online challenges: $e'));
    _beat = Timer.periodic(heartbeat, (_) => _touch());
    unawaited(_touch());
  }

  void _stopListening() {
    _meSub?.cancel();
    _inSub?.cancel();
    _beat?.cancel();
    _meSub = _inSub = null;
    _beat = null;
    me.value = null;
    meLoaded.value = false;
    incoming.value = const [];
  }

  Future<void> _touch() async {
    final u = uid;
    if (u == null || me.value?.available != true) return;
    try {
      await _db.collection('players').doc(u).update({'lastSeen': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  /// A handle suggestion from the player's name.
  static String suggestHandle(String name) {
    var h = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (h.length < 3) h = 'player';
    if (h.length > 12) h = h.substring(0, 12);
    return '$h${math.Random().nextInt(900) + 100}';
  }

  /// Claims [handle] (unique) and creates / renames my profile. Returns an
  /// error key, or null on success.
  Future<String?> setHandle(String handle) async {
    final u = uid;
    if (u == null) return 'online.err.signin';
    final h = handle.trim().toLowerCase();
    if (!handlePattern.hasMatch(h)) return 'online.err.handle_format';
    final old = me.value?.handle;
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('handles').doc(h);
        final snap = await tx.get(ref);
        if (snap.exists && snap.data()?['uid'] != u) throw const _Taken();
        if (!snap.exists) tx.set(ref, {'uid': u});
        if (old != null && old.isNotEmpty && old != h) tx.delete(_db.collection('handles').doc(old));
        tx.set(
          _db.collection('players').doc(u),
          {
            'handle': h,
            'handleLower': h,
            'name': _name,
            'available': me.value?.available ?? true,
            'lastSeen': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      return null;
    } on _Taken {
      return 'online.err.handle_taken';
    } catch (e) {
      debugPrint('setHandle: $e');
      return 'online.err.network';
    }
  }

  String get _name {
    final n = AccountService.I.name.trim();
    return n.isEmpty ? 'Player' : (n.length > 24 ? n.substring(0, 24) : n);
  }

  Future<void> setAvailable(bool on) async {
    final u = uid;
    if (u == null || me.value == null) return;
    try {
      await _db.collection('players').doc(u).update({'available': on, 'lastSeen': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('setAvailable: $e');
    }
  }

  /// Players marked available and seen in the last few minutes.
  Future<List<OnlinePlayer>> onlinePlayers() async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(onlineWindow));
    final q = await _db.collection('players').where('lastSeen', isGreaterThan: cutoff).limit(60).get();
    return [
      for (final d in q.docs)
        if (d.id != uid) OnlinePlayer.fromDoc(d.id, d.data())
    ].where((p) => p.available && p.handle.isNotEmpty).toList();
  }

  /// Players whose handle starts with [prefix].
  Future<List<OnlinePlayer>> search(String prefix) async {
    final p = prefix.trim().toLowerCase().replaceAll('@', '');
    if (p.isEmpty) return const [];
    final q = await _db
        .collection('players')
        .where('handleLower', isGreaterThanOrEqualTo: p)
        .where('handleLower', isLessThan: '$p')
        .limit(15)
        .get();
    return [
      for (final d in q.docs)
        if (d.id != uid) OnlinePlayer.fromDoc(d.id, d.data())
    ];
  }

  // ---------------------------------------------------------------- challenges

  /// Sends a challenge; returns its id.
  Future<String> challenge(OnlinePlayer to, {String game = 'chess'}) async {
    final ref = await _db.collection('challenges').add({
      'game': game,
      'from': uid,
      'fromName': me.value?.handle ?? _name,
      'to': to.uid,
      'toName': to.handle,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<Challenge?> watchChallenge(String id) =>
      _db.collection('challenges').doc(id).snapshots().map((s) => s.exists ? Challenge.fromDoc(s.id, s.data()!) : null);

  Future<void> cancelChallenge(String id) async {
    try {
      await _db.collection('challenges').doc(id).update({'status': 'cancelled'});
    } catch (_) {}
  }

  Future<void> decline(Challenge c) async {
    try {
      await _db.collection('challenges').doc(c.id).update({'status': 'declined'});
    } catch (_) {}
  }

  /// Accepts [c]: creates the game (random colours) and links it to the
  /// challenge in one batch. Returns the game id.
  Future<String> accept(Challenge c) async {
    final game = _db.collection('games').doc();
    final iAmWhite = math.Random().nextBool();
    final batch = _db.batch()
      ..set(game, _newGame(
        white: iAmWhite ? uid! : c.from,
        black: iAmWhite ? c.from : uid!,
        whiteName: iAmWhite ? (me.value?.handle ?? _name) : c.fromName,
        blackName: iAmWhite ? c.fromName : (me.value?.handle ?? _name),
      ))
      ..update(_db.collection('challenges').doc(c.id), {'status': 'accepted', 'gameId': game.id});
    await batch.commit();
    return game.id;
  }

  Map<String, Object?> _newGame({required String white, required String black, required String whiteName, required String blackName}) => {
        'game': 'chess',
        'white': white,
        'black': black,
        'whiteName': whiteName,
        'blackName': blackName,
        'players': [white, black],
        'moves': <String>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  // ---------------------------------------------------------------- quick match

  /// Joins someone already waiting, or waits in the queue. The returned
  /// stream yields the game id once matched.
  Future<Stream<String?>> quickMatch() async {
    final me = uid!;
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(queueWindow));
    final q = await _db.collection('queue').where('createdAt', isGreaterThan: cutoff).orderBy('createdAt').limit(10).get();
    for (final d in q.docs) {
      if (d.id == me || d.data()['gameId'] != null) continue;
      try {
        final id = await _db.runTransaction<String?>((tx) async {
          final snap = await tx.get(d.reference);
          if (!snap.exists || snap.data()?['gameId'] != null) return null;
          final other = snap.data()!;
          final game = _db.collection('games').doc();
          final iAmWhite = math.Random().nextBool();
          final otherName = other['name'] as String? ?? 'Player';
          final myName = this.me.value?.handle ?? _name;
          tx.set(game, _newGame(
            white: iAmWhite ? me : d.id,
            black: iAmWhite ? d.id : me,
            whiteName: iAmWhite ? myName : otherName,
            blackName: iAmWhite ? otherName : myName,
          ));
          tx.update(d.reference, {'gameId': game.id});
          return game.id;
        });
        if (id != null) return Stream.value(id);
      } catch (e) {
        debugPrint('quick match join: $e');
      }
    }
    final ref = _db.collection('queue').doc(me);
    await ref.set({'name': this.me.value?.handle ?? _name, 'createdAt': FieldValue.serverTimestamp()});
    return ref.snapshots().map((s) => s.data()?['gameId'] as String?);
  }

  Future<void> leaveQueue() async {
    final u = uid;
    if (u == null) return;
    try {
      await _db.collection('queue').doc(u).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- games

  Stream<OnlineGame?> watchGame(String id) =>
      _db.collection('games').doc(id).snapshots().map((s) => s.exists ? OnlineGame.fromDoc(s.id, s.data()!) : null);

  /// Appends my move (only accepted by the rules when it is my turn and
  /// exactly one move longer). [result]/[reason] end the game with it.
  Future<bool> sendMove(OnlineGame g, String uci, {String? result, String? reason}) async {
    try {
      await _db.collection('games').doc(g.id).update({
        'moves': [...g.moves, uci],
        'updatedAt': FieldValue.serverTimestamp(),
        if (result != null) ...{'status': 'over', 'result': result, 'reason': reason},
      });
      return true;
    } catch (e) {
      debugPrint('sendMove: $e');
      return false;
    }
  }

  /// Ends the game without a move (resign, abandoned opponent).
  Future<void> end(OnlineGame g, String result, String reason) async {
    try {
      await _db.collection('games').doc(g.id).update({
        'status': 'over',
        'result': result,
        'reason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('end game: $e');
    }
  }

  /// Adds my finished game to my win / loss counters (once per game).
  Future<void> recordResult({required bool won, required bool lost}) async {
    final u = uid;
    if (u == null || me.value == null || (!won && !lost)) return;
    try {
      await _db.collection('players').doc(u).update({
        if (won) 'wins': FieldValue.increment(1),
        if (lost) 'losses': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// My unfinished games (newest first).
  Future<List<OnlineGame>> myActiveGames() async {
    final u = uid;
    if (u == null) return const [];
    final q = await _db.collection('games').where('players', arrayContains: u).limit(30).get();
    final list = [
      for (final d in q.docs) OnlineGame.fromDoc(d.id, d.data())
    ].where((g) => !g.over).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return list;
  }
}

class _Taken implements Exception {
  const _Taken();
}
