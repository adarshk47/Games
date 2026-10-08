import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/tile_match_logic.dart';
import 'progress.dart';
import 'tile_art.dart';
import 'tile_match_game.dart';

export 'tile_match_game.dart' show TileMatchGame;

/// Entry point: tier selection.
class TileMatchScreen extends StatefulWidget {
  const TileMatchScreen({super.key});

  @override
  State<TileMatchScreen> createState() => _TileMatchScreenState();
}

class _TileMatchScreenState extends State<TileMatchScreen> {
  late TmTier _last;

  @override
  void initState() {
    super.initState();
    _last = TmTier.fromId(Storage.getString(TmProgress.lastTierKey));
  }

  Future<void> _open(TmTier t) async {
    Storage.setString(TmProgress.lastTierKey, t.id);
    setState(() => _last = t);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TileMatchLevels(tier: t)));
    if (mounted) setState(() {});
  }

  static const _info = <TmTier, (Color, IconData)>{
    TmTier.easy: (Color(0xFF4ADE80), Icons.spa_rounded),
    TmTier.medium: (Color(0xFFFFB347), Icons.bolt_rounded),
    TmTier.hard: (Color(0xFFFF6B8A), Icons.local_fire_department_rounded),
    TmTier.extreme: (Color(0xFFB66DFF), Icons.whatshot_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('tile_match.title'),
      tint: tmAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.rotate(
                    angle: (i - 1.5) * 0.12,
                    child: TileView(icon: const [0, 3, 18, 15][i], size: 34),
                  )
                      .animate(delay: (120 * i).ms)
                      .scale(begin: const Offset(0, 0), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms)
                      .moveY(begin: -20, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('tile_match.choose'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('tile_match.choose_sub'),
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 12),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Pal.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('tile_match.how'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.35)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          for (final t in TmTier.values) ...[
            _TierCard(
              tier: t,
              color: _info[t]!.$1,
              icon: _info[t]!.$2,
              last: t == _last,
              onTap: () => _open(t),
            ).animate().fadeIn(duration: 300.ms, delay: (80 * t.index).ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          Center(
            child: PremiumButton(
              label: tr('tile_match.continue_tier', {'tier': tmTierName(_last)}),
              icon: Icons.play_arrow_rounded,
              color: tmAccentHot,
              onTap: () => _open(_last),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.color, required this.icon, required this.last, required this.onTap});
  final TmTier tier;
  final Color color;
  final IconData icon;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = tmSpec(tier);
    final done = TmProgress.completed(tier);
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
                child: Text(tmTierName(tier),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('tile_match.last'),
                      style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              tr('tile_match.tiles_range', {
                'range': '${spec.minTiles}-${spec.maxTiles}',
                'types': '${spec.minTypes}-${spec.maxTypes}',
              }),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            Text(tr('tile_match.desc.${tier.id}'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              done == 0 ? tr('tile_match.not_started') : tr('tile_match.cleared', {'n': done, 'total': kTmLevels}),
              style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ]),
    );
  }
}

/// Level grid for one tier (lazy).
class TileMatchLevels extends StatefulWidget {
  const TileMatchLevels({super.key, required this.tier});
  final TmTier tier;

  @override
  State<TileMatchLevels> createState() => _TileMatchLevelsState();
}

class _TileMatchLevelsState extends State<TileMatchLevels> {
  TmTier get _t => widget.tier;
  bool _buying = false;

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TileMatchGame(tier: _t, level: level)));
    if (mounted) setState(() {});
  }

  Future<void> _buy(int level) async {
    if (_buying) return;
    _buying = true;
    final ok = await LevelGate.buy(context, prefix: TmProgress.prefix(_t), freeUpTo: TmProgress.unlocked(_t), level: level);
    _buying = false;
    if (!mounted) return;
    setState(() {});
    if (ok) await _play(level);
  }

  @override
  Widget build(BuildContext context) {
    final current = TmProgress.current(_t);
    return GameScaffold(
      title: tr('tile_match.title_tier', {'tier': tmTierName(_t)}),
      tint: tmAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
            label: tr('tile_match.play_level', {'n': current}),
            icon: Icons.play_arrow_rounded,
            color: tmAccentHot,
            compact: true,
            onTap: () => _play(current),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: kTmLevels,
            itemBuilder: (_, i) {
              final lv = i + 1;
              final playable = TmProgress.canPlay(_t, lv);
              return _LevelTile(
                key: ValueKey('tm_level_$lv'),
                level: lv,
                locked: !playable,
                stars: TmProgress.stars(_t, lv),
                playsLeft: TmProgress.playsLeft(_t, lv),
                current: lv == current,
                onTap: () => playable ? _play(lv) : _buy(lv),
              ).animate().fadeIn(duration: 250.ms, delay: (12 * (i % 30)).ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
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
    required this.current,
    required this.stars,
    required this.playsLeft,
    required this.onTap,
  });
  final int level, stars, playsLeft;
  final bool locked, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const a = tmAccentHot;
    final tile = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: locked
            ? const LinearGradient(colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)])
            : current
                ? Pal.accent(a)
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [a.withValues(alpha: 0.28), a.withValues(alpha: 0.08)]),
        border: Border.all(color: current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
        boxShadow: locked
            ? null
            : [BoxShadow(color: a.withValues(alpha: current ? 0.55 : 0.2), blurRadius: current ? 16 : 8, spreadRadius: -2)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (locked) ...[
            const Icon(Icons.lock_rounded, size: 16, color: Pal.textDim),
            Text('$level', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 12)),
          ] else ...[
            Text('$level',
                style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
            if (stars > 0) StarRow(stars: stars, size: 12),
            if (playsLeft > 0)
              Text(tr('common.skip.plays_left', {'n': playsLeft}),
                  style: const TextStyle(color: Pal.gold, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
    return Pressable(onTap: onTap, child: tile);
  }
}
