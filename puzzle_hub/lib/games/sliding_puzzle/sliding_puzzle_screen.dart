import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/sliding_logic.dart';

const _tint = Color(0xFFB794FF);

String _kStars(SlideTier t, int l) => 'sliding.${t.key}.stars.$l';
String _kMoves(SlideTier t, int l) => 'sliding.${t.key}.bestMoves.$l';
String _kTime(SlideTier t, int l) => 'sliding.${t.key}.bestTime.$l';

int _stars(SlideTier t, int l) => Storage.getInt(_kStars(t, l));

/// Unlocked through progress: level 1, a cleared level, or the one after it.
bool _unlocked(SlideTier t, int l) => l == 1 || _stars(t, l) > 0 || _stars(t, l - 1) > 0;

/// [LevelGate] prefix, e.g. `sliding.easy`.
String slideGatePrefix(SlideTier t) => 'sliding.${t.key}';

/// Next unbeaten level in sequence: the furthest level that is free to open.
int slideFreeUpTo(SlideTier t) {
  for (var l = 1; l <= SlideTier.levelCount; l++) {
    if (_stars(t, l) == 0) return l;
  }
  return SlideTier.levelCount;
}

/// Plays left on a level skipped to with coins (0 for unlocked levels).
int slidePlaysLeft(SlideTier t, int l) => _unlocked(t, l) ? 0 : LevelGate.playsLeft(slideGatePrefix(t), l);

bool slideCanPlay(SlideTier t, int l) => _unlocked(t, l) || slidePlaysLeft(t, l) > 0;

/// Counts one play of a bought level (no-op for unlocked levels).
Future<void> slideOnStart(SlideTier t, int l) =>
    LevelGate.onStart(slideGatePrefix(t), _unlocked(t, l) ? l : slideFreeUpTo(t), l);

/// Makes sure level [l] may be played; a locked level must be bought first.
Future<bool> _ensurePlayable(BuildContext context, SlideTier t, int l) async {
  if (slideCanPlay(t, l)) return true;
  return LevelGate.buy(context, prefix: slideGatePrefix(t), freeUpTo: slideFreeUpTo(t), level: l);
}

String _tierLabel(SlideTier t) => tr('common.tier.${t.name}');

String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Sliding (15) puzzle with four tiers and 100 scramble-depth levels each.
class SlidingPuzzleScreen extends StatefulWidget {
  const SlidingPuzzleScreen({super.key, this.debugStart, this.debugRng});

  /// Test hook: fixed starting board for the first game that is opened.
  final List<int>? debugStart;
  final Random? debugRng;

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  SlideTier _tier = SlideTier.easy;
  int? _level; // null = menu
  late bool _picture = Storage.getBool('sliding.picture');
  bool _usedDebug = false;
  int _attempt = 0;

  void _open(int level) => setState(() {
        _level = level;
        _attempt++;
      });

  /// Tapping a level tile: free levels open; locked ones can be skipped to
  /// with coins (100 per skipped level, a limited number of plays).
  Future<void> _tapLevel(int level) async {
    final ok = await _ensurePlayable(context, _tier, level);
    if (!mounted) return;
    if (ok) {
      _open(level);
    } else {
      AppAudio.play(Sound.fail, volume: 0.4);
      setState(() {});
    }
  }

  void _toMenu() => setState(() => _level = null);

  @override
  Widget build(BuildContext context) {
    final playing = _level != null;
    return GameScaffold(
      title: playing ? '${_tierLabel(_tier)} - ${tr('common.level_n', {'n': _level})}' : tr('sliding_puzzle.title'),
      tint: _tint,
      onBack: playing ? _toMenu : null,
      body: playing ? _gameView() : _menu(),
    );
  }

