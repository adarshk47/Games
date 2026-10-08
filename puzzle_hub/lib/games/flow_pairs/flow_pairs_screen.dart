import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import 'flow_game_page.dart';
import 'logic/flow_logic.dart';
import 'progress.dart';

Route<void> _fadeRoute(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

const _tierColors = {
  FlowTier.easy: Color(0xFF4ADE80),
  FlowTier.medium: Color(0xFF38BDF8),
  FlowTier.hard: Color(0xFFFF9F43),
  FlowTier.extreme: Color(0xFFFF4D6D),
};

const _tierIcons = {
  FlowTier.easy: Icons.spa_rounded,
  FlowTier.medium: Icons.bolt_rounded,
  FlowTier.hard: Icons.whatshot_rounded,
  FlowTier.extreme: Icons.local_fire_department_rounded,
};

/// Flow / Connect Pairs entry: difficulty selection.
class FlowPairsScreen extends StatefulWidget {
  const FlowPairsScreen({super.key});

  @override
  State<FlowPairsScreen> createState() => _FlowPairsScreenState();
}

class _FlowPairsScreenState extends State<FlowPairsScreen> {
  Future<void> _open(FlowTier tier) async {
    AppAudio.play(Sound.tap);
    await FlowProgress.setLastTier(tier);
    if (!mounted) return;
    setState(() {});
    await Navigator.of(context).push(_fadeRoute(FlowLevelsPage(tier: tier)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final last = FlowProgress.lastTier;
    return GameScaffold(
      title: tr('flow_pairs.title'),
      tint: flowTint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(tr('flow_pairs.choose'), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(tr('flow_pairs.subtitle'),
                style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          for (final (i, t) in FlowTier.values.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TierCard(tier: t, last: t == last, onTap: () => _open(t))
                  .animate(delay: (80 * i).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0),
            ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.last, required this.onTap});
  final FlowTier tier;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _tierColors[tier]!;
    final done = FlowProgress.doneCount(tier);
    final stars = FlowProgress.totalStars(tier);
    return GlassCard(
      onTap: onTap,
      blur: 0,
      glow: last ? color : null,
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.06)],
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: Pal.accent(color)),
          child: Icon(_tierIcons[tier], color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(flowTierLabel(tier), style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('${tier.sizeLabel}${tier.requireFill ? '  -  ${tr('flow_pairs.fill_all')}' : ''}',
                style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done / FlowLevels.count,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(tr('flow_pairs.progress', {'done': done, 'total': FlowLevels.count, 'stars': stars, 'max': FlowLevels.count * 3}),
                style: const TextStyle(color: Pal.textDim, fontSize: 12)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ]),
    );
  }
}

/// 100-level grid with locks, stars and skip-ahead.
class FlowLevelsPage extends StatefulWidget {
  const FlowLevelsPage({super.key, required this.tier});
  final FlowTier tier;

  @override
  State<FlowLevelsPage> createState() => _FlowLevelsPageState();
}

class _FlowLevelsPageState extends State<FlowLevelsPage> {
  bool _buying = false;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  Future<void> _play(int level) async {
    if (!FlowProgress.canPlay(widget.tier, level)) return _buy(level);
    await Navigator.of(context).push(_fadeRoute(FlowGamePage(tier: widget.tier, level: level)));
    if (mounted) setState(() {});
  }

  /// Skip ahead: any locked level can be bought (100 coins per skipped level).
  Future<void> _buy(int level) async {
    if (_buying) return;
    _buying = true;
    final t = widget.tier;
    final ok = await LevelGate.buy(context, prefix: FlowProgress.gate(t), freeUpTo: FlowProgress.freeUpTo(t, level), level: level);
    _buying = false;
    if (!mounted) return;
    setState(() {});
    if (ok && FlowProgress.canPlay(t, level)) {
      await _play(level);
    } else if (!ok) {
      AppAudio.play(Sound.fail, volume: 0.4);
    }
  }

  /// Starts the grid scrolled so the next level to play is in view.
  ScrollController _controllerFor(double width) {
    if (_scroll != null) return _scroll!;
    const cols = 4, gap = 12.0;
    final tileW = (width - 32 - gap * (cols - 1)) / cols;
    final rowH = tileW / 0.82 + gap;
    final row = (FlowProgress.frontier(widget.tier) - 1) ~/ cols;
    return _scroll = ScrollController(initialScrollOffset: row <= 1 ? 0 : (row - 1) * rowH);
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final color = _tierColors[tier]!;
    return GameScaffold(
      title: tr('flow_pairs.tier_levels', {'tier': flowTierLabel(tier)}),
      tint: flowTint,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: Pal.gold, size: 20),
            const SizedBox(width: 6),
            Text('${FlowProgress.totalStars(tier)}/${FlowLevels.count * 3}',
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(tier.sizeLabel, style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => GridView.builder(
              controller: _controllerFor(c.maxWidth),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
              itemCount: FlowLevels.count,
              itemBuilder: (_, i) {
                final level = i + 1;
                final left = FlowProgress.playsLeft(tier, level);
                final bought = left > 0;
                final unlocked = FlowProgress.isFree(tier, level) || bought;
                final done = FlowProgress.isDone(tier, level);
                return GlassCard(
                  key: ValueKey('flow_level_$level'),
                  blur: 0,
                  radius: 18,
                  padding: const EdgeInsets.all(6),
                  onTap: () => _play(level),
                  glow: bought ? Pal.gold : null,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: unlocked
                        ? [color.withValues(alpha: done ? 0.35 : 0.22), color.withValues(alpha: 0.06)]
                        : const [Color(0x14FFFFFF), Color(0x08FFFFFF)],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (bought)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Pal.gold, borderRadius: BorderRadius.circular(8)),
                          child: Text(tr('flow_pairs.bought'),
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      if (unlocked)
                        Text('$level', style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900))
                      else
                        const Icon(Icons.lock_rounded, color: Pal.textDim, size: 22),
                      const SizedBox(height: 4),
                      if (bought)
                        Text(tr('common.skip.plays_left', {'n': left}),
                            style: const TextStyle(color: Pal.gold, fontSize: 11, fontWeight: FontWeight.w700))
                      else if (unlocked)
                        StarRow(stars: FlowProgress.stars(tier, level), size: 13),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
