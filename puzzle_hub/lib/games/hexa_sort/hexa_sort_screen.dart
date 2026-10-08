import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'hexa_art.dart';
import 'hexa_sort_game.dart';
import 'logic/hexa_sort_logic.dart';
import 'progress.dart';

export 'hexa_sort_game.dart' show HexaSortGame;

/// Entry point: tier selection.
class HexaSortScreen extends StatefulWidget {
  const HexaSortScreen({super.key});

  @override
  State<HexaSortScreen> createState() => _HexaSortScreenState();
}

class _HexaSortScreenState extends State<HexaSortScreen> {
  late HsTier _last;

  @override
  void initState() {
    super.initState();
    _last = HsTier.fromId(Storage.getString(HsProgress.lastTierKey));
  }

  Future<void> _open(HsTier t) async {
    Storage.setString(HsProgress.lastTierKey, t.id);
    setState(() => _last = t);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HexaSortLevels(tier: t)));
    if (mounted) setState(() {});
  }

  static const _info = <HsTier, (Color, IconData)>{
    HsTier.easy: (Color(0xFF4ADE80), Icons.spa_rounded),
    HsTier.medium: (Color(0xFFFFB347), Icons.bolt_rounded),
    HsTier.hard: (Color(0xFFFF6B8A), Icons.local_fire_department_rounded),
    HsTier.extreme: (Color(0xFFB66DFF), Icons.whatshot_rounded),
  };

  static const _deco = [
    [0, 0, 1, 1, 1],
    [3, 2, 2],
    [4, 4, 0, 0],
    [5, 7, 7, 7, 7],
  ];

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('hexa_sort.title'),
      tint: hsAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _deco.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: HexStackIcon(tiles: _deco[i], size: 40)
                      .animate(delay: (120 * i).ms)
                      .moveY(begin: -40, end: 0, curve: Curves.bounceOut, duration: 700.ms)
                      .fadeIn(duration: 200.ms),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('hexa_sort.choose'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('hexa_sort.choose_sub'),
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 12),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Pal.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('hexa_sort.how'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.35)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          for (final t in HsTier.values) ...[
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
              label: tr('hexa_sort.continue_tier', {'tier': hsTierName(_last)}),
              icon: Icons.play_arrow_rounded,
              color: hsAccentHot,
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
  final HsTier tier;
  final Color color;
  final IconData icon;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = hsSpec(tier);
    final done = HsProgress.completed(tier);
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
                child: Text(hsTierName(tier),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('hexa_sort.last'),
                      style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              tr('hexa_sort.board_info', {'cells': spec.cells, 'colors': '${spec.minColors}-${spec.maxColors}'}),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            Text(tr('hexa_sort.desc.${tier.id}'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              done == 0 ? tr('hexa_sort.not_started') : tr('hexa_sort.cleared', {'n': done, 'total': kHsLevels}),
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
class HexaSortLevels extends StatefulWidget {
  const HexaSortLevels({super.key, required this.tier});
  final HsTier tier;

  @override
  State<HexaSortLevels> createState() => _HexaSortLevelsState();
}

class _HexaSortLevelsState extends State<HexaSortLevels> {
  HsTier get _t => widget.tier;
  bool _buying = false;

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HexaSortGame(tier: _t, level: level)));
    if (mounted) setState(() {});
  }

  Future<void> _skipTo(int level) async {
    if (_buying) return;
    _buying = true;
    final bought = await LevelGate.buy(context,
        prefix: HsProgress.prefix(_t), freeUpTo: HsProgress.unlocked(_t), level: level);
    _buying = false;
    if (!mounted || !bought) return;
    setState(() {});
    await _play(level);
  }

  @override
  Widget build(BuildContext context) {
    final current = HsProgress.current(_t);
    return GameScaffold(
      title: tr('hexa_sort.title_tier', {'tier': hsTierName(_t)}),
      tint: hsAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
            label: tr('hexa_sort.play_level', {'n': current}),
            icon: Icons.play_arrow_rounded,
            color: hsAccentHot,
            compact: true,
            onTap: () => _play(current),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: kHsLevels,
            itemBuilder: (_, i) {
              final lv = i + 1;
              final open = HsProgress.canPlay(_t, lv);
              return _LevelTile(
                key: ValueKey('hs_level_$lv'),
                level: lv,
                locked: !open,
                stars: HsProgress.stars(_t, lv),
                plays: HsProgress.isDone(_t, lv) ? 0 : HsProgress.playsLeft(_t, lv),
                current: lv == current,
                onTap: open ? () => _play(lv) : () => _skipTo(lv),
              ).animate().fadeIn(duration: 250.ms, delay: (10 * (i % 30)).ms).scale(
                  begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
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
    required this.plays,
    required this.onTap,
  });
  final int level, stars, plays;
  final bool locked, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const a = hsAccentHot;
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
            if (plays > 0)
              Text(tr('common.skip.plays_left', {'n': plays}),
                  style: const TextStyle(color: Pal.gold, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
    return Pressable(onTap: onTap, child: tile);
  }
}
