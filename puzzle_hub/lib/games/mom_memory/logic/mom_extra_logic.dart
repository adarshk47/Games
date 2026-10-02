import 'dart:math';

/// Small emoji thing with a Hinglish name.
class MmThing {
  const MmThing(this.emoji, this.hi);
  final String emoji, hi;
}

// ---------- Missing Item (Kya gaya?) ----------
const missingPool = [
  MmThing('🍼', 'Bottle'),
  MmThing('🧸', 'Khilona'),
  MmThing('🧦', 'Moze'),
  MmThing('🧷', 'Pin'),
  MmThing('🛁', 'Tub'),
  MmThing('🧴', 'Lotion'),
  MmThing('🧺', 'Tokri'),
  MmThing('🪥', 'Brush'),
  MmThing('🧼', 'Sabun'),
  MmThing('🧣', 'Shawl'),
  MmThing('🧢', 'Topi'),
  MmThing('🦆', 'Battakh'),
  MmThing('🍪', 'Biscuit'),
  MmThing('🔔', 'Ghanti'),
  MmThing('🪮', 'Kanghi'),
  MmThing('🥄', 'Chamach'),
  MmThing('☕', 'Chai'),
  MmThing('🔑', 'Chaabi'),
];

const missingMaxLevel = 5;

/// 4 items at level 0 up to 9 at level 5.
int missingCount(int level) => 4 + level.clamp(0, missingMaxLevel);
int missingShowSeconds(int level) => 4 + missingCount(level);

class MissingRound {
  MissingRound(this.items, this.hiddenIndex, this.options);
  final List<int> items; // indices into missingPool, in display order
  final int hiddenIndex; // position in [items] that disappears
  final List<int> options; // pool indices (4), includes the hidden one
  int get answer => items[hiddenIndex];
}

MissingRound buildMissingRound(int level, Random rng) {
  final count = missingCount(level);
  final all = List.generate(missingPool.length, (i) => i)..shuffle(rng);
  final items = all.take(count).toList();
  final hidden = rng.nextInt(count);
  final distract = all.skip(count).take(3).toList();
  final options = [items[hidden], ...distract]..shuffle(rng);
  return MissingRound(items, hidden, options);
}

/// Gentle: wrong tries only lower stars, never end the round.
int triesToStars(int tries) => tries <= 1 ? 3 : (tries == 2 ? 2 : 1);

// ---------- Word Pairs (Jodi Milao) ----------
class WordPair {
  const WordPair(this.word, this.partner);
  final String word; // Hindi/English word shown
  final MmThing partner;
}

const wordPairs = [
  WordPair('Doodh', MmThing('🍼', 'Bottle')),
  WordPair('Neend', MmThing('😴', 'Sona')),
  WordPair('Nahana', MmThing('🛁', 'Tub')),
  WordPair('Lori', MmThing('🌙', 'Chaand')),
  WordPair('Khilona', MmThing('🧸', 'Teddy')),
  WordPair('Sardi', MmThing('🧣', 'Shawl')),
  WordPair('Baarish', MmThing('☔', 'Chhatri')),
  WordPair('Roti', MmThing('🥣', 'Katori')),
  WordPair('Phool', MmThing('🌸', 'Bagiya')),
  WordPair('Sooraj', MmThing('☀️', 'Roshni')),
  WordPair('Paani', MmThing('💧', 'Glass')),
  WordPair('Kitaab', MmThing('📖', 'Kahani')),
  WordPair('Chai', MmThing('☕', 'Pyaali')),
  WordPair('Taare', MmThing('⭐', 'Aasman')),
  WordPair('Gaadi', MmThing('🚗', 'Sadak')),
  WordPair('Tooth', MmThing('🪥', 'Brush')),
];

const pairsMaxLevel = 5;

/// 3 pairs at level 0 up to 6 at level 5.
int pairsCount(int level) =>
    3 + (level.clamp(0, pairsMaxLevel) * 3 / 5).round();
int pairsOptionCount(int level) => level < 2 ? 3 : 4;
int pairsShowSeconds(int level) => 6 + pairsCount(level) * 2;
int pairsQuestionCount(int level) => min(pairsCount(level), 3);

class PairQuestion {
  PairQuestion(this.pairIndex, this.options, this.answerOption);
  final int pairIndex; // index into wordPairs
  final List<int>
  options; // indices into wordPairs (their partners are options)
  final int answerOption; // position in [options] holding the right one
}

class PairsRound {
  PairsRound(this.shown, this.questions);
  final List<int> shown; // wordPairs indices
  final List<PairQuestion> questions;
}

PairsRound buildPairsRound(int level, Random rng) {
  final all = List.generate(wordPairs.length, (i) => i)..shuffle(rng);
  final shown = all.take(pairsCount(level)).toList();
  final qs = (List.of(shown)..shuffle(rng)).take(pairsQuestionCount(level));
  final n = pairsOptionCount(level);
  final questions = <PairQuestion>[];
  for (final q in qs) {
    final others = all.where((i) => i != q).toList()..shuffle(rng);
    final opts = [q, ...others.take(n - 1)]..shuffle(rng);
    questions.add(PairQuestion(q, opts, opts.indexOf(q)));
  }
  return PairsRound(shown, questions);
}

