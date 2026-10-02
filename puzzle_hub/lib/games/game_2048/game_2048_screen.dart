import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/game_2048_logic.dart';

const _tint = Color(0xFFFB923C);
const _slideMs = 120;

String _bestKey(Tier2048 t) => 'g2048.${t.name}.best';
String _saveKey(Tier2048 t) => 'g2048.${t.name}.save';
const _tierKey = 'g2048.tier';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  late Game2048 _g;
  late int _best;
  List<Tile> _ghosts = [];
  Timer? _ghostTimer;
  int _floatSerial = 0;
  int _floatPts = 0;
  bool _dialogOpen = false;
  final Set<String> _paid = {};
  bool _overReported = false;
  Offset _drag = Offset.zero;
  bool _swiped = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load(Tier2048.values[Storage.getInt(_tierKey, Tier2048.medium.index).clamp(0, Tier2048.values.length - 1)]);
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _load(Tier2048 t) {
    final saved = Game2048.fromJsonString(Storage.getString(_saveKey(t)));
    _g = (saved != null && saved.tier == t) ? saved : (Game2048.forTier(t)..reset());
    _best = Storage.getInt(_bestKey(t));
    _ghosts = [];
    _resetRewardGuards();
  }

  /// Milestones already present in a resumed game must not pay out again.
  void _resetRewardGuards() {
    _paid.clear();
    _overReported = false;
    final m = _g.maxTile;
    if (m >= 512) _paid.add('512');
    if (m >= 1024) _paid.add('1024');
    if (_g.keepGoing || m >= _g.target) _paid.add('target');
  }

  void _awardMilestones() {
    final n = _g.size, m = _g.maxTile, t = _g.tier.name;
    void pay(String id, int v, int stars) {
      if (_paid.add(id)) Rewards.onLevelComplete('game_2048', 'size$n/tier-$t-$v', stars: stars, score: _g.score);
    }
    if (m >= _g.target) pay('target', _g.target, 3);
    if (m >= 512 && _g.target != 512) pay('512', 512, 1);
    if (m >= 1024 && _g.target != 1024) pay('1024', 1024, 2);
  }

  void _reportOver() {
    if (_overReported) return;
    _overReported = true;
    Rewards.onGameEnd('game_2048', score: _g.score, won: false);
  }

  void _save() {
    if (_g.hasMoves) {
      Storage.setString(_saveKey(_g.tier), _g.toJsonString());
    } else {
      Storage.setString(_saveKey(_g.tier), '');
    }
  }

  void _setTier(Tier2048 t) {
    if (t == _g.tier) return;
    AppAudio.play(Sound.tap);
    _save();
    Storage.setInt(_tierKey, t.index);
    setState(() => _load(t));
  }

  void _restart() {
    AppAudio.play(Sound.tap);
    setState(() {
      _g = Game2048.forTier(_g.tier)..reset();
      _ghosts = [];
      _resetRewardGuards();
    });
    _save();
  }

  void _undo() {
    if (_g.undo()) {
      AppAudio.play(Sound.tap);
      AppAudio.haptic();
      setState(() => _ghosts = []);
      _save();
    }
  }

  void _move(Dir d) {
    if (_dialogOpen) return;
    final res = _g.move(d);
    if (res == null) return;
    AppAudio.haptic();
    if (res.merged.isNotEmpty) {
      final big = _g.tiles.any((t) => res.merged.contains(t.id) && t.value >= 128);
      AppAudio.play(big ? Sound.success : Sound.pop);
    } else {
      AppAudio.play(Sound.slide);
    }
    _ghostTimer?.cancel();
    _ghostTimer = Timer(const Duration(milliseconds: _slideMs + 20), () {
      if (mounted) setState(() => _ghosts = []);
    });
    if (Storage.setBest(_bestKey(_g.tier), _g.score)) _best = _g.score;
    setState(() {
      _ghosts = res.removed;
      if (res.gained > 0) {
        _floatSerial++;
        _floatPts = res.gained;
      }
    });
    _save();
    _awardMilestones();
    if (!_g.keepGoing && _g.reachedTarget) {
      _showWin();
    } else if (!_g.hasMoves) {
      _showOver();
    }
  }

  void _showWin() {
    _dialogOpen = true;
    showPremiumDialog(
      context,
      title: '${_g.target} reached!',
      message: 'Score ${_g.score}. Keep going for a higher tile?',
      emoji: '🏆',
      color: _tint,
      actions: [
        DialogAction('Keep going', () {
          _g.keepGoing = true;
          _save();
          if (!_g.hasMoves) _showOver();
        }, primary: true),
        DialogAction('New game', _restart),
      ],
    ).then((_) => _dialogOpen = false);
  }

  void _showOver() {
    AppAudio.play(Sound.fail);
    _reportOver();
    _dialogOpen = true;
    showPremiumDialog(
      context,
      title: 'Game over',
      message: 'Score ${_g.score}  •  Best $_best\nHighest tile ${_g.maxTile}',
      emoji: '😵',
      color: Pal.danger,
      actions: [
        if (_g.canUndo) DialogAction('Undo', _undo),
        DialogAction('Try again', _restart, primary: true),
      ],
    ).then((_) => _dialogOpen = false);
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final d = k == LogicalKeyboardKey.arrowUp
        ? Dir.up
        : k == LogicalKeyboardKey.arrowDown
            ? Dir.down
            : k == LogicalKeyboardKey.arrowLeft
                ? Dir.left
                : k == LogicalKeyboardKey.arrowRight
                    ? Dir.right
                    : null;
    if (d == null) return KeyEventResult.ignored;
    _move(d);
    return KeyEventResult.handled;
  }

  void _onPan(DragUpdateDetails u) {
    if (_swiped) return;
    _drag += u.delta;
    if (_drag.distance < 22) return;
    _swiped = true;
    _move(_drag.dx.abs() > _drag.dy.abs()
        ? (_drag.dx > 0 ? Dir.right : Dir.left)
        : (_drag.dy > 0 ? Dir.down : Dir.up));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '2048',
      tint: _tint,
      actions: [
        BarAction(icon: Icons.undo_rounded, tooltip: 'Undo (${_g.undosLeft})', onTap: _g.canUndo ? _undo : null),
        BarAction(icon: Icons.refresh_rounded, tooltip: 'Restart', onTap: _restart),
      ],
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _ScorePill(label: 'SCORE', value: _g.score, floatSerial: _floatSerial, floatPts: _floatPts)),
              const SizedBox(width: 12),
              Expanded(child: _ScorePill(label: 'BEST', value: math.max(_best, _g.score))),
            ]),
            const SizedBox(height: 14),
            _TierSelector(selected: _g.tier, undosLeft: _g.undosLeft, onSelect: _setTier),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, c) {
                  final side = math.min(c.maxWidth, c.maxHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {
                      _drag = Offset.zero;
                      _swiped = false;
                    },
                    onPanUpdate: _onPan,
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: _Board(game: _g, ghosts: _ghosts, side: side),
                    ),
                  );
                }),
              ),
            ),
            Text('Swipe to merge tiles. Reach ${_g.target}!',
                style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _TierSelector extends StatelessWidget {
  const _TierSelector({required this.selected, required this.undosLeft, required this.onSelect});
  final Tier2048 selected;
  final int undosLeft;
  final ValueChanged<Tier2048> onSelect;

  static const _colors = {
    Tier2048.easy: Color(0xFF4ADE80),
    Tier2048.medium: Color(0xFF60A5FA),
    Tier2048.hard: Color(0xFFFB923C),
    Tier2048.extreme: Color(0xFFFF4D6D),
  };

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final t in Tier2048.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TierCard(
              tier: t,
              color: _colors[t]!,
              selected: t == selected,
              undosLeft: t == selected ? undosLeft : null,
              onTap: () => onSelect(t),
            ),
          ),
        ),
    ]);
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.color, required this.selected, required this.onTap, this.undosLeft});
  final Tier2048 tier;
  final Color color;
  final bool selected;
  final int? undosLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dim = selected ? Colors.white.withValues(alpha: 0.9) : Pal.textDim;
    final undoTxt = undosLeft != null ? '$undosLeft/${tier.undos}' : '${tier.undos}';
    final small = TextStyle(color: dim, fontSize: 10, fontWeight: FontWeight.w700, height: 1.25);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? Pal.accent(color) : null,
          color: selected ? null : Pal.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.45) : Pal.glassBorder),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14, spreadRadius: -3)] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tier.label,
              maxLines: 1,
              style: TextStyle(color: selected ? Colors.white : Pal.text, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 3),
          Text('${tier.size}x${tier.size} \u2192 ${tier.target}', maxLines: 1, style: small),
          Text('$undoTxt undo${tier.undos == 1 ? '' : 's'}', maxLines: 1, style: small),
          Text(tier.stones > 0 ? '${tier.stones} stones' : 'no stones', maxLines: 1, style: small),
          Text('${(tier.fourChance * 100).round()}% fours', maxLines: 1, style: small),
        ]),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value, this.floatSerial = 0, this.floatPts = 0});
  final String label;
  final int value;
  final int floatSerial;
  final int floatPts;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      SizedBox(
        width: double.infinity,
        child: GlassCard(
          blur: 0,
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Column(children: [
            Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(height: 2),
            Text('$value', style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
      if (floatSerial > 0)
        Positioned(
          right: 14,
          top: 4,
          child: IgnorePointer(
            child: Text('+$floatPts', key: ValueKey(floatSerial), style: const TextStyle(color: Pal.gold, fontSize: 18, fontWeight: FontWeight.w900))
                .animate(key: ValueKey(floatSerial))
                .fadeIn(duration: 120.ms)
                .moveY(begin: 0, end: -34, duration: 700.ms, curve: Curves.easeOut)
                .fadeOut(delay: 400.ms, duration: 300.ms),
          ),
        ),
    ]);
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.game, required this.ghosts, required this.side});
  final Game2048 game;
  final List<Tile> ghosts;
  final double side;

  @override
  Widget build(BuildContext context) {
    final n = game.size;
    final pad = side * 0.03;
    final gap = side * (n == 5 ? 0.02 : 0.025);
    final cell = (side - pad * 2 - gap * (n - 1)) / n;
    double pos(int i) => pad + i * (cell + gap);
    final radius = cell * 0.16;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(side * 0.05),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: Pal.glassBorder),
      ),
      child: Stack(children: [
        for (var r = 0; r < n; r++)
          for (var c = 0; c < n; c++)
            Positioned(
              left: pos(c),
              top: pos(r),
              width: cell,
              height: cell,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(radius)),
              ),
            ),
        for (final i in game.stones)
          Positioned(
            left: pos(i % n),
            top: pos(i ~/ n),
            width: cell,
            height: cell,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2547),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.35), size: cell * 0.4),
            ),
          ),
        for (final t in [...ghosts, ...game.tiles])
          AnimatedPositioned(
            key: ValueKey(t.id),
            duration: const Duration(milliseconds: _slideMs),
            curve: Curves.easeOutCubic,
            left: pos(t.c),
            top: pos(t.r),
            width: cell,
            height: cell,
            child: RepaintBoundary(child: _TileView(value: t.value, size: cell, radius: radius, isGhost: ghosts.contains(t))),
          ),
      ]),
    );
  }
}