  Widget _gameView() {
    final dbg = !_usedDebug ? widget.debugStart : null;
    _usedDebug = true;
    return _SlideGame(
      key: ValueKey('${_tier.key}-$_level-$_picture-$_attempt'),
      tier: _tier,
      level: _level!,
      picture: _picture,
      rng: widget.debugRng,
      startBoard: dbg,
      onMenu: _toMenu,
      onNext: _open,
    );
  }

  Widget _menu() {
    int total(SlideTier t) => [for (var l = 1; l <= SlideTier.levelCount; l++) _stars(t, l)].fold(0, (a, b) => a + b);
    final header = <Widget>[
      Row(children: [
        for (final t in SlideTier.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                radius: 18,
                blur: 0,
                glow: t == _tier ? _tint : null,
                gradient: t == _tier
                    ? LinearGradient(colors: [_tint.withValues(alpha: 0.5), _tint.withValues(alpha: 0.18)])
                    : null,
                onTap: () => setState(() => _tier = t),
                child: Column(children: [
                  Text('${t.size}x${t.size}',
                      style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(_tierLabel(t),
                        style: TextStyle(
                            color: t == _tier ? Pal.text : Pal.textDim, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 12, color: Pal.gold),
                    Text(' ${total(t)}', style: const TextStyle(color: Pal.gold, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              ),
            ),
          ),
      ]).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        radius: 20,
        blur: 0,
        child: Row(children: [
          const Icon(Icons.image_rounded, color: _tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('sliding_puzzle.picture_mode'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Switch(
            value: _picture,
            activeThumbColor: _tint,
            onChanged: (v) {
              Storage.setBool('sliding.picture', v);
              setState(() => _picture = v);
            },
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(tr('sliding_puzzle.choose_level'), style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 10),
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(header)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.95),
            delegate: SliverChildBuilderDelegate((_, i) => _levelTile(i + 1), childCount: SlideTier.levelCount),
          ),
        ),
      ],
    );
  }

  Widget _levelTile(int l) {
    final free = _unlocked(_tier, l);
    final plays = free ? 0 : slidePlaysLeft(_tier, l);
    final open = free || plays > 0;
    final s = _stars(_tier, l);
    return Opacity(
      key: ValueKey('slide-level-$l'),
      opacity: open ? 1 : 0.5,
      child: GlassCard(
        padding: const EdgeInsets.all(6),
        radius: 18,
        blur: 0,
        glow: plays > 0 ? Pal.gold : null,
        onTap: () => _tapLevel(l),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (plays > 0)
              Text(tr('sliding_puzzle.bought'),
                  style: const TextStyle(color: Pal.gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            open
                ? Text('$l', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 20))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_rounded, color: Pal.textDim, size: 20),
                    Text('$l', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 10)),
                  ]),
            const SizedBox(height: 4),
            if (plays > 0)
              Text(tr('common.skip.plays_left', {'n': plays}),
                  style: const TextStyle(color: Pal.gold, fontSize: 10, fontWeight: FontWeight.w800))
            else
              StarRow(stars: s, size: 13),
          ]),
        ),
      ),
    );
  }
}

class _SlideGame extends StatefulWidget {
  const _SlideGame({
    super.key,
    required this.tier,
    required this.level,
    required this.picture,
    required this.onMenu,
    required this.onNext,
    this.rng,
    this.startBoard,
  });
  final SlideTier tier;
  final int level;
  final bool picture;
  final Random? rng;
  final List<int>? startBoard;
  final VoidCallback onMenu;
  final void Function(int level) onNext;

  @override
  State<_SlideGame> createState() => _SlideGameState();
}

