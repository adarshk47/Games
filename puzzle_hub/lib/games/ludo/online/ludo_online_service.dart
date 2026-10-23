import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/cloud/online_service.dart';
import '../logic/ludo_logic.dart';

/// Encodes a Ludo action as one int for Firestore: roll = 100 + seat,
/// move = seat * 10 + token.
int encodeLudo(LudoAction a) => a.isRoll ? 100 + a.seat : a.seat * 10 + a.token!;
LudoAction decodeLudo(int v) => v >= 100 ? LudoAction.roll(v - 100) : LudoAction.move(v ~/ 10, v % 10);

/// One online Ludo game document.
@immutable
class LudoOnlineGame {
  const LudoOnlineGame({
    required this.id,
    required this.players,
    required this.names,
    required this.seed,
    required this.quick,
    required this.log,
    required this.status,
    this.updatedAt,
    this.game = 'ludo',
  });
  final String id;

  /// 'ludo' or 'snakes'.
  final String game;
  final List<String> players, names;
  final int seed;
  final bool quick;
  final List<int> log;
  final String status;
  final DateTime? updatedAt;

  bool get over => status == 'over';

  LudoGame build(String? me) {
    final cols = ludoColours(players.length);
    return LudoGame.replay(
      seats: [
        for (var i = 0; i < players.length; i++)
          LudoSeat(cols[i], players[i] == me ? SeatKind.human : SeatKind.remote, name: names[i], uid: players[i]),
      ],
      seed: seed,
      quick: quick,
      actions: log.map(decodeLudo),
    );
  }

  static LudoOnlineGame fromDoc(String id, Map<String, dynamic> d) => LudoOnlineGame(
        id: id,
        players: [for (final p in d['players'] as List? ?? const []) '$p'],
        names: [for (final p in d['names'] as List? ?? const []) '$p'],
        seed: (d['seed'] as num?)?.toInt() ?? 1,
        quick: d['quick'] as bool? ?? false,
        log: [for (final v in d['log'] as List? ?? const []) (v as num).toInt()],
        status: d['status'] as String? ?? 'active',
        updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
        game: d['game'] as String? ?? 'ludo',
      );
}

/// A room friends join with a short code (2–4 players).
@immutable
class LudoRoom {
  const LudoRoom({required this.code, required this.host, required this.players, required this.names, required this.max, required this.quick, required this.status, this.gameId, this.game = 'ludo'});
  final String code, host, status, game;
  final List<String> players, names;
  final int max;
  final bool quick;
  final String? gameId;

  static LudoRoom fromDoc(String code, Map<String, dynamic> d) => LudoRoom(
        code: code,
        host: d['host'] as String? ?? '',
        players: [for (final p in d['players'] as List? ?? const []) '$p'],
        names: [for (final p in d['names'] as List? ?? const []) '$p'],
        max: (d['max'] as num?)?.toInt() ?? 4,
        quick: d['quick'] as bool? ?? false,
        status: d['status'] as String? ?? 'open',
        gameId: d['gameId'] as String?,
        game: d['game'] as String? ?? 'ludo',
      );
}

/// Firestore side of online Ludo (uses the same player names, challenges
/// and sign-in as online Chess).
class LudoOnline {
  LudoOnline._();
  static final LudoOnline I = LudoOnline._();

  /// After this long without a move, another player may play the turn for
  /// the silent one (so a game never gets stuck).
  static const turnTime = Duration(seconds: 30);

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  OnlineService get _o => OnlineService.I;
  String get _myName => _o.me.value?.handle ?? 'Player';