class _TileView extends StatefulWidget {
  const _TileView({required this.value, required this.size, required this.radius, required this.isGhost});
  final int value;
  final double size;
  final double radius;
  final bool isGhost;

  @override
  State<_TileView> createState() => _TileViewState();
}

class _TileViewState extends State<_TileView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // spawn: scale in after the slide
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOutBack)),
    );
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant _TileView old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !widget.isGhost) {
      // merge pop
      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 55),
      ]).animate(_c);
      _c.duration = const Duration(milliseconds: 220);
      _c.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final st = _styleFor(v);
    final digits = '$v'.length;
    final fs = widget.size * (digits <= 2 ? 0.46 : digits == 3 ? 0.38 : digits == 4 ? 0.3 : 0.24);
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [st.hi, st.lo]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(color: st.glow.withValues(alpha: st.glowAlpha), blurRadius: widget.size * st.glowSpread, spreadRadius: 0.5),
          ],
        ),
        child: Stack(children: [
          // glossy highlight
          Positioned(
            left: widget.size * 0.06,
            right: widget.size * 0.06,
            top: widget.size * 0.04,
            height: widget.size * 0.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Center(
            child: Text('$v',
                style: TextStyle(
                  color: st.fg,
                  fontSize: fs,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))],
                )),
          ),
        ]),
      ),
    );
  }
}

