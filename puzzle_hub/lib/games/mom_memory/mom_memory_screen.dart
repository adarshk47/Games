import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/ads/ads_service.dart';
import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'balloon_colors_game.dart';
import 'breathe_game.dart';
import 'lullaby_game.dart';
import 'mm_common.dart';
import 'story_recall_game.dart';

class MomMemoryScreen extends StatefulWidget {
  const MomMemoryScreen({super.key});
  @override
  State<MomMemoryScreen> createState() => _MomMemoryScreenState();
}

class _MomMemoryScreenState extends State<MomMemoryScreen> {
  @override
  void initState() {
    super.initState();
    AdsService.suppress(); // no ads anywhere in the pregnancy section
    AppAudio.setMusic(MusicTrack.calm);
  }

  @override
  void dispose() {
    AdsService.unsuppress();
    AppAudio.setMusic(MusicTrack.main);
    super.dispose();
  }

  Future<void> _open(Widget game) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => game,
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) setState(() {});
  }

  String _lvl(String k) {
    final l = Storage.getInt('mom.$k.level');
    return l == 0 && Storage.getInt('mom.$k.stars.0') == 0
        ? tr('mom_memory.start_now')
        : tr('common.level_n', {'n': l + 1});
  }

  @override
  Widget build(BuildContext context) {
    final streak = currentStreak();
    final lul = Storage.getInt('mom.lullaby.best');
    final br = Storage.getInt('mom.breath.sessions');
    final cards = [
      _Hero(
        '🎈',
        tr('mom_memory.balloon_title'),
        tr('mom_memory.balloon_sub'),
        _lvl('balloon'),
        Mm.sky,
        () => _open(const BalloonColorsGame()),
      ),
      _Hero(
        '🌙',
        tr('mom_memory.lullaby_title'),
        tr('mom_memory.lullaby_sub'),
        lul == 0
            ? tr('mom_memory.start_now')
            : tr('mom_memory.lullaby_longest', {'n': lul}),
        Mm.peach,
        () => _open(const LullabyGame()),
      ),
      _Hero(
        '🌬️',
        tr('mom_memory.breathe_title'),
        tr('mom_memory.breathe_sub'),
        br == 0
            ? tr('mom_memory.start_now')
            : tr('mom_memory.breath_stats', {
                'n': br,
                'm': Storage.getInt('mom.breath.minutes'),
              }),
        Mm.mint,
        () => _open(const BreatheGame()),
      ),
      _Hero(
        '📖',
        tr('mom_memory.story_title'),
        tr('mom_memory.story_sub'),
        Storage.getInt('mom.story.played') == 0
            ? tr('mom_memory.start_now')
            : tr('mom_memory.story_stats', {
                'n': Storage.getInt('mom.story.best'),
                'played': Storage.getInt('mom.story.played'),
              }),
        Mm.lavender,
        () => _open(const StoryRecallGame()),
      ),
    ];
    return MmPage(
      title: tr('mom_memory.title'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          GlassCard(
            blur: 0,
            radius: 24,
            glow: Mm.rose,
            gradient: LinearGradient(
              colors: [
                Mm.rose.withValues(alpha: 0.28),
                Mm.lavender.withValues(alpha: 0.16),
              ],
            ),
            child: Row(
              children: [
                const Text('🌸', style: TextStyle(fontSize: 38))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.08, 1.08),
                      duration: 2200.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('mom_memory.greeting'),
                        style: const TextStyle(
                          color: Pal.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        streak > 0
                            ? tr('mom_memory.streak', {'n': streak})
                            : tr('mom_memory.no_streak'),
                        style: const TextStyle(
                          color: Pal.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 14),
          for (var i = 0; i < cards.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: cards[i]
                  .build()
                  .animate(delay: (120 + i * 110).ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
            ),
          const MmFootnote(),
        ],
      ),
    );
  }
}

class _Hero {
  _Hero(this.emoji, this.title, this.sub, this.best, this.color, this.onTap);
  final String emoji, title, sub, best;
  final Color color;
  final VoidCallback onTap;

  Widget build() => GlassCard(
    blur: 0,
    radius: 26,
    padding: const EdgeInsets.all(18),
    onTap: onTap,
    glow: color,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.08)],
    ),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white30),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Pal.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(color: Pal.textDim, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                best,
                style: TextStyle(
                  color: Color.lerp(color, Colors.white, 0.4),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ],
    ),
  );
}
