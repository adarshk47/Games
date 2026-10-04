import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/minesweeper_logic.dart';

const _tint = Color(0xFFFB923C);
const _maxHints = 3;

String _bestKey(MineTier t) => 'mines.${t.name}.best';
String _winsKey(MineTier t) => 'mines.${t.name}.wins';

String _tierLabel(MineTier t) => tr('common.tier.${t.name}');

String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

const _numColors = <Color>[
  Colors.transparent,
  Color(0xFF60A5FA),
  Color(0xFF4ADE80),
  Color(0xFFFF6B8A),
  Color(0xFFC084FC),
  Color(0xFFFBBF24),
  Color(0xFF2DD4BF),
  Color(0xFFF472B6),
  Color(0xFFCBD5E1),
];

const _tierIcons = <MineTier, IconData>{
  MineTier.easy: Icons.spa_rounded,
  MineTier.medium: Icons.local_fire_department_rounded,
  MineTier.hard: Icons.bolt_rounded,
  MineTier.extreme: Icons.whatshot_rounded,
};

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  MineTier? _tier;
  MineGame? _game;
  int _elapsed = 0;
  int _hintsUsed = 0;
  bool _flagMode = false;
  Timer? _timer;
  Timer? _endTimer;
  // Ripple delay (ms) for cells revealed by the latest move.
  final Map<int, int> _delay = {};
  int _moveSeq = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _endTimer?.cancel();
    super.dispose();
  }

  void _start(MineTier t) {
    _timer?.cancel();
    _endTimer?.cancel();
    setState(() {
      _tier = t;
      _game = MineGame.forTier(t);
      _elapsed = 0;
      _hintsUsed = 0;
      _flagMode = false;
      _delay.clear();
    });
  }

  void _menu() {
    _timer?.cancel();
    _endTimer?.cancel();
    setState(() {
      _tier = null;
      _game = null;
    });
  }

  void _tickStart() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });
  }

  void _afterMove(List<int> revealed, int origin) {
    final g = _game!;
    _moveSeq++;
    _delay.clear();
    final oc = origin % g.cols, orow = origin ~/ g.cols;
    for (final i in revealed) {
      final d = math.max((i % g.cols - oc).abs(), (i ~/ g.cols - orow).abs());
      _delay[i] = d * 28;
    }
    if (g.status == MineStatus.playing) _tickStart();
    if (g.status == MineStatus.lost) {
      _timer?.cancel();
      AppAudio.play(Sound.fail);
      AppAudio.haptic(true);
      // Stagger the remaining mines outward from the blast.
      for (var i = 0; i < g.size; i++) {
        if (g.mine[i] && i != g.explodedAt) {
          final d = math.max((i % g.cols - g.explodedAt! % g.cols).abs(), (i ~/ g.cols - g.explodedAt! ~/ g.cols).abs());
          _delay[i] = 150 + d * 40;
        }
      }
      _finish(false);
    } else if (g.status == MineStatus.won) {
      _timer?.cancel();
      AppAudio.play(Sound.success);
      _finish(true);
    } else if (revealed.length > 1) {
      AppAudio.play(Sound.slide);
    } else if (revealed.isNotEmpty) {
      AppAudio.play(Sound.pop);
    }
  }

  void _tap(int i) {
    final g = _game;
    if (g == null || g.over) return;
    if (g.revealed[i]) {
      final r = g.chord(i);
      if (r.isNotEmpty || g.status == MineStatus.lost) setState(() => _afterMove(r, i));
      return;
    }
    if (_flagMode) {
      _flag(i);
      return;
    }
    if (g.flagged[i]) return;
    setState(() => _afterMove(g.reveal(i), i));
  }

  void _flag(int i) {
    final g = _game;
    if (g == null || g.over) return;
    if (g.toggleFlag(i)) {
      AppAudio.play(Sound.tap);
      AppAudio.haptic();
      setState(() {
        _delay.clear();
        _moveSeq++;
      });
    }
  }

  void _hint() {
    final g = _game;
    if (g == null || g.over || _hintsUsed >= _maxHints) return;
    final r = g.hint();
    if (r.isEmpty) return;
    _hintsUsed++;
    setState(() => _afterMove(r, r.first));
  }

  void _finish(bool won) {
    final t = _tier!;
    final c = mineConfigs[t]!;
    String message;
    int? stars;
    if (won) {
      stars = starsForTime(_elapsed, c.parSeconds, usedHint: _hintsUsed > 0);
      final best = Storage.getInt(_bestKey(t));
      final isBest = best == 0 || _elapsed < best;
      if (isBest) Storage.setInt(_bestKey(t), _elapsed);
      Storage.setInt(_winsKey(t), Storage.getInt(_winsKey(t)) + 1);
      Rewards.onLevelComplete('minesweeper', '${t.name}-win', stars: stars);
      message = '${tr('minesweeper.cleared_in', {'tier': _tierLabel(t), 'time': _fmt(_elapsed)})}${isBest ? '\n${tr('minesweeper.new_best')}' : ''}';
    } else {
      Rewards.onGameEnd('minesweeper', won: false);
      message = tr('minesweeper.hit_mine', {'time': _fmt(_elapsed)});
    }
    _endTimer?.cancel();
    _endTimer = Timer(Duration(milliseconds: won ? 500 : 1300), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: won ? tr('minesweeper.field_cleared') : tr('minesweeper.boom'),
        emoji: won ? '🏆' : '💥',
        stars: stars,
        message: message,
        color: won ? Pal.gold : Pal.danger,
        actions: [
          DialogAction(tr('common.play_again'), () => _start(t), primary: true),
          DialogAction(tr('common.menu'), _menu),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final inGame = _game != null;
    return GameScaffold(
      title: inGame ? '${tr('minesweeper.title')} · ${_tierLabel(_tier!)}' : tr('minesweeper.title'),
      tint: _tint,
      onBack: inGame ? _menu : null,
      actions: inGame ? [BarAction(icon: Icons.refresh_rounded, tooltip: tr('common.restart'), onTap: () => _start(_tier!))] : null,
      body: inGame ? _gameBody() : _menuBody(),
    );
  }

  // ---------------------------------------------------------------- menu

  Widget _menuBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4),
          child: Text(tr('minesweeper.intro'),
              style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
        ),
        for (final (n, t) in MineTier.values.indexed) _tierCard(t, n),
      ],
    );
  }

  Widget _tierCard(MineTier t, int n) {
    final c = mineConfigs[t]!;
    final best = Storage.getInt(_bestKey(t));
    final wins = Storage.getInt(_winsKey(t));
    final col = Pal.accents[n % Pal.accents.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _start(t),
        blur: 0,
        glow: _tint.withValues(alpha: 0.25),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Pal.accent(_tint),
              boxShadow: [BoxShadow(color: _tint.withValues(alpha: 0.4), blurRadius: 14)],
            ),
            child: Icon(_tierIcons[t], color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tierLabel(t), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(tr('minesweeper.board_info', {'cols': c.cols, 'rows': c.rows, 'n': c.mines}), style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  best > 0
                      ? tr('minesweeper.best_wins', {'time': _fmt(best), 'n': wins})
                      : (wins > 0 ? tr('minesweeper.wins', {'n': wins}) : tr('minesweeper.not_cleared')),
                  style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.play_arrow_rounded, color: Pal.text, size: 30),
        ]),
      ).animate().fadeIn(delay: (80 * n).ms, duration: 350.ms).slideX(begin: 0.1, end: 0),
    );
  }

  // ---------------------------------------------------------------- game

  Widget _gameBody() {
    final g = _game!;
    final best = Storage.getInt(_bestKey(_tier!));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Row(children: [
          Expanded(child: _stat(Icons.flag_rounded, '${g.minesLeft}', tr('minesweeper.mines'), Pal.danger, key: const ValueKey('minesLeft'))),
          const SizedBox(width: 8),
          Expanded(child: _stat(Icons.timer_rounded, _fmt(_elapsed), tr('common.time'), _tint, key: const ValueKey('timer'))),
          const SizedBox(width: 8),
          Expanded(child: _stat(Icons.emoji_events_rounded, best > 0 ? _fmt(best) : '--:--', tr('common.best'), Pal.gold)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (ctx, box) {
          const pad = 10.0;
          final fit = math.min((box.maxWidth - pad * 2 - 4) / g.cols, (box.maxHeight - pad * 2 - 4) / g.rows);
          final cell = fit.clamp(30.0, 46.0).toDouble();
          final w = cell * g.cols + pad * 2 + 2, h = cell * g.rows + pad * 2 + 2;
          final board = _board(g, cell, pad);
          if (w <= box.maxWidth && h <= box.maxHeight) return Center(child: board);
          return InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth, minHeight: box.maxHeight),
              child: Center(child: board),
            ),
          );
        }),
      ),
      _controls(g),
    ]);
  }

  Widget _stat(IconData icon, String value, String label, Color c, {Key? key}) {
    return GlassCard(
      blur: 0,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 6),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                key: key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _board(MineGame g, double cell, double pad) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: Pal.glassBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var r = 0; r < g.rows; r++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var c = 0; c < g.cols; c++) _cell(g, g.idx(r, c), cell),
          ]),
      ]),
    );
  }

  Widget _cell(MineGame g, int i, double size) {
    final revealed = g.revealed[i];
    final flagged = g.flagged[i];
    final exploded = g.explodedAt == i;
    final delay = _delay[i];
    Widget inner;
    if (revealed && g.mine[i]) {
      inner = Container(
        decoration: _insetDeco(exploded ? const Color(0xFFB91C1C) : const Color(0xFF3A2250)),
        alignment: Alignment.center,
        child: Text('💣', style: TextStyle(fontSize: size * 0.5)),
      );
      if (delay != null || exploded) {
        inner = inner
            .animate(key: ValueKey('m$i$_moveSeq'), delay: (exploded ? 0 : delay ?? 0).ms)
            .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 600.ms)
            .tint(color: exploded ? Colors.orangeAccent : Colors.transparent, duration: 300.ms);
      }
    } else if (revealed) {
      final n = g.adj[i];
      inner = Container(
        decoration: _insetDeco(const Color(0xFF1A1340)),
        alignment: Alignment.center,
        child: n == 0
            ? null
            : Text('$n',
                style: TextStyle(
                  color: _numColors[n],
                  fontSize: size * 0.52,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: _numColors[n].withValues(alpha: 0.6), blurRadius: 6)],
                )),
      );
      if (delay != null) {
        inner = inner
            .animate(key: ValueKey('r$i$_moveSeq'), delay: delay.ms)
            .fadeIn(duration: 160.ms)
            .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 240.ms);
      }
    } else {
      inner = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C6FD8), Color(0xFF4B3FA0)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Stack(children: [
          // Glossy highlight on the upper half.
          Positioned(
            left: size * 0.08,
            right: size * 0.08,
            top: size * 0.05,
            height: size * 0.34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ),
          if (flagged)
            Center(
              child: Text('🚩', style: TextStyle(fontSize: size * 0.5))
                  .animate(key: ValueKey('f$i$_moveSeq'))
                  .scale(begin: const Offset(0, 0), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 450.ms),
            ),
        ]),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        onLongPress: () => _flag(i),
        child: Padding(padding: const EdgeInsets.all(1.5), child: inner),
      ),
    );
  }

  BoxDecoration _insetDeco(Color base) => BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(base, Colors.black, 0.35)!, base],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      );

  Widget _controls(MineGame g) {
    final left = _maxHints - _hintsUsed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onTap: () => setState(() => _flagMode = !_flagMode),
            child: GlassCard(
              key: const ValueKey('modeToggle'),
              blur: 0,
              radius: 22,
              glow: _flagMode ? _tint : null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_flagMode ? Icons.flag_rounded : Icons.touch_app_rounded, color: _flagMode ? _tint : Pal.text, size: 22),
                const SizedBox(width: 8),
                Text(_flagMode ? tr('minesweeper.flag') : tr('minesweeper.reveal'),
                    style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            onTap: left > 0 ? _hint : () {},
            child: Opacity(
              opacity: left > 0 ? 1 : 0.45,
              child: GlassCard(
                key: const ValueKey('hintButton'),
                blur: 0,
                radius: 22,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lightbulb_rounded, color: Pal.gold, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('${tr('common.hint')} ($left)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