class _TileStyle {
  const _TileStyle(this.hi, this.lo, this.fg, this.glow, this.glowAlpha, this.glowSpread);
  final Color hi, lo, fg, glow;
  final double glowAlpha, glowSpread;
}

// Cool-to-hot ramp: index = log2(value) - 1.
const _ramp = <List<int>>[
  [0xFFE9E3FF, 0xFFB9ADEB], // 2
  [0xFFD6D0FF, 0xFF8F86E8], // 4
  [0xFF8BB8FF, 0xFF4F7CE8], // 8
  [0xFF5FD8F0, 0xFF1E9FCB], // 16
  [0xFF4FE3B5, 0xFF15A57F], // 32
  [0xFFA8E85C, 0xFF5FB52A], // 64
  [0xFFFFE066, 0xFFF2B01E], // 128
  [0xFFFFC04D, 0xFFF57C00], // 256
  [0xFFFF9248, 0xFFE8501A], // 512
  [0xFFFF6B6B, 0xFFD6254B], // 1024
  [0xFFFF5FA8, 0xFFC4167F], // 2048
  [0xFFB06BFF, 0xFF6D1FD1], // 4096
  [0xFF6B5BFF, 0xFF2A1BB8], // 8192+
];

_TileStyle _styleFor(int v) {
  final e = (math.log(v) / math.ln2).round().clamp(1, 30);
  final idx = math.min(e - 1, _ramp.length - 1);
  final hi = Color(_ramp[idx][0]);
  final lo = Color(_ramp[idx][1]);
  final heat = (e / 11).clamp(0.0, 1.0);
  return _TileStyle(
    hi,
    lo,
    e <= 2 ? const Color(0xFF3B2F7A) : Colors.white,
    e >= 7 ? Color.lerp(hi, Colors.white, 0.1)! : lo,
    e < 3 ? 0.12 : 0.2 + 0.55 * heat,
    0.12 + 0.35 * heat,
  );
}
