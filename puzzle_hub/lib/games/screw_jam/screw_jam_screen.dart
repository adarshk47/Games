import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/screw_jam_logic.dart';
import 'progress.dart';
import 'screw_art.dart';
import 'screw_jam_game.dart';

export 'screw_jam_game.dart' show ScrewJamGame;

/// Entry point: tier selection.
class ScrewJamScreen extends StatefulWidget {
  const ScrewJamScreen({super.key});

  @override
  State<ScrewJamScreen> createState() => _ScrewJamScreenState();
}

class _ScrewJamScreenState extends State<ScrewJamScreen> {
  late SjTier _last;

  @override
  void initState() {
    super.initState();
    _last = SjTier.fromId(Storage.getString(SjProgress.lastTierKey));
  }

  Future<void> _open(SjTier t) async {
    Storage.setString(SjProgress.lastTierKey, t.id);
    setState(() => _last = t);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScrewJamLevels(tier: t)));
    if (mounted) setState(() {});
  }

  static const _info = <SjTier, (Color, IconData)>{
    SjTier.easy: (Color(0xFF4ADE80), Icons.spa_rounded),
    SjTier.medium: (Color(0xFFFFB347), Icons.bolt_rounded),
    SjTier.hard: (Color(0xFFFF6B8A), Icons.local_fire_department_rounded),
    SjTier.extreme: (Color(0xFFB66DFF), Icons.whatshot_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('screw_jam.title'),
      tint: sjAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ScrewIcon(color: sjColor(i), size: 26, angle: i * 0.6)
                      .animate(delay: (120 * i).ms)
                      .scale(begin: const Offset(0, 0), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms)
                      .rotate(begin: -0.5, end: 0, duration: 700.ms),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('screw_jam.choose'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('screw_jam.choose_sub'),
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 12),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Pal.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('screw_jam.how'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.35)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          for (final t in SjTier.values) ...[
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
              label: tr('screw_jam.continue_tier', {'tier': sjTierName(_last)}),
              icon: Icons.play_arrow_rounded,
              color: sjAccentHot,
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
  final SjTier tier;
  final Color color;
  final IconData icon;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = sjSpec(tier);
    final done = SjProgress.completed(tier);
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
                child: Text(sjTierName(tier),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('screw_jam.last'),
                      style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              tr('screw_jam.plates_range', {'range': '${spec.minPlates}-${spec.maxPlates}', 'tray': spec.tray}),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            Text(tr('screw_jam.desc.${tier.id}'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              done == 0 ? tr('screw_jam.not_started') : tr('screw_jam.cleared', {'n': done, 'total': kSjLevels}),
              style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ]),
    );
  }
}

/// Level grid for one tier.
class ScrewJamLevels extends StatefulWidget {
  const ScrewJamLevels({super.key, required this.tier});
  final SjTier tier;

  @override
  State<ScrewJamLevels> createState() => _ScrewJamLevelsState();
}

class _ScrewJamLevelsState extends State<ScrewJamLevels> {
  SjTier get _t => widget.tier;
  bool _buying = false;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  Future<void> _play(int level) async {
    if (!SjProgress.canPlay(_t, level)) return _buy(level);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScrewJamGame(tier: _t, level: level)));
    if (mounted) setState(() {});
  }

  /// Skip ahead: any locked level can be bought (100 coins per skipped level).
  Future<void> _buy(int level) async {
    if (_buying) return;
    _buying = true;
    final ok = await LevelGate.buy(context, prefix: SjProgress.gate(_t), freeUpTo: SjProgress.freeUpTo(_t, level), level: level);
    _buying = false;
    if (!mounted) return;
    setState(() {});
    if (ok && SjProgress.canPlay(_t, level)) await _play(level);
  }

  /// Starts the grid scrolled so the current level is in view.
  ScrollController _controllerFor(double width, int current) {
    if (_scroll != null) return _scroll!;
    const gap = 12.0, pad = 18.0, extent = 80.0;
    final inner = width - pad * 2;
    final cols = ((inner + gap) / (extent + gap)).ceil().clamp(1, 100);
    final tile = (inner - gap * (cols - 1)) / cols;
    final row = (current - 1) ~/ cols;
    return _scroll = ScrollController(initialScrollOffset: row <= 1 ? 0 : (row - 1) * (tile + gap));
  }

  @override
  Widget build(BuildContext context) {
    final current = SjProgress.current(_t);
    return GameScaffold(
      title: tr('screw_jam.title_tier', {'tier': sjTierName(_t)}),
      tint: sjAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
            label: tr('screw_jam.play_level', {'n': current}),
            icon: Icons.play_arrow_rounded,
            color: sjAccentHot,
            compact: true,
            onTap: () => _play(current),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => GridView.builder(
              controller: _controllerFor(c.maxWidth, current),
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 80, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: kSjLevels,
              itemBuilder: (_, i) {
                final lv = i + 1;
                final free = SjProgress.isFree(_t, lv);
                final left = SjProgress.playsLeft(_t, lv);
                final tile = _LevelTile(
                  key: ValueKey('sj_level_$lv'),
                  level: lv,
                  locked: !free && left == 0,
                  playsLeft: left,
                  stars: SjProgress.stars(_t, lv),
                  current: lv == current,
                  onTap: () => _play(lv),
                );
                // Only the first screenful animates in; later tiles appear
                // instantly so scrolling 100 levels stays smooth.
                return i < 24
                    ? tile.animate().fadeIn(duration: 250.ms, delay: (12 * i).ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1))
                    : tile;
              },
            ),
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
    required this.playsLeft,
    required this.current,
    required this.stars,
    required this.onTap,
  });
  final int level, stars, playsLeft;
  final bool locked, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const a = sjAccentHot;
    final bought = playsLeft > 0;
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
        border: Border.all(
            color: bought ? Pal.gold : (current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
            width: bought ? 1.5 : 1),
        boxShadow: locked
            ? null
            : [BoxShadow(color: a.withValues(alpha: current ? 0.55 : 0.2), blurRadius: current ? 16 : 8, spreadRadius: -2)],
      ),
      child: locked
          ? _LockedLevelLabel(level: level)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (bought)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Pal.gold, borderRadius: BorderRadius.circular(8)),
                    child: Text(tr('screw_jam.bought'),
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                Text('$level',
                    style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
                if (bought)
                  Text(tr('common.skip.plays_left', {'n': playsLeft}),
                      style: const TextStyle(color: Pal.gold, fontSize: 10, fontWeight: FontWeight.w700))
                else if (stars > 0)
                  StarRow(stars: stars, size: 12),
              ]),
            ),
    );
    return Pressable(onTap: onTap, child: tile);
  }
}

/// Locked tile content: the level number stays readable (dimmed), with a
/// small lock badge in the corner.
class _LockedLevelLabel extends StatelessWidget {
  const _LockedLevelLabel({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$level',
              style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
      ),
      const Positioned(
        top: 2,
        right: 2,
        child: Icon(Icons.lock_rounded, size: 12, color: Pal.textDim),
      ),
    ]);
  }
}
