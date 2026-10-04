import 'package:flutter/material.dart';

import '../account/auth_screens.dart';
import '../ui/ui.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'leaderboard_service.dart';

/// Leaderboards: one tab per score game + "Total stars". Needs cloud login.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.initialBoard});
  final String? initialBoard;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Board _board = leaderboards.firstWhere((b) => b.id == widget.initialBoard, orElse: () => leaderboards.first);
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
      _page = CloudService.available && CloudAuth.I.user.value != null ? _fetch(_board) : null;
    });
  }

  Future<LeaderboardPage> _fetch(Board b) async {
    // Make sure our own latest score is on the board before reading it.
    if (b.gameId == null) {
      await LeaderboardService.I.submitTotalStars();
    } else {
      await LeaderboardService.I.submitAll();
    }
    return LeaderboardService.I.load(b);
  }

  void _select(Board b) {
    if (b.id == _board.id) return;
    _board = b;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Leaderboard',
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
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final b in leaderboards)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                  child: ChoiceChip(
                    label: Text('${b.emoji} ${b.title}'),
                    selected: b.id == _board.id,
                    onSelected: (_) => _select(b),
                    selectedColor: Pal.goldDeep,
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    labelStyle: TextStyle(color: b.id == _board.id ? Colors.white : Pal.text, fontWeight: FontWeight.w700),
                    side: const BorderSide(color: Pal.glassBorder),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _message(IconData icon, String title, String text, {Widget? action}) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
        children: [
          GlassCard(
            child: Column(children: [
              Icon(icon, size: 52, color: Pal.gold),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
              if (action != null) ...[const SizedBox(height: 20), action],
            ]),
          ),
        ],
      );

  Widget _body() {
    if (!CloudService.available) {
      return _message(Icons.cloud_off_rounded, 'Cloud setup pending',
          'Leaderboards will appear here once online features are switched on. Keep playing - your records are saved!');
    }
    if (CloudAuth.I.user.value == null) {
      return _message(Icons.emoji_events_rounded, 'Sign in to compete',
          'Sign in with Google or Email to put your best scores on the leaderboard.',
          action: const CloudSignInPanel());
    }
    return FutureBuilder<LeaderboardPage>(
      future: _page,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Pal.gold));
        }
        if (snap.hasError || !snap.hasData) {
          return _message(Icons.wifi_off_rounded, 'Could not load', 'Check your internet connection and try again.',
              action: PremiumButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: _reload, compact: true));
        }
        final p = snap.data!;
        final me = CloudAuth.I.user.value?.uid;
        return Column(children: [
          if (p.mine != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GlassCard(
                glow: Pal.gold,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.person_pin_rounded, color: Pal.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Your rank: #${p.myRank ?? '-'}',
                        style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  Text('${p.mine!.score}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
            ),
          Expanded(
            child: p.top.isEmpty
                ? _message(Icons.emoji_events_outlined, 'No scores yet', 'Be the first on the ${_board.title} board!')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    itemCount: p.top.length,
                    itemBuilder: (_, i) => _Row(rank: i + 1, entry: p.top[i], isMe: p.top[i].uid == me),
                  ),
          ),
        ]);
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
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => null };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: 0,
        glow: isMe ? Pal.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 40,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 24))
                : Text('#$rank', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(isMe ? '${entry.name} (you)' : entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isMe ? Pal.gold : Pal.text, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Text('${entry.score}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ),
    );
  }
}
