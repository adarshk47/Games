import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import 'ludo_board.dart';

/// How dice values are made in an offline Ludo / Saanp-Seedhi game.
enum DiceMode {
  /// The app rolls.
  auto,

  /// Players throw a real dice at home and tap the number they got.
  manual,

  /// Players solve a small riddle; the answer (1..6) is the dice value.
  riddle;

  static DiceMode fromName(String? n) => DiceMode.values.firstWhere((m) => m.name == n, orElse: () => DiceMode.auto);
}

/// A riddle whose answer is a number from 1 to 6.
class DiceRiddle {
  const DiceRiddle(this.question, this.answer);
  final String question;
  final int answer;

  static DiceRiddle make(math.Random r) {
    switch (r.nextInt(5)) {
      case 0: // a + b
        final ans = 2 + r.nextInt(5);
        final a = 1 + r.nextInt(ans - 1);
        return DiceRiddle('$a + ${ans - a} = ?', ans);
      case 1: // a − b
        final ans = 1 + r.nextInt(6);
        final b = 1 + r.nextInt(9);
        return DiceRiddle('${ans + b} − $b = ?', ans);
      case 2: // a × b
        const pairs = [(1, 1), (1, 2), (1, 3), (2, 2), (1, 4), (1, 5), (2, 3), (1, 6), (3, 2), (5, 1)];
        final (a, b) = pairs[r.nextInt(pairs.length)];
        return DiceRiddle('$a × $b = ?', a * b);
      case 3: // a ÷ b
        final ans = 1 + r.nextInt(6);
        final b = 2 + r.nextInt(4);
        return DiceRiddle('${ans * b} ÷ $b = ?', ans);
      default: // what comes next
        final step = 1 + r.nextInt(2);
        final ans = 3 + r.nextInt(4);
        final start = ans - 3 * step;
        if (start < 0) return DiceRiddle('${ans - 2}, ${ans - 1}, ?', ans);
        return DiceRiddle('$start, ${start + step}, ${start + 2 * step}, ?', ans);
    }
  }
}

final _rnd = math.Random();

/// Asks the player for the dice value. Returns 1..6, 0 for a wrong riddle
/// answer (turn passes), or null if the player closed the sheet.
Future<int?> askDice(BuildContext context, DiceMode mode, Color color) {
  if (mode == DiceMode.manual) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1740),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('dice.manual_ask'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (var v = 1; v <= 6; v++)
                GestureDetector(
                  key: ValueKey('dice_pick_$v'),
                  onTap: () => Navigator.of(ctx).pop(v),
                  child: LudoDice(value: v, color: color, size: 58),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
  final q = DiceRiddle.make(_rnd);
  return showModalBottomSheet<int>(
    context: context,
    isDismissible: false,
    backgroundColor: const Color(0xFF1A1740),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('dice.riddle_ask'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(q.question, key: const ValueKey('dice_riddle'), style: const TextStyle(color: Pal.text, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (var v = 1; v <= 6; v++)
              SizedBox(
                width: 64,
                height: 52,
                child: ElevatedButton(
                  key: ValueKey('dice_answer_$v'),
                  style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.85), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.of(ctx).pop(v == q.answer ? v : 0),
                  child: Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
              ),
          ]),
        ]),
      ),
    ),
  );
}

/// Chips to pick the dice mode in a game menu.
class DiceModePicker extends StatelessWidget {
  const DiceModePicker({super.key, required this.value, required this.onChanged, required this.color});
  final DiceMode value;
  final ValueChanged<DiceMode> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (m, icon) in const [(DiceMode.auto, '🎲'), (DiceMode.manual, '✋'), (DiceMode.riddle, '🧩')])
          ChoiceChip(
            key: ValueKey('dice_mode_${m.name}'),
            label: Text('$icon ${tr('dice.mode.${m.name}')}'),
            selected: value == m,
            selectedColor: color.withValues(alpha: 0.55),
            onSelected: (_) => onChanged(m),
          ),
      ]);
}
