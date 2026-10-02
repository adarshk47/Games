import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/sudoku_logic.dart';

const _saveKey = 'sudoku.save';
String _bestKey(Difficulty d) => 'sudoku.best.${d.name}';
String _dailyKey(DateTime d) => 'sudoku.daily.${dailySeed(d)}';

String fmtTime(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

Difficulty _diffFromSave(Object? d) {
  if (d is int) return Difficulty.values[d.clamp(0, Difficulty.values.length - 1)];
  return difficultyFromName('$d');
}

int _bestFor(Difficulty d) {
  final v = _bestFor(d);
  if (v > 0 || d != Difficulty.extreme) return v;
  return Storage.getInt('sudoku.best.expert');
}

class _Game {
  final Difficulty difficulty;
  final bool daily;
  final List<int> puzzle, solution;
  List<int> cur;
  List<int> notes;
  int mistakes, hints, elapsed;
  final List<List<List<int>>> undo = [];

  _Game(this.difficulty, this.daily, this.puzzle, this.solution,
      {List<int>? cur, List<int>? notes, this.mistakes = 0, this.hints = 0, this.elapsed = 0})
      : cur = cur ?? List<int>.from(puzzle),
        notes = notes ?? List<int>.filled(81, 0);

  int get maxHints => difficulty.maxHints;
  int get maxMistakes => difficulty.maxMistakes; // 0 = unlimited

  bool get solved {
    for (var i = 0; i < 81; i++) {
      if (cur[i] != solution[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'd': difficulty.index,
        'daily': daily,
        'p': puzzle,
        's': solution,
        'c': cur,
        'n': notes,
        'm': mistakes,
        'h': hints,
        't': elapsed,
      };

  static _Game? fromJson(String s) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      List<int> l(String k) => (j[k] as List).cast<int>();
      return _Game(_diffFromSave(j['d']), j['daily'] as bool, l('p'), l('s'),
          cur: l('c'), notes: l('n'), mistakes: j['m'] as int, hints: j['h'] as int, elapsed: j['t'] as int);
    } catch (_) {
      return null;
    }
  }
}

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> with TickerProviderStateMixin {
  static const _tint = Color(0xFF4DA8FF);
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _flashCell = -1;
  int _pulseOrigin = 0;
  Set<int> _pulseCells = const {};

  _Game? _g;
  bool _loading = false;
  bool _over = false;
  bool _won = false;
  bool _notesMode = false;
  int _sel = -1;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _save();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _save() {
    final g = _g;
    if (g == null) return;
    if (_over || _won) {
      Storage.setString(_saveKey, '');
    } else {
      Storage.setString(_saveKey, jsonEncode(g.toJson()));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_g == null || _over || _won) return;
      setState(() => _g!.elapsed++);
      if (_g!.elapsed % 5 == 0) _save();
    });
  }

  Future<void> _newGame(Difficulty d, {bool daily = false}) async {
    setState(() => _loading = true);
    final seed = daily ? dailySeed(DateTime.now()) : -1;
    final r = await compute(generateForIsolate, [d.index, seed]);
    if (!mounted) return;
    setState(() {
      _g = _Game(d, daily, r['puzzle']!, r['solution']!);
      _loading = false;
      _over = _won = _notesMode = false;
      _sel = -1;
    });
    _save();
    _startTimer();
  }

  void _resume(_Game g) {
    setState(() {
      _g = g;
      _over = _won = _notesMode = false;
      _sel = -1;
    });
    _startTimer();
  }

  void _snapshot() {
    final g = _g!;
    g.undo.add([List<int>.from(g.cur), List<int>.from(g.notes)]);
    if (g.undo.length > 200) g.undo.removeAt(0);
  }

  bool get _active => _g != null && !_over && !_won;

  void _place(int v) {
    if (!_active || _sel < 0) return;
    final g = _g!;
    if (g.puzzle[_sel] != 0 || g.cur[_sel] == g.solution[_sel]) return;
    if (_notesMode && g.cur[_sel] != 0) return;
    setState(() {
      _snapshot();
      if (_notesMode) {
        AppAudio.play(Sound.tap);
        g.notes[_sel] ^= 1 << v;
      } else {
        g.cur[_sel] = v;
        g.notes[_sel] = 0;
        if (v != g.solution[_sel]) {
          g.mistakes++;
          _mistakeFx(_sel);
          AppAudio.play(Sound.fail);
          AppAudio.haptic(true);
          if (g.maxMistakes > 0 && g.mistakes >= g.maxMistakes) _over = true;
        } else {
          AppAudio.play(Sound.pop);
          _clearPeerNotes(_sel, v);
        }
      }
    });
    if (!_notesMode && v == g.solution[_sel]) _celebrate(_sel);
    _afterMove();
  }

  void _clearPeerNotes(int i, int v) {
    final g = _g!;
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 81; k++) {
      if (k ~/ 9 == r || k % 9 == c || (k ~/ 27 == r ~/ 3 && (k % 9) ~/ 3 == c ~/ 3)) {
        g.notes[k] &= ~(1 << v);
      }
    }
  }

  void _erase() {
    if (!_active || _sel < 0) return;
    final g = _g!;
    if (g.puzzle[_sel] != 0 || g.cur[_sel] == g.solution[_sel]) return;
    AppAudio.play(Sound.tap);
    setState(() {
      _snapshot();
      g.cur[_sel] = 0;
      g.notes[_sel] = 0;
    });
    _save();
  }

  void _undo() {
    final g = _g;
    if (!_active || g == null || g.undo.isEmpty) return;
    AppAudio.play(Sound.tap);
    setState(() {
      final s = g.undo.removeLast();
      g.cur = s[0];
      g.notes = s[1];
    });
    _save();
  }

  void _hint() {
    final g = _g;
    if (!_active || g == null || g.hints >= g.maxHints) return;
    var i = _sel;
    if (i < 0 || g.cur[i] == g.solution[i]) {
      i = List.generate(81, (k) => k).firstWhere((k) => g.cur[k] != g.solution[k], orElse: () => -1);
    }
    if (i < 0) return;
    final cell = i;
    AppAudio.play(Sound.pop);
    setState(() {
      _snapshot();
      g.cur[cell] = g.solution[cell];
      g.notes[cell] = 0;
      g.hints++;
      _sel = cell;
      _clearPeerNotes(cell, g.solution[cell]);
    });
    _celebrate(cell);
    _afterMove();
  }

  void _afterMove() {
    final g = _g!;
    if (_over) {
      AppAudio.play(Sound.fail);
      _save();
      Rewards.onGameEnd('sudoku', won: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd(false));
    } else if (g.solved) {
      setState(() => _won = true);
      var newBest = false;
      final prev = _bestFor(g.difficulty);
      if (!g.daily && (prev == 0 || g.elapsed < prev)) {
        Storage.setInt(_bestKey(g.difficulty), g.elapsed);
        newBest = true;
      }
      if (g.daily) Storage.setInt(_dailyKey(DateTime.now()), g.elapsed);
      _save();
      Rewards.onLevelComplete('sudoku', g.daily ? 'daily-${dailySeed(DateTime.now())}' : g.difficulty.name,
          stars: _starsFor(g));
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd(true, newBest: newBest));
    } else {
      _save();
    }
  }

  int _starsFor(_Game g) {
    var stars = 3;
    if (g.mistakes > 0) stars--;
    if (g.hints > 1) stars--;
    return stars < 1 ? 1 : stars;
  }

  void _showEnd(bool win, {bool newBest = false}) {
    if (!mounted) return;
    final g = _g!;
    final stars = _starsFor(g);
    showPremiumDialog(
      context,
      title: win ? 'Solved!' : 'Game over',
      emoji: win ? '🏆' : '💔',
      color: win ? Pal.gold : Pal.danger,
      stars: win ? stars : null,
      message: win
          ? 'Time ${fmtTime(g.elapsed)}${newBest ? '\nNew best time!' : ''}'
          : 'You made ${g.maxMistakes} mistakes.',
      actions: [
        DialogAction('Menu', () => setState(() => _g = null)),
        DialogAction('New game', () => _newGame(g.difficulty), primary: true),
      ],
    );
  }

  // ---------------------------------------------------------------- effects

  /// Cells forming a completed row/col/box/digit that include [i].
  Set<int> _completedUnits(int i) {
    final g = _g!;
    final out = <int>{};
    bool ok(Iterable<int> cells) => cells.every((k) => g.cur[k] == g.solution[k]);
    final r = i ~/ 9, c = i % 9;
    final row = [for (var k = 0; k < 9; k++) r * 9 + k];
    final col = [for (var k = 0; k < 9; k++) k * 9 + c];
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    final box = [for (var k = 0; k < 9; k++) (br + k ~/ 3) * 9 + bc + k % 3];
    if (ok(row)) out.addAll(row);
    if (ok(col)) out.addAll(col);
    if (ok(box)) out.addAll(box);
    final v = g.solution[i];
    final digit = [for (var k = 0; k < 81; k++) if (g.solution[k] == v) k];
    if (ok(digit)) out.addAll(digit);
    return out;
  }

  void _celebrate(int i) {
    final cells = _completedUnits(i);
    if (cells.isEmpty) return;
    AppAudio.play(Sound.success);
    _pulseCells = cells;
    _pulseOrigin = i;
    _pulse.forward(from: 0);
  }

  void _mistakeFx(int i) {
    _flashCell = i;
    _shake.forward(from: 0);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    final g = _g;
    if (g == null) return _menu(context);
    return GameScaffold(
      title: '${g.difficulty.label}${g.daily ? ' · Daily' : ''}',
      tint: _tint,
      onBack: () {
        _save();
        setState(() => _g = null);
      },
      actions: [
        BarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'New game',
          onTap: () => _newGame(g.difficulty, daily: g.daily),
        ),
      ],
      body: _gameBody(context, g),
    );
  }

  Widget _loadingView() {
    return GameScaffold(
      title: 'Sudoku',
      tint: _tint,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Column(children: [
              for (var r = 0; r < 3; r++)
                Expanded(
                  child: Row(children: [
                    for (var c = 0; c < 3; c++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            gradient: Pal.accent(_tint),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )
                            .animate(onPlay: (a) => a.repeat(reverse: true), delay: ((r + c) * 140).ms)
                            .fade(begin: 0.2, end: 1, duration: 600.ms)
                            .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 600.ms),
                      ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Generating puzzle...',
              style: TextStyle(color: Pal.textDim, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4))
              .animate(onPlay: (a) => a.repeat(reverse: true))
              .fade(begin: 0.5, end: 1, duration: 900.ms),
        ]),
      ),
    );
  }

  static const _diffColors = <Difficulty, Color>{
    Difficulty.easy: Color(0xFF2EE6A8),
    Difficulty.medium: Color(0xFFFFC857),
    Difficulty.hard: Color(0xFFFF7A59),
    Difficulty.extreme: Color(0xFFFF6FB5),
  };

  Widget _hero({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      blur: 0,
      glow: color,
      radius: 26,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.42), color.withValues(alpha: 0.10)],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: Pal.accent(color),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16)],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Pal.text, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Pal.text, size: 28),
      ]),
    );
  }

  Widget _menu(BuildContext context) {
    final saved = Storage.getString(_saveKey);
    final savedGame = (saved == null || saved.isEmpty) ? null : _Game.fromJson(saved);
    final dailyDone = Storage.getInt(_dailyKey(DateTime.now()));
    final items = <Widget>[
      if (savedGame != null)
        _hero(
          icon: Icons.play_arrow_rounded,
          title: 'Resume ${savedGame.difficulty.label}${savedGame.daily ? ' (Daily)' : ''}',
          subtitle: '${fmtTime(savedGame.elapsed)}  ·  ${savedGame.mistakes} mistakes',
          color: Pal.success,
          onTap: () => _resume(savedGame),
        ),
      _hero(
        icon: Icons.today_rounded,
        title: 'Daily puzzle',
        subtitle: dailyDone > 0 ? 'Completed in ${fmtTime(dailyDone)}' : 'Medium · same for everyone today',
        color: Pal.gold,
        onTap: () => _newGame(Difficulty.medium, daily: true),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 8, 0, 0),
        child: Text('DIFFICULTY',
            style: TextStyle(color: Pal.textDim, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ),
      for (final d in Difficulty.values) _difficultyCard(d),
    ];
    return GameScaffold(
      title: 'Sudoku',
      tint: _tint,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => items[i]
            .animate(delay: (70 * i).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic, duration: 400.ms),
      ),
    );
  }

  Widget _difficultyCard(Difficulty d) {
    final color = _diffColors[d]!;
    final best = _bestFor(d);
    final level = d.index + 1;
    return GlassCard(
      blur: 0,
      glow: color,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: () => _newGame(d),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color.withValues(alpha: 0.26), Colors.white.withValues(alpha: 0.05)],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.label, style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
                '${d.maxHints} ${d.maxHints == 1 ? 'hint' : 'hints'} · ${d.maxMistakes == 0 ? 'unlimited mistakes' : '${d.maxMistakes} mistakes'}',
                style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.timer_outlined, size: 14, color: best > 0 ? color : Pal.textDim),
              const SizedBox(width: 4),
              Text(best > 0 ? 'Best ${fmtTime(best)}' : 'No best time yet',
                  style: TextStyle(color: best > 0 ? color : Pal.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var k = 0; k < 4; k++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: k < level ? color : Colors.white.withValues(alpha: 0.15),
                boxShadow: k < level ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)] : null,
              ),
            ),
        ]),
        const SizedBox(width: 10),
        const Icon(Icons.chevron_right_rounded, color: Pal.text),
      ]),
    );
  }

  // ------------------------------------------------------------------- game

  Widget _gameBody(BuildContext context, _Game g) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hearts(g),
              GlassCard(
                blur: 0,
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_rounded, size: 16, color: Pal.textDim),
                  const SizedBox(width: 6),
                  Text(fmtTime(g.elapsed),
                      style: const TextStyle(
                          color: Pal.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: Pal.gold),
                const SizedBox(width: 4),
                Text('${g.maxHints - g.hints}',
                    style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) {
                    final t = _shake.value;
                    final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 7) * 9 * (1 - t);
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: GlassCard(
                    blur: 0,
                    radius: 22,
                    padding: const EdgeInsets.all(6),
                    glow: _tint,
                    child: _board(g),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tool(Icons.undo_rounded, 'Undo', _undo),
              _tool(Icons.backspace_rounded, 'Erase', _erase),
              _tool(Icons.edit_rounded, _notesMode ? 'Notes on' : 'Notes',
                  () {
                    AppAudio.play(Sound.tap);
                    setState(() => _notesMode = !_notesMode);
                  },
                  highlight: _notesMode),
              _tool(Icons.lightbulb_rounded, 'Hint', _hint, badge: g.maxHints - g.hints),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
          child: Row(
            children: [
              for (var v = 1; v <= 9; v++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _padButton(g, v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hearts(_Game g) {
    if (g.maxMistakes == 0) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.favorite_rounded, size: 22, color: Pal.danger),
        const SizedBox(width: 4),
        Text('${g.mistakes} · no limit',
            style: const TextStyle(color: Pal.text, fontSize: 14, fontWeight: FontWeight.w800)),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var k = 0; k < g.maxMistakes; k++)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.elasticOut,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: k < g.maxMistakes - g.mistakes
                ? const Icon(Icons.favorite_rounded, key: ValueKey('on'), size: 24, color: Pal.danger)
                : Icon(Icons.favorite_border_rounded,
                    key: const ValueKey('off'), size: 24, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
    ]);
  }

  Widget _padButton(_Game g, int v) {
    final remaining = 9 - g.cur.where((e) => e == v).length;
    final enabled = remaining > 0;
    return Pressable(
      onTap: enabled ? () => _place(v) : () {},
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: enabled
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _notesMode
                            ? [const Color(0xFF8E7CFF), const Color(0xFF4B3AB8)]
                            : [Color.lerp(_tint, Colors.white, 0.35)!, _tint, Color.lerp(_tint, Colors.black, 0.35)!],
                        stops: _notesMode ? null : const [0, 0.5, 1],
                      )
                    : const LinearGradient(colors: [Color(0x22FFFFFF), Color(0x11FFFFFF)]),
                border: Border.all(color: Colors.white.withValues(alpha: enabled ? 0.4 : 0.1)),
                boxShadow: enabled
                    ? [BoxShadow(color: _tint.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              alignment: Alignment.center,
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('$v',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: enabled ? Colors.white : Pal.textDim.withValues(alpha: 0.4))),
                ),
              ),
            ),
          ),
          // glossy highlight
          Positioned(
            left: 3,
            right: 3,
            top: 3,
            height: 14,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: enabled ? 0.35 : 0.08), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          if (enabled)
            Positioned(
              right: -2,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Pal.bg1,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Pal.glassBorder),
                ),
                child: Text('$remaining',
                    style: const TextStyle(color: Pal.text, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, {bool highlight = false, int? badge}) {
    final c = highlight ? _tint : Pal.text;
    return Pressable(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight ? _tint.withValues(alpha: 0.28) : Pal.glass,
              border: Border.all(color: highlight ? _tint : Pal.glassBorder),
              boxShadow: highlight ? [BoxShadow(color: _tint.withValues(alpha: 0.5), blurRadius: 14)] : null,
            ),
            child: Icon(icon, size: 22, color: c),
          ),
          if (badge != null)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Pal.gold),
                child: Text('$badge',
                    style: const TextStyle(color: Pal.bg0, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: highlight ? _tint : Pal.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _board(_Game g) {
    final selV = _sel >= 0 ? g.cur[_sel] : 0;
    final sr = _sel >= 0 ? _sel ~/ 9 : -1, sc = _sel >= 0 ? _sel % 9 : -1;
    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _pulse]),
      builder: (context, _) {
        return Stack(
          children: [
            Column(
              children: [
                for (var r = 0; r < 9; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < 9; c++) Expanded(child: _cell(g, r, c, selV, sr, sc)),
                      ],
                    ),
                  ),
              ],
            ),
            const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
          ],
        );
      },
    );
  }

  Widget _cell(_Game g, int r, int c, int selV, int sr, int sc) {
    final i = r * 9 + c;
    final v = g.cur[i];
    final given = g.puzzle[i] != 0;
    final wrong = v != 0 && v != g.solution[i];
    final selected = i == _sel;
    final peer = _sel >= 0 && (r == sr || c == sc || (r ~/ 3 == sr ~/ 3 && c ~/ 3 == sc ~/ 3));
    final same = selV != 0 && v == selV;

    Color? bg;
    if (peer) bg = Colors.white.withValues(alpha: 0.07);
    if (same) bg = _tint.withValues(alpha: 0.26);
    if (selected) bg = _tint.withValues(alpha: 0.42);

    final overlays = <Widget>[];
    if (_pulseCells.contains(i) && _pulse.isAnimating) {
      final dist = (i ~/ 9 - _pulseOrigin ~/ 9).abs() + (i % 9 - _pulseOrigin % 9).abs();
      final p = ((_pulse.value * 1.7) - dist * 0.07).clamp(0.0, 1.0);
      final a = math.sin(p * math.pi);
      if (a > 0.01) {
        overlays.add(Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Pal.gold.withValues(alpha: 0.45 * a),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: Pal.gold.withValues(alpha: 0.6 * a), blurRadius: 10 * a)],
            ),
          ),
        ));
      }
    }
    if (i == _flashCell && _shake.isAnimating) {
      overlays.add(Positioned.fill(
        child: ColoredBox(color: Pal.danger.withValues(alpha: 0.6 * (1 - _shake.value))),
      ));
    }

    final Widget content;
    if (v != 0) {
      content = FittedBox(
        key: ValueKey('v$i-$v'),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text('$v',
              style: TextStyle(
                fontSize: 24,
                fontWeight: given ? FontWeight.w800 : FontWeight.w600,
                color: wrong ? Pal.danger : (given ? Pal.text : const Color(0xFF8FCBFF)),
                shadows: selected || same ? [Shadow(color: _tint.withValues(alpha: 0.9), blurRadius: 8)] : null,
              )),
        ),
      );
    } else {
      content = g.notes[i] == 0
          ? SizedBox.shrink(key: ValueKey('e$i'))
          : KeyedSubtree(key: ValueKey('n$i-${g.notes[i]}'), child: _notesGrid(g.notes[i], selV));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _sel = i),
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected ? [BoxShadow(color: _tint.withValues(alpha: 0.5), blurRadius: 10)] : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          ...overlays,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            reverseDuration: Duration.zero,
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, a) => ScaleTransition(
                scale: a, child: FadeTransition(opacity: a.drive(CurveTween(curve: Curves.easeOut)), child: child)),
            child: content,
          ),
        ]),
      ),
    );
  }

  Widget _notesGrid(int mask, int selV) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: Center(
                        child: (mask & (1 << (r * 3 + c + 1))) != 0
                            ? FittedBox(
                                child: Text('${r * 3 + c + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: r * 3 + c + 1 == selV ? FontWeight.w900 : FontWeight.w500,
                                        color: r * 3 + c + 1 == selV ? Pal.gold : Pal.textDim)))
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 9, ch = size.height / 9;
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    final thick = Paint()
      ..color = const Color(0xFF4DA8FF).withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var k = 1; k < 9; k++) {
      if (k % 3 == 0) continue;
      canvas.drawLine(Offset(k * cw, 4), Offset(k * cw, size.height - 4), thin);
      canvas.drawLine(Offset(4, k * ch), Offset(size.width - 4, k * ch), thin);
    }
    for (var k = 3; k < 9; k += 3) {
      canvas.drawLine(Offset(k * cw, 2), Offset(k * cw, size.height - 2), thick);
      canvas.drawLine(Offset(2, k * ch), Offset(size.width - 2, k * ch), thick);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
