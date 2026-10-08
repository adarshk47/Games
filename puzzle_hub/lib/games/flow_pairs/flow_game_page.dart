import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'flow_painter.dart';
import 'logic/flow_logic.dart';
import 'progress.dart';

const flowTint = Color(0xFF5EEAD4);

/// Localized tier name.
String flowTierLabel(FlowTier t) => tr('common.tier.${t.name}');

/// One playable level; can advance to the next level in place.
class FlowGamePage extends StatefulWidget {
  const FlowGamePage({super.key, required this.tier, required this.level});
  final FlowTier tier;
  final int level;

  @override
  State<FlowGamePage> createState() => _FlowGamePageState();
}

class _FlowGamePageState extends State<FlowGamePage> with TickerProviderStateMixin {
  late int _level;
  late FlowGame _game;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _winTimer;
  int _version = 0;
  bool _finished = false;
  int _lastTapMs = 0;
  int _lastFailMs = 0;
  int? _lastCell;

  FlowTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    final l = widget.level.clamp(1, FlowLevels.count);
    _load(FlowProgress.canPlay(_tier, l) ? l : FlowProgress.frontier(_tier));
    FlowProgress.start(_tier, _level);
  }

  /// Counts a play of a bought level; false (and a dialog) when its plays
  /// are used up and it locked again.
  bool _countPlay() {
    if (!FlowProgress.canPlay(_tier, _level)) {
      _failSound(force: true);
      showPremiumDialog(
        context,
        title: tr('common.skip.title', {'n': _level}),
        message: tr('flow_pairs.plays_over'),
        emoji: '🔒',
        color: Pal.gold,
        actions: [DialogAction(tr('common.levels'), () => Navigator.of(context).maybePop(), primary: true)],
      );
      return false;
    }
    FlowProgress.start(_tier, _level);
    return true;
  }

  void _replay() {
    if (_countPlay()) setState(() => _load(_level));
  }

  void _next() {
    setState(() => _load(_level + 1));
    FlowProgress.start(_tier, _level);
  }

  @override
  void dispose() {
    _winTimer?.cancel();
    _pulse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _load(int level) {
    _winTimer?.cancel();
    _level = level;
    _game = FlowGame(FlowLevels.generate(_tier, level));
    _finished = false;
    _lastCell = null;
    _shimmer.value = 0;
  }

  void _bump() => setState(() => _version++);

  int _cellAt(Offset p, double side) {
    final n = _game.puzzle.size;
    final cs = side / n;
    final c = (p.dx / cs).floor().clamp(0, n - 1);
    final r = (p.dy / cs).floor().clamp(0, n - 1);
    return r * n + c;
  }

  void _tapSound() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 70) return;
    _lastTapMs = now;
    AppAudio.play(Sound.tap, volume: 0.35);
  }

  void _failSound({bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastFailMs < 350) return;
    _lastFailMs = now;
    AppAudio.play(Sound.fail, volume: 0.35);
  }

  void _onDown(Offset p, double side) {
    if (_finished) return;
    final cell = _cellAt(p, side);
    if (_game.begin(cell) != null) {
      _lastCell = cell;
      AppAudio.haptic();
      _tapSound();
      _bump();
    }
  }

  /// Moves the active head toward [target], one orthogonal step at a time.
  void _onMove(Offset p, double side) {
    if (_finished || _game.board.active == null) return;
    final target = _cellAt(p, side);
    if (target == _lastCell) return;
    _lastCell = target;
    final n = _game.puzzle.size;
    var changed = false;
    for (var guard = 0; guard < n * 2; guard++) {
      final a = _game.board.active;
      if (a == null || _game.board.paths[a].isEmpty) break;
      final head = _game.board.paths[a].last;
      if (head == target) break;
      final dr = target ~/ n - head ~/ n, dc = target % n - head % n;
      final vert = head + dr.sign * n, horiz = head + dc.sign;
      final first = (dr.abs() >= dc.abs()) ? (dr != 0 ? vert : horiz) : (dc != 0 ? horiz : vert);
      final second = first == vert ? (dc != 0 ? horiz : -1) : (dr != 0 ? vert : -1);
      var step = _game.extend(first);
      if ((step == FlowStep.blocked || step == FlowStep.none) && second >= 0 && second != first) {
        step = _game.extend(second);
      }
      if (step == FlowStep.none) break;
      if (step == FlowStep.blocked) {
        _failSound();
        break;
      }
      changed = true;
      switch (step) {
        case FlowStep.connected:
          AppAudio.play(Sound.success);
          AppAudio.haptic(true);
        case FlowStep.cut:
          _failSound(force: true);
          AppAudio.haptic();
        default:
          _tapSound();
      }
      if (_game.solved) break;
    }
    if (changed) {
      if (_game.solved) {
        _win();
      } else {
        _bump();
      }
    }
  }

  void _onUp() {
    _lastCell = null;
    if (_finished) return;
    _game.end();
    if (_game.solved) {
      _win();
    } else {
      _bump();
    }
  }

  void _win() {
    if (_finished) return;
    _finished = true;
    _game.end();
    final stars = flowStars(_game.moves, _game.puzzle.pairs.length);
    FlowProgress.complete(_tier, _level, stars);
    Rewards.onLevelComplete('flow_pairs', '${_tier.id}-L$_level', stars: stars);
    _shimmer.forward(from: 0);
    _bump();
    _winTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr('flow_pairs.complete'),
        emoji: '🌈',
        stars: stars,
        color: flowTint,
        message: MediaQuery.sizeOf(context).height < 560
            ? null
            : tr('flow_pairs.strokes', {'n': _game.moves, 'best': _game.puzzle.minMoves}),
        actions: [
          DialogAction(tr('common.levels'), () => Navigator.of(context).maybePop()),
          DialogAction(tr('common.replay'), _replay),
          if (_level < FlowLevels.count) DialogAction(tr('common.next_level'), _next, primary: true),
        ],
      );
    });
  }

  void _undo() {
    if (_finished) return;
    if (_game.undo()) {
      AppAudio.play(Sound.pop, volume: 0.4);
      _bump();
    }
  }

  void _hint() {
    if (_finished) return;
    if (_game.hint() != null) {
      AppAudio.play(Sound.success, volume: 0.5);
      AppAudio.haptic();
      if (_game.solved) {
        _win();
      } else {
        _bump();
      }
    } else {
      _failSound(force: true);
    }
  }

  void _restart() {
    if (_finished || !_countPlay()) return;
    _game.restart();
    AppAudio.play(Sound.slide, volume: 0.4);
    _bump();
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _game.puzzle;
    final board = _game.board;
    return GameScaffold(
      title: '${flowTierLabel(_tier)}  -  ${tr('common.level_n', {'n': _level})}',
      tint: flowTint,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            radius: 20,
            blur: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Stat(tr('flow_pairs.pairs'), '${board.connectedCount}/${puzzle.pairs.length}'),
              _Stat(tr('common.moves'), '${_game.moves}'),
              if (puzzle.requireFill)
                _Stat(tr('flow_pairs.fill_all'), '${(board.filledCount * 100 ~/ puzzle.cells)}%')
              else
                _Stat(tr('flow_pairs.grid'), '${puzzle.size}x${puzzle.size}'),
            ]),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(builder: (context, cons) {
                final side = math.max(60.0, math.min(cons.maxWidth, cons.maxHeight));
                return SizedBox(
                  key: ValueKey('flow_board_${_tier.id}_$_level'),
                  width: side,
                  height: side,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onDown(e.localPosition, side),
                    onPointerMove: (e) => _onMove(e.localPosition, side),
                    onPointerUp: (_) => _onUp(),
                    onPointerCancel: (_) => _onUp(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0x66000000),
                        boxShadow: [BoxShadow(color: flowTint.withValues(alpha: 0.18), blurRadius: 30, spreadRadius: -6)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulse, _shimmer]),
                          builder: (_, _) => CustomPaint(
                            size: Size.square(side),
                            painter: FlowPainter(
                              board: board,
                              pulse: _pulse.value,
                              shimmer: _shimmer.value,
                              solved: _finished,
                              version: _version,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate(key: ValueKey('anim_${_tier.id}_$_level')).fadeIn(duration: 350.ms).scale(
                    begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 350.ms);
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _Tool(icon: Icons.undo_rounded, label: tr('common.undo'), onTap: _game.canUndo ? _undo : null),
            _Tool(
                icon: Icons.lightbulb_rounded,
                label: '${tr('common.hint')} ${_game.hintsLeft}',
                onTap: _game.hintsLeft > 0 ? _hint : null,
                color: Pal.gold),
            _Tool(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart),
          ]),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
      ]);
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap, this.color = Pal.text});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        radius: 18,
        blur: 0,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: onTap == null ? body : Pressable(onTap: onTap!, child: body),
      ),
    );
  }
}
