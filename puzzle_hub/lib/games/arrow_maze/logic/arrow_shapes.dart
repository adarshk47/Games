import 'dart:math' as math;

/// Board outlines for Arrow Maze: every level is a picture (a big letter, a
/// heart, a train, a city skyline...) instead of a plain rectangle. Arrows
/// fill only the cells inside the picture and fly out across the empty cells.
///
/// Shapes are small pixel templates ('#' = inside) scaled up to the level's
/// board size, so they stay crisp on big boards and still fit small ones.
class ArrowShape {
  const ArrowShape(this.id, this.emoji, this.rows);
  final String id;
  final String emoji;
  final List<String> rows;

  int get h => rows.length;
  int get w => rows.first.length;

  bool at(int r, int c) => rows[r][c] == '#';
}

/// A shape scaled onto a board: [inside] has rows * cols entries.
class ShapedBoard {
  const ShapedBoard(this.shape, this.rows, this.cols, this.inside);
  final ArrowShape shape;
  final int rows, cols;
  final List<bool> inside;

  int get insideCount => inside.where((x) => x).length;
}

// ---------------------------------------------------------------- letters (5x7)
const _letters = <String, List<String>>{
  'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  'G': ['.####', '#....', '#....', '#.###', '#...#', '#...#', '.###.'],
  'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'I': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'],
  'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
  'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
  'N': ['#...#', '##..#', '#.#.#', '#.#.#', '#..##', '#...#', '#...#'],
  'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
  'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
  'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
  'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
  'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
  'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
  'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
};

ArrowShape _letter(String l) => ArrowShape('letter_$l', l, _letters[l]!);

/// Two letters side by side with a 1-cell gap.
ArrowShape _word(String w) {
  final a = _letters[w[0]]!, b = _letters[w[1]]!;
  return ArrowShape('word_$w', w, [for (var i = 0; i < 7; i++) '${a[i]}.${b[i]}']);
}

// ---------------------------------------------------------------- pictures
const _heart = ArrowShape('heart', '❤️', [
  '.###...###.',
  '#####.#####',
  '###########',
  '###########',
  '###########',
  '.#########.',
  '..#######..',
  '...#####...',
  '....###....',
  '.....#.....',
]);

const _star = ArrowShape('star', '⭐', [
  '.....#.....',
  '....###....',
  '....###....',
  '###########',
  '.#########.',
  '..#######..',
  '..#######..',
  '.####.####.',
  '.###...###.',
  '##.......##',
]);

const _train = ArrowShape('train', '🚂', [
  '.##.............',
  '.##....#########',
  '####...#########',
  '####...#########',
  '################',
  '################',
  '################',
  '.##.##.....##.##',
  '.##.##.....##.##',
]);

const _bus = ArrowShape('bus', '🚌', [
  '##############..',
  '#..#..#..#..###.',
  '#..#..#..#..####',
  '################',
  '################',
  '################',
  '.###.......###..',
  '.###.......###..',
]);

const _plane = ArrowShape('plane', '✈️', [
  '......#......',
  '.....###.....',
  '.....###.....',
  '.....###.....',
  '....#####....',
  '..#########..',
  '#############',
  '#############',
  '.....###.....',
  '.....###.....',
  '....#####....',
  '...#######...',
  '.....###.....',
]);

const _rocket = ArrowShape('rocket', '🚀', [
  '....#....',
  '...###...',
  '..#####..',
  '..#####..',
  '.#######.',
  '.###.###.',
  '.##...##.',
  '.###.###.',
  '.#######.',
  '.#######.',
  '##.###.##',
  '#..###..#',
  '#..###..#',
  '...#.#...',
]);

const _mountain = ArrowShape('mountain', '🏔️', [
  '..........##....',
  '.........####...',
  '....#...######..',
  '...###.########.',
  '..#############.',
  '.###############',
  '################',
  '################',
]);

const _city = ArrowShape('city', '🏙️', [
  '..##..........',
  '..##......##..',
  '..##.###..##..',
  '####.###..##..',
  '####.###.#####',
  '####.########.',
  '#############.',
  '##############',
  '##############',
  '##############',
]);

const _crown = ArrowShape('crown', '👑', [
  '#....#....#',
  '##..###..##',
  '##..###..##',
  '###.###.###',
  '###########',
  '###########',
  '###########',
  '###########',
]);

const _house = ArrowShape('house', '🏠', [
  '.....#.....',
  '....###....',
  '...#####...',
  '..#######..',
  '.#########.',
  '###########',
  '.#########.',
  '.###...###.',
  '.###...###.',
  '.###...###.',
  '.#########.',
]);

const _tree = ArrowShape('tree', '🌳', [
  '....###....',
  '..#######..',
  '.#########.',
  '###########',
  '###########',
  '.#########.',
  '..#######..',
  '....###....',
  '....###....',
  '....###....',
  '..#######..',
]);

