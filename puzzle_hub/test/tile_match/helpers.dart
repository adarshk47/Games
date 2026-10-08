import 'package:puzzle_hub/games/tile_match/logic/tile_match_logic.dart';

/// Picks that fill the tray without ever making a triple.
List<int> losingLine(TmGame g) {
  final out = <int>[];
  while (!g.over) {
    final free = g.freeTiles.toList()..sort();
    int countOf(int t) => g.tray.where((x) => g.icons[x] == g.icons[t]).length;
    free.sort((a, b) => countOf(a).compareTo(countOf(b)));
    final pick = free.firstWhere((t) => countOf(t) < 2, orElse: () => -1);
    if (pick < 0) break;
    g.tap(pick);
    out.add(pick);
  }
  return out;
}
