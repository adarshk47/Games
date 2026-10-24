import 'dart:async';

import '../../../core/share/score_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/auth_screens.dart';
import '../../../core/cloud/cloud_auth.dart';
import '../../../core/cloud/cloud_service.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/ui.dart';
import '../../chess/online/online_lobby_screen.dart';
import '../ludo_board.dart';
import '../../snakes/online/snakes_online_game.dart';
import 'ludo_online_game.dart';
import 'ludo_online_service.dart';

/// Opens an online Ludo or Saanp-Seedhi game.
void openBoardGame(NavigatorState nav, String id, String game) => nav.push(MaterialPageRoute<void>(
      builder: (_) => game == 'snakes' ? SnakesOnlineGameScreen(gameId: id) : LudoOnlineGameScreen(gameId: id),
    ));

/// Online Ludo / Saanp-Seedhi: quick match, rooms with a code for 2–4
/// friends, and challenges by player name.
class LudoOnlineLobby extends StatefulWidget {
  const LudoOnlineLobby({super.key, this.game = 'ludo'});

  /// 'ludo' or 'snakes'.
  final String game;

  @override
  State<LudoOnlineLobby> createState() => _LudoOnlineLobbyState();
}

class _LudoOnlineLobbyState extends State<LudoOnlineLobby> {
  final _code = TextEditingController();
  final _search = TextEditingController();
  List<OnlinePlayer>? _found;
  Future<List<LudoOnlineGame>>? _games;
  int _roomSize = 4;

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
    _code.dispose();
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (_games == null) _load();
    setState(() {});
  }

  void _load() {
    if (OnlineService.I.ready) _games = LudoOnline.I.myGames(widget.game);
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _open(NavigatorState nav, String id, [String? game]) => openBoardGame(nav, id, game ?? widget.game);

  Future<void> _waitDialog(String text, Stream<String?> ids, Future<void> Function() cancel, {Stream<String>? failures}) async {
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
      _open(nav, id);
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
      final ids = await LudoOnline.I.quickMatch(widget.game);
      if (!mounted) return;
      await _waitDialog(tr('online.searching'), ids, LudoOnline.I.leaveQueue);
      unawaited(LudoOnline.I.leaveQueue());
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  Future<void> _createRoom() async {
    try {
      final code = await LudoOnline.I.createRoom(_roomSize, false, widget.game);
      if (mounted) _roomDialog(code);
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  Future<void> _joinRoom() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 5) return _snack(tr('ludo.err.no_room'));
    final err = await LudoOnline.I.joinRoom(code);
    if (!mounted) return;
    if (err != null) return _snack(tr(err));
    _roomDialog(code);
  }

  /// Shows the room: code to share, who joined, Start for the host.
  void _roomDialog(String code) {
    final nav = Navigator.of(context);
    final me = OnlineService.I.uid;
    var opened = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StreamBuilder<LudoRoom?>(
        stream: LudoOnline.I.watchRoom(code),
        builder: (ctx, snap) {
          final r = snap.data;
          if (snap.connectionState == ConnectionState.active && r == null) {
            // Host closed the room.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            });
          }
          if (r != null && r.gameId != null && !opened) {
            opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(ctx).pop();
              _open(nav, r.gameId!, r.game);
            });
          }
          final host = r?.host == me;
          return AlertDialog(
            backgroundColor: const Color(0xFF241A4F),
            title: Text(tr('ludo.room'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('ludo.room_share'), style: const TextStyle(color: Pal.textDim, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                SelectableText(code, key: const ValueKey('ludo_room_code'), style: const TextStyle(color: Pal.gold, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Pal.gold),
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                ),
              ]),
              TextButton.icon(
                key: const ValueKey('ludo_room_invite'),
                onPressed: () => ScoreShare.invite(tr('invite.room', {'game': tr('game.${widget.game}.title'), 'code': code})),
                icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                label: Text(tr('invite.whatsapp'), style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              if (r != null)
                for (final (i, n) in r.names.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(width: 18, height: 18, child: LudoToken(color: ludoColors[i])),
                      const SizedBox(width: 8),
                      Text('@$n', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              if (r != null) Text(tr('ludo.room_count', {'n': r.players.length, 'max': r.max}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              if (r != null && !host) Text(tr('ludo.room_wait_host'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
            actions: [
              TextButton(
                onPressed: () {
                  if (r != null) unawaited(LudoOnline.I.leaveRoom(r));
                  Navigator.of(ctx).pop();
                },
                child: Text(tr('ludo.leave'), style: const TextStyle(color: Pal.textDim)),
              ),
              if (host)
                TextButton(
                  key: const ValueKey('ludo_room_start'),
                  onPressed: r != null && r.players.length >= 2 ? () => LudoOnline.I.startRoom(r) : null,
                  child: Text(tr('ludo.start'), style: TextStyle(color: r != null && r.players.length >= 2 ? Pal.gold : Pal.textDim, fontWeight: FontWeight.w900)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _doSearch() async {
    if (_search.text.trim().isEmpty) return;
    try {
      final r = await OnlineService.I.search(_search.text);
      if (mounted) setState(() => _found = r);
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  Future<void> _challenge(OnlinePlayer p) async {
    try {
      final id = await OnlineService.I.challenge(p, game: widget.game);
      if (!mounted) return;
      final s = OnlineService.I.watchChallenge(id).asBroadcastStream();
      await _waitDialog(
        tr('online.waiting_for', {'name': '@${p.handle}'}),
        s.map((c) => c?.status == 'accepted' ? c?.gameId : null),
        () => OnlineService.I.cancelChallenge(id),
        failures: s.where((c) => c?.status == 'declined').map((_) => tr('online.declined', {'name': '@${p.handle}'})),
      );
    } catch (_) {
      _snack(tr('online.err.network'));
    }
  }

  Widget _inviteButton() => OutlinedButton.icon(
        key: const ValueKey('online_invite_friend'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366)), padding: const EdgeInsets.symmetric(vertical: 12)),
        onPressed: () => ScoreShare.invite(tr('invite.play', {
          'game': tr('game.${widget.game}.title'),
          'name': '@${OnlineService.I.me.value?.handle ?? ''}',
        })),
        icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
        label: Text(tr('invite.friend'), style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w800)),
      );

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
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 18), action],
          ]),
        ),
      );

  Widget _lobby() {
    final me = OnlineService.I.uid;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
      PremiumButton(key: const ValueKey('ludo_online_quick'), label: tr('ludo.quick_match'), icon: Icons.bolt_rounded, onTap: _quick),
      const SizedBox(height: 8),
      _inviteButton(),
      _section(tr('ludo.play_friends')),
      GlassCard(
        blur: 0,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('ludo.create_room'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            for (final n in const [2, 3, 4])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tr('ludo.n_players', {'n': n})),
                  selected: _roomSize == n,
                  onSelected: (_) => setState(() => _roomSize = n),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          PremiumButton(key: const ValueKey('ludo_create_room'), label: tr('ludo.create_room'), icon: Icons.add_rounded, compact: true, onTap: _createRoom),
          const Divider(color: Colors.white24, height: 24),
          Text(tr('ludo.join_room'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('ludo_join_code'),
                controller: _code,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, letterSpacing: 3),
                decoration: InputDecoration(hintText: tr('ludo.code_hint'), hintStyle: const TextStyle(color: Pal.textDim), counterText: ''),
              ),
            ),
            PremiumButton(label: tr('ludo.join'), compact: true, onTap: _joinRoom),
          ]),
        ]),
      ),
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
                        Text(switch (c.game) { 'ludo' => '🎲 ', 'snakes' => '🐍 ', _ => '♟️ ' }),
                        Expanded(child: Text('@${c.fromName}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800))),
                        TextButton(onPressed: () => OnlineService.I.decline(c), child: Text(tr('online.decline'), style: const TextStyle(color: Pal.textDim))),
                        PremiumButton(
                          label: tr('online.accept'),
                          compact: true,
                          onTap: () async {
                            try {
                              await acceptChallenge(c, Navigator.of(context));
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
      FutureBuilder<List<LudoOnlineGame>>(
        future: _games,
        builder: (context, snap) {
          final list = snap.data ?? const <LudoOnlineGame>[];
          if (list.isEmpty) return const SizedBox();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section(tr('online.my_games')),
            for (final g in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pressable(
                  onTap: () => _open(Navigator.of(context), g.id),
                  child: GlassCard(
                    blur: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Text(widget.game == 'snakes' ? '🐍' : '🎲', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text([for (final (i, n) in g.names.indexed) if (g.players[i] != me) '@$n'].join(', '),
                            overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                      ),
                      const Icon(Icons.play_arrow_rounded, color: Pal.gold),
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
            controller: _search,
            onSubmitted: (_) => _doSearch(),
            style: const TextStyle(color: Pal.text),
            decoration: InputDecoration(prefixText: '@', hintText: tr('online.search_hint'), hintStyle: const TextStyle(color: Pal.textDim)),
          ),
        ),
        IconButton(onPressed: _doSearch, icon: const Icon(Icons.search_rounded, color: Pal.gold)),
      ]),
      if (_found != null)
        if (_found!.isEmpty)
          Text(tr('online.none_found'), style: const TextStyle(color: Pal.textDim))
        else
          for (final p in _found!)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassCard(
                blur: 0,
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(children: [
                  Expanded(child: Text('@${p.handle}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800))),
                  PremiumButton(label: tr('online.challenge'), compact: true, onTap: () => _challenge(p)),
                ]),
              ),
            ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!CloudService.available) {
      body = _message(Icons.cloud_off_rounded, tr('online.title'), CloudService.pendingText);
    } else if (CloudAuth.I.user.value == null) {
      body = _message(Icons.public_rounded, tr('online.signin_title'), tr('ludo.online_text'), action: const CloudSignInPanel());
    } else if (!OnlineService.I.meLoaded.value) {
      body = const Center(child: CircularProgressIndicator(color: Pal.gold));
    } else if (OnlineService.I.me.value == null) {
      body = _message(
        Icons.badge_rounded,
        tr('online.pick_handle'),
        tr('online.pick_handle_text'),
        action: PremiumButton(
          label: tr('online.pick_handle'),
          compact: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OnlineLobbyScreen())),
        ),
      );
    } else {
      body = _lobby();
    }
    return GameScaffold(title: '${tr('game.${widget.game}.title')} · ${tr('online.title')}', tint: const Color(0xFFE53935), body: body);
  }
}
