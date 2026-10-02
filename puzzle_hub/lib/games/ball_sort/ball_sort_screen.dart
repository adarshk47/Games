import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  static const _info = <BsDifficulty, (String, String, Color, IconData)>{
    BsDifficulty.easy: ('3-5 colors', 'Relaxed start. Two spare tubes.', Color(0xFF4ADE80), Icons.spa_rounded),
    BsDifficulty.medium: ('6-9 colors', 'A proper sorting workout.', Color(0xFFFFB347), Icons.bolt_rounded),
    BsDifficulty.hard:
        ('10-14 colors', 'A rainbow of tubes. Shape markers help.', Color(0xFFFF6B8A), Icons.local_fire_department_rounded),
    BsDifficulty.extreme:
        ('15-20 colors', 'Only 1-2 spare tubes. Pure chaos.', Color(0xFFB66DFF), Icons.whatshot_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Ball Sort',
      tint: bsAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          const Text('Choose difficulty',
              textAlign: TextAlign.center,
              style: TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Each mode keeps its own levels and records.',
              textAlign: TextAlign.center, style: TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 18),
          for (final d in BsDifficulty.values) ...[
            _DiffCard(
              difficulty: d,
              title: _info[d]!.$1,
              subtitle: _info[d]!.$2,
              color: _info[d]!.$3,
              icon: _info[d]!.$4,
              last: d == _last,
              onTap: () => _open(d),
            ).animate().fadeIn(duration: 300.ms, delay: (80 * d.index).ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          Center(
            child: PremiumButton(
              label: 'Continue ${_last.label}',
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
    final unlocked = Storage.getInt(bsKey(difficulty, 'unlocked'), 1);
    final done = unlocked - 1;
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
              Text(difficulty.label,
                  style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: const Text('LAST', style: TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(done == 0 ? 'Not started' : '$done level${done == 1 ? '' : 's'} cleared',
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

  @override
  Widget build(BuildContext context) {
    final unlocked = Storage.getInt(bsKey(_d, 'unlocked'), 1);
    final current = Storage.getInt(bsKey(_d, 'level'), 1).clamp(1, unlocked);
    return GameScaffold(
      title: 'Ball Sort · ${_d.label}',
      tint: bsAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
              label: 'Play level $current',
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
            itemCount: unlocked + 9,
            itemBuilder: (_, i) {
              final lv = i + 1;
              return _LevelTile(
                level: lv,
                locked: lv > unlocked,
                stars: Storage.getInt(bsKey(_d, 'stars.$lv')),
                done: lv < unlocked,
                current: lv == current,
                onTap: () => _play(lv),
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
    required this.level,
    required this.locked,
    required this.done,
    required this.current,
    required this.stars,
    required this.onTap,
  });
  final int level, stars;
  final bool locked, done, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      alignment: Alignment.center,
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
        border: Border.all(color: current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
        boxShadow: locked
            ? null
            : [BoxShadow(color: bsAccent.withValues(alpha: current ? 0.55 : 0.2), blurRadius: current ? 16 : 8, spreadRadius: -2)],
      ),
      child: locked
          ? const Icon(Icons.lock_rounded, size: 18, color: Pal.textDim)
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$level',
                  style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
              if (done) StarRow(stars: stars, size: 12),
            ]),
    );
    return locked ? tile : Pressable(onTap: onTap, child: tile);
  }
}