const _diamond = ArrowShape('diamond', '💎', [
  '.#########.',
  '###########',
  '###########',
  '.#########.',
  '..#######..',
  '...#####...',
  '....###....',
  '.....#.....',
]);

const _ring = ArrowShape('ring', '⭕', [
  '...#####...',
  '.#########.',
  '####...####',
  '###.....###',
  '###.....###',
  '###.....###',
  '####...####',
  '.#########.',
  '...#####...',
]);

const _fish = ArrowShape('fish', '🐟', [
  '.....####.....',
  '...#######...#',
  '.##########.##',
  '##.#########.#',
  '##############',
  '.##########.##',
  '...#######...#',
  '.....####.....',
]);

// Small pictures for the small early boards.
const _miniHeart = ArrowShape('mini_heart', '❤️', [
  '##.##',
  '#####',
  '#####',
  '#####',
  '.###.',
  '..#..',
]);

const _miniHouse = ArrowShape('mini_house', '🏠', [
  '..#..',
  '.###.',
  '#####',
  '#####',
  '##.##',
  '##.##',
]);

const _miniTree = ArrowShape('mini_tree', '🌲', [
  '..#..',
  '.###.',
  '#####',
  '.###.',
  '#####',
  '..#..',
  '.###.',
]);

const _cup = ArrowShape('cup', '🏆', [
  '#######',
  '#######',
  '.#####.',
  '..###..',
  '...#...',
  '..###..',
  '.#####.',
]);

const _arrow = ArrowShape('arrow', '⬆️', [
  '...#...',
  '..###..',
  '.#####.',
  '#######',
  '..###..',
  '..###..',
  '..###..',
]);

/// Pictures (most levels) and big letters / words (every third level).
final List<ArrowShape> kArrowPictures = [
  _heart, _star, _house, _crown, _diamond, _tree, _ring, _rocket, _plane,
  _fish, _mountain, _city, _train, _bus,
];
final List<ArrowShape> kArrowMiniPictures = [_miniHeart, _miniHouse, _miniTree, _cup, _arrow];
final List<ArrowShape> kArrowLetters = [
  for (final l in 'MASTERGXZKWHYPNOI'.split('')) _letter(l),
  _word('GO'), _word('HI'), _word('OK'),
];
List<ArrowShape> get kArrowShapes => [...kArrowPictures, ...kArrowMiniPictures, ...kArrowLetters];

/// Board size for [shape] on a level whose plain board is [maxRows] x
/// [maxCols]: grown a little so the picture holds about as many cells as the
/// plain rectangle (up to 30% per side, never over 34 x 22 so cells stay
/// tappable), then fitted to the picture's proportions.
(int, int) _dims(ArrowShape shape, int maxRows, int maxCols) {
  final fill = shape.rows.join().split('').where((x) => x == '#').length / (shape.h * shape.w);
  final grow = math.min(1.3, math.sqrt(1 / fill));
  final mr = math.min((maxRows * grow).round(), math.max(maxRows, 34));
  final mc = math.min((maxCols * grow).round(), math.max(maxCols, 22));
  final k = math.min(mr / shape.h, mc / shape.w);
  // Allow a little stretch so the board is filled better, but keep the look.
  final ky = math.min(mr / shape.h, k * 1.2);
  final kx = math.min(mc / shape.w, k * 1.2);
  return ((shape.h * ky).floor(), (shape.w * kx).floor());
}

/// Picks the shape of a level ([pick] = level number based) and scales it
/// onto the board. Shapes that do not fit are skipped, so small early boards
/// get letters.
ShapedBoard shapeBoard(int maxRows, int maxCols, int pick) {
  bool fits(ArrowShape s) {
    final (r, c) = _dims(s, maxRows, maxCols);
    return r >= s.h && c >= s.w;
  }

  // Detailed pictures when they fit, the small ones on small boards.
  var pics = kArrowPictures.where(fits).toList();
  if (pics.isEmpty) pics = kArrowMiniPictures.where(fits).toList();
  final lets = kArrowLetters.where(fits).toList();
  final usePic = pics.isNotEmpty && (lets.isEmpty || pick % 3 != 2);
  final list = usePic ? pics : lets;
  final shape = list[(usePic ? pick - pick ~/ 3 : pick ~/ 3) % list.length];
  final (rows, cols) = _dims(shape, maxRows, maxCols);
  final inside = List<bool>.filled(rows * cols, false);
  for (var r = 0; r < rows; r++) {
    final tr = ((r + 0.5) * shape.h / rows).floor().clamp(0, shape.h - 1);
    for (var c = 0; c < cols; c++) {
      final tc = ((c + 0.5) * shape.w / cols).floor().clamp(0, shape.w - 1);
      inside[r * cols + c] = shape.at(tr, tc);
    }
  }
  return ShapedBoard(shape, rows, cols, inside);
}
