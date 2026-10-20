import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import 'logic/ludo_logic.dart';
import 'ludo_board.dart';

/// Board + players + dice for one Ludo game. [canAct] says whether the
/// player to move is controlled on this phone right now.
class LudoTable extends StatelessWidget {
  const LudoTable({
    super.key,
    required this.game,
    required this.canAct,
    required this.onRoll,
    required this.onToken,
    this.rollSeq = 0,
    this.status,
    this.secondsLeft,
  });

  final LudoGame game;
  final bool canAct;
  final VoidCallback onRoll;
  final void Function(int token) onToken;
  final int rollSeq;
  final String? status;

  /// Turn timer (online), null = none.
  final int? secondsLeft;

  String _name(int seat) {
    final s = game.seats[seat];
    if (s.name.isNotEmpty) return s.name;
    return tr('ludo.colour.${s.colour}');
  }

  Widget _chip(int seat) {
    final c = ludoColors[game.colourOf(seat)];
    final turn = seat == game.turn && !game.over;
    final place = game.finished.indexOf(seat);
    final home = game.tokens[seat].where((p) => p == Ludo.home).length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: c.withValues(alpha: turn ? 0.45 : 0.18),
        border: Border.all(color: turn ? Colors.white : c.withValues(alpha: 0.6), width: turn ? 2 : 1),
        boxShadow: turn ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 18, height: 18, child: LudoToken(color: c)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            place >= 0 ? '${place + 1}. ${_name(seat)}' : _name(seat),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        Text('🏠$home', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        if (game.seats[seat].kind == SeatKind.bot) const Text(' 🤖', style: TextStyle(fontSize: 11)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seat = game.turn;
    final colour = ludoColors[game.colourOf(seat)];
    final mustRoll = canAct && game.pending == null && !game.over;
    final movable = canAct && game.pending != null ? game.movable(seat, game.pending!) : const <int>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [for (var s = 0; s < game.seats.length; s++) _chip(s)],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: LudoBoard(
              key: const ValueKey('ludoBoard'),
              game: game,
              movable: movable,
              onToken: (i) {
                AppAudio.haptic();
                onToken(i);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                game.over ? tr('ludo.game_over') : tr('ludo.turn_of', {'name': _name(seat)}),
                style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                status ??
                    (game.over
                        ? ''
                        : mustRoll
                            ? tr('ludo.tap_dice')
                            : movable.isNotEmpty
                                ? tr('ludo.pick_token')
                                : tr('ludo.waiting')),
                style: const TextStyle(color: Pal.textDim, fontSize: 13),
              ),
              if (secondsLeft != null && !game.over)
                Text(tr('ludo.seconds', {'n': secondsLeft}), style: TextStyle(color: secondsLeft! <= 10 ? const Color(0xFFFF6B6B) : Pal.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          LudoDice(
            key: const ValueKey('ludo_dice'),
            value: game.pending ?? game.last.rolled,
            color: colour,
            enabled: mustRoll,
            rollSeq: rollSeq,
            onTap: onRoll,
          ),
        ]),
      ]),
    );
  }
}
