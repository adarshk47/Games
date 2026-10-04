import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_logic.dart';
import 'mm_common.dart';

enum _Phase { intro, show, pick, result }

class HospitalBagGame extends StatefulWidget {
  const HospitalBagGame({super.key});
  @override
  State<HospitalBagGame> createState() => _HospitalBagGameState();
}

class _HospitalBagGameState extends State<HospitalBagGame>
    with SingleTickerProviderStateMixin {
  late int _level = Storage.getInt('mom.bag.level').clamp(0, 6);
  _Phase _phase = _Phase.intro;
  late BagRound _round;
  final Set<int> _picked = {};
  late final AnimationController _bar = AnimationController(vsync: this);

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  BagLevel get _lv => bagLevel(_level);

  void _begin() {
    _round = buildBagRound(_lv, math.Random());
    _picked.clear();
    setState(() => _phase = _Phase.show);
    _bar.duration = Duration(seconds: _lv.showSeconds);
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.show) _toPick();
    });
  }

  void _toPick() {
    _bar.stop();
    setState(() => _phase = _Phase.pick);
  }

  void _submit() {
    final r = scoreBag(_picked, _round.shown);
    final stars = bagStars(r.correct, _lv.count);
    Storage.setBest('mom.bag.best', r.correct);
    Storage.setBest('mom.bag.stars.$_level', stars);
    if (stars >= 2 && _level < 6) Storage.setBest('mom.bag.level', _level + 1);
    recordPlay();
    Rewards.onLevelComplete('mom_memory', 'bag-L${_level + 1}', stars: stars);
    setState(() => _phase = _Phase.result);
  }

  void _toggle(int i) {
    softTap();
    setState(() => _picked.contains(i) ? _picked.remove(i) : _picked.add(i));
  }

  @override
  Widget build(BuildContext context) {
    return MmPage(
      title: tr('mom_memory.bag_title'),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(key: ValueKey(_phase), child: _content()),
            ),
          ),
          const MmFootnote(),
        ],
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.intro:
        return _intro();
      case _Phase.show:
        return _show();
      case _Phase.pick:
        return _pick();
      case _Phase.result:
        return _result();
    }
  }

  Widget _intro() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧳', style: TextStyle(fontSize: 72))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 14),
          Text(
            tr('common.level_n', {'n': _level + 1}),
            style: const TextStyle(
              color: Pal.text,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('mom_memory.bag_intro', {'n': _lv.count}),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Pal.textDim,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              for (
                var i = 0;
                i <= Storage.getInt('mom.bag.level').clamp(0, 6);
                i++
              )
                GestureDetector(
                  onTap: () => setState(() => _level = i),
                  child: Chip(
                    label: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == _level ? Mm.ink : Pal.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    backgroundColor: i == _level ? Mm.rose : Pal.glass,
                    side: const BorderSide(color: Pal.glassBorder),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          PremiumButton(
            label: tr('mom_memory.start'),
            icon: Icons.favorite_rounded,
            color: Mm.rose,
            onTap: _begin,
          ),
        ],
      ),
    ),
  );

  Widget _grid(
    List<int> ids,
    Widget Function(int id, int idx) tile, {
    int cols = 3,
    double aspect = 1,
  }) => LayoutBuilder(
    builder: (_, c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspect,
        children: [for (var i = 0; i < ids.length; i++) tile(ids[i], i)],
      ),
    ),
  );

  Widget _label(BagItem it, {double size = 34}) {
    final name = it.name;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(it.emoji, style: TextStyle(fontSize: size)),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Mm.ink,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        // Small English helper line when the main name differs.
        if (name != it.en)
          Text(
            it.en,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Mm.ink.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  Widget _show() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(
          tr('mom_memory.remember_items'),
          style: const TextStyle(
            color: Pal.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
        child: AnimatedBuilder(
          animation: _bar,
          builder: (_, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 1 - _bar.value,
              minHeight: 6,
              color: Mm.rose,
              backgroundColor: Pal.glass,
            ),
          ),
        ),
      ),
      Expanded(
        child: _grid(
          _round.shown,
          (id, i) =>
              PastelTile(
                    color: Mm.pads[i % Mm.pads.length],
                    child: _label(bagItems[id]),
                  )
                  .animate(delay: (i * 90).ms)
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    curve: Curves.easeOutBack,
                  ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PremiumButton(
          label: tr('mom_memory.memorized'),
          compact: true,
          color: Mm.lavender,
          onTap: _toPick,
        ),
      ),
    ],
  );

  Widget _pick() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(
          tr('mom_memory.bag_pick', {
            'n': _picked.length,
            'total': _lv.count,
          }),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Pal.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        child: _grid(
          _round.options,
          (id, i) => Pressable(
            onTap: () => _toggle(id),
            child: PastelTile(
              color: Mm.pads[i % Mm.pads.length],
              selected: _picked.contains(id),
              dim: !_picked.contains(id),
              child: _label(bagItems[id], size: 30),
            ),
          ),
          cols: 4,
          aspect: 0.82,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PremiumButton(
          label: tr('mom_memory.done'),
          icon: Icons.check_rounded,
          color: Mm.rose,
          onTap: _picked.isEmpty ? null : _submit,
        ),
      ),
    ],
  );

  Widget _result() {
    final r = scoreBag(_picked, _round.shown);
    final total = _lv.count;
    final stars = bagStars(r.correct, total);
    final shown = _round.shown.toSet();
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          tr('mom_memory.bag_result', {'n': r.correct, 'total': total}),
          style: const TextStyle(
            color: Pal.text,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 4),
        StarRow(stars: stars, size: 26),
        const SizedBox(height: 4),
        Text(
          r.correct == total
              ? pick(praise)
              : tr('mom_memory.good_try'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Pal.textDim, fontSize: 14),
        ),
        Expanded(
          child: _grid(
            _round.options,
            (id, i) {
              final isShown = shown.contains(id);
              final picked = _picked.contains(id);
              return Stack(
                children: [
                  Positioned.fill(
                    child: PastelTile(
                      color: isShown ? Mm.mint : Mm.pads[i % Mm.pads.length],
                      dim: !isShown,
                      selected: isShown && picked,
                      child: _label(bagItems[id], size: 28),
                    ),
                  ),
                  if (picked || isShown)
                    Positioned(
                      top: 4,
                      right: 6,
                      child: Text(
                        isShown ? (picked ? '✅' : '💭') : '🌫️',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
              );
            },
            cols: 4,
            aspect: 0.82,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 10,
            children: [
              PremiumButton(
                label: tr('common.replay'),
                compact: true,
                color: const Color(0xFF6F63B8),
                onTap: _begin,
              ),
              PremiumButton(
                label: tr('common.next_level'),
                compact: true,
                color: Mm.rose,
                onTap: _level < 6
                    ? () {
                        setState(() => _level++);
                        _begin();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