int pairsStars(int correct, int total) {
  if (total == 0) return 0;
  final r = correct / total;
  if (r >= 0.99) return 3;
  if (r >= 0.6) return 2;
  return 1;
}

// ---------- Where Was It? (Kahan tha?) ----------
const whereEmojis = ['🐥', '🌸', '⭐', '🧸', '🍼', '🦋', '🌙', '🍓', '🐰', '🎈'];
const whereMaxLevel = 5;

int whereSize(int level) => level.clamp(0, whereMaxLevel) < 3 ? 3 : 4;
int whereCount(int level) =>
    const [2, 3, 4, 4, 5, 6][level.clamp(0, whereMaxLevel)];
int whereShowMs(int level) => 2200 + whereCount(level) * 500;

/// Returns cell -> emoji index.
Map<int, int> buildWhereRound(int level, Random rng) {
  final size = whereSize(level);
  final cells = List.generate(size * size, (i) => i)..shuffle(rng);
  final emo = List.generate(whereEmojis.length, (i) => i)..shuffle(rng);
  final n = whereCount(level);
  return {for (var i = 0; i < n; i++) cells[i]: emo[i % emo.length]};
}

({int correct, int wrong}) scoreWhere(
  Iterable<int> tapped,
  Iterable<int> cells,
) {
  final s = cells.toSet();
  final t = tapped.toSet();
  return (
    correct: t.where(s.contains).length,
    wrong: t.where((x) => !s.contains(x)).length,
  );
}

/// Extra wrong taps only soften the score a little.
int whereStars(int correct, int wrong, int total) {
  if (total == 0) return 0;
  final eff = max(0, correct - wrong ~/ 2) / total;
  if (eff >= 0.99) return 3;
  if (eff >= 0.6) return 2;
  return 1;
}

// ---------- Story Recall (Kahani yaad karo) ----------
class StoryQ {
  const StoryQ(this.q, this.options, this.answer);
  final String q;
  final List<String> options;
  final int answer;
}

class MmStory {
  const MmStory(this.emoji, this.title, this.lines, this.questions);
  final String emoji, title;
  final List<String> lines;
  final List<StoryQ> questions;
}

