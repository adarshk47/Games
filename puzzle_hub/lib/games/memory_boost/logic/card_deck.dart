import 'dart:math';

const List<String> cardEmojis = [
  '🐶', '🐱', '🦊', '🐼', '🐸', '🐵', '🦁', '🐯', '🐙', '🦄',
  '🐢', '🦋', '🍎', '🍕', '🚀', '⚽', '🎸', '🌈', '🍩', '🌻',
];

class CardLevel {
  final int rows, cols;
  const CardLevel(this.rows, this.cols);
  int get pairs => rows * cols ~/ 2;
  String get label => '${rows}x$cols';
}

const List<CardLevel> cardLevels = [
  CardLevel(2, 2),
  CardLevel(2, 3),
  CardLevel(3, 4),
  CardLevel(4, 4),
  CardLevel(4, 5),
  CardLevel(5, 6),
  CardLevel(6, 6),
];

/// Returns a shuffled list of pair ids (each id in [0, pairs) appears twice).
List<int> generateDeck(int pairs, [Random? rng]) {
  assert(pairs > 0 && pairs <= cardEmojis.length);
  final deck = [for (var i = 0; i < pairs; i++) ...[i, i]];
  deck.shuffle(rng ?? Random());
  return deck;
}

bool isMatch(List<int> deck, int a, int b) => a != b && deck[a] == deck[b];

/// 3 stars for near-perfect play, 2 for decent, 1 for finishing.
int starsFor(int moves, int pairs) {
  if (moves <= (pairs * 1.5).ceil()) return 3;
  if (moves <= pairs * 2.5) return 2;
  return 1;
}
