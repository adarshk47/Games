import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/i18n/i18n.dart';
import '../core/rewards.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';
import 'theme_styles.dart';

/// Category filter shared by the new layouts: null = all games.
List<GameInfo> _filter(List<GameInfo> games, List<String>? ids) =>
    ids == null ? games : [for (final g in games) if (ids.contains(g.id)) g];

// ------------------------------------------------------------------ spotlight

/// "Spotlight" home: one big game card at a time (swipe), a big Play button
/// and category buttons underneath. Feels like a game console menu.
class SpotlightHome extends StatefulWidget {
  const SpotlightHome({
    super.key,
    required this.header,
    required this.games,
    required this.categories,
    required this.onOpen,
    this.bottomInset = 0,
  });

  final Widget header;

  /// Games in spotlight order (new / featured first).
  final List<GameInfo> games;
  final List<(String, String, List<String>)> categories;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  @override
  State<SpotlightHome> createState() => _SpotlightHomeState();
}

class _SpotlightHomeState extends State<SpotlightHome> {
  final _page = PageController(viewportFraction: 0.8);
  int _index = 0;
  int? _cat;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _pickCategory(int? c) {
    setState(() {
      _cat = c;
      _index = 0;
    });
    if (_page.hasClients) _page.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final list = _filter(widget.games, _cat == null ? null : widget.categories[_cat!].$3);
    final current = list.isEmpty ? null : list[_index.clamp(0, list.length - 1)];
    final h = MediaQuery.sizeOf(context).height;
    final cardH = math.min(360.0, h * 0.42);
    return ListView(
      key: const ValueKey('spotlight_layout'),
      padding: EdgeInsets.only(bottom: widget.bottomInset + 20),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: widget.header),
        if (ThemeStyle.greeting() case final greet?) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: greet),
        const SizedBox(height: 14),
        SizedBox(
          height: cardH,
          child: PageView.builder(
            key: const ValueKey('spotlight_pages'),
            controller: _page,
            itemCount: list.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: i == _index ? 1 : 0.9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ThemeStyle.frame(
                  _SpotCard(key: ValueKey('game_${list[i].id}'), g: list[i], onTap: () => widget.onOpen(list[i])),
                  radius: 30,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Page dots (max 12 shown).
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < math.min(list.length, 12); i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i == _index ? t.highlight : Colors.white.withValues(alpha: 0.3),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        if (current != null)
          Center(
            child: PremiumButton(
              key: const ValueKey('spotlight_play'),
              label: current.comingSoon ? '🔒 ${tr('home.coming_soon')}' : '${tr('home.play_now')} · ${current.title}',
              icon: Icons.play_arrow_rounded,
              onTap: () => widget.onOpen(current),
            ),
          ),
        const SizedBox(height: 18),
        // Category buttons.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            _CatButton(emoji: '✨', label: tr('home.bento.all'), selected: _cat == null, onTap: () => _pickCategory(null), key: const ValueKey('spot_cat_all')),
            for (final (i, (label, emoji, _)) in widget.categories.indexed)
              _CatButton(emoji: emoji, label: label, selected: _cat == i, onTap: () => _pickCategory(i), key: ValueKey('spot_cat_$i')),
          ]),
        ),
      ],
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({super.key, required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = g.color;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(c, Colors.white, 0.22)!, Color.lerp(c, Colors.black, 0.45)!],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(12)),
              child: Text(g.comingSoon ? '🔒 ${tr('home.coming_soon')}' : (g.featured ? tr('home.new_badge') : '🎮'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                child: g.emoji != null
                    ? Text(g.emoji!, style: const TextStyle(fontSize: 110))
                    : Icon(g.icon, color: Colors.white, size: 110),
              ),
            ),
          ),
          Text(g.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(g.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        ]),
      ),
    );
  }
}

class _CatButton extends StatelessWidget {
  const _CatButton({super.key, required this.emoji, required this.label, required this.selected, required this.onTap});
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? t.accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: selected ? t.highlight : Pal.glassBorder),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ journey

/// "Journey" home: a personal list. Games you play are on top with your
/// progress (levels / wins); new and unplayed games follow.
class JourneyHome extends StatelessWidget {
  const JourneyHome({super.key, required this.header, required this.games, required this.onOpen, this.bottomInset = 0});
  final Widget header;
  final List<GameInfo> games;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  static int _score(GameInfo g) => Rewards.levels(g.id) + Rewards.wins(g.id);

  @override
  Widget build(BuildContext context) {
    final played = [for (final g in games) if (!g.comingSoon && Rewards.plays(g.id) > 0) g]
      ..sort((a, b) => Rewards.plays(b.id).compareTo(Rewards.plays(a.id)));
    final rest = [for (final g in games) if (!played.contains(g)) g];
    final maxScore = played.isEmpty ? 1 : played.map(_score).reduce(math.max).clamp(1, 1 << 30);
    return ListView(
      key: const ValueKey('journey_layout'),
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 20),
      children: [
        header,
        if (ThemeStyle.greeting() case final greet?) Padding(padding: const EdgeInsets.only(top: 8), child: greet),
        if (played.isNotEmpty) ...[
          _title('▶ ${tr('home.journey.continue')}'),
          for (final g in played) _row(g, progress: _score(g) / maxScore),
        ],
        _title(played.isEmpty ? '🎮 ${tr('home.journey.start')}' : '✨ ${tr('home.journey.more')}'),
        for (final g in rest) _row(g),
      ],
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: const TextStyle(color: Pal.text, fontSize: 17, fontWeight: FontWeight.w900)),
      );

  Widget _row(GameInfo g, {double? progress}) {
    final t = AppThemeController.theme;
    final levels = Rewards.levels(g.id), wins = Rewards.wins(g.id);
    final stats = [
      if (levels > 0) tr('home.journey.levels', {'n': levels}),
      if (wins > 0) tr('home.journey.wins', {'n': wins}),
    ].join(' · ');
    return Padding(
      key: ValueKey('game_${g.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: ThemeStyle.frame(
        GlassCard(
          blur: 0,
          radius: 20,
          onTap: () => onOpen(g),
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [Color.lerp(g.color, Colors.white, 0.2)!, Color.lerp(g.color, Colors.black, 0.35)!]),
              ),
              child: g.emoji != null ? Text(g.emoji!, style: const TextStyle(fontSize: 30)) : Icon(g.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: t.highlight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(stats.isEmpty ? tr('home.journey.played', {'n': Rewards.plays(g.id)}) : stats,
                      style: const TextStyle(color: Pal.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
                ] else
                  Text(g.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(g.comingSoon ? Icons.lock_rounded : Icons.play_circle_fill_rounded, color: g.comingSoon ? Pal.textDim : t.highlight, size: 30),
          ]),
        ),
      ),
    );
  }
}
