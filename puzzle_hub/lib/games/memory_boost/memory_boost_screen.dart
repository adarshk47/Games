import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'card_match_game.dart';
import 'logic/mb_tiers.dart';
import 'mb_widgets.dart';
import 'number_memory_game.dart';
import 'simon_game.dart';

class MemoryBoostScreen extends StatefulWidget {
  const MemoryBoostScreen({super.key});
  @override
  State<MemoryBoostScreen> createState() => _MemoryBoostScreenState();
}

class _MemoryBoostScreenState extends State<MemoryBoostScreen> {
  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {}); // refresh best scores
  }

  @override
  Widget build(BuildContext context) {
    var cardStars = 0, cardMax = 0, simonBest = 0, numBest = 0;
    for (final t in Tier.values) {
      final n = cardTierParams[t]!.levels.length;
      cardMax += n * 3;
      for (var i = 0; i < n; i++) {
        cardStars += Storage.getInt(cardStarsKey(t, i));
      }
      simonBest = simonBest > Storage.getInt(simonBestKeyFor(t)) ? simonBest : Storage.getInt(simonBestKeyFor(t));
      numBest = numBest > Storage.getInt(numberBestKeyFor(t)) ? numBest : Storage.getInt(numberBestKeyFor(t));
    }
    final cards = <_Hero>[
      _Hero(Icons.grid_view_rounded, Pal.accents[4], tr('memory_boost.card.title'), tr('memory_boost.card.sub'),
          tr('memory_boost.card.stars', {'n': cardStars, 'max': cardMax}), () => _open(const CardMatchScreen())),
      _Hero(Icons.lightbulb_rounded, Pal.accents[1], tr('memory_boost.simon.title'), tr('memory_boost.simon.sub'),
          tr('memory_boost.simon.best_streak', {'n': simonBest}), () => _open(const SimonScreen())),
      _Hero(Icons.pin_rounded, Pal.accents[3], tr('memory_boost.number.title'), tr('memory_boost.number.sub'),
          tr('memory_boost.number.best_round', {'n': numBest}), () => _open(const NumberMemoryScreen())),
    ];
    return GameScaffold(
      title: tr('memory_boost.title'),
      tint: mbTint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < cards.length; i++)
            _heroCard(cards[i])
                .animate(delay: (120 * i).ms)
                .fadeIn(duration: 420.ms)
                .slideY(begin: 0.25, end: 0, duration: 520.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _heroCard(_Hero h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassCard(
        blur: 0,
        radius: 28,
        glow: h.color,
        padding: const EdgeInsets.all(20),
        onTap: h.onTap,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [h.color.withValues(alpha: 0.34), h.color.withValues(alpha: 0.06)],
        ),
        child: Row(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: Pal.accent(h.color),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: h.color.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: -2)],
            ),
            child: Icon(h.icon, color: Colors.white, size: 38),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1600.ms, curve: Curves.easeInOut),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.title, style: const TextStyle(color: Pal.text, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(h.sub, style: const TextStyle(color: Pal.textDim, fontSize: 13, height: 1.3)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: h.color.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events_rounded, size: 14, color: Pal.gold),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(h.best,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Pal.textDim, size: 28),
        ]),
      ),
    );
  }
}

class _Hero {
  final IconData icon;
  final Color color;
  final String title, sub, best;
  final VoidCallback onTap;
  _Hero(this.icon, this.color, this.title, this.sub, this.best, this.onTap);
}
