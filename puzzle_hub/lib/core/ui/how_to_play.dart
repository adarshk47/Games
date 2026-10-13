import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../game_info.dart';
import '../i18n/i18n.dart';
import 'dialogs.dart';
import 'palette.dart';

/// "How to play" help for the game that is currently open.
///
/// [current] is set while a game (and any page it pushes) is on screen, so
/// every [GameScaffold] inside it shows a ❓ button.
class HowToPlay {
  HowToPlay._();

  static GameInfo? current;

  /// Opens [g] and remembers it as the current game until it is closed.
  static Future<T?> run<T>(GameInfo g, Future<T?> Function() open) async {
    final prev = current;
    current = g;
    try {
      return await open();
    } finally {
      current = prev;
    }
  }

  /// Shows the rules; when the player closes them an interstitial may follow
  /// (same frequency rules as after a game, never for ad-free players).
  static Future<void> show(BuildContext context, GameInfo g) async {
    await showPremiumDialog(
      context,
      emoji: '❓',
      title: tr('howto.title', {'game': g.title}),
      message: _bullets(tr('howto.${g.id}')),
      dismissible: true,
      actions: [DialogAction(tr('howto.got_it'), () {}, primary: true)],
    );
    AdsService.onLevelCompleted(gameId: g.id);
  }

  static String _bullets(String s) =>
      s.split('\n').where((l) => l.trim().isNotEmpty).map((l) => '• $l').join('\n');
}

/// The ❓ action used in game top bars.
class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({super.key, required this.game});
  final GameInfo game;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Tooltip(
      message: tr('howto.tooltip'),
      child: InkResponse(
        key: const ValueKey('howto_btn'),
        radius: 24,
        onTap: () => HowToPlay.show(context, game),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Pal.glass,
            border: Border.all(color: Pal.glassBorder),
          ),
          child: const Icon(Icons.help_outline_rounded, size: 20, color: Pal.text),
        ),
      ),
    ),
  );
}
