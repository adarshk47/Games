import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud/cloud_service.dart';
import 'storage.dart';

/// One app (3.0.0) that can look like each staged release, switched from
/// Firestore `config/app` without an app update:
///
/// * stage 1 – Dominoes and the rest; Business, Brain Age, Saanp-Seedhi and
///   Mom Memory "Coming soon"; Neon Night theme, classic sounds.
/// * stage 2 – + Business and Brain Age (shown first), Merry Christmas theme,
///   retro arcade sounds.
/// * stage 3 – every game, every theme free, Happy New Year theme, soft
///   sounds, new home layouts, New Year sale, two "New game" cards.
///
/// Firestore `config/app` (all optional):
///   stage:  1 | 2 | 3
///   v2From: 'YYYY-MM-DD'   stage 2 from this date (India time)
///   v3From: 'YYYY-MM-DD'   stage 3 from this date
///   games:  { business: 'on' | 'soon' | 'off', ... }   per-game override
/// The last values are cached, so offline starts look the same. Without any
/// value the build's STAGE define is used (tests: 3).
class ReleaseStage {
  ReleaseStage._();

  static const fallback = int.fromEnvironment('STAGE', defaultValue: 3);
  static const _kCache = 'stage.remote';

  static int _stage = fallback;
  static int get current => _stage;

  /// Per-game override from Firestore: 'on', 'soon' or 'off'.
  static Map<String, String> games = const {};

  @visibleForTesting
  static void debugSet(int stage, {Map<String, String> games = const {}}) {
    _stage = stage;
    ReleaseStage.games = games;
  }

  /// Applies the cached config, then (when online) the fresh one. Call once
  /// at startup after Firebase is ready and before anything reads [games].
  static Future<void> load() async {
    _apply(_cached());
    if (!CloudService.available) return;
    try {
      final d = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 3));
      final data = d.data();
      if (data == null) return;
      final keep = <String, Object?>{
        for (final k in ['stage', 'v2From', 'v3From', 'games'])
          if (data[k] != null) k: data[k],
      };
      await Storage.setGlobalString(_kCache, jsonEncode(keep));
      _apply(keep);
    } catch (e) {
      debugPrint('release stage: $e');
    }
  }

  static Map<String, Object?> _cached() {
    try {
      final s = Storage.globalString(_kCache);
      return s == null ? const {} : (jsonDecode(s) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }

  static void _apply(Map<String, Object?> d, [DateTime? now]) {
    _stage = stageFor(d, now ?? DateTime.now());
    final g = d['games'];
    games = g is Map ? {for (final e in g.entries) '${e.key}': '${e.value}'} : const {};
  }

  /// The stage for config [d] at [now]: the `stage` field (or the build
  /// default), raised by any `v2From` / `v3From` date already reached.
  static int stageFor(Map<String, Object?> d, DateTime now) {
    final s = d['stage'];
    var stage = s is num ? s.toInt().clamp(1, 3) : fallback;
    bool reached(Object? day) {
      if (day is! String) return false;
      final t = DateTime.tryParse('${day}T00:00:00+05:30');
      return t != null && !now.isBefore(t);
    }

    if (reached(d['v2From']) && stage < 2) stage = 2;
    if (reached(d['v3From'])) stage = 3;
    return stage;
  }
}

/// The current stage (1, 2 or 3), see [ReleaseStage].
int get kStage => ReleaseStage.current;

/// Games newly opened in this stage: shown first on Home with a big card.
Set<String> get kStageNewGames => kStage == 2
    ? const {'business', 'brain_age'}
    : (kStage == 3 ? const {'snakes', 'mom_memory'} : const {'dominoes'});

/// Game id → first stage it is playable in (earlier stages: "Coming soon").
const Map<String, int> kGameStage = {'business': 2, 'brain_age': 2, 'snakes': 3, 'mom_memory': 3};

/// Whether game [id] is "Coming soon" right now (Firestore override first).
bool gameComingSoon(String id) => switch (ReleaseStage.games[id]) {
      'on' => false,
      'soon' => true,
      _ => kStage < (kGameStage[id] ?? 1),
    };

/// Whether game [id] is hidden completely by a Firestore 'off' override.
bool gameHidden(String id) => ReleaseStage.games[id] == 'off';

/// Theme id → first stage it can be picked in.
const Map<String, int> kThemeStage = {
  'arcade': 3,
  'winter': 3,
  'neon': 1,
  'christmas': 2,
  'newyear': 3,
};

/// Each stage's own theme, used until the player picks one:
/// 1 Neon Night, 2 Merry Christmas, 3 Happy New Year.
String get kStageTheme => kStage == 1 ? 'neon' : (kStage == 2 ? 'christmas' : 'newyear');

/// Each stage has its own sound-effect set (assets/audio/sfx_vN/).
String get kStageSfxDir => 'sfx_v$kStage';

bool themeInStage(String id) => kStage >= (kThemeStage[id] ?? 1);

/// New home layouts (Bento, Spotlight, Journey, Mosaic, A–Z, Rooms) and the
/// themed music open in stage 3; earlier stages show the layouts as "Coming soon".
const int kNewLayoutsStage = 3;
