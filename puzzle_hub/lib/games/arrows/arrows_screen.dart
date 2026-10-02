import 'package:flutter/material.dart';

import 'logic/arrows_logic.dart';
import 'progress.dart';

class ArrowsScreen extends StatefulWidget {
  const ArrowsScreen({super.key});

  @override
  State<ArrowsScreen> createState() => _ArrowsScreenState();
}

class _ArrowsScreenState extends State<ArrowsScreen> {
  Future<void> _open(int level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArrowsGamePage(level: level)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Arrows')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 90, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: ArrowsLevels.count,
        itemBuilder: (context, i) {
          final level = i + 1;
          final unlocked = ArrowsProgress.isUnlocked(level);
          final done = ArrowsProgress.isDone(level);
          return Material(
            color: done
                ? cs.primaryContainer
                : unlocked
                    ? cs.surfaceContainerHighest
                    : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: unlocked ? () => _open(level) : null,
              child: Center(
                child: unlocked
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$level',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (done)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var s = 0; s < 3; s++)
                                  Icon(
                                      s < ArrowsProgress.stars(level)
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 13,
                                      color: Colors.amber),
                              ],
                            ),
                        ],
                      )
                    : Icon(Icons.lock, color: cs.outline),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ArrowsGamePage extends StatefulWidget {
  const ArrowsGamePage({super.key, required this.level});
  final int level;

  @override
  State<ArrowsGamePage> createState() => _ArrowsGamePageState();
}

class _ArrowsGamePageState extends State<ArrowsGamePage> {
  static const maxLives = 3;
  late int level = widget.level;
  late ArrowsBoard board;
  late List<ArrowPiece> all;
  final Set<int> removed = {};
  final Map<int, int> shakes = {};
  int lives = maxLives;
  int moves = 0;
  int? hinted;
  bool over = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    board = ArrowsLevels.generate(level);
    all = board.pieces;
    removed.clear();
    shakes.clear();
    lives = maxLives;
    moves = 0;
    hinted = null;
    over = false;
  }

  void _tap(ArrowPiece p) {
    if (over || removed.contains(p.id)) return;
    final res = board.tap(p.r, p.c);
    setState(() {
      hinted = null;
      if (res == true) {
        removed.add(p.id);
        moves++;
      } else if (res == false) {
        shakes[p.id] = (shakes[p.id] ?? 0) + 1;
        lives--;
      }
    });
    if (board.isCleared) {
      over = true;
      ArrowsProgress.complete(level, lives.clamp(1, 3));
      Future.delayed(const Duration(milliseconds: 500), _showWin);
    } else if (lives <= 0) {
      over = true;
      Future.delayed(const Duration(milliseconds: 350), _showLose);
    }
  }

  void _showWin() {
    if (!mounted) return;
    final hasNext = level < ArrowsLevels.count;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Level cleared!'),
        content: Text('Lives left: $lives'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Levels')),
          if (hasNext)
            FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    level++;
                    _load();
                  });
                },
                child: const Text('Next level')),
        ],
      ),
    );
  }

  void _showLose() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of lives'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Levels')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(_load);
              },
              child: const Text('Retry')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = board.size;
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $level'),
        actions: [
          IconButton(
              tooltip: 'Hint',
              icon: const Icon(Icons.lightbulb_outline),
              onPressed: over
                  ? null
                  : () => setState(() => hinted = board.hint()?.id)),
          IconButton(
              tooltip: 'Restart',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    for (var i = 0; i < maxLives; i++)
                      Icon(i < lives ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent),
                  ]),
                  Text('Moves $moves  |  Left ${board.remaining}'),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (context, box) {
                    final side = box.biggest.shortestSide;
                    final cell = side / n;
                    return SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          for (final p in all)
                            Positioned(
                              key: ValueKey('${level}_${p.id}'),
                              left: p.c * cell,
                              top: p.r * cell,
                              width: cell,
                              height: cell,
                              child: _ArrowTile(
                                piece: p,
                                n: n,
                                removed: removed.contains(p.id),
                                shake: shakes[p.id] ?? 0,
                                hinted: hinted == p.id,
                                onTap: () => _tap(p),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowTile extends StatefulWidget {
  const _ArrowTile(
      {required this.piece,
      required this.n,
      required this.removed,
      required this.shake,
      required this.hinted,
      required this.onTap});
  final ArrowPiece piece;
  final int n;
  final bool removed, hinted;
  final int shake;
  final VoidCallback onTap;

  @override
  State<_ArrowTile> createState() => _ArrowTileState();
}

class _ArrowTileState extends State<_ArrowTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void didUpdateWidget(_ArrowTile old) {
    super.didUpdateWidget(old);
    if (widget.shake != old.shake) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  static IconData _icon(Dir d) => switch (d) {
        Dir.up => Icons.arrow_upward_rounded,
        Dir.down => Icons.arrow_downward_rounded,
        Dir.left => Icons.arrow_back_rounded,
        Dir.right => Icons.arrow_forward_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = widget.piece;
    final cs = Theme.of(context).colorScheme;
    final dist = widget.n.toDouble() + 1;
    final offset =
        widget.removed ? Offset(p.dir.dc * dist, p.dir.dr * dist) : Offset.zero;
    return IgnorePointer(
      ignoring: widget.removed,
      child: AnimatedSlide(
        offset: offset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeIn,
        child: AnimatedOpacity(
          opacity: widget.removed ? 0 : 1,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeIn,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final dx = (1 - _shake.value) *
                  8 *
                  (_shake.isAnimating
                      ? ((_shake.value * 6).floor().isEven ? 1 : -1)
                      : 0);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: GestureDetector(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: widget.hinted ? Colors.amber : cs.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: widget.hinted
                        ? [
                            BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.7),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: LayoutBuilder(
                      builder: (_, b) => Icon(_icon(p.dir),
                          size: b.biggest.shortestSide * 0.75,
                          color: widget.hinted ? Colors.black87 : cs.onPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
