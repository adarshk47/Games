import 'dart:async';

import '../../games/registry.dart';
import 'package:flutter/material.dart';

import '../account/account_service.dart';
import '../account/auth_screens.dart';
import '../account/countries.dart';
import '../i18n/i18n.dart';
import '../ui/ui.dart';
import '../share/score_share.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'leaderboard_service.dart';

/// Display name of a board: game names stay as-is, "Total stars" and
/// "Chess wins" are localized.
String boardTitle(Board b) => switch (b.metric) {
  BoardMetric.totalStars => tr('cloud.lb.total_stars'),
  BoardMetric.wins when b.gameId == 'chess' => tr('cloud.lb.chess_wins'),
  _ =>
    b.gameId == null
        ? b.title
        : tr('game.${b.gameId}.title', const {}, b.title),
};

/// "🌍 Global" or "🇮🇳 India".
String scopeLabel(LeaderboardScope scope, String? country) {
  if (scope == LeaderboardScope.global) return '🌍 ${tr('cloud.lb.global')}';
  final c = countryByCode(normalizeCountry(country));
  return c == null ? (normalizeCountry(country) ?? '') : '${c.flag} ${c.name}';
}

/// "Global" / "India" (no flag) for the rank line.
String _placeName(LeaderboardScope scope, String? country) =>
    scope == LeaderboardScope.global
    ? tr('cloud.lb.global')
    : (countryByCode(normalizeCountry(country))?.name ??
          normalizeCountry(country) ??
          '');

