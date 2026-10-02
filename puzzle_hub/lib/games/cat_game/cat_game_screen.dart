import 'package:flutter/material.dart';

import '../../core/storage.dart';
import 'logic/cat_logic.dart';

const _skins = ['🐱', '😺', '😸', '🐈'];
const _skinStars = [0, 6, 15, 30];
const _bg = Color(0xFFFFF1E6);
const _pink = Color(0xFFFF8FAB);
const _teal = Color(0xFF4CC9B0);

int _starsOf(int level) => Storage.getInt('cat_game.stars.$level');
int _totalStars() {
  var t = 0;
  for (var i = 0; i < CatLevels.count; i++) {
    t += _starsOf(i);
  }
  return t;
}

class CatGameScreen extends StatefulWidget {
  const CatGameScreen({super.key});

  @override
  State<CatGameScreen> createState() => _CatGameScreenState();
}

class _CatGameScreenState extends State<CatGameScreen> {
  @override
  Widget build(BuildContext context) {
    final total = _totalStars();
    final skin = Storage.getInt('cat_game.skin').clamp(0, _skins.length - 1);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Cat & Fish'),
        backgroundColor: _pink,
        actions: [
          TextButton(
            onPressed: () async {
              await showDialog<void>(
                  context: context, builder: (_) => const _SkinDialog());
              setState(() {});
            },
            child: Text('${_skins[skin]}  ⭐$total',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 90, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: CatLevels.count,
        itemBuilder: (_, i) {
          final s = _starsOf(i);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => _LevelScreen(index: i)));
              setState(() {});
            },
            child: Container(
              decoration: BoxDecoration(
                  color: s > 0 ? const Color(0xFFFFE08A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _pink, width: 2)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text('⭐' * s + '☆' * (3 - s),
                    style: const TextStyle(fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SkinDialog extends StatelessWidget {
  const _SkinDialog();

  @override
  Widget build(BuildContext context) {
    final total = _totalStars();
    return StatefulBuilder(builder: (context, set) {
      final cur = Storage.getInt('cat_game.skin');
      return AlertDialog(
        title: Text('Cat skins (⭐$total)'),
        content: Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < _skins.length; i++)
            InkWell(
              onTap: total >= _skinStars[i]
                  ? () {
                      Storage.setInt('cat_game.skin', i);
                      set(() {});
                    }
                  : null,
              child: Container(
                width: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: cur == i ? _teal : Colors.black12, width: 3),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text(total >= _skinStars[i] ? _skins[i] : '🔒',
                      style: const TextStyle(fontSize: 30)),
                  Text('⭐${_skinStars[i]}',
                      style: const TextStyle(fontSize: 11)),
                ]),
              ),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
    });
  }
}

class _LevelScreen extends StatefulWidget {
  const _LevelScreen({required this.index});
  final int index;

  @override
  State<_LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<_LevelScreen> {
  late int index = widget.index;
  late CatLevel level;
  late int cat;
  final List<int> history = [];
  int moves = 0;
  bool busy = false;
  bool dead = false;
  Offset _dragStart = Offset.zero;
  Duration _anim = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    level = CatLevels.level(index);
    cat = level.start;
    history.clear();
    moves = 0;
    busy = false;
    dead = false;
    _anim = Duration.zero;
  }

  Future<void> _move(Dir d) async {
    if (busy) return;
    final res = level.slide(cat, d);
    if (res.outcome == SlideOutcome.blocked) return;
    busy = true;
    final from = cat;
    setState(() {
      _anim = Duration(milliseconds: 90 * res.path.length + 60);
      cat = res.end;
    });
    await Future<void>.delayed(_anim + const Duration(milliseconds: 80));
    if (!mounted) return;
    if (res.outcome == SlideOutcome.dog) {
      setState(() => dead = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _anim = const Duration(milliseconds: 200);
        cat = from;
        dead = false;
        busy = false;
      });
      return;
    }
    setState(() {
      history.add(from);
      moves++;
      busy = res.outcome == SlideOutcome.fish;
    });
    if (res.outcome == SlideOutcome.fish) _win();
  }

  void _undo() {
    if (busy || history.isEmpty) return;
    setState(() {
      _anim = const Duration(milliseconds: 200);
      cat = history.removeLast();
      moves--;
    });
  }

  void _restart() => setState(_load);

  Future<void> _win() async {
    final par = level.optimal!;
    final stars = starsFor(moves, par);
    final before = _totalStars();
    Storage.setBest('cat_game.stars.$index', stars);
    final after = _totalStars();
    final unlocked = [
      for (var i = 0; i < _skins.length; i++)
        if (before < _skinStars[i] && after >= _skinStars[i]) _skins[i]
    ];
    final next = index + 1 < CatLevels.count;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('${'⭐' * stars}${'☆' * (3 - stars)}'),
        content: Text('Yum! Caught the fish in $moves moves (par $par).'
            '${unlocked.isEmpty ? '' : '\nNew skin unlocked: ${unlocked.join(' ')}'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'menu'),
              child: const Text('Levels')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'retry'),
              child: const Text('Retry')),
          if (next)
            FilledButton(
                onPressed: () => Navigator.pop(context, 'next'),
                child: const Text('Next')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'next') {
      index++;
      _restart();
    } else if (action == 'retry') {
      _restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = _skins[Storage.getInt('cat_game.skin').clamp(0, 3)];
    final par = level.optimal ?? 0;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: Text('Level ${index + 1}'), backgroundColor: _pink),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Moves: $moves   Par: $par',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: level.width / level.height,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(builder: (context, box) {
                    final cw = box.maxWidth / level.width;
                    final ch = box.maxHeight / level.height;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _dragStart = d.localPosition,
                      onPanUpdate: (d) {
                        final delta = d.localPosition - _dragStart;
                        if (delta.distance > 24) {
                          _dragStart = d.localPosition;
                          if (delta.dx.abs() > delta.dy.abs()) {
                            _move(delta.dx > 0 ? Dir.right : Dir.left);
                          } else {
                            _move(delta.dy > 0 ? Dir.down : Dir.up);
                          }
                        }
                      },
                      child: Stack(children: [
                        Positioned.fill(
                            child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12)),
                        )),
                        for (var i = 0; i < level.cells.length; i++)
                          Positioned(
                            left: (i % level.width) * cw,
                            top: (i ~/ level.width) * ch,
                            width: cw,
                            height: ch,
                            child: _tile(i, cw),
                          ),
                        AnimatedPositioned(
                          duration: _anim,
                          curve: Curves.easeOut,
                          left: (cat % level.width) * cw,
                          top: (cat ~/ level.width) * ch,
                          width: cw,
                          height: ch,
                          child: Center(
                              child: Text(dead ? '😵' : skin,
                                  style: TextStyle(fontSize: cw * 0.7))),
                        ),
                      ]),
                    );
                  }),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo')),
              const SizedBox(width: 16),
              FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart')),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Swipe to slide. Avoid the dogs!'),
          ),
        ]),
      ),
    );
  }

  Widget _tile(int i, double size) {
    String? e;
    switch (level.cells[i]) {
      case Cell.wall:
        e = '📦';
      case Cell.yarn:
        e = '🧶';
      case Cell.dog:
        e = '🐶';
      case Cell.empty:
        break;
    }
    if (i == level.fish) e = '🐟';
    final dark = (i % level.width + i ~/ level.width) % 2 == 0;
    return Container(
      color: dark ? const Color(0xFFFFF8F0) : null,
      alignment: Alignment.center,
      child: e == null ? null : Text(e, style: TextStyle(fontSize: size * 0.6)),
    );
  }
}
