import 'package:flutter/material.dart';

import '../../games/registry.dart';
import '../ads/ads_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../ui/ui.dart';

/// Where every coin came from (per game and per source), what it was spent
/// on, ads watched, and the most recent transactions.
class CoinHistoryScreen extends StatelessWidget {
  const CoinHistoryScreen({super.key});

  static const _sources = ['game', 'ad', 'daily', 'quest', 'achievement', 'invite', 'other'];
  static const _uses = ['skip', 'unlockLevel', 'hint', 'undo', 'extraLife', 'theme', 'adfree', 'other'];

  String _sourceLabel(String s) {
    final g = allGames.where((x) => x.id == s);
    if (g.isNotEmpty) return g.first.title;
    final k = 'shop.src.$s';
    final t = tr(k);
    if (t != k) return t;
    final u = tr('shop.use.$s');
    return u == 'shop.use.$s' ? s : u;
  }

  @override
  Widget build(BuildContext context) {
    final byGame = [
      for (final g in allGames)
        if (CoinHistory.earnedFromGame(g.id) > 0) (g, CoinHistory.earnedFromGame(g.id)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final sources = [for (final s in _sources) if (CoinHistory.earnedFrom(s) > 0) (s, CoinHistory.earnedFrom(s))];
    final uses = [for (final u in _uses) if (CoinHistory.spentOn(u) > 0) (u, CoinHistory.spentOn(u))];
    final recent = CoinHistory.entries().take(50).toList();

    Widget stat(String label, String value, Color c) => Expanded(
          child: GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              FittedBox(child: Text(value, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900))),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.textDim, fontSize: 11)),
            ]),
          ),
        );

    Widget section(String title, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GlassCard(
              blur: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: rows),
            ),
          ]),
        );

    Widget row(String leading, String label, int amount) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 30, child: Text(leading, style: const TextStyle(fontSize: 18))),
            Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontSize: 14)),
            ),
            Text('${amount > 0 ? '+' : ''}$amount 🪙',
                style: TextStyle(
                    color: amount >= 0 ? Pal.success : Pal.danger, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        );

    String emojiFor(String? gameId, String source) {
      if (gameId != null) {
        final g = allGames.where((x) => x.id == gameId);
        if (g.isNotEmpty) return g.first.emoji ?? '🎮';
      }
      return const {'ad': '📺', 'daily': '🎁', 'quest': '📋', 'achievement': '🏅', 'invite': '🤝', 'skip': '⏭️', 'hint': '💡', 'undo': '↩️', 'extraLife': '❤️', 'theme': '🎨', 'adfree': '🚫', 'unlockLevel': '🔓'}[source] ??
          '🪙';
    }

    String when(DateTime t) =>
        '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return GameScaffold(
      title: tr('shop.history.title'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(children: [
            stat(tr('shop.history.balance'), '${Rewards.balance}', Pal.gold),
            const SizedBox(width: 8),
            stat(tr('shop.history.earned'), '${Rewards.earned}', Pal.success),
            const SizedBox(width: 8),
            stat(tr('shop.history.spent'), '${Rewards.spent}', Pal.danger),
            const SizedBox(width: 8),
            stat(tr('shop.history.ads'), '${AdsService.adsWatched}', Pal.text),
          ]),
          if (byGame.isNotEmpty)
            section(tr('shop.history.by_game'), [for (final (g, n) in byGame) row(g.emoji ?? '🎮', g.title, n)]),
          if (sources.isNotEmpty)
            section(tr('shop.history.by_source'),
                [for (final (s, n) in sources) row(emojiFor(null, s), _sourceLabel(s), n)]),
          if (uses.isNotEmpty)
            section(tr('shop.history.by_use'), [for (final (u, n) in uses) row(emojiFor(null, u), _sourceLabel(u), -n)]),
          section(tr('shop.history.recent'), [
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(tr('shop.history.empty'), style: const TextStyle(color: Pal.textDim)),
              ),
            for (final t in recent)
              row(emojiFor(t.gameId, t.source), '${_sourceLabel(t.gameId ?? t.source)}  •  ${when(t.time)}', t.amount),
          ]),
        ],
      ),
    );
  }
}
