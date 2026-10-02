import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/storage.dart';
import 'logic/sudoku_logic.dart';

const _saveKey = 'sudoku.save';
String _bestKey(Difficulty d) => 'sudoku.best.${d.name}';
String _dailyKey(DateTime d) => 'sudoku.daily.${dailySeed(d)}';
const _maxMistakes = 3;
const _maxHints = 3;

String fmtTime(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

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
      return _Game(Difficulty.values[j['d'] as int], j['daily'] as bool, l('p'), l('s'),
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

class _SudokuScreenState extends State<SudokuScreen> {
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
        g.notes[_sel] ^= 1 << v;
      } else {
        g.cur[_sel] = v;
        g.notes[_sel] = 0;
        if (v != g.solution[_sel]) {
          g.mistakes++;
          if (g.mistakes >= _maxMistakes) _over = true;
        } else {
          _clearPeerNotes(_sel, v);
        }
      }
    });
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
    setState(() {
      final s = g.undo.removeLast();
      g.cur = s[0];
      g.notes = s[1];
    });
    _save();
  }

  void _hint() {
    final g = _g;
    if (!_active || g == null || g.hints >= _maxHints) return;
    var i = _sel;
    if (i < 0 || g.cur[i] == g.solution[i]) {
      i = List.generate(81, (k) => k).firstWhere((k) => g.cur[k] != g.solution[k], orElse: () => -1);
    }
    if (i < 0) return;
    final cell = i;
    setState(() {
      _snapshot();
      g.cur[cell] = g.solution[cell];
      g.notes[cell] = 0;
      g.hints++;
      _sel = cell;
      _clearPeerNotes(cell, g.solution[cell]);
    });
    _afterMove();
  }

  void _afterMove() {
    final g = _g!;
    if (_over) {
      _save();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd(false));
    } else if (g.solved) {
      setState(() => _won = true);
      var newBest = false;
      final prev = Storage.getInt(_bestKey(g.difficulty));
      if (!g.daily && (prev == 0 || g.elapsed < prev)) {
        Storage.setInt(_bestKey(g.difficulty), g.elapsed);
        newBest = true;
      }
      if (g.daily) Storage.setInt(_dailyKey(DateTime.now()), g.elapsed);
      _save();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd(true, newBest: newBest));
    } else {
      _save();
    }
  }

  void _showEnd(bool win, {bool newBest = false}) {
    if (!mounted) return;
    final g = _g!;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(win ? 'Solved!' : 'Game over'),
        content: Text(win
            ? 'Time: ${fmtTime(g.elapsed)}${newBest ? '\nNew best time!' : ''}'
            : 'You made $_maxMistakes mistakes.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _g = null);
            },
            child: const Text('Menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _newGame(g.difficulty);
            },
            child: const Text('New game'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sudoku')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating puzzle...'),
          ]),
        ),
      );
    }
    final g = _g;
    if (g == null) return _menu(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Sudoku - ${g.difficulty.label}${g.daily ? ' (Daily)' : ''}'),
        actions: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.grid_view),
            onPressed: () {
              _save();
              setState(() => _g = null);
            },
          ),
        ],
      ),
      body: SafeArea(child: _gameBody(context, g)),
    );
  }

  Widget _menu(BuildContext context) {
    final saved = Storage.getString(_saveKey);
    final savedGame = (saved == null || saved.isEmpty) ? null : _Game.fromJson(saved);
    final dailyDone = Storage.getInt(_dailyKey(DateTime.now()));
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (savedGame != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text('Resume ${savedGame.difficulty.label}${savedGame.daily ? ' (Daily)' : ''}'),
                subtitle: Text('Time ${fmtTime(savedGame.elapsed)} - ${savedGame.mistakes} mistakes'),
                onTap: () => _resume(savedGame),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Daily puzzle'),
              subtitle: Text(dailyDone > 0 ? 'Completed in ${fmtTime(dailyDone)}' : 'Medium - same for everyone today'),
              onTap: () => _newGame(Difficulty.medium, daily: true),
            ),
          ),
          const SizedBox(height: 8),
          for (final d in Difficulty.values)
            Card(
              child: ListTile(
                title: Text(d.label),
                subtitle: Text(Storage.getInt(_bestKey(d)) > 0
                    ? 'Best: ${fmtTime(Storage.getInt(_bestKey(d)))}'
                    : 'No best time yet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _newGame(d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gameBody(BuildContext context, _Game g) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mistakes: ${g.mistakes}/$_maxMistakes'),
              Text(fmtTime(g.elapsed), style: Theme.of(context).textTheme.titleMedium),
              Text('Hints: ${_maxHints - g.hints}'),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AspectRatio(aspectRatio: 1, child: _board(cs, g)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tool(Icons.undo, 'Undo', _undo),
              _tool(Icons.backspace_outlined, 'Erase', _erase),
              _tool(_notesMode ? Icons.edit : Icons.edit_outlined, _notesMode ? 'Notes: on' : 'Notes',
                  () => setState(() => _notesMode = !_notesMode),
                  highlight: _notesMode),
              _tool(Icons.lightbulb_outline, 'Hint', _hint),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Row(
            children: [
              for (var v = 1; v <= 9; v++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _padButton(g, v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _padButton(_Game g, int v) {
    final remaining = 9 - g.cur.where((e) => e == v).length;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), minimumSize: Size.zero),
      onPressed: remaining <= 0 ? null : () => _place(v),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$v', style: const TextStyle(fontSize: 22)),
        Text('$remaining', style: const TextStyle(fontSize: 10)),
      ]),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: highlight ? Theme.of(context).colorScheme.primary : null),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _board(ColorScheme cs, _Game g) {
    final selV = _sel >= 0 ? g.cur[_sel] : 0;
    final sr = _sel >= 0 ? _sel ~/ 9 : -1, sc = _sel >= 0 ? _sel % 9 : -1;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.onSurface, width: 2)),
      child: Column(
        children: [
          for (var r = 0; r < 9; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 9; c++) Expanded(child: _cell(cs, g, r, c, selV, sr, sc)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(ColorScheme cs, _Game g, int r, int c, int selV, int sr, int sc) {
    final i = r * 9 + c;
    final v = g.cur[i];
    final given = g.puzzle[i] != 0;
    final wrong = v != 0 && v != g.solution[i];
    final selected = i == _sel;
    final peer = _sel >= 0 && (r == sr || c == sc || (r ~/ 3 == sr ~/ 3 && c ~/ 3 == sc ~/ 3));
    final same = selV != 0 && v == selV;
    Color bg = cs.surface;
    if (peer) bg = cs.primaryContainer.withValues(alpha: 0.35);
    if (same) bg = cs.primaryContainer.withValues(alpha: 0.8);
    if (selected) bg = cs.primary.withValues(alpha: 0.35);
    final thick = BorderSide(color: cs.onSurface, width: 2);
    final thin = BorderSide(color: cs.outlineVariant, width: 0.5);
    return GestureDetector(
      onTap: () => setState(() => _sel = i),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: r % 3 == 0 && r != 0 ? thick : thin,
            left: c % 3 == 0 && c != 0 ? thick : thin,
            right: c == 8 ? BorderSide.none : thin,
            bottom: r == 8 ? BorderSide.none : thin,
          ),
        ),
        alignment: Alignment.center,
        child: v != 0
            ? FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text('$v',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: given ? FontWeight.bold : FontWeight.normal,
                        color: wrong ? Colors.red : (given ? cs.onSurface : cs.primary),
                      )),
                ),
              )
            : (g.notes[i] == 0 ? null : _notesGrid(cs, g.notes[i], selV)),
      ),
    );
  }

  Widget _notesGrid(ColorScheme cs, int mask, int selV) {
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
                                        fontWeight: r * 3 + c + 1 == selV ? FontWeight.bold : FontWeight.normal,
                                        color: cs.onSurfaceVariant)))
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
