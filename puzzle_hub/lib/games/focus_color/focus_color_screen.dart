import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import '../../core/storage.dart';
import 'focus_play.dart';
import 'logic/focus_difficulty.dart';

class FocusColorScreen extends StatefulWidget {
  const FocusColorScreen({super.key});

  @override
  State<FocusColorScreen> createState() => _FocusColorScreenState();
}

class _FocusColorScreenState extends State<FocusColorScreen> {
  static const _lastKey = 'focus.lastTier';
  static const _tierColors = {
    FocusTier.easy: Color(0xFF34D399),
    FocusTier.medium: Color(0xFF4DA8FF),
    FocusTier.hard: Color(0xFFFF9140),
    FocusTier.extreme: Color(0xFFFF4D5E),
  };

  Future<void> _open(FocusModeInfo m) async {
    final last = FocusTier.fromName(Storage.getString(_lastKey));
    final tier = await showModalBottomSheet<FocusTier>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _chooser(m, last),
    );
    if (tier == null || !mounted) return;
    await Storage.setString(_lastKey, tier.name);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FocusPlayScreen(info: m, tier: tier)));
    if (mounted) setState(() {});
  }

  Widget _chooser(FocusModeInfo m, FocusTier last) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFF1A1740),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: m.color.withValues(alpha: 0.35), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(m.icon, color: m.color),
            const SizedBox(width: 10),
            Expanded(child: Text(m.title, style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(tr('focus_color.choose'), style: const TextStyle(color: Pal.textDim, fontSize: 14)),
          const SizedBox(height: 14),
          for (final t in FocusTier.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tierTile(m, t, selected: t == last),
            ),
        ]),
      ),
    );
  }

  Widget _tierTile(FocusModeInfo m, FocusTier t, {required bool selected}) {
    final c = _tierColors[t]!;
    final best = m.bestFor(t);
    return Pressable(
      onTap: () => Navigator.of(context).pop(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0.10)]),
          border: Border.all(color: c.withValues(alpha: selected ? 0.95 : 0.4), width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(focusTierName(t), style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(tr('focus_color.tier_blurb.${t.name}'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(best > 0 ? tr('focus_color.best_n', {'n': best}) : tr('focus_color.new'),
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 2),
            StarRow(stars: focusStars(m.mode, t, best)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('focus_color.title'),
      tint: focusTint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(tr('focus_color.subtitle'), style: const TextStyle(color: Pal.textDim, fontSize: 15)),
          ),
          for (var i = 0; i < focusModes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _hero(focusModes[i]).animate(delay: (80 * i).ms).fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
            ),
        ],
      ),
    );
  }

  Widget _hero(FocusModeInfo m) {
    // Show the highest tier played so far.
    FocusTier? top;
    for (final t in FocusTier.values) {
      if (m.bestFor(t) > 0) top = t;
    }
    final best = top == null ? 0 : m.bestFor(top);
    return Pressable(
      onTap: () => _open(m),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: Pal.accent(m.color),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: m.color.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
            child: Icon(m.icon, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(m.blurb, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.3)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      top != null ? tr('focus_color.top_best', {'tier': focusTierName(top), 'n': best}) : tr('focus_color.no_score'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                StarRow(stars: top == null ? 0 : focusStars(m.mode, top, best)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
