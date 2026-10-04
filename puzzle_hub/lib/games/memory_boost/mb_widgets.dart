import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mb_tiers.dart';

const Color mbTint = Color(0xFFB794FF);

enum DialogChoice { menu, extra, retry }

/// Shows a premium result dialog and returns the user's choice.
Future<DialogChoice> showResultDialog(
  BuildContext context, {
  required String title,
  String? message,
  String emoji = '🧠',
  int? stars,
  Color color = Pal.gold,
  String? retryLabel,
  String? extraLabel,
}) async {
  final done = Completer<DialogChoice>();
  void finish(DialogChoice c) {
    if (!done.isCompleted) done.complete(c);
  }

  await showPremiumDialog(
    context,
    title: title,
    message: message,
    emoji: emoji,
    stars: stars,
    color: color,
    actions: [
      DialogAction(tr('common.back'), () => finish(DialogChoice.menu)),
      if (extraLabel != null) DialogAction(extraLabel, () => finish(DialogChoice.extra)),
      DialogAction(retryLabel ?? tr('common.try_again'), () => finish(DialogChoice.retry), primary: true),
    ],
  );
  finish(DialogChoice.menu);
  return done.future;
}

/// Glass HUD pill (icon + text).
class StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const StatChip(this.icon, this.text, {super.key, this.color = mbTint});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 0,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
            child: Text(text,
                key: ValueKey(text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ),
      ]),
    );
  }
}

String fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

const _tierColors = {
  Tier.easy: Color(0xFF2EE6A8),
  Tier.medium: Color(0xFF4DA8FF),
  Tier.hard: Color(0xFFFFB347),
  Tier.extreme: Color(0xFFFF4D6D),
};
const _tierIcons = {
  Tier.easy: Icons.spa_rounded,
  Tier.medium: Icons.bolt_rounded,
  Tier.hard: Icons.local_fire_department_rounded,
  Tier.extreme: Icons.whatshot_rounded,
};

Color tierColor(Tier t) => _tierColors[t]!;

/// Localized tier name (Easy / Medium / Hard / Extreme).
String tierName(Tier t) => tr('common.tier.${t.key}');

/// Last tier the player picked for [game] (defaults to Medium).
Tier lastTier(String game) => Tier.fromIndex(Storage.getInt(tierPrefKey(game), Tier.medium.index));

void saveTier(String game, Tier t) => Storage.setInt(tierPrefKey(game), t.index);

/// Premium Easy / Medium / Hard / Extreme chooser.
class TierChooser extends StatelessWidget {
  final String game;
  final String heading;
  final Map<Tier, String> descriptions;
  final String Function(Tier) bestText;
  final ValueChanged<Tier> onSelect;
  const TierChooser({
    super.key,
    required this.game,
    required this.heading,
    required this.descriptions,
    required this.bestText,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final last = lastTier(game);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4),
          child: Text(heading, style: const TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4)),
        ),
        for (var i = 0; i < Tier.values.length; i++)
          _card(Tier.values[i], Tier.values[i] == last).animate(delay: (80 * i).ms).fadeIn(duration: 350.ms).slideX(
              begin: 0.15, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _card(Tier t, bool isLast) {
    final c = tierColor(t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        blur: 0,
        radius: 24,
        glow: isLast ? c : null,
        padding: const EdgeInsets.all(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0.05)],
        ),
        onTap: () {
          AppAudio.play(Sound.tap);
          saveTier(game, t);
          onSelect(t);
        },
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Pal.accent(c),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 14)],
            ),
            child: Icon(_tierIcons[t], color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(tierName(t),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.text, fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                if (isLast) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tr('memory_boost.last'), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(descriptions[t] ?? '', style: const TextStyle(color: Pal.textDim, fontSize: 13, height: 1.3)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 14, color: Pal.gold),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(bestText(t),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Pal.textDim, size: 26),
        ]),
      ),
    );
  }
}
