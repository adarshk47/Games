import 'package:flutter/material.dart';

import '../../core/storage.dart';
import 'logic/ball_sort_logic.dart';

const _kLevelKey = 'ball_sort.level';
const _kUnlockedKey = 'ball_sort.unlocked';
const _kMarkersKey = 'ball_sort.markers';

const _palette = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
  Color(0xFF00ACC1), // cyan
  Color(0xFFEC407A), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF9E9E9E), // grey
  Color(0xFF7CB342), // lime
  Color(0xFF1A237E), // navy
];

const _shapes = <IconData>[
  Icons.circle,
  Icons.change_history,
  Icons.square,
  Icons.star,
  Icons.favorite,
  Icons.diamond,
  Icons.hexagon,
  Icons.add,
  Icons.close,
  Icons.remove,
  Icons.bolt,
  Icons.crop_square,
];

class BallSortScreen extends StatefulWidget {
  const BallSortScreen({super.key});

  @override
  State<BallSortScreen> createState() => _BallSortScreenState();
}

class _BallSortScreenState extends State<BallSortScreen> {
  late int _level;
  late int _unlocked;
  late bool _markers;
  late BallSortState _state;
  final List<BallSortState> _history = [];
  int? _selected;
  int _lastDest = -1;
  int _lastCount = 0;
  int _moveSerial = 0;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _unlocked = Storage.getInt(_kUnlockedKey, 1);
    _level = Storage.getInt(_kLevelKey, 1).clamp(1, _unlocked);
    _markers = Storage.getBool(_kMarkersKey);
    _load(_level);
  }

  void _load(int level) {
    _level = level;
    Storage.setInt(_kLevelKey, level);
    _state = generateLevel(level);
    _history.clear();
    _selected = null;
    _lastDest = -1;
    _won = false;
  }

  void _restart() => setState(() => _load(_level));

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _state = _history.removeLast();
      _selected = null;
      _lastDest = -1;
      _won = false;
    });
  }

  void _addTube() {
    if (!_state.canAddTube) return;
    setState(() {
      _history.add(_state.clone());
      _state.addTube();
    });
  }

  void _tap(int i) {
    if (_won) return;
    setState(() {
      final sel = _selected;
      if (sel == null) {
        if (_state.tubes[i].isNotEmpty) _selected = i;
      } else if (sel == i) {
        _selected = null;
      } else if (_state.canPour(sel, i)) {
        _history.add(_state.clone());
        _lastCount = _state.pour(sel, i);
        _lastDest = i;
        _moveSerial++;
        _selected = null;
        if (_state.isSolved) _onWin();
      } else {
        _selected = _state.tubes[i].isNotEmpty ? i : null;
      }
    });
  }

  void _onWin() {
    _won = true;
    if (_level >= _unlocked) {
      _unlocked = _level + 1;
      Storage.setInt(_kUnlockedKey, _unlocked);
    }
    final key = 'ball_sort.best_moves.$_level';
    final best = Storage.getInt(key, 0);
    if (best == 0 || _state.moves < best) Storage.setInt(key, _state.moves);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showWin();
    });
  }

  void _showWin() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Level complete!'),
        content: Text('Level $_level solved in ${_state.moves} moves.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restart();
            },
            child: const Text('Replay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _load(_level + 1));
            },
            child: const Text('Next level'),
          ),
        ],
      ),
    );
  }

  void _showLevels() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 64, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: _unlocked + 9,
          itemBuilder: (_, i) {
            final lv = i + 1;
            final locked = lv > _unlocked;
            final done = lv < _unlocked;
            return FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: lv == _level ? Theme.of(ctx).colorScheme.primary : null,
                foregroundColor: lv == _level ? Theme.of(ctx).colorScheme.onPrimary : null,
              ),
              onPressed: locked
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      setState(() => _load(lv));
                    },
              child: locked
                  ? const Icon(Icons.lock, size: 18)
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$lv'),
                      if (done) const Icon(Icons.check, size: 14),
                    ]),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _state.tubes.length;
    return Scaffold(
      appBar: AppBar(
        title: TextButton.icon(
          onPressed: _showLevels,
          icon: const Icon(Icons.grid_view),
          label: Text('Level $_level'),
        ),
        actions: [
          IconButton(
            tooltip: 'Shape markers',
            icon: Icon(_markers ? Icons.accessibility_new : Icons.accessibility_outlined),
            onPressed: () {
              setState(() => _markers = !_markers);
              Storage.setBool(_kMarkersKey, _markers);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Moves: ${_state.moves}', style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final perRow = n <= 6 ? n : (n + 1) ~/ 2;
                final ball = ((c.maxWidth - 16) / perRow / 1.35).clamp(24.0, 52.0);
                return Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: ball * 0.3,
                      runSpacing: ball * 0.6,
                      children: [
                        for (var i = 0; i < n; i++)
                          _TubeView(
                            balls: _state.tubes[i],
                            capacity: _state.capacity,
                            ball: ball,
                            lifted: _selected == i ? _state.topRun(i) : 0,
                            markers: _markers,
                            dropCount: _lastDest == i ? _lastCount : 0,
                            serial: _moveSerial,
                            onTap: () => _tap(i),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                      onPressed: _history.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo')),
                  OutlinedButton.icon(
                      onPressed: _restart, icon: const Icon(Icons.refresh), label: const Text('Restart')),
                  OutlinedButton.icon(
                      onPressed: _state.canAddTube ? _addTube : null,
                      icon: const Icon(Icons.add),
                      label: Text('Tube (${kMaxExtraTubes - _state.extraUsed})')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TubeView extends StatelessWidget {
  const _TubeView({
    required this.balls,
    required this.capacity,
    required this.ball,
    required this.lifted,
    required this.markers,
    required this.dropCount,
    required this.serial,
    required this.onTap,
  });

  final List<int> balls;
  final int capacity;
  final double ball;
  final int lifted;
  final bool markers;
  final int dropCount;
  final int serial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = ball * 1.2;
    final lift = ball * 0.9;
    final h = ball * capacity + 12;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h + lift + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: Border.all(color: scheme.outline, width: 2),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(w / 2)),
                ),
              ),
            ),
            for (var i = 0; i < balls.length; i++)
              AnimatedPositioned(
                key: ValueKey('b$i'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: (w - ball) / 2,
                bottom: 6 + i * ball + (i >= balls.length - lifted ? lift : 0),
                width: ball,
                height: ball,
                child: i >= balls.length - dropCount
                    ? TweenAnimationBuilder<double>(
                        key: ValueKey('d$serial-$i'),
                        tween: Tween(begin: -lift * 2, end: 0),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.bounceOut,
                        builder: (_, v, child) => Transform.translate(offset: Offset(0, v), child: child),
                        child: _BallView(color: balls[i], size: ball, marker: markers),
                      )
                    : _BallView(color: balls[i], size: ball, marker: markers),
              ),
          ],
        ),
      ),
    );
  }
}

class _BallView extends StatelessWidget {
  const _BallView({required this.color, required this.size, required this.marker});
  final int color;
  final double size;
  final bool marker;

  @override
  Widget build(BuildContext context) {
    final base = _palette[color % _palette.length];
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.45),
          radius: 0.9,
          colors: [
            Color.lerp(base, Colors.white, 0.65)!,
            base,
            Color.lerp(base, Colors.black, 0.45)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: marker
          ? Center(
              child: Icon(_shapes[color % _shapes.length],
                  size: size * 0.45,
                  color: base.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
            )
          : null,
    );
  }
}
