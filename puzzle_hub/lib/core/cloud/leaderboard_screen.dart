import 'dart:async';

import 'package:flutter/material.dart';

import '../account/account_service.dart';
import '../account/auth_screens.dart';
import '../account/countries.dart';
import '../i18n/i18n.dart';
import '../ui/ui.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'leaderboard_service.dart';

/// Display name of a board: game names stay as-is, "Total stars" and
/// "Chess wins" are localized.
String boardTitle(Board b) => switch (b.metric) {
  BoardMetric.totalStars => tr('cloud.lb.total_stars'),
  BoardMetric.wins when b.gameId == 'chess' => tr('cloud.lb.chess_wins'),
  _ => b.title,
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
  const LeaderboardScreen({super.key, this.initialBoard});
  final String? initialBoard;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Board _board = leaderboards.firstWhere(
    (b) => b.id == widget.initialBoard,
    orElse: () => leaderboards.first,
  );
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
      _page = CloudService.available && CloudAuth.I.user.value != null
          ? _fetch(_board, _scope)
          : null;
    });
  }

  Object? _lastError;

  Future<LeaderboardPage> _fetch(Board b, LeaderboardScope scope) async {
    // Push our own latest scores in the background (never block the screen on
    // writes), then read with a timeout so a stuck request shows Retry.
    unawaited(
      (b.gameId == null
              ? LeaderboardService.I.submitTotalStars()
              : LeaderboardService.I.submitAll())
          .timeout(const Duration(seconds: 20))
          .catchError(
            (Object e) => debugPrint('leaderboard submit failed: $e'),
          ),
    );
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
    _board = b;
    _reload();
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
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final b in leaderboards)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                    child: _chip(
                      '${b.emoji} ${boardTitle(b)}',
                      b.id == _board.id,
                      () => _select(b),
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

  Widget _body() {
    if (!CloudService.available) {
      return _message(
        Icons.cloud_off_rounded,
        tr('cloud.lb.pending_title'),
        tr('cloud.lb.pending_text'),
      );
    }
    if (CloudAuth.I.user.value == null) {
      return _message(
        Icons.emoji_events_rounded,
        tr('cloud.lb.signin_title'),
        tr('cloud.lb.signin_text'),
        action: const CloudSignInPanel(),
      );
    }
    return FutureBuilder<LeaderboardPage>(
      future: _page,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Pal.gold),
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
                    ],
                  ),
                ),
              ),
            Expanded(
              child: p.top.isEmpty
                  ? _message(
                      Icons.emoji_events_outlined,
                      tr('cloud.lb.no_scores'),
                      tr('cloud.lb.be_first', {'board': boardTitle(_board)}),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: p.top.length,
                      itemBuilder: (_, i) => _Row(
                        rank: i + 1,
                        entry: p.top[i],
                        isMe: p.top[i].uid == me,
                      ),
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
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: 0,
        glow: isMe ? Pal.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 24))
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Pal.textDim,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            Expanded(
              child: Text(
                isMe ? tr('cloud.lb.you', {'name': entry.name}) : entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? Pal.gold : Pal.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
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