class _SlideGameState extends State<_SlideGame> with SingleTickerProviderStateMixin {
  late final int n = widget.tier.size;
  late final int depth = widget.tier.depthFor(widget.level);
  late final Random _rng = widget.rng ?? Random(widget.tier.seedFor(widget.level));
  late List<int> _start;
  late List<int> _board;
  final List<List<int>> _history = [];
  int _moves = 0;
  int _seconds = 0;
  bool _won = false;
  Timer? _timer;
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    slideOnStart(widget.tier, widget.level);
    _start = widget.startBoard ?? SlidingLogic.shuffle(n, depth, _rng);
    _board = List.of(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_won) setState(() => _seconds++);
    });
  }

  void _tap(int index) {
    if (_won) return;
    final nb = SlidingLogic.slide(_board, n, index);
    if (nb == null) {
      AppAudio.play(Sound.fail, volume: 0.4);
      return;
    }
    _startTimer();
    // Did any moved tile land on its goal square?
    var pop = false;
    for (final i in SlidingLogic.movers(_board, n, index)) {
      final v = _board[i];
      if (nb.indexOf(v) == v - 1 && i != v - 1) pop = true;
    }
    setState(() {
      _history.add(_board);
      _board = nb;
      _moves++;
    });
    if (SlidingLogic.isSolved(nb)) {
      _win();
    } else if (pop) {
      AppAudio.play(Sound.pop, volume: 0.35);
      AppAudio.haptic();
    } else {
      AppAudio.play(Sound.slide, volume: 0.5);
      AppAudio.haptic();
    }
  }

  void _undo() {
    if (_won || _history.isEmpty) return;
    setState(() {
      _board = _history.removeLast();
      _moves--;
    });
    AppAudio.play(Sound.slide, volume: 0.3);
  }

  /// Restart: a bought level spends one of its plays; when none are left the
  /// skip offer is shown again, otherwise back to the menu.
  Future<void> _restart() async {
    final ok = await _ensurePlayable(context, widget.tier, widget.level);
    if (!mounted) return;
    if (!ok) {
      widget.onMenu();
      return;
    }
    slideOnStart(widget.tier, widget.level);
    _timer?.cancel();
    _timer = null;
    _wave.reset();
    setState(() {
      _board = List.of(_start);
      _history.clear();
      _moves = 0;
      _seconds = 0;
      _won = false;
    });
  }

  void _win() {
    _timer?.cancel();
    final t = widget.tier, l = widget.level;
    final stars = SlidingLogic.starsFor(_moves, depth);
    final prevMoves = Storage.getInt(_kMoves(t, l));
    final newMoves = prevMoves == 0 || _moves < prevMoves;
    if (newMoves) Storage.setInt(_kMoves(t, l), _moves);
    final prevTime = Storage.getInt(_kTime(t, l));
    if (prevTime == 0 || _seconds < prevTime) Storage.setInt(_kTime(t, l), max(1, _seconds));
    if (stars > _stars(t, l)) Storage.setInt(_kStars(t, l), stars);
    LevelGate.onCleared(slideGatePrefix(t), l);
    Rewards.onLevelComplete('sliding_puzzle', '${t.key}-L$l', stars: stars);
    setState(() => _won = true);
    _wave.forward(from: 0);
    final hasNext = l < SlideTier.levelCount;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr('sliding_puzzle.solved'),
        emoji: '🧩',
        stars: stars,
        color: _tint,
        message: '${tr('sliding_puzzle.result', {'n': _moves, 'time': _fmt(_seconds)})}${newMoves ? '\n${tr('sliding_puzzle.new_best')}' : ''}\n${tr('sliding_puzzle.par_n', {'n': depth})}',
        actions: [
          if (hasNext) DialogAction(tr('common.next_level'), () => widget.onNext(l + 1), primary: true),
          DialogAction(tr('common.retry'), () => widget.onNext(l), primary: !hasNext),
          DialogAction(tr('common.menu'), widget.onMenu),
        ],
      );
    });
  }

  // Continuous gradient across the whole board (tile tint comes from its goal square).
  static const _stops = [Color(0xFF7C5CFF), Color(0xFF4DA8FF), Color(0xFF2EE6A8), Color(0xFFFFC857), Color(0xFFFF6FB5)];
  Color _colorAt(double t) {
    final x = t.clamp(0.0, 1.0) * (_stops.length - 1);
    final i = min(x.floor(), _stops.length - 2);
    return Color.lerp(_stops[i], _stops[i + 1], x - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final bestM = Storage.getInt(_kMoves(widget.tier, widget.level));
    final bestT = Storage.getInt(_kTime(widget.tier, widget.level));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          _stat(tr('common.moves').toUpperCase(), '$_moves'),
          const SizedBox(width: 8),
          _stat(tr('common.time').toUpperCase(), _fmt(_seconds)),
          const SizedBox(width: 8),
          _stat(tr('sliding_puzzle.par').toUpperCase(), '$depth'),
          const SizedBox(width: 8),
          _stat(tr('common.best').toUpperCase(), bestM == 0 ? '-' : '$bestM / ${_fmt(bestT)}'),
        ]),
      ),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(builder: (ctx, c) {
              final side = min(c.maxWidth, c.maxHeight);
              return SizedBox(width: side, height: side, child: _boardView(side));
            }),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: PremiumButton(
              label: tr('common.undo'),
              icon: Icons.undo_rounded,
              compact: true,
              color: const Color(0xFF6F63B8),
              onTap: _history.isEmpty || _won ? null : _undo,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: PremiumButton(
                label: tr('common.restart'), icon: Icons.refresh_rounded, compact: true, color: _tint, onTap: _restart),
          ),
        ]),
      ),
    ]);
  }

  Widget _stat(String label, String value) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          radius: 14,
          blur: 0,
          child: Column(children: [
            Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(value, style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );

  Widget _boardView(double side) {
    const pad = 8.0;
    final cell = (side - pad * 2) / n;
    final fontSize = cell * (n >= 6 ? 0.42 : 0.4);
    return Container(
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x33FFFFFF), Color(0x0FFFFFFF)],
        ),
        border: Border.all(color: Pal.glassBorder),
        boxShadow: [BoxShadow(color: _tint.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: -6)],
      ),
      child: Stack(children: [
        for (var v = 1; v < n * n; v++) _tile(v, cell, fontSize),
      ]),
    );
  }

  Widget _tile(int v, double cell, double fontSize) {
    final idx = _board.indexOf(v);
    final r = idx ~/ n, c = idx % n;
    final gr = (v - 1) ~/ n, gc = (v - 1) % n;
    final inPlace = idx == v - 1;
    final c0 = _colorAt((gr + gc) / (2.0 * n));
    final c1 = _colorAt((gr + gc + 2) / (2.0 * n));
    const inset = 3.0;
    final radius = BorderRadius.circular(cell * 0.2);
    return AnimatedPositioned(
      key: ValueKey('tile-$v'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      left: c * cell,
      top: r * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(_board.indexOf(v)),
        child: AnimatedBuilder(
          animation: _wave,
          builder: (_, child) {
            var bump = 0.0;
            if (_wave.value > 0) {
              final t = (_wave.value * 1.7 - (r + c) / (2.0 * n)).clamp(0.0, 1.0);
              bump = sin(pi * t);
            }
            return Transform.scale(
              scale: 1 + 0.12 * bump,
              child: Stack(fit: StackFit.expand, children: [
                child!,
                if (bump > 0)
                  Padding(
                    padding: const EdgeInsets.all(inset),
                    child: DecoratedBox(
                      decoration: BoxDecoration(borderRadius: radius, color: Colors.white.withValues(alpha: 0.5 * bump)),
                    ),
                  ),
              ]),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(inset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(c0, Colors.white, 0.22)!, c0, Color.lerp(c1, Colors.black, 0.2)!],
                  stops: const [0, 0.45, 1],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: inPlace ? 0.85 : 0.35), width: inPlace ? 1.8 : 1),
                boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: cell * 0.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(cell * 0.2)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                if (!widget.picture)
                  Center(
                    child: Text('$v',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
                        )),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
