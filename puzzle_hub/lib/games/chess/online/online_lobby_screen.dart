import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/account/auth_screens.dart';
import '../../../core/cloud/cloud_auth.dart';
import '../../../core/cloud/cloud_service.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/rewards.dart';
import '../../../core/ui/ui.dart';
import 'online_chess_screen.dart';
import '../../ludo/online/ludo_online_game.dart';
import '../../ludo/online/ludo_online_service.dart';

/// Opens an online game (used by the lobby and the incoming-challenge popup).
void openOnlineGame(BuildContext context, String gameId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnlineChessScreen(gameId: gameId)));
}

/// Accepts [c] (Chess or Ludo) and opens the new game.
Future<void> acceptChallenge(Challenge c, NavigatorState? nav) async {
  if (c.game == 'ludo') {
    final id = await LudoOnline.I.acceptChallenge(c);
    nav?.push(MaterialPageRoute(builder: (_) => LudoOnlineGameScreen(gameId: id)));
  } else {
    final id = await OnlineService.I.accept(c);
    nav?.push(MaterialPageRoute(builder: (_) => OnlineChessScreen(gameId: id)));
  }
}

/// App-wide popup for challenges sent to me (wired up once at start).
void installChallengePopup() {
  OnlineService.I.onIncoming = (c) {
    final ctx = Rewards.navKey.currentContext;
    if (ctx == null) return;
    showPremiumDialog(
      ctx,
      title: tr('online.challenged', {'name': '@${c.fromName}'}),
      message: tr(c.game == 'ludo' ? 'online.challenged_text_ludo' : 'online.challenged_text'),
      emoji: c.game == 'ludo' ? '🎲' : '♟️',
      actions: [
        DialogAction(tr('online.accept'), () async {
          try {
            await acceptChallenge(c, Rewards.navKey.currentState);
          } catch (e) {
            debugPrint('accept: $e');
          }
        }, primary: true),
        DialogAction(tr('online.decline'), () => OnlineService.I.decline(c)),
      ],
    );
  };
}

