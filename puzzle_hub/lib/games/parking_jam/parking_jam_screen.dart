import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/parking_logic.dart';
import 'parking_jam_game.dart';
import 'parking_painters.dart';

const _kLastTierKey = 'parking_jam.tier';

/// Entry point: tier selection.
class ParkingJamScreen extends StatefulWidget {
  const ParkingJamScreen({super.key});

  @override
  State<ParkingJamScreen> createState() => _ParkingJamScreenState();
}

class _ParkingJamScreenState extends State<ParkingJamScreen> {
  late PjTier _last;

  @override
  void initState() {
    super.initState();
    _last = PjTier.fromId(Storage.getString(_kLastTierKey));
  }

  Future<void> _open(PjTier t) async {
    Storage.setString(_kLastTierKey, t.id);
    setState(() => _last = t);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PjLevelGridScreen(tier: t)));
    if (mounted) setState(() {});
  }

  /// Lot sizes, color, icon and preview car color per tier.
  static const _info = <PjTier, (String, Color, IconData, int)>{
    PjTier.easy: ('6×6', Color(0xFF4ADE80), Icons.directions_car_rounded, 2),
    PjTier.medium: ('7×7', Color(0xFFFFB347), Icons.local_shipping_rounded, 3),
    PjTier.hard: ('8×8 – 9×9', Color(0xFFFF6B8A), Icons.airport_shuttle_rounded, 0),
    PjTier.extreme: ('9×9 – 10×10', Color(0xFFB66DFF), Icons.directions_bus_rounded, 4),
  };

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('parking_jam.title'),
      tint: pjAccent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(tr('parking_jam.choose'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('parking_jam.choose_sub'),
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          const SizedBox(height: 18),
          for (final t in PjTier.values) ...[
            _TierCard(
              tier: t,
              title: tr('parking_jam.lot', {'size': _info[t]!.$1}),
              subtitle: tr('parking_jam.desc.${t.id}'),
              color: _info[t]!.$2,
              icon: _info[t]!.$3,
              carColor: _info[t]!.$4,
              last: t == _last,
              onTap: () => _open(t),
            ).animate().fadeIn(duration: 300.ms, delay: (80 * t.index).ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          Center(
            child: PremiumButton(
              label: tr('parking_jam.continue_tier', {'tier': pjTierName(_last)}),
              icon: Icons.play_arrow_rounded,
              color: pjAccent,
              onTap: () => _open(_last),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.carColor,
    required this.last,
    required this.onTap,
  });
  final PjTier tier;
  final String title, subtitle;
  final Color color;
  final IconData icon;
  final int carColor;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = Storage.getInt(pjKey(tier, 'unlocked'), 1);
    final done = (unlocked - 1).clamp(0, kPjLevels);
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
          alignment: Alignment.center,
          child: SizedBox(
            width: 44,
            height: 24,
            child: RotatedBox(
              quarterTurns: 1,
              child: CustomPaint(
                painter: VehiclePainter(
                    color: pjCarColors[carColor], length: tier == PjTier.easy ? 2 : 3, variant: tier.index),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(pjTierName(tier),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (last) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('parking_jam.last'),
                      style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14))),
            ]),
            Text(subtitle, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
                done == 0
                    ? tr('parking_jam.not_started')
                    : tr('parking_jam.cleared', {'n': done, 'total': kPjLevels}),
                style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
      ]),
    );
  }
}

/// Level grid (30 levels) for one tier, with locks and stars.
class PjLevelGridScreen extends StatefulWidget {
  const PjLevelGridScreen({super.key, required this.tier});
  final PjTier tier;

  @override
  State<PjLevelGridScreen> createState() => _PjLevelGridScreenState();
}

class _PjLevelGridScreenState extends State<PjLevelGridScreen> {
  PjTier get _t => widget.tier;
  bool _offerOpen = false;

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ParkingJamGame(tier: _t, level: level)));
    if (mounted) setState(() {});
  }

  /// Buy the next locked level (coins / ad), persist it and open it.
  Future<void> _unlockNext(int level) async {
    final unlocked = Storage.getInt(pjKey(_t, 'unlocked'), 1);
    if (level != unlocked + 1 || level > kPjLevels || _offerOpen) return;
    _offerOpen = true;
    final paid = await showContinueOffer(context, OfferKind.unlockLevel);
    _offerOpen = false;
    if (!mounted || !paid) return;
    if (Storage.getInt(pjKey(_t, 'unlocked'), 1) < level) {
      await Storage.setInt(pjKey(_t, 'unlocked'), level);
    }
    if (!mounted) return;
    setState(() {});
    await _play(level);
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = Storage.getInt(pjKey(_t, 'unlocked'), 1);
    final maxPlayable = unlocked.clamp(1, kPjLevels);
    final current = Storage.getInt(pjKey(_t, 'level'), 1).clamp(1, maxPlayable);
    return GameScaffold(
      title: tr('parking_jam.title_tier', {'tier': pjTierName(_t)}),
      tint: pjAccent,
      body: Column(children: [
        const SizedBox(height: 8),
        Center(
          child: PremiumButton(
            label: tr('parking_jam.play_level', {'n': current}),
            icon: Icons.play_arrow_rounded,
            color: pjAccent,
            compact: true,
            onTap: () => _play(current),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 80, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: kPjLevels,
            itemBuilder: (_, i) {
              final lv = i + 1;
              return _LevelTile(
                key: ValueKey('pj_level_$lv'),
                level: lv,
                locked: lv > unlocked,
                stars: Storage.getInt(pjKey(_t, 'stars.$lv')),
                done: lv < unlocked,
                current: lv == current,
                onTap: () => _play(lv),
                onLockedTap: lv == unlocked + 1 ? () => _unlockNext(lv) : null,
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
    this.onLockedTap,
  });
  final int level, stars;
  final bool locked, done, current;
  final VoidCallback onTap;

  /// Set only for the next locked level, which can be bought.
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: locked
            ? const LinearGradient(colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)])
            : current
                ? Pal.accent(pjAccent)
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [pjAccent.withValues(alpha: 0.28), pjAccent.withValues(alpha: 0.08)]),
        border: Border.all(color: current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
        boxShadow: locked
            ? null
            : [
                BoxShadow(
                    color: pjAccent.withValues(alpha: current ? 0.55 : 0.2),
                    blurRadius: current ? 16 : 8,
                    spreadRadius: -2)
              ],
      ),
      child: locked
          ? Icon(onLockedTap != null ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18, color: onLockedTap != null ? Pal.gold : Pal.textDim)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$level',
                    style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
                if (done) StarRow(stars: stars, size: 12),
              ]),
            ),
    );
    if (locked) return onLockedTap == null ? tile : Pressable(onTap: onLockedTap!, child: tile);
    return Pressable(onTap: onTap, child: tile);
  }
}
