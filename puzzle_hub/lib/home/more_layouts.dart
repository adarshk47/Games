import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_info.dart';
import '../core/i18n/i18n.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';
import 'theme_styles.dart';

/// Shared bits of the 2.7.0 layouts below.
Widget _art(GameInfo g, double size) => g.emoji != null
    ? Text(g.emoji!, style: TextStyle(fontSize: size))
    : Icon(g.icon, color: Colors.white, size: size);

Widget _lock() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
      child: const Text('🔒', style: TextStyle(fontSize: 11)),
    );

LinearGradient _tileGradient(Color c) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(c, Colors.white, 0.15)!, Color.lerp(c, Colors.black, 0.45)!],
    );

// ------------------------------------------------------------------ mosaic

/// "Mosaic" home: two columns of cards in mixed heights, like a magazine.
/// New games get the tallest cards.
class MosaicHome extends StatelessWidget {
  const MosaicHome({super.key, required this.header, required this.games, required this.onOpen, this.bottomInset = 0});

  final Widget header;
  final List<GameInfo> games;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 12.0 : 16.0;
    const gap = 12.0;
    final colW = (width - hPad * 2 - gap) / 2;
    // Height pattern per column so the two sides stay staggered.
    const left = [1.35, 0.95, 1.15, 0.95];
    const right = [0.95, 1.2, 0.95, 1.3];
    final cols = <List<Widget>>[[], []];
    for (final (i, g) in games.indexed) {
      final col = i % 2;
      final row = i ~/ 2;
      final f = g.featured ? 1.45 : (col == 0 ? left : right)[row % 4];
      cols[col].add(Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: _MosaicCard(key: ValueKey('game_${g.id}'), g: g, width: colW, height: colW * f, onTap: () => onOpen(g)),
      ));
    }
    return CustomScrollView(
      key: const ValueKey('mosaic_layout'),
      slivers: [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4), child: header)),
        if (ThemeStyle.greeting() case final greet?)
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0), child: greet)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, bottomInset + 20),
          sliver: SliverToBoxAdapter(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: cols[0].animate(interval: 40.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08))),
              const SizedBox(width: gap),
              // The right column starts lower for the magazine look.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(children: cols[1].animate(interval: 40.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MosaicCard extends StatelessWidget {
  const _MosaicCard({super.key, required this.g, required this.width, required this.height, required this.onTap});
  final GameInfo g;
  final double width, height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: _tileGradient(g.color),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Stack(children: [
          // Big faded art in the corner.
          Positioned(right: -6, bottom: -6, child: Opacity(opacity: 0.35, child: _art(g, height * 0.42))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _art(g, 26),
              const Spacer(),
              if (g.comingSoon) _lock() else if (g.featured) _badge(tr('home.new_badge')),
            ]),
            const Spacer(),
            Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
            if (height > width) ...[
              const SizedBox(height: 4),
              Text(g.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.2)),
            ],
          ]),
        ]),
      ),
    );
    return ThemeStyle.frame(card);
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

// ------------------------------------------------------------------ A–Z

/// "A–Z" home: a search box and every game in alphabetical order, each row
/// with a quick Play button. Fastest way to a game you already know.
class AzHome extends StatefulWidget {
  const AzHome({super.key, required this.header, required this.games, required this.onOpen, this.bottomInset = 0});

  final Widget header;
  final List<GameInfo> games;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  @override
  State<AzHome> createState() => _AzHomeState();
}

class _AzHomeState extends State<AzHome> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 12.0 : 16.0;
    final t = AppThemeController.theme;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final g in widget.games)
        if (q.isEmpty || g.title.toLowerCase().contains(q) || g.subtitle.toLowerCase().contains(q)) g,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final rows = <Widget>[];
    String? letter;
    for (final g in list) {
      final l = g.title.isEmpty ? '#' : g.title.characters.first.toUpperCase();
      if (q.isEmpty && l != letter) {
        letter = l;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 0, 4),
          child: Text(l, style: TextStyle(color: t.highlight, fontSize: 15, fontWeight: FontWeight.w900)),
        ));
      }
      rows.add(_AzRow(key: ValueKey('game_${g.id}'), g: g, onTap: () => widget.onOpen(g)));
    }
    return CustomScrollView(
      key: const ValueKey('az_layout'),
      slivers: [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4), child: widget.header)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 4),
            child: TextField(
              key: const ValueKey('az_search'),
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: tr('home.az.search'),
                hintStyle: const TextStyle(color: Pal.textDim),
                prefixIcon: const Icon(Icons.search_rounded, color: Pal.textDim),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: Pal.textDim),
                        onPressed: () => setState(() {
                          _search.clear();
                          _q = '';
                        }),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Pal.glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Pal.glassBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: t.highlight)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 4, hPad, widget.bottomInset + 20),
          sliver: SliverList.list(
            children: list.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(tr('home.az.empty'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 15)),
                    ),
                  ]
                : rows,
          ),
        ),
      ],
    );
  }
}