const stories = [
  MmStory(
    '🐥',
    'Chhoti Chidiya',
    [
      'Sunita ki chhoti chidiya ka naam Chiku tha.',
      'Roz subah Chiku neem ke ped par gaana gaati thi.',
      'Aaj Sunita ne use teen laal daane khilaaye.',
      'Chiku khush hokar phurr se ud gayi.',
    ],
    [
      StoryQ('Chidiya ka naam kya tha?', ['Chiku', 'Mithu', 'Tuntun'], 0),
      StoryQ('Chiku kis ped par gaati thi?', ['Aam', 'Neem', 'Peepal'], 1),
      StoryQ('Sunita ne kitne daane khilaaye?', ['Do', 'Teen', 'Paanch'], 1),
    ],
  ),
  MmStory(
    '🧸',
    'Pyaara Teddy',
    [
      'Aarav ke paas ek bhura teddy tha.',
      'Teddy ne neela scarf pehna tha.',
      'Raat ko Aarav teddy ko god mein lekar so jaata.',
      'Dono ko meethe sapne aate.',
    ],
    [
      StoryQ('Teddy ka rang kaisa tha?', ['Bhura', 'Safed', 'Gulabi'], 0),
      StoryQ('Teddy ne kya pehna tha?', ['Topi', 'Neela scarf', 'Moze'], 1),
      StoryQ('Aarav teddy ko kab god mein leta?', [
        'Subah',
        'Dopahar',
        'Raat ko',
      ], 2),
    ],
  ),
  MmStory(
    '🌧️',
    'Baarish Ka Din',
    [
      'Aaj Meera ke ghar ke bahar halki baarish ho rahi thi.',
      'Maa ne garam adrak wali chai banayi.',
      'Meera ne khidki se chhote bachchon ko chhatri mein dekha.',
      'Sab kuch bahut shaant aur sundar tha.',
    ],
    [
      StoryQ('Bahar kya ho raha tha?', ['Dhoop', 'Halki baarish', 'Aandhi'], 1),
      StoryQ('Maa ne kaisi chai banayi?', [
        'Adrak wali',
        'Elaichi wali',
        'Bina cheeni',
      ], 0),
      StoryQ('Meera ne kahan se dekha?', [
        'Chhat se',
        'Darwaze se',
        'Khidki se',
      ], 2),
    ],
  ),
  MmStory(
    '🍼',
    'Nanhi Gudiya',
    [
      'Nanhi Gudiya subah paanch baje uthi.',
      'Dadi ne use halka doodh pilaya.',
      'Phir Gudiya ne peele rang ka khilona pakda.',
      'Dadi ne pyaar se uske sir par haath fera.',
    ],
    [
      StoryQ('Gudiya kab uthi?', ['Paanch baje', 'Saat baje', 'Chhe baje'], 0),
      StoryQ('Doodh kisne pilaya?', ['Nani', 'Dadi', 'Bua'], 1),
      StoryQ('Khilone ka rang kaisa tha?', ['Peela', 'Laal', 'Hara'], 0),
    ],
  ),
  MmStory(
    '🌳',
    'Bagiya Mein Subah',
    [
      'Papa aur Rohan bagiya mein gaye.',
      'Wahan do gulabi phool khile the.',
      'Rohan ne ek titli ko phool par baithte dekha.',
      'Papa ne kaha, "Dekho, prakriti kitni pyaari hai."',
    ],
    [
      StoryQ('Rohan kiske saath gaya?', ['Mama', 'Papa', 'Dada'], 1),
      StoryQ('Kitne phool khile the?', ['Do', 'Chaar', 'Ek'], 0),
      StoryQ('Phool par kaun baitha?', ['Bhanwra', 'Titli', 'Chidiya'], 1),
    ],
  ),
  MmStory(
    '🌙',
    'Chaand Ki Lori',
    [
      'Raat ko aasman mein poora chaand chamak raha tha.',
      'Nani ne dheere se ek lori gungunayi.',
      'Chhoti Tara ki aankhen dheere dheere band ho gayin.',
      'Chaand muskuraya aur taare jhilmilaye.',
    ],
    [
      StoryQ('Aasman mein kya chamak raha tha?', [
        'Suraj',
        'Poora chaand',
        'Indradhanush',
      ], 1),
      StoryQ('Lori kisne gungunayi?', ['Nani', 'Mausi', 'Didi'], 0),
      StoryQ('Chhoti bachchi ka naam kya tha?', ['Tara', 'Gudiya', 'Pari'], 0),
    ],
  ),
  MmStory(
    '🍎',
    'Mithe Seb',
    [
      'Mausi bazaar se chaar laal seb laayi.',
      'Maa ne unhe dhokar plate mein sajaya.',
      'Kabir ne ek seb aadha kaata aur sabko baanta.',
      'Sab ne milkar seb ka maza liya.',
    ],
    [
      StoryQ('Mausi kya laayi?', ['Kele', 'Seb', 'Angoor'], 1),
      StoryQ('Kitne seb laayi?', ['Teen', 'Chaar', 'Chhe'], 1),
      StoryQ('Seb kisne baanta?', ['Kabir', 'Maa', 'Papa'], 0),
    ],
  ),
  MmStory(
    '🚲',
    'Nayi Cycle',
    [
      'Dada ji Ishaan ke liye hari cycle laaye.',
      'Ishaan ne cycle par ek chhoti ghanti lagayi.',
      'Shaam ko usne park ke teen chakkar lagaye.',
      'Dada ji taaliyan bajate rahe.',
    ],
    [
      StoryQ('Cycle ka rang kaisa tha?', ['Hara', 'Neela', 'Laal'], 0),
      StoryQ('Cycle par kya lagaya?', ['Tokri', 'Ghanti', 'Jhanda'], 1),
      StoryQ('Park ke kitne chakkar lagaye?', ['Do', 'Teen', 'Paanch'], 1),
    ],
  ),
  MmStory(
    '🍪',
    'Biscuit Wala Din',
    [
      'Riya ne Maa ke saath biscuit banaye.',
      'Unhone aate mein thoda sa gud milaya.',
      'Biscuit ko tare ke aakar mein kaata gaya.',
      'Poore ghar mein meethi khushbu phail gayi.',
    ],
    [
      StoryQ('Riya ne kiske saath biscuit banaye?', [
        'Maa',
        'Dadi',
        'Saheli',
      ], 0),
      StoryQ('Aate mein kya milaya?', ['Namak', 'Gud', 'Shahad'], 1),
      StoryQ('Biscuit kis aakar ke the?', ['Dil', 'Gol', 'Tare'], 2),
    ],
  ),
  MmStory(
    '🐶',
    'Moti Kutta',
    [
      'Gali ka bhura kutta Moti sabka dost tha.',
      'Roz shaam ko Moti Gudiya ke saath khelta.',
      'Aaj Gudiya ne use ek laal gend di.',
      'Moti poonchh hilata hua gend le aaya.',
    ],
    [
      StoryQ('Kutte ka naam kya tha?', ['Sheru', 'Moti', 'Tommy'], 1),
      StoryQ('Gudiya ne kya di?', ['Haddi', 'Roti', 'Laal gend'], 2),
      StoryQ('Moti kab khelta tha?', ['Shaam ko', 'Subah', 'Raat ko'], 0),
    ],
  ),
];

const storyReadSeconds = 20;

/// Random story index, never repeating the previous one back to back.
int nextStoryIndex(int? previous, Random rng) {
  var n = rng.nextInt(stories.length);
  if (previous != null && n == previous) n = (n + 1) % stories.length;
  return n;
}

int storyStars(int correct) => correct.clamp(0, 3);
