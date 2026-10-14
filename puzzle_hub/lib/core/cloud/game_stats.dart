import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import '../ui/ui.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import '../ui/how_to_play.dart';

/// Per-game numbers for the developer, in Firestore `game_stats/{gameId}`:
/// `plays` (every time the game is opened), `ratings` (how many players rated
/// it), `stars` (sum of all stars; average = stars / ratings) and `r1`..`r5`
/// (how many gave 1..5 stars). Each player's own rating is kept in
/// `game_stats/{gameId}/ratings/{userId}` so re-rating replaces it.
class GameStats {
  GameStats._();

  static const _kMine = 'rating.';

  /// Test hook: replaces the Firestore writes.
  @visibleForTesting
  static Future<void> Function(String gameId, Map<String, Object> delta)?
  writeOverride;

  @visibleForTesting
  static Random random = Random();

  /// This player's stars for [gameId] (0 = not rated yet).
  static int myRating(String gameId) => Storage.getInt('$_kMine$gameId');

  static DocumentReference<Map<String, dynamic>> _doc(String id) =>
      FirebaseFirestore.instance.collection('game_stats').doc(id);

  static Future<void> _apply(String gameId, Map<String, Object> delta) async {
    final o = writeOverride;
    if (o != null) return o(gameId, delta);
    if (!CloudService.available) return;
    await _doc(gameId)
        .set({
          for (final e in delta.entries)
            e.key: FieldValue.increment(e.value as num),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 10));
  }

  /// Counts one play of [gameId]. Never throws, never blocks.
  static void played(String gameId) {
    unawaited(
      _apply(gameId, {
        'plays': 1,
      }).catchError((Object e) => debugPrint('play count failed: $e')),
    );
  }

  /// Saves this player's [stars] (1-5) for [gameId]. Needs a signed-in
  /// account (returns false otherwise).
  static Future<bool> rate(String gameId, int stars) async {
    final s = stars.clamp(1, 5);
    final user = CloudAuth.I.user.value;
    if (writeOverride == null && (user == null || !CloudService.available)) {
      return false;
    }
    final old = myRating(gameId);
    if (old == s) return true;
    final delta = <String, Object>{
      'stars': s - old,
      'r$s': 1,
      if (old > 0) 'r$old': -1 else 'ratings': 1,
    };
    try {
      await _apply(gameId, delta);
      if (writeOverride == null && user != null) {
        await _doc(gameId)
            .collection('ratings')
            .doc(user.uid)
            .set({'stars': s, 'at': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 10));
      }
      await Storage.setInt('$_kMine$gameId', s);
      return true;
    } catch (e) {
      debugPrint('rating failed: $e');
      return false;
    }
  }

  /// After a win, now and then (25%) ask to rate this game if the player
  /// has not rated it yet.
  static Future<void> maybeAskAfterWin(String gameId) async {
    final open = HowToPlay.current;
    final title = open != null && open.id == gameId ? open.title : gameId;
    if (myRating(gameId) > 0) return;
    if (writeOverride == null && CloudAuth.I.user.value == null) return;
    if (random.nextDouble() >= 0.25) return;
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    final ctx = Rewards.navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await askToRate(ctx, gameId, title);
  }

  static Future<void> askToRate(
    BuildContext context,
    String gameId,
    String title,
  ) async {
    final stars = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('rate_game.title', {'game': title})),
        content: RateStars(
          gameId: gameId,
          onPick: (s) => Navigator.of(ctx).pop(s),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('retry.no')),
          ),
        ],
      ),
    );
    if (stars == null) return;
    final ok = await rate(gameId, stars);
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(tr(ok ? 'rate_game.thanks' : 'rate_game.signin')),
        ),
      );
    }
  }
}

/// A row of 5 tappable stars showing this player's rating of [gameId].
class RateStars extends StatelessWidget {
  const RateStars({
    super.key,
    required this.gameId,
    required this.onPick,
    this.size = 34,
  });
  final String gameId;
  final ValueChanged<int> onPick;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mine = GameStats.myRating(gameId);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var s = 1; s <= 5; s++)
          InkResponse(
            key: ValueKey('rate_${gameId}_$s'),
            radius: size * 0.7,
            onTap: () => onPick(s),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                s <= mine ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Pal.gold,
                size: size,
              ),
            ),
          ),
      ],
    );
  }
}
