import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../game_info.dart';
import '../storage.dart';

/// Home-screen widget (1 row × 3 games) and app-icon shortcuts. Both open a
/// game directly. The 3 games are the most recently played ones (filled up
/// with the first games of the hub).
///
/// A tap only *requests* a game ([pending]); the home screen opens it, so the
/// app lock / sign-in always comes first.
class GameShortcuts {
  GameShortcuts._();

  static const slots = 3;
  static const _kRecent = 'shortcuts.recent';
  static const _androidWidget = 'GamesWidgetProvider';

  /// Game id waiting to be opened by the home screen.
  static final ValueNotifier<String?> pending = ValueNotifier(null);

  static bool get _android {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static String? idFromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'masterg' || uri.host != 'game') {
      return null;
    }
    final seg = uri.pathSegments;
    return seg.isEmpty ? null : seg.first;
  }

  /// Starts listening for widget taps and icon shortcuts. Safe to call once
  /// at startup; does nothing off Android.
  static Future<void> init() async {
    if (!_android) return;
    try {
      final first = idFromUri(
        await HomeWidget.initiallyLaunchedFromHomeWidget(),
      );
      if (first != null) pending.value = first;
      HomeWidget.widgetClicked.listen((u) {
        final id = idFromUri(u);
        if (id != null) pending.value = id;
      });
    } catch (e) {
      debugPrint('home widget init failed: $e');
    }
    try {
      const QuickActions().initialize((type) {
        if (type.startsWith('game:')) pending.value = type.substring(5);
      });
    } catch (e) {
      debugPrint('quick actions init failed: $e');
    }
  }

  /// The games shown on the widget / shortcuts: recent first, then [all].
  static List<GameInfo> pick(List<GameInfo> all, {List<String>? recent}) {
    final ids = recent ?? (Storage.getString(_kRecent) ?? '').split(',');
    final out = <GameInfo>[];
    for (final id in ids) {
      final g = all.where((x) => x.id == id);
      if (g.isNotEmpty && !out.contains(g.first)) out.add(g.first);
      if (out.length == slots) return out;
    }
    for (final g in all) {
      if (!out.contains(g)) out.add(g);
      if (out.length == slots) break;
    }
    return out;
  }

  /// Remembers that [id] was just played and refreshes widget + shortcuts.
  static Future<void> played(String id, List<GameInfo> all) async {
    final list = (Storage.getString(_kRecent) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty && s != id)
        .toList();
    list.insert(0, id);
    await Storage.setString(_kRecent, list.take(slots).join(','));
    await refresh(all);
  }

  /// Pushes the current 3 games to the widget and the icon shortcuts.
  static Future<void> refresh(List<GameInfo> all) async {
    if (!_android) return;
    final games = pick(all);
    try {
      for (var i = 0; i < games.length; i++) {
        await HomeWidget.saveWidgetData<String>('g${i}_id', games[i].id);
        await HomeWidget.saveWidgetData<String>(
          'g${i}_emoji',
          games[i].emoji ?? '🎮',
        );
        await HomeWidget.saveWidgetData<String>('g${i}_title', games[i].title);
      }
      await HomeWidget.updateWidget(androidName: _androidWidget);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
    try {
      await const QuickActions().setShortcutItems([
        for (final g in games)
          ShortcutItem(
            type: 'game:${g.id}',
            localizedTitle: '${g.emoji ?? ''} ${g.title}'.trim(),
          ),
      ]);
    } catch (e) {
      debugPrint('shortcuts update failed: $e');
    }
  }
}