/// Online chess: my handle, "available" switch, quick match, search by
/// handle, players online now, challenges and my running games.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _handle = TextEditingController();
  final _search = TextEditingController();
  String? _handleErr;
  bool _busy = false;
  Future<List<OnlinePlayer>>? _online;
  Future<List<OnlineGame>>? _games;
  List<OnlinePlayer>? _found;

  @override
  void initState() {
    super.initState();
    CloudAuth.I.user.addListener(_refresh);
    OnlineService.I.me.addListener(_refresh);
    OnlineService.I.meLoaded.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    CloudAuth.I.user.removeListener(_refresh);
    OnlineService.I.me.removeListener(_refresh);
    OnlineService.I.meLoaded.removeListener(_refresh);
    _handle.dispose();
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (_online == null) _load();
    setState(() {});
  }

  void _load() {
    if (!OnlineService.I.ready) return;
    _online = OnlineService.I.onlinePlayers();
    _games = OnlineService.I.myActiveGames();
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _saveHandle() async {
    setState(() {
      _busy = true;
      _handleErr = null;
    });
    final err = await OnlineService.I.setHandle(_handle.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _handleErr = err == null ? null : tr(err);
    });
    if (err == null) setState(_load);
  }

  Future<void> _doSearch() async {
    final q = _search.text;
    if (q.trim().isEmpty) return;
    try {
      final r = await OnlineService.I.search(q);
      if (mounted) setState(() => _found = r);
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  /// Shows a "waiting..." dialog until [ids] yields a game id, then opens it.
  Future<void> _wait(String text, Stream<String?> ids, Future<void> Function() cancel, {Stream<String>? failures}) async {
    final nav = Navigator.of(context);
    StreamSubscription? a, b;
    var done = false;
    void close() {
      if (done) return;
      done = true;
      a?.cancel();
      b?.cancel();
      nav.pop();
    }

    a = ids.listen((id) {
      if (id == null || done) return;
      close();
      nav.push(MaterialPageRoute(builder: (_) => OnlineChessScreen(gameId: id)));
    }, onError: (_) => close());
    b = failures?.listen((m) {
      close();
      _snack(m);
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF241A4F),
        content: Row(children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Pal.gold, strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700))),
        ]),
        actions: [
          TextButton(
            key: const ValueKey('online_wait_cancel'),
            onPressed: () {
              unawaited(cancel());
              close();
            },
            child: Text(tr('common.cancel'), style: const TextStyle(color: Pal.gold)),
          ),
        ],
      ),
    );
    done = true;
    unawaited(a.cancel());
    unawaited(b?.cancel());
  }

  Future<void> _quick() async {
    try {
      final ids = await OnlineService.I.quickMatch();
      if (!mounted) return;
      await _wait(tr('online.searching'), ids, OnlineService.I.leaveQueue);
      unawaited(OnlineService.I.leaveQueue());
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  Future<void> _challenge(OnlinePlayer p) async {
    try {
      final id = await OnlineService.I.challenge(p);
      if (!mounted) return;
      final s = OnlineService.I.watchChallenge(id).asBroadcastStream();
      await _wait(
        tr('online.waiting_for', {'name': '@${p.handle}'}),
        s.map((c) => c?.status == 'accepted' ? c?.gameId : null),
        () => OnlineService.I.cancelChallenge(id),
        failures: s.where((c) => c?.status == 'declined').map((_) => tr('online.declined', {'name': '@${p.handle}'})),
      );
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  // ---------------------------------------------------------------- ui

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(t, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );

  Widget _message(IconData icon, String title, String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Pal.gold, size: 56),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 18), action],
          ]),
        ),
      );

  Widget _playerRow(OnlinePlayer p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          blur: 0,
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(Icons.circle, size: 10, color: p.online ? const Color(0xFF34D27B) : Pal.textDim),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${p.handle}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
                Text(tr('online.record', {'w': p.wins, 'l': p.losses}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              ]),
            ),
            PremiumButton(key: ValueKey('challenge_${p.uid}'), label: tr('online.challenge'), compact: true, onTap: () => _challenge(p)),
          ]),
        ),
      );

  Widget _handleSetup() {
    if (_handle.text.isEmpty) _handle.text = OnlineService.suggestHandle(CloudAuth.I.user.value?.name ?? 'player');
    return ListView(padding: const EdgeInsets.all(16), children: [
      GlassCard(
        glow: Pal.gold,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('online.pick_handle'), style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(tr('online.pick_handle_text'), style: const TextStyle(color: Pal.textDim, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('online_handle'),
            controller: _handle,
            maxLength: 16,
            style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700),
            decoration: InputDecoration(prefixText: '@', errorText: _handleErr, counterText: ''),
          ),
          const SizedBox(height: 12),
          PremiumButton(key: const ValueKey('online_handle_save'), label: tr('online.save'), icon: Icons.check_rounded, onTap: _busy ? null : _saveHandle),
        ]),
      ),
    ]);
  }

  Widget _lobby(OnlinePlayer me) {
    return RefreshIndicator(
      color: Pal.gold,
      onRefresh: () async {
        setState(_load);
        await _online;
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
        GlassCard(
          glow: Pal.gold,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${me.handle}', style: const TextStyle(color: Pal.gold, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(tr('online.record', {'w': me.wins, 'l': me.losses}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              ]),
            ),
            Text(tr('online.available'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 13)),
            Switch(
              key: const ValueKey('online_available'),
              value: me.available,
              activeThumbColor: Pal.gold,
              onChanged: (v) => OnlineService.I.setAvailable(v),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        PremiumButton(key: const ValueKey('online_quick'), label: tr('online.quick'), icon: Icons.bolt_rounded, onTap: _quick),
        ValueListenableBuilder<List<Challenge>>(
          valueListenable: OnlineService.I.incoming,
          builder: (context, list, _) => list.isEmpty
              ? const SizedBox()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _section(tr('online.requests')),
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        blur: 0,
                        glow: Pal.gold,
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        child: Row(children: [
                          Expanded(child: Text('@${c.fromName}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800))),
                          TextButton(onPressed: () => OnlineService.I.decline(c), child: Text(tr('online.decline'), style: const TextStyle(color: Pal.textDim))),
                          PremiumButton(
                            label: tr('online.accept'),
                            compact: true,
                            onTap: () async {
                              try {
                                await acceptChallenge(c, mounted ? Navigator.of(this.context) : null);
                              } catch (_) {
                                _snack(tr('online.err.network'));
                              }
                            },
                          ),
                        ]),
                      ),
                    ),
                ]),
        ),
        FutureBuilder<List<OnlineGame>>(
          future: _games,
          builder: (context, snap) {
            final list = snap.data ?? const <OnlineGame>[];
            if (list.isEmpty) return const SizedBox();
            final uid = OnlineService.I.uid;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _section(tr('online.my_games')),
              for (final g in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: () async {
                      openOnlineGame(context, g.id);
                    },
                    child: GlassCard(
                      blur: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        const Text('♟️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('@${g.white == uid ? g.blackName : g.whiteName}',
                              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                        ),
                        Text(tr(g.turnUid() == uid ? 'online.your_turn' : 'online.their_turn'),
                            style: TextStyle(color: g.turnUid() == uid ? Pal.gold : Pal.textDim, fontSize: 12, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
            ]);
          },
        ),
        _section(tr('online.find')),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('online_search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _doSearch(),
              style: const TextStyle(color: Pal.text),
              decoration: InputDecoration(prefixText: '@', hintText: tr('online.search_hint'), hintStyle: const TextStyle(color: Pal.textDim)),
            ),
          ),
          IconButton(onPressed: _doSearch, icon: const Icon(Icons.search_rounded, color: Pal.gold)),
        ]),
        const SizedBox(height: 8),
        if (_found != null)
          if (_found!.isEmpty)
            Text(tr('online.none_found'), style: const TextStyle(color: Pal.textDim))
          else
            for (final p in _found!) _playerRow(p),
        _section(tr('online.online_now')),
        FutureBuilder<List<OnlinePlayer>>(
          future: _online,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Pal.gold)));
            }
            final list = snap.data ?? const <OnlinePlayer>[];
            if (list.isEmpty) {
              return Text(snap.hasError ? tr('online.err.network') : tr('online.nobody'), style: const TextStyle(color: Pal.textDim, height: 1.4));
            }
            return Column(children: [for (final p in list) _playerRow(p)]);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!CloudService.available) {
      body = _message(Icons.cloud_off_rounded, tr('online.title'), CloudService.pendingText);
    } else if (CloudAuth.I.user.value == null) {
      body = _message(Icons.public_rounded, tr('online.signin_title'), tr('online.signin_text'), action: const CloudSignInPanel());
    } else if (!OnlineService.I.meLoaded.value) {
      body = const Center(child: CircularProgressIndicator(color: Pal.gold));
    } else if (OnlineService.I.me.value == null) {
      body = _handleSetup();
    } else {
      body = _lobby(OnlineService.I.me.value!);
    }
    return GameScaffold(title: tr('online.title'), tint: Pal.gold, body: body);
  }
}