/// Leaderboards: one tab per score game + "Total stars", each Global or
/// limited to the player's country. Needs cloud login.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.initialBoard,
    this.embedded = false,
  });
  final String? initialBoard;

  /// Shown as a home tab (no back button / own background).
  final bool embedded;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Board _board = () {
    final b = leaderboards.firstWhere(
      (b) => b.id == widget.initialBoard,
      orElse: () => leaderboards.first,
    );
    return b.tiers.isEmpty ? b : b.withTier(b.tiers.first);
  }();
  final String? _country = AccountService.I.country;
  late LeaderboardScope _scope = hasCountryScope(_country)
      ? defaultScope(_country)
      : LeaderboardScope.global;
  Future<LeaderboardPage>? _page;

  @override
  void initState() {
    super.initState();
    CloudAuth.I.user.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    CloudAuth.I.user.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      // Signed-out players still see the board (public read) with their
      // own offline score as the last row.
      _page = CloudService.available ? _fetch(_board, _scope) : null;
      _offline = LeaderboardService.I.localValue(_board);
    });
  }

  Object? _lastError;
  Future<int>? _offline;

  Future<LeaderboardPage> _fetch(Board b, LeaderboardScope scope) async {
    // Push our own latest scores in the background (never block the screen on
    // writes), then read with a timeout so a stuck request shows Retry.
    if (CloudAuth.I.user.value != null) {
      unawaited(
        (b.gameId == null
                ? LeaderboardService.I.submitTotalStars()
                : LeaderboardService.I.submitAll())
            .timeout(const Duration(seconds: 20))
            .catchError(
              (Object e) => debugPrint('leaderboard submit failed: $e'),
            ),
      );
    }
    try {
      return await LeaderboardService.I
          .load(b, scope: scope)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      _lastError = e;
      debugPrint('leaderboard load failed: $e');
      rethrow;
    }
  }

  /// Short reason for the failure message (e.g. permission-denied, failed-precondition).
  String get _errorHint {
    final e = _lastError;
    if (e == null) return '';
    final s = e.toString();
    final m = RegExp(r'\[cloud_firestore/([a-z-]+)\]').firstMatch(s);
    if (m != null) return '(${m.group(1)})';
    if (e is TimeoutException) return '(timeout)';
    return '(${s.length > 60 ? s.substring(0, 60) : s})';
  }

  void _select(Board b) {
    if (b.id == _board.id) return;
    _board = b.tiers.isEmpty
        ? b
        : b.withTier(
            b.tiers.contains(_board.tier) ? _board.tier : b.tiers.first,
          );
    _reload();
  }

  void _selectTier(String t) {
    if (t == _board.tier) return;
    _board = _board.withTier(t);
    _reload();
  }

  /// Boards shown (games marked "Coming soon" are left out for now).
  List<Board> get _boards {
    final soon = {for (final g in allGames) if (g.comingSoon) g.id};
    return [for (final b in leaderboards) if (b.gameId == null || !soon.contains(b.gameId)) b];
  }

  void _pickBoard() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1245),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('cloud.lb.choose_game'), style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  for (final b in _boards)
                    GestureDetector(
                      key: ValueKey('lb_board_${b.id}'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _select(b);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: b.id == _board.id ? Pal.goldDeep : Colors.white.withValues(alpha: 0.07),
                          border: Border.all(color: b.id == _board.id ? Pal.gold : Pal.glassBorder),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(b.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(boardTitle(b),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Pal.text, fontSize: 11, fontWeight: FontWeight.w700, height: 1.1)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _selectScope(LeaderboardScope s) {
    if (s == _scope) return;
    _scope = s;
    _reload();
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: Pal.goldDeep,
    backgroundColor: Colors.black.withValues(alpha: 0.25),
    labelStyle: TextStyle(
      color: selected ? Colors.white : Pal.text,
      fontWeight: FontWeight.w700,
    ),
    side: const BorderSide(color: Pal.glassBorder),
    showCheckmark: false,
  );

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('cloud.lb.title'),
      tint: Pal.gold,
      embedded: widget.embedded,
      actions: [
        if (_page != null)
          GlassCard(
            padding: const EdgeInsets.all(10),
            radius: 16,
            blur: 0,
            onTap: _reload,
            child: const Icon(Icons.refresh_rounded, size: 20, color: Pal.text),
          ),
      ],
      body: Column(
        children: [
          // One button with the chosen game; tapping opens every board in a
          // compact grid (all games visible at once, no long scrolling).
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: GlassCard(
              key: const ValueKey('lb_pick_board'),
              blur: 0,
              radius: 16,
              onTap: _pickBoard,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Text(_board.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(boardTitle(_board),
                      style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Text(tr('cloud.lb.change'), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
                const Icon(Icons.expand_more_rounded, color: Pal.gold),
              ]),
            ),
          ),
          if (_board.tiers.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final t in _board.tiers)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 2,
                        bottom: 2,
                      ),
                      child: _chip(
                        t == 'classic'
                            ? tr('game_2048.classic')
                            : tr('common.tier.$t'),
                        t == _board.tier,
                        () => _selectTier(t),
                      ),
                    ),
                ],
              ),
            ),
          if (hasCountryScope(_country))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in const [
                    LeaderboardScope.country,
                    LeaderboardScope.global,
                  ])
                    _chip(
                      scopeLabel(s, _country),
                      s == _scope,
                      () => _selectScope(s),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String title, String text, {Widget? action}) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
        children: [
          GlassCard(
            child: Column(
              children: [
                Icon(icon, size: 52, color: Pal.gold),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Pal.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Pal.textDim,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 20), action],
              ],
            ),
          ),
        ],
      );

  Widget _offlineRow() => FutureBuilder<int>(
    future: _offline,
    builder: (context, s) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: GlassCard(
        key: const ValueKey('lb_offline_row'),
        blur: 0,
        glow: Pal.gold,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 44,
              child: Icon(Icons.cloud_off_rounded, color: Pal.textDim),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('cloud.lb.offline_you'),
                    style: const TextStyle(
                      color: Pal.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    tr('cloud.lb.offline_hint'),
                    style: const TextStyle(
                      color: Pal.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${s.data ?? 0}',
              style: const TextStyle(
                color: Pal.text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _signInCard() => GlassCard(
    child: Column(
      children: [
        Text(
          tr('cloud.lb.signin_text'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 14),
        const CloudSignInPanel(compact: true),
      ],
    ),
  );

  Widget _body() {
    if (!CloudService.available) {
      return _message(
        Icons.cloud_off_rounded,
        tr('cloud.lb.pending_title'),
        tr('cloud.lb.pending_text'),
      );
    }
    final signedOut = CloudAuth.I.user.value == null;
    return FutureBuilder<LeaderboardPage>(
      future: _page,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Pal.gold),
          );
        }
        if (signedOut && (snap.hasError || !snap.hasData)) {
          // Board not readable without an account: own score + sign in.
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [_offlineRow(), _signInCard()],
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _message(
            Icons.wifi_off_rounded,
            tr('cloud.lb.load_failed_title'),
            '${tr('cloud.lb.load_failed_text')}\n$_errorHint',
            action: PremiumButton(
              label: tr('common.retry'),
              icon: Icons.refresh_rounded,
              onTap: _reload,
              compact: true,
            ),
          );
        }
        final p = snap.data!;
        final me = CloudAuth.I.user.value?.uid;
        return Column(
          children: [
            if (p.mine != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: GlassCard(
                  glow: Pal.gold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Pal.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('cloud.lb.scope_rank', {
                            'place': _placeName(_scope, _country),
                            'rank': p.myRank ?? '-',
                          }),
                          style: const TextStyle(
                            color: Pal.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${p.mine!.score}',
                        style: const TextStyle(
                          color: Pal.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('lb_challenge'),
                        tooltip: tr('share.challenge'),
                        icon: const Icon(Icons.share_rounded, color: Pal.gold),
                        onPressed: () => ScoreShare.show(
                          context,
                          game: boardTitle(_board),
                          emoji: _board.emoji,
                          value: '${p.mine!.score}',
                          label: tr('share.rank_label', {
                            'rank': p.myRank ?? '-',
                            'place': _placeName(_scope, _country),
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: p.top.isEmpty && !signedOut
                  ? _message(
                      Icons.emoji_events_outlined,
                      tr('cloud.lb.no_scores'),
                      tr('cloud.lb.be_first', {'board': boardTitle(_board)}),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        if (p.top.isNotEmpty)
                          _Podium(top: p.top.take(3).toList(), me: me),
                        if (p.top.length > 3)
                          _SectionLabel(tr('cloud.lb.top10')),
                        for (var i = 3; i < p.top.length && i < 10; i++)
                          _Row(
                            rank: i + 1,
                            entry: p.top[i],
                            isMe: p.top[i].uid == me,
                          ),
                        if (p.top.length > 10)
                          _SectionLabel(tr('cloud.lb.others')),
                        for (var i = 10; i < p.top.length; i++)
                          _Row(
                            rank: i + 1,
                            entry: p.top[i],
                            isMe: p.top[i].uid == me,
                          ),
                        // Always last, whatever the score: not on the board
                        // until signed in.
                        if (signedOut) ...[_offlineRow(), _signInCard()],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.isMe});
  final int rank;
  final LeaderEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final tier = leaderTier(rank);
    final medal = tier?.emoji;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: 0,
        glow: isMe ? Pal.gold : tier?.color,
        gradient: tier == null
            ? null
            : LinearGradient(
                colors: [
                  tier.color.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Serial number on every row; the top 5 also get their medal.
            SizedBox(
              width: medal != null ? 64 : 44,
              child: Row(
                children: [
                  Text(
                    '$rank.',
                    key: ValueKey('lb_rank_$rank'),
                    style: TextStyle(
                      color: tier?.color ?? Pal.textDim,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (medal != null) ...[
                    const SizedBox(width: 4),
                    Text(medal, style: const TextStyle(fontSize: 20)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    withFlag(
                      entry,
                      isMe ? tr('cloud.lb.you', {'name': entry.name}) : entry.name,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? Pal.gold : Pal.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (tier != null)
                    Text(
                      tr('cloud.lb.tier.${tier.id}'),
                      style: TextStyle(
                        color: tier.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${entry.score}',
              style: const TextStyle(
                color: Pal.text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-5 tiers on every leaderboard scope: Diamond, Gold, Silver, Bronze, Steel.
class LeaderTier {
  const LeaderTier(this.id, this.emoji, this.color);
  final String id;
  final String emoji;
  final Color color;
}

/// The player's name with their country flag in front (e.g. "🇮🇳 Adarsh").
String withFlag(LeaderEntry e, String name) {
  final flag = countryByCode(e.country)?.flag;
  return flag == null || flag.isEmpty ? name : '$flag $name';
}

LeaderTier? leaderTier(int rank) => switch (rank) {
  1 => const LeaderTier('diamond', '💎', Color(0xFF7DD3FC)),
  2 => const LeaderTier('gold', '🥇', Color(0xFFFFD369)),
  3 => const LeaderTier('silver', '🥈', Color(0xFFD1D5DB)),
  4 => const LeaderTier('bronze', '🥉', Color(0xFFD97706)),
  5 => const LeaderTier('steel', '⚙️', Color(0xFF94A3B8)),
  >= 6 && <= 10 => const LeaderTier('top10', '⭐', Color(0xFFB794FF)),
  _ => null,
};

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Pal.textDim,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// Ranks 1–3 on a podium (2nd left, 1st in the middle and tallest, 3rd right).
class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.me});
  final List<LeaderEntry> top;
  final String? me;

  Widget _step(int rank) {
    if (rank > top.length) return const Expanded(child: SizedBox());
    final e = top[rank - 1];
    final tier = leaderTier(rank)!;
    final h = switch (rank) {
      1 => 92.0,
      2 => 70.0,
      _ => 56.0,
    };
    final isMe = e.uid == me;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(tier.emoji, style: TextStyle(fontSize: rank == 1 ? 34 : 26)),
          const SizedBox(height: 4),
          Text(
            withFlag(e, isMe ? tr('cloud.lb.you', {'name': e.name}) : e.name),
            key: ValueKey('lb_rank_$rank'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMe ? Pal.gold : Pal.text,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            '${e.score}',
            style: TextStyle(
              color: tier.color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tier.color.withValues(alpha: 0.85),
                  tier.color.withValues(alpha: 0.25),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_step(2), _step(1), _step(3)],
      ),
    ),
  );
}
