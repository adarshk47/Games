import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/arrows_logic.dart';
import 'progress.dart';

const _arrowsColor = Color(0xFFFF7A59);

String _tierName(ArrowsTier t) => tr('common.tier.${t.id}');

Route<void> _fadeRoute(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

const _tierColors = {
  ArrowsTier.easy: Color(0xFF4ADE80),
  ArrowsTier.medium: Color(0xFF38BDF8),
  ArrowsTier.hard: Color(0xFFFF9F43),
  ArrowsTier.extreme: Color(0xFFFF4D6D),
};

const _tierIcons = {
  ArrowsTier.easy: Icons.spa_rounded,
  ArrowsTier.medium: Icons.bolt_rounded,
  ArrowsTier.hard: Icons.whatshot_rounded,
  ArrowsTier.extreme: Icons.local_fire_department_rounded,
};

/// Difficulty selection screen (entry point of the game).
class ArrowsScreen extends StatefulWidget {
  const ArrowsScreen({super.key});

  @override
  State<ArrowsScreen> createState() => _ArrowsScreenState();
}

class _ArrowsScreenState extends State<ArrowsScreen> {
  Future<void> _open(ArrowsTier tier) async {
    AppAudio.play(Sound.tap);
    await ArrowsProgress.setLastTier(tier);
    if (!mounted) return;
    setState(() {});
    await Navigator.of(context).push(_fadeRoute(ArrowsLevelsPage(tier: tier)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final last = ArrowsProgress.lastTier;
    return GameScaffold(
      title: tr('arrows.title'),
      tint: _arrowsColor,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(tr('arrows.choose_difficulty'),
                style: const TextStyle(
                    color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          for (final (i, t) in ArrowsTier.values.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TierCard(
                tier: t,
                last: t == last,
                onTap: () => _open(t),
              )
                  .animate(delay: (i * 90).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.last, required this.onTap});
  final ArrowsTier tier;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _tierColors[tier]!;
    final done = ArrowsProgress.completed(tier);
    final stars = ArrowsProgress.totalStars(tier);
    final frac = done / ArrowsLevels.count;
    final lo = ArrowsLevels.sizeFor(tier, 1);
    final hi = ArrowsLevels.sizeFor(tier, ArrowsLevels.count);
    return GlassCard(
      key: ValueKey('tier_${tier.id}'),
      onTap: onTap,
      glow: color,
      blur: 0,
      radius: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.08)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Pal.accent(color),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: -2)
              ],
            ),
            child: Icon(_tierIcons[tier], color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(_tierName(tier),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Pal.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ),
                  if (last) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.history_rounded,
                        color: Pal.textDim, size: 16),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                    tr(tier.lives == 1 ? 'arrows.tier_info_one' : 'arrows.tier_info_many',
                        {'lo': lo, 'hi': hi, 'n': tier.lives}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.textDim, fontSize: 13)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$done / ${ArrowsLevels.count}',
                        style: const TextStyle(
                            color: Pal.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Pal.gold, size: 16),
                      const SizedBox(width: 2),
                      Text('$stars / ${ArrowsLevels.count * 3}',
                          style: const TextStyle(
                              color: Pal.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Level grid for one difficulty tier.
class ArrowsLevelsPage extends StatefulWidget {
  const ArrowsLevelsPage({super.key, required this.tier});
  final ArrowsTier tier;

  @override
  State<ArrowsLevelsPage> createState() => _ArrowsLevelsPageState();
}

class _ArrowsLevelsPageState extends State<ArrowsLevelsPage> {
  Future<void> _open(int level) async {
    await Navigator.of(context)
        .push(_fadeRoute(ArrowsGamePage(tier: widget.tier, level: level)));
    if (mounted) setState(() {});
  }

  /// Only the first locked level can be bought; others stay locked.
  Future<void> _buy(int level) async {
    if (ArrowsProgress.firstLocked(widget.tier) != level) {
      AppAudio.haptic();
      return;
    }
    final ok = await showContinueOffer(context, OfferKind.unlockLevel);
    if (!ok || !mounted) return;
    await ArrowsProgress.buyUnlock(widget.tier, level);
    if (!mounted) return;
    setState(() {});
    await _open(level);
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    return GameScaffold(
      title: tr('arrows.grid_title', {'tier': _tierName(tier)}),
      tint: _tierColors[tier],
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 90, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: ArrowsLevels.count,
        itemBuilder: (context, i) {
          final level = i + 1;
          final unlocked = ArrowsProgress.isUnlocked(tier, level);
          final done = ArrowsProgress.isDone(tier, level);
          return _LevelTile(
            level: level,
            color: _tierColors[tier]!,
            unlocked: unlocked,
            done: done,
            stars: ArrowsProgress.stars(tier, level),
            onTap: () => unlocked ? _open(level) : _buy(level),
          )
              .animate(delay: (math.min(i, 24) * 30).ms)
              .fadeIn(duration: 350.ms)
              .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 450.ms);
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile(
      {required this.level,
      required this.color,
      required this.unlocked,
      required this.done,
      required this.stars,
      required this.onTap});
  final int level, stars;
  final Color color;
  final bool unlocked, done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(20);
    final Gradient gradient = unlocked
        ? (done
            ? Pal.accent(color)
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.38),
                  color.withValues(alpha: 0.12),
                ],
              ))
        : const LinearGradient(
            colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
          );
    final tile = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: gradient,
        border: Border.all(
            color: unlocked
                ? Colors.white.withValues(alpha: 0.4)
                : Pal.glassBorder),
        boxShadow: unlocked
            ? [
                BoxShadow(
                    color: color.withValues(alpha: done ? 0.5 : 0.28),
                    blurRadius: done ? 18 : 12,
                    spreadRadius: -2)
              ]
            : null,
      ),
      child: Center(
        child: unlocked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$level',
                      style: const TextStyle(
                          color: Pal.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  if (done)
                    StarRow(stars: stars, size: 15)
                  else
                    const SizedBox(height: 15),
                ],
              )
            : const Icon(Icons.lock_rounded, color: Pal.textDim, size: 24),
      ),
    );
    return unlocked
        ? Pressable(onTap: onTap, child: tile)
        : GestureDetector(onTap: onTap, child: Opacity(opacity: 0.7, child: tile));
  }
}

class ArrowsGamePage extends StatefulWidget {
  const ArrowsGamePage({super.key, required this.tier, required this.level});
  final ArrowsTier tier;
  final int level;

  @override
  State<ArrowsGamePage> createState() => _ArrowsGamePageState();
}

class _ArrowsGamePageState extends State<ArrowsGamePage> {
  ArrowsTier get tier => widget.tier;
  int get maxLives => tier.lives;
  late int level = widget.level;
  late ArrowsBoard board;
  late List<ArrowPiece> all;
  final Set<int> removed = {};
  final Map<int, int> shakes = {};
  late int lives = maxLives;
  int moves = 0;
  int? hinted;
  bool over = false;
  int attempt = 0;
  int continuesUsed = 0;
  static const maxContinues = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    board = ArrowsLevels.generate(tier, level);
    all = board.pieces;
    removed.clear();
    shakes.clear();
    lives = maxLives;
    moves = 0;
    hinted = null;
    over = false;
    continuesUsed = 0;
    attempt++;
  }

  int get _stars => (3 - (maxLives - lives)).clamp(1, 3);

  void _tap(ArrowPiece p) {
    if (over || removed.contains(p.id)) return;
    final res = board.tap(p.r, p.c);
    setState(() {
      hinted = null;
      if (res == true) {
        removed.add(p.id);
        moves++;
        AppAudio.play(Sound.slide);
      } else if (res == false) {
        AppAudio.play(Sound.fail);
        AppAudio.haptic(true);
        shakes[p.id] = (shakes[p.id] ?? 0) + 1;
        lives--;
      }
    });
    if (board.isCleared) {
      over = true;
      final stars = _stars;
      ArrowsProgress.complete(tier, level, stars);
      Rewards.onLevelComplete('arrows', '${tier.id}-L$level',
          stars: stars);
      final a = attempt, l = level;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (attempt == a && level == l) _showWin();
      });
    } else if (lives <= 0) {
      over = true;
      AppAudio.play(Sound.fail);
      final a = attempt;
      Future.delayed(const Duration(milliseconds: 450), () {
        if (attempt == a) _offerContinue();
      });
    }
  }

  /// Out of lives: offer an extra life (coins / ad) a couple of times per
  /// level before the lose dialog.
  Future<void> _offerContinue() async {
    if (!mounted) return;
    if (continuesUsed < maxContinues) {
      final a = attempt;
      final ok = await showContinueOffer(context, OfferKind.extraLife);
      if (!mounted || attempt != a) return;
      if (ok) {
        setState(() {
          continuesUsed++;
          lives += 1;
          over = false;
        });
        return;
      }
    }
    _showLose();
  }

  void _showWin() {
    if (!mounted) return;
    final hasNext = level < ArrowsLevels.count;
    final stars = _stars;
    showPremiumDialog(
      context,
      title: tr('arrows.win_title'),
      message: tr('arrows.win_msg', {'lives': lives}),
      emoji: '🎉✨',
      stars: stars,
      color: _arrowsColor,
      actions: [
        DialogAction(tr('common.levels'), () => Navigator.pop(context)),
        if (hasNext)
          DialogAction(tr('common.next_level'), () {
            setState(() {
              level++;
              _load();
            });
          }, primary: true),
      ],
    );
  }

  void _showLose() {
    if (!mounted) return;
    showPremiumDialog(
      context,
      title: tr('arrows.lose_title'),
      message: tr('arrows.lose_msg'),
      emoji: '💔',
      color: Pal.danger,
      actions: [
        DialogAction(tr('common.levels'), () => Navigator.pop(context)),
        DialogAction(tr('common.retry'), () => setState(_load), primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = board.size;
    return GameScaffold(
      title: tr('arrows.game_title', {'tier': _tierName(tier), 'n': level}),
      tint: _tierColors[tier],
      actions: [
        BarAction(
            icon: Icons.lightbulb_rounded,
            tooltip: tr('common.hint'),
            onTap: over
                ? null
                : () {
                    AppAudio.play(Sound.pop);
                    setState(() => hinted = board.hint()?.id);
                  }),
        BarAction(
            icon: Icons.refresh_rounded,
            tooltip: tr('common.restart'),
            onTap: () => setState(_load)),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GlassCard(
              blur: 0,
              radius: 20,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    for (var i = 0; i < maxLives; i++)
                      _Heart(alive: i < lives),
                  ]),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tr('arrows.hud', {'moves': moves, 'left': board.remaining}),
                          maxLines: 1,
                          style: const TextStyle(
                              color: Pal.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, box) {
                  final side = math.max(1.0, box.biggest.shortestSide);
                  final cell = side / n;
                  return SizedBox(
                    key: ValueKey('board_${tier.id}_${level}_$attempt'),
                    width: side,
                    height: side,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
                              ),
                              border: Border.all(color: Pal.glassBorder),
                              boxShadow: [
                                BoxShadow(
                                    color: _arrowsColor.withValues(alpha: 0.25),
                                    blurRadius: 30,
                                    spreadRadius: -6)
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                              painter: _GridPainter(n)),
                        ),
                        for (final p in all)
                          Positioned(
                            key: ValueKey('${tier.id}_${level}_${attempt}_${p.id}'),
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
                  )
                      .animate(key: ValueKey('anim_${tier.id}_${level}_$attempt'))
                      .fadeIn(duration: 350.ms)
                      .scale(
                          begin: const Offset(0.92, 0.92),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutCubic,
                          duration: 400.ms);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.alive});
  final bool alive;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.elasticOut,
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Padding(
        key: ValueKey(alive),
        padding: const EdgeInsets.only(right: 4),
        child: alive
            ? DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: Pal.danger.withValues(alpha: 0.5), blurRadius: 12)
                ]),
                child: const Icon(Icons.favorite_rounded,
                    color: Pal.danger, size: 26),
              )
            : const Icon(Icons.heart_broken_rounded,
                color: Pal.textDim, size: 26),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.n);
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final cell = size.width / n;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cell, 10), Offset(i * cell, size.height - 10), paint);
      canvas.drawLine(Offset(10, i * cell), Offset(size.width - 10, i * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.n != n;
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

class _ArrowTileState extends State<_ArrowTile> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _out = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    if (widget.removed) _out.value = 1;
    if (widget.hinted) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ArrowTile old) {
    super.didUpdateWidget(old);
    if (widget.shake != old.shake) _shake.forward(from: 0);
    if (widget.removed && !old.removed) _out.forward(from: 0);
    if (!widget.removed && old.removed) _out.value = 0;
    if (widget.hinted && !old.hinted) {
      _pulse.repeat(reverse: true);
    } else if (!widget.hinted && old.hinted) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _out.dispose();
    _pulse.dispose();
    super.dispose();
  }

  static Color _color(Dir d) => switch (d) {
        Dir.up => Pal.accents[0],
        Dir.down => Pal.accents[2],
        Dir.left => Pal.accents[4],
        Dir.right => Pal.accents[3],
      };

  @override
  Widget build(BuildContext context) {
    final p = widget.piece;
    final dist = widget.n.toDouble() + 1;
    return IgnorePointer(
      ignoring: widget.removed,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shake, _out, _pulse]),
        builder: (context, _) {
          final t = Curves.easeInCubic.transform(_out.value);
          final shaking = _shake.isAnimating;
          final dx = shaking
              ? (1 - _shake.value) *
                  8 *
                  ((_shake.value * 6).floor().isEven ? 1 : -1)
              : 0.0;
          final flash = shaking ? (1 - _shake.value) : 0.0;
          return LayoutBuilder(builder: (context, box) {
          final cellSize = box.maxWidth.isFinite ? box.maxWidth : 40.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (_out.value > 0 && _out.value < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailPainter(
                        dir: p.dir,
                        progress: t,
                        distance: dist,
                        color: _color(p.dir)),
                  ),
                ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(dx + p.dir.dc * dist * t * cellSize,
                      p.dir.dr * dist * t * cellSize),
                  child: Opacity(
                    opacity: (1 - _out.value * 0.9).clamp(0.0, 1.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      child: CustomPaint(
                        painter: _ArrowPainter(
                          dir: p.dir,
                          color: _color(p.dir),
                          flash: flash,
                          hint: widget.hinted ? _pulse.value : -1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          });
        },
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(
      {required this.dir,
      required this.progress,
      required this.distance,
      required this.color});
  final Dir dir;
  final double progress, distance;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final d = Offset(dir.dc.toDouble(), dir.dr.toDouble());
    final end = c + d * (distance * progress * size.width);
    final paint = Paint()
      ..shader = LinearGradient(colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.55 * (1 - progress)),
      ]).createShader(Rect.fromPoints(c, end).inflate(1))
      ..strokeWidth = size.width * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, end, paint);
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.progress != progress;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(
      {required this.dir,
      required this.color,
      required this.flash,
      required this.hint});
  final Dir dir;
  final Color color;
  final double flash;
  final double hint; // -1 = off, otherwise pulse 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pad = s * 0.07;
    final rect = Rect.fromLTWH(pad, pad, s - pad * 2, s - pad * 2);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.24));
    final isHint = hint >= 0;
    final base = isHint ? Pal.gold : color;
    final body = Color.lerp(base, Pal.danger, flash * 0.85)!;

    // glow
    canvas.drawRRect(
      rr.inflate(isHint ? 1 + hint * 3 : 0),
      Paint()
        ..color = (isHint ? Pal.gold : body)
            .withValues(alpha: isHint ? 0.35 + hint * 0.4 : 0.35 + flash * 0.4)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, s * (isHint ? 0.14 + hint * 0.1 : 0.1)),
    );
    // body
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(body, Colors.white, 0.3)!,
            body,
            Color.lerp(body, Colors.black, 0.3)!,
          ],
        ).createShader(rect),
    );
    // gloss highlight
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // arrow glyph (drawn pointing up, then rotated)
    final angle = switch (dir) {
      Dir.up => 0.0,
      Dir.right => math.pi / 2,
      Dir.down => math.pi,
      Dir.left => -math.pi / 2,
    };
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(angle);
    final u = rect.width / 2;
    final path = Path()
      ..moveTo(0, -u * 0.62)
      ..lineTo(u * 0.55, -u * 0.02)
      ..lineTo(u * 0.22, -u * 0.02)
      ..lineTo(u * 0.22, u * 0.6)
      ..lineTo(-u * 0.22, u * 0.6)
      ..lineTo(-u * 0.22, -u * 0.02)
      ..lineTo(-u * 0.55, -u * 0.02)
      ..close();
    canvas.drawPath(path.shift(Offset(0, u * 0.05)),
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.flash != flash || old.hint != hint || old.dir != dir || old.color != color;
}
