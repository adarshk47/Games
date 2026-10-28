import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../storage.dart';
import 'ui.dart';

/// Names for computer players (famous computers) and editable names for
/// friends playing on one phone (saved for next time).
class PlayerNames {
  PlayerNames._();

  /// Computer players: India's Param supercomputer first, then other famous ones.
  static const bots = ['Param', 'Deep Blue', 'Watson', 'AlphaGo'];

  /// Name of computer player [seat] (seat 0 is the human).
  static String bot(int seat) => '🤖 ${bots[(seat - 1) % bots.length]}';

  static const _key = 'players.names';

  /// Saved name of friend [seat] (0-based), or "Player N".
  static String friend(int seat) {
    final saved = (Storage.getString(_key) ?? '').split('\n');
    final n = seat < saved.length ? saved[seat].trim() : '';
    return n.isNotEmpty ? n : tr('biz.player_n', {'n': seat + 1});
  }

  static Future<void> setFriend(int seat, String name) async {
    final saved = (Storage.getString(_key) ?? '').split('\n');
    while (saved.length <= seat) {
      saved.add('');
    }
    saved[seat] = name.trim().replaceAll('\n', ' ');
    await Storage.setString(_key, saved.join('\n'));
  }
}

/// Text fields to name the friends in a pass & play game.
class PlayerNamesEditor extends StatefulWidget {
  const PlayerNamesEditor({super.key, required this.count, this.colors});
  final int count;

  /// Optional colour dot per seat.
  final List<Color>? colors;

  @override
  State<PlayerNamesEditor> createState() => _PlayerNamesEditorState();
}

class _PlayerNamesEditorState extends State<PlayerNamesEditor> {
  late final List<TextEditingController> _c = [
    for (var i = 0; i < 4; i++) TextEditingController(text: _initial(i)),
  ];

  String _initial(int i) {
    final n = PlayerNames.friend(i);
    return n == tr('biz.player_n', {'n': i + 1}) ? '' : n;
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < widget.count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              blur: 0,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (widget.colors != null)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.colors![i % widget.colors!.length]),
                  ),
                Expanded(
                  child: TextField(
                    key: ValueKey('player_name_$i'),
                    controller: _c[i],
                    maxLength: 16,
                    style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: tr('biz.player_n', {'n': i + 1}),
                      hintStyle: const TextStyle(color: Pal.textDim),
                    ),
                    onChanged: (v) => PlayerNames.setFriend(i, v),
                  ),
                ),
                const Icon(Icons.edit_rounded, color: Pal.textDim, size: 18),
              ]),
            ),
          ),
      ]);
}
