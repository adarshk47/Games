import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// Undo rule picked before a Chess / Ludo game: take moves back as often as
/// you like (an ad every few steps, see UndoOffer), 3 free undos per game, or
/// no undo at all.
enum UndoMode {
  unlimited,
  three,
  off;

  static const freeUndos = 3;

  static UndoMode fromIndex(int i) => values[i.clamp(0, values.length - 1)];
}

/// Choice chips for [UndoMode] on a game's setup screen.
class UndoModePicker extends StatelessWidget {
  const UndoModePicker({super.key, required this.value, required this.onChanged, required this.color});
  final UndoMode value;
  final ValueChanged<UndoMode> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (m, icon) in const [(UndoMode.unlimited, '♾️'), (UndoMode.three, '3️⃣'), (UndoMode.off, '🚫')])
          ChoiceChip(
            key: ValueKey('undo_mode_${m.name}'),
            label: Text('$icon ${tr('undo.mode.${m.name}')}'),
            selected: value == m,
            selectedColor: color.withValues(alpha: 0.55),
            onSelected: (_) => onChanged(m),
          ),
      ]);
}