class _AzRow extends StatelessWidget {
  const _AzRow({super.key, required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: 0,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: _tileGradient(g.color)),
            child: _art(g, 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 15)),
              Text(g.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          if (g.comingSoon)
            _lock()
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ rooms

/// "Rooms" home: one big tile per category (Board, Brain, Puzzles, …) with a
/// peek at its games. Tap a room to open it in place and pick a game.
class RoomsHome extends StatefulWidget {
  const RoomsHome({
    super.key,
    required this.header,
    required this.games,
    required this.rooms,
    required this.onOpen,
    this.bottomInset = 0,
  });

  final Widget header;
  final List<GameInfo> games;

  /// (label, emoji, game ids); games in no room go to an extra "More" room.
  final List<(String, String, List<String>)> rooms;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  @override
  State<RoomsHome> createState() => _RoomsHomeState();
}

class _RoomsHomeState extends State<RoomsHome> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 12.0 : 16.0;
    final listed = {for (final r in widget.rooms) ...r.$3};
    final rooms = [
      for (final (label, emoji, ids) in widget.rooms)
        (label, emoji, [for (final id in ids) ...widget.games.where((g) => g.id == id)]),
      (tr('home.shelf.more'), '✨', [for (final g in widget.games) if (!listed.contains(g.id)) g]),
    ].where((r) => r.$3.isNotEmpty).toList();
    const palette = [Color(0xFF7C4DFF), Color(0xFF00B8D4), Color(0xFFFF7043), Color(0xFF43A047), Color(0xFFEC407A), Color(0xFFFFB300)];
    return CustomScrollView(
      key: const ValueKey('rooms_layout'),
      slivers: [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4), child: widget.header)),
        if (ThemeStyle.greeting() case final greet?)
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0), child: greet)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, widget.bottomInset + 20),
          sliver: SliverList.list(children: [
            for (final (i, (label, emoji, games)) in rooms.indexed)
              _Room(
                key: ValueKey('room_$i'),
                label: label,
                emoji: emoji,
                games: games,
                color: palette[i % palette.length],
                open: _open == i,
                onToggle: () => setState(() => _open = _open == i ? -1 : i),
                onOpen: widget.onOpen,
              ),
          ]),
        ),
      ],
    );
  }
}

class _Room extends StatelessWidget {
  const _Room({
    super.key,
    required this.label,
    required this.emoji,
    required this.games,
    required this.color,
    required this.open,
    required this.onToggle,
    required this.onOpen,
  });

  final String label, emoji;
  final List<GameInfo> games;
  final Color color;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<GameInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final door = Pressable(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: _tileGradient(color),
          border: Border.all(color: Colors.white.withValues(alpha: open ? 0.5 : 0.2), width: open ? 2 : 1),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              // A peek at what is inside.
              Row(children: [
                for (final g in games.take(5))
                  Padding(padding: const EdgeInsets.only(right: 4), child: _art(g, 16)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(tr('home.rooms.games', {'n': games.length}), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
          AnimatedRotation(
            turns: open ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
          ),
        ]),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        ThemeStyle.frame(door),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LayoutBuilder(builder: (context, c) {
                    const gap = 10.0;
                    final w = (c.maxWidth - gap * 2) / 3;
                    return Wrap(spacing: gap, runSpacing: gap, children: [
                      for (final g in games) _RoomGame(key: ValueKey('game_${g.id}'), g: g, size: w, onTap: () => onOpen(g)),
                    ]);
                  }),
                ),
        ),
      ]),
    );
  }
}

class _RoomGame extends StatelessWidget {
  const _RoomGame({super.key, required this.g, required this.size, required this.onTap});
  final GameInfo g;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: size,
          height: size * 1.05,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: g.color.withValues(alpha: 0.6)),
          ),
          child: Stack(children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(child: Center(child: _art(g, size * 0.36))),
              Text(g.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800, height: 1.1)),
            ]),
            if (g.comingSoon) Positioned(top: 0, right: 0, child: _lock()),
          ]),
        ),
      );
}
