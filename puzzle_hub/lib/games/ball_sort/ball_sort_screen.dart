import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'ball_sort_game.dart';
import 'logic/ball_sort_logic.dart';

const _kLastDiffKey = 'ball_sort.diff';

/// Entry point: difficulty selection.
class BallSortScreen extends StatefulWidget {
  const BallSortScreen({super.key});

  @override
  State<BallSortScreen> createState() => _BallSortScreenState();
}

class _BallSortScreenState extends State<BallSortScreen> {
  late BsDifficulty _last;

  @override
  void initState() {
    super.initState();
    _last = BsDifficulty.fromId(Storage.getString(_kLastDiffKey));
  }

  Future<void> _open(BsDifficulty d) async {
    Storage.setString(_kLastDiffKey, d.id);
    setState(() => _last = d);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _LevelGridScreen(difficulty: d)));
    if (mounted) setState(() {});
  }

  /// Color range, color and icon per difficulty; texts come from [tr].
  static const _info = <BsDifficulty, (String, Color, IconData)>{
    BsDifficulty.easy: ('3-5', Color(0xFF4ADE80), Icons.spa_rounded),
    BsDifficulty.medium: ('6-9', Color(0xFFFFB347), Icons.bolt_rounded),
    BsDifficulty.hard: ('10-14', Color(0xFFFF6B8A), Icons.local_fire_department_rounded),
    BsDifficulty.extreme: ('15-20', Color(0xFFB66DFF), Icons.whatshot_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('ball_sort.title'),
      tint: bsAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(tr('ball_sort.choose'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('ball_sort.choose_sub'),
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 18),
          for (final d in BsDifficulty.values) ...[
            _DiffCard(
              difficulty: d,
              title: tr('ball_sort.colors', {'range': _info[d]!.$1}),
              subtitle: tr('ball_sort.desc.${d.id}'),
              color: _info[d]!.$2,
              icon: _info[d]!.$3,
              last: d == _last,
              onTap: () => _open(d),
            ).animate().fadeIn(duration: 300.ms, delay: (80 * d.index).ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          Center(
            child: PremiumButton(
              label: tr('ball_sort.continue_tier', {'tier': bsTierName(_last)}),
              icon: Icons.play_arrow_rounded,
              color: bsAccent,
              onTap: () => _open(_last),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({
    required this.difficulty,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.last,
    required this.onTap,
  });
  final BsDifficulty difficulty;
  final String title, subtitle;
  final Color color;
  final IconData icon;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var cleared = 0;
    for (var l = 1; l <= kBsLevelCount; l++) {
      if (bsStars(difficulty, l) > 0) cleared++;
    }
    final done = math.max(math.min(bsUnlockedInSequence(difficulty), kBsLevelCount + 1) - 1, cleared);
    return GlassCard(
      onTap: onTap,
      glow: last ? color : null,
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
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(bsTierName(difficulty),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('ball_sort.last'), style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(done == 0 ? tr('ball_sort.not_started') : tr(done == 1 ? 'ball_sort.cleared_one' : 'ball_sort.cleared_n', {'n': done}),
                style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ]),
    );
  }
}

/// Level grid for one difficulty.
class _LevelGridScreen extends StatefulWidget {
  const _LevelGridScreen({required this.difficulty});
  final BsDifficulty difficulty;

  @override
  State<_LevelGridScreen> createState() => _LevelGridScreenState();
}

class _LevelGridScreenState extends State<_LevelGridScreen> {
  BsDifficulty get _d => widget.difficulty;

  Future<void> _play(int level) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => BallSortGame(difficulty: _d, level: level)));
    if (mounted) setState(() {});
  }

  bool _offerOpen = false;

  /// Tapping a locked level: skip ahead with coins (100 per skipped level, a
  /// limited number of plays), then open it.
  Future<void> _buy(int level) async {
    if (_offerOpen) return;
    _offerOpen = true;
    final ok = await bsEnsurePlayable(context, _d, level);
    _offerOpen = false;
    if (!mounted) return;
    setState(() {});
    if (ok) await _play(level);
  }

  @override
  Widget build(BuildContext context) {
    final free = bsFreeUpTo(_d);
    final current = Storage.getInt(bsKey(_d, 'level'), 1).clamp(1, free);
    return GameScaffold(
      title: tr('ball_sort.title_tier', {'tier': bsTierName(_d)}),
      tint: bsAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
              label: tr('ball_sort.play_level', {'n': current}),
              icon: Icons.play_arrow_rounded,
              color: bsAccent,
              compact: true,
              onTap: () => _play(current)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: kBsLevelCount,
            itemBuilder: (_, i) {
              final lv = i + 1;
              final unlocked = bsUnlocked(_d, lv);
              final plays = unlocked ? 0 : bsPlaysLeft(_d, lv);
              final stars = bsStars(_d, lv);
              return _LevelTile(
                key: ValueKey('bs-level-$lv'),
                level: lv,
                locked: !unlocked && plays == 0,
                playsLeft: plays,
                stars: stars,
                done: stars > 0 || lv < free,
                current: lv == current,
                onTap: () => _play(lv),
                onLockedTap: () => _buy(lv),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    super.key,
    required this.level,
    required this.locked,
    required this.done,
    required this.current,
    required this.stars,
    required this.onTap,
    required this.onLockedTap,
    this.playsLeft = 0,
  });
  final int level, stars;
  final bool locked, done, current;
  final VoidCallback onTap;

  /// Locked levels can be skipped to with coins.
  final VoidCallback onLockedTap;

  /// Plays left on a bought (skipped) level; 0 = not bought.
  final int playsLeft;

  @override
  Widget build(BuildContext context) {
    final bought = playsLeft > 0;
    final tile = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: locked
            ? const LinearGradient(colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)])
            : current
                ? Pal.accent(bsAccent)
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bsAccent.withValues(alpha: 0.28), bsAccent.withValues(alpha: 0.08)]),
        border: Border.all(
            color: bought ? Pal.gold : (current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
            width: bought ? 1.5 : 1),
        boxShadow: locked
            ? null
            : [BoxShadow(color: bsAccent.withValues(alpha: current ? 0.55 : 0.2), blurRadius: current ? 16 : 8, spreadRadius: -2)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: locked
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, size: 18, color: Pal.textDim),
                Text('$level', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 11)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (bought)
                  Text(tr('ball_sort.bought'),
                      style: const TextStyle(color: Pal.gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text('$level',
                    style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
                if (bought)
                  Text(tr('common.skip.plays_left', {'n': playsLeft}),
                      style: const TextStyle(color: Pal.gold, fontSize: 10, fontWeight: FontWeight.w800))
                else if (done)
                  StarRow(stars: stars, size: 12),
              ]),
      ),
    );
    return Pressable(onTap: locked ? onLockedTap : onTap, child: tile);
  }
}