  Map<String, Object?> _newGame(List<String> players, List<String> names, bool quick, [String game = 'ludo']) => {
        'game': game,
        'players': players,
        'names': names,
        'seed': math.Random().nextInt(1 << 30) + 1,
        'quick': quick,
        'log': <int>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Stream<LudoOnlineGame?> watch(String id) =>
      _db.collection('ludo_games').doc(id).snapshots().map((s) => s.exists ? LudoOnlineGame.fromDoc(s.id, s.data()!) : null);

  /// Appends [a] if the log is still [expectLen] long (no double moves).
  Future<bool> act(String id, int expectLen, LudoAction a, {String? endWinner}) async {
    final ref = _db.collection('ludo_games').doc(id);
    try {
      return await _db.runTransaction((tx) async {
        final s = await tx.get(ref);
        final log = [for (final v in s.data()?['log'] as List? ?? const []) (v as num).toInt()];
        if (log.length != expectLen || s.data()?['status'] == 'over') return false;
        tx.update(ref, {
          'log': [...log, encodeLudo(a)],
          'updatedAt': FieldValue.serverTimestamp(),
          if (endWinner != null) ...{'status': 'over', 'winner': endWinner},
        });
        return true;
      });
    } catch (e) {
      debugPrint('ludo act: $e');
      return false;
    }
  }

  Future<List<LudoOnlineGame>> myGames([String game = 'ludo']) async {
    final u = _o.uid;
    if (u == null) return const [];
    final q = await _db.collection('ludo_games').where('players', arrayContains: u).limit(30).get();
    return [for (final d in q.docs) LudoOnlineGame.fromDoc(d.id, d.data())].where((g) => !g.over && g.game == game).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
  }

  // ---------------------------------------------------------------- quick match

  Future<Stream<String?>> quickMatch([String game = 'ludo']) async {
    final me = _o.uid!;
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(OnlineService.queueWindow));
    final q = await _db.collection('ludo_queue').where('createdAt', isGreaterThan: cutoff).orderBy('createdAt').limit(10).get();
    for (final d in q.docs) {
      if (d.id == me || d.data()['gameId'] != null || (d.data()['game'] ?? 'ludo') != game) continue;
      try {
        final id = await _db.runTransaction<String?>((tx) async {
          final snap = await tx.get(d.reference);
          if (!snap.exists || snap.data()?['gameId'] != null) return null;
          final doc = _db.collection('ludo_games').doc();
          tx.set(doc, _newGame([d.id, me], [snap.data()?['name'] as String? ?? 'Player', _myName], false, game));
          tx.update(d.reference, {'gameId': doc.id});
          return doc.id;
        });
        if (id != null) return Stream.value(id);
      } catch (e) {
        debugPrint('ludo quick join: $e');
      }
    }
    final ref = _db.collection('ludo_queue').doc(me);
    await ref.set({'name': _myName, 'game': game, 'createdAt': FieldValue.serverTimestamp()});
    return ref.snapshots().map((s) => s.data()?['gameId'] as String?);
  }

  Future<void> leaveQueue() async {
    final u = _o.uid;
    if (u == null) return;
    try {
      await _db.collection('ludo_queue').doc(u).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- challenge

  /// Creates the 2-player game for an accepted Ludo challenge.
  Future<String> acceptChallenge(Challenge c) async {
    final game = _db.collection('ludo_games').doc();
    final batch = _db.batch()
      ..set(game, _newGame([c.from, _o.uid!], [c.fromName, _myName], false, c.game))
      ..update(_db.collection('challenges').doc(c.id), {'status': 'accepted', 'gameId': game.id});
    await batch.commit();
    return game.id;
  }

  // ---------------------------------------------------------------- rooms

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> createRoom(int max, bool quick, [String game = 'ludo']) async {
    final r = math.Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(5, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
      final ref = _db.collection('ludo_rooms').doc(code);
      final ok = await _db.runTransaction<bool>((tx) async {
        final s = await tx.get(ref);
        if (s.exists) return false;
        tx.set(ref, {
          'host': _o.uid,
          'players': [_o.uid],
          'names': [_myName],
          'max': max,
          'quick': quick,
          'game': game,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (ok) return code;
    }
    throw StateError('no free room code');
  }

  Stream<LudoRoom?> watchRoom(String code) =>
      _db.collection('ludo_rooms').doc(code).snapshots().map((s) => s.exists ? LudoRoom.fromDoc(s.id, s.data()!) : null);

  /// Joins a room. Returns an error key or null.
  Future<String?> joinRoom(String code) async {
    final ref = _db.collection('ludo_rooms').doc(code.trim().toUpperCase());
    try {
      return await _db.runTransaction<String?>((tx) async {
        final s = await tx.get(ref);
        if (!s.exists) return 'ludo.err.no_room';
        final r = LudoRoom.fromDoc(s.id, s.data()!);
        if (r.players.contains(_o.uid)) return null;
        if (r.status != 'open') return 'ludo.err.started';
        if (r.players.length >= r.max) return 'ludo.err.full';
        tx.update(ref, {
          'players': [...r.players, _o.uid],
          'names': [...r.names, _myName],
        });
        return null;
      });
    } catch (e) {
      debugPrint('join room: $e');
      return 'online.err.network';
    }
  }

  /// Host starts the game with everyone who joined (2+ players).
  Future<void> startRoom(LudoRoom r) async {
    final game = _db.collection('ludo_games').doc();
    final batch = _db.batch()
      ..set(game, _newGame(r.players, r.names, r.quick, r.game))
      ..update(_db.collection('ludo_rooms').doc(r.code), {'status': 'started', 'gameId': game.id});
    await batch.commit();
  }

  Future<void> leaveRoom(LudoRoom r) async {
    final ref = _db.collection('ludo_rooms').doc(r.code);
    try {
      if (r.host == _o.uid) {
        await ref.delete();
      } else {
        final i = r.players.indexOf(_o.uid ?? '');
        if (i < 0) return;
        await ref.update({
          'players': [...r.players]..removeAt(i),
          'names': [...r.names]..removeAt(i),
        });
      }
    } catch (_) {}
  }
}
