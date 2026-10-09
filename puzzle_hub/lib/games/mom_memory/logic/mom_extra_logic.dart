import 'dart:math';

import 'mm_text.dart';
import 'mom_stories.dart';

export 'mm_text.dart';
export 'mom_stories.dart';

/// Small emoji thing with a name in every language.
class MmThing {
  const MmThing(this.emoji, this.names);
  final String emoji;
  final MmL<String> names; // lang -> name
  String get name => mmPick(names);
}

// ---------- Missing Item (Kya gaya?) ----------
const missingPool = [
  MmThing('🍼', {
    'en': "Bottle",
    'hi': "बोतल",
    'hinglish': "Bottle",
    'te': "సీసా",
    'ta': "புட்டி",
    'pa': "ਬੋਤਲ",
    'bho': "बोतल",
    'mr': "बाटली",
    'sa': "कूपी",
  }),
  MmThing('🧸', {
    'en': "Toy",
    'hi': "खिलौना",
    'hinglish': "Khilona",
    'te': "బొమ్మ",
    'ta': "பொம்மை",
    'pa': "ਖਿਡੌਣਾ",
    'bho': "खिलौना",
    'mr': "खेळणे",
    'sa': "क्रीडनकम्",
  }),
  MmThing('🧦', {
    'en': "Socks",
    'hi': "मोज़े",
    'hinglish': "Moze",
    'te': "సాక్స్",
    'ta': "காலுறை",
    'pa': "ਜੁਰਾਬਾਂ",
    'bho': "मोजा",
    'mr': "मोजे",
    'sa': "पादावरणे",
  }),
  MmThing('🧷', {
    'en': "Pin",
    'hi': "पिन",
    'hinglish': "Pin",
    'te': "పిన్",
    'ta': "பின்",
    'pa': "ਪਿੰਨ",
    'bho': "पिन",
    'mr': "पिन",
    'sa': "सूचिका",
  }),
  MmThing('🛁', {
    'en': "Tub",
    'hi': "टब",
    'hinglish': "Tub",
    'te': "తొట్టి",
    'ta': "தொட்டி",
    'pa': "ਟੱਬ",
    'bho': "टब",
    'mr': "टब",
    'sa': "द्रोणी",
  }),
  MmThing('🧴', {
    'en': "Lotion",
    'hi': "लोशन",
    'hinglish': "Lotion",
    'te': "లోషన్",
    'ta': "லோஷன்",
    'pa': "ਲੋਸ਼ਨ",
    'bho': "लोशन",
    'mr': "लोशन",
    'sa': "लेपः",
  }),
  MmThing('🧺', {
    'en': "Basket",
    'hi': "टोकरी",
    'hinglish': "Tokri",
    'te': "బుట్ట",
    'ta': "கூடை",
    'pa': "ਟੋਕਰੀ",
    'bho': "टोकरी",
    'mr': "टोपली",
    'sa': "करण्डः",
  }),
  MmThing('🪥', {
    'en': "Brush",
    'hi': "ब्रश",
    'hinglish': "Brush",
    'te': "బ్రష్",
    'ta': "பிரஷ்",
    'pa': "ਬੁਰਸ਼",
    'bho': "ब्रश",
    'mr': "ब्रश",
    'sa': "कूर्चः",
  }),
  MmThing('🧼', {
    'en': "Soap",
    'hi': "साबुन",
    'hinglish': "Sabun",
    'te': "సబ్బు",
    'ta': "சோப்பு",
    'pa': "ਸਾਬਣ",
    'bho': "साबुन",
    'mr': "साबण",
    'sa': "फेनकम्",
  }),
  MmThing('🧣', {
    'en': "Shawl",
    'hi': "शॉल",
    'hinglish': "Shawl",
    'te': "శాలువా",
    'ta': "சால்வை",
    'pa': "ਸ਼ਾਲ",
    'bho': "साल",
    'mr': "शाल",
    'sa': "शाटिका",
  }),
  MmThing('🧢', {
    'en': "Cap",
    'hi': "टोपी",
    'hinglish': "Topi",
    'te': "టోపీ",
    'ta': "தொப்பி",
    'pa': "ਟੋਪੀ",
    'bho': "टोपी",
    'mr': "टोपी",
    'sa': "शिरस्त्रम्",
  }),
  MmThing('🦆', {
    'en': "Duck",
    'hi': "बत्तख",
    'hinglish': "Battakh",
    'te': "బాతు",
    'ta': "வாத்து",
    'pa': "ਬੱਤਖ",
    'bho': "बतख",
    'mr': "बदक",
    'sa': "हंसकः",
  }),
  MmThing('🍪', {
    'en': "Biscuit",
    'hi': "बिस्कुट",
    'hinglish': "Biscuit",
    'te': "బిస్కెట్",
    'ta': "பிஸ்கட்",
    'pa': "ਬਿਸਕੁਟ",
    'bho': "बिस्कुट",
    'mr': "बिस्किट",
    'sa': "पिष्टकम्",
  }),
  MmThing('🔔', {
    'en': "Bell",
    'hi': "घंटी",
    'hinglish': "Ghanti",
    'te': "గంట",
    'ta': "மணி",
    'pa': "ਘੰਟੀ",
    'bho': "घंटी",
    'mr': "घंटा",
    'sa': "घण्टा",
  }),
  MmThing('🪮', {
    'en': "Comb",
    'hi': "कंघी",
    'hinglish': "Kanghi",
    'te': "దువ్వెన",
    'ta': "சீப்பு",
    'pa': "ਕੰਘੀ",
    'bho': "ककही",
    'mr': "कंगवा",
    'sa': "कङ्कतम्",
  }),
  MmThing('🥄', {
    'en': "Spoon",
    'hi': "चम्मच",
    'hinglish': "Chamach",
    'te': "చెంచా",
    'ta': "கரண்டி",
    'pa': "ਚਮਚਾ",
    'bho': "चम्मच",
    'mr': "चमचा",
    'sa': "दर्वी",
  }),
  MmThing('☕', {
    'en': "Tea",
    'hi': "चाय",
    'hinglish': "Chai",
    'te': "టీ",
    'ta': "தேநீர்",
    'pa': "ਚਾਹ",
    'bho': "चाय",
    'mr': "चहा",
    'sa': "चायम्",
  }),
  MmThing('🔑', {
    'en': "Key",
    'hi': "चाबी",
    'hinglish': "Chaabi",
    'te': "తాళం చెవి",
    'ta': "சாவி",
    'pa': "ਚਾਬੀ",
    'bho': "चाभी",
    'mr': "किल्ली",
    'sa': "कुञ्चिका",
  }),
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
  const WordPair(this.words, this.partner);
  final MmL<String> words; // lang -> word shown
  final MmThing partner;
  String get word => mmPick(words);
}

const wordPairs = [
  WordPair(
    {
      'en': "Milk",
      'hi': "दूध",
      'hinglish': "Doodh",
      'te': "పాలు",
      'ta': "பால்",
      'pa': "ਦੁੱਧ",
      'bho': "दूध",
      'mr': "दूध",
      'sa': "दुग्धम्",
    },
    MmThing('🍼', {
      'en': "Bottle",
      'hi': "बोतल",
      'hinglish': "Bottle",
      'te': "సీసా",
      'ta': "புட்டி",
      'pa': "ਬੋਤਲ",
      'bho': "बोतल",
      'mr': "बाटली",
      'sa': "कूपी",
    }),
  ),
  WordPair(
    {
      'en': "Sleep",
      'hi': "नींद",
      'hinglish': "Neend",
      'te': "నిద్ర",
      'ta': "தூக்கம்",
      'pa': "ਨੀਂਦ",
      'bho': "नींद",
      'mr': "झोप",
      'sa': "निद्रा",
    },
    MmThing('😴', {
      'en': "Nap",
      'hi': "सोना",
      'hinglish': "Sona",
      'te': "కునుకు",
      'ta': "ஓய்வு",
      'pa': "ਸੌਣਾ",
      'bho': "सुतल",
      'mr': "डुलकी",
      'sa': "शयनम्",
    }),
  ),
  WordPair(
    {
      'en': "Bath",
      'hi': "नहाना",
      'hinglish': "Nahana",
      'te': "స్నానం",
      'ta': "குளியல்",
      'pa': "ਨਹਾਉਣਾ",
      'bho': "नहाइल",
      'mr': "अंघोळ",
      'sa': "स्नानम्",
    },
    MmThing('🛁', {
      'en': "Tub",
      'hi': "टब",
      'hinglish': "Tub",
      'te': "తొట్టి",
      'ta': "தொட்டி",
      'pa': "ਟੱਬ",
      'bho': "टब",
      'mr': "टब",
      'sa': "द्रोणी",
    }),
  ),
  WordPair(
    {
      'en': "Lullaby",
      'hi': "लोरी",
      'hinglish': "Lori",
      'te': "జోల పాట",
      'ta': "தாலாட்டு",
      'pa': "ਲੋਰੀ",
      'bho': "लोरी",
      'mr': "अंगाई",
      'sa': "लालीगीतम्",
    },
    MmThing('🌙', {
      'en': "Moon",
      'hi': "चाँद",
      'hinglish': "Chaand",
      'te': "చందమామ",
      'ta': "நிலா",
      'pa': "ਚੰਨ",
      'bho': "चंदा",
      'mr': "चंद्र",
      'sa': "चन्द्रः",
    }),
  ),
  WordPair(
    {
      'en': "Toy",
      'hi': "खिलौना",
      'hinglish': "Khilona",
      'te': "బొమ్మ",
      'ta': "பொம்மை",
      'pa': "ਖਿਡੌਣਾ",
      'bho': "खिलौना",
      'mr': "खेळणे",
      'sa': "क्रीडनकम्",
    },
    MmThing('🧸', {
      'en': "Teddy",
      'hi': "टेडी",
      'hinglish': "Teddy",
      'te': "టెడ్డీ",
      'ta': "டெடி",
      'pa': "ਟੈਡੀ",
      'bho': "टेडी",
      'mr': "टेडी",
      'sa': "टेडी",
    }),
  ),
  WordPair(
    {
      'en': "Winter",
      'hi': "सर्दी",
      'hinglish': "Sardi",
      'te': "చలి",
      'ta': "குளிர்",
      'pa': "ਸਰਦੀ",
      'bho': "जाड़ा",
      'mr': "हिवाळा",
      'sa': "शीतकालः",
    },
    MmThing('🧣', {
      'en': "Shawl",
      'hi': "शॉल",
      'hinglish': "Shawl",
      'te': "శాలువా",
      'ta': "சால்வை",
      'pa': "ਸ਼ਾਲ",
      'bho': "साल",
      'mr': "शाल",
      'sa': "शाटिका",
    }),
  ),
  WordPair(
    {
      'en': "Rain",
      'hi': "बारिश",
      'hinglish': "Baarish",
      'te': "వర్షం",
      'ta': "மழை",
      'pa': "ਮੀਂਹ",
      'bho': "बरखा",
      'mr': "पाऊस",
      'sa': "वर्षा",
    },
    MmThing('☔', {
      'en': "Umbrella",
      'hi': "छतरी",
      'hinglish': "Chhatri",
      'te': "గొడుగు",
      'ta': "குடை",
      'pa': "ਛਤਰੀ",
      'bho': "छाता",
      'mr': "छत्री",
      'sa': "छत्रम्",
    }),
  ),
  WordPair(
    {
      'en': "Soup",
      'hi': "रोटी",
      'hinglish': "Roti",
      'te': "పప్పు",
      'ta': "சாம்பார்",
      'pa': "ਰੋਟੀ",
      'bho': "रोटी",
      'mr': "वरण",
      'sa': "सूपः",
    },
    MmThing('🥣', {
      'en': "Bowl",
      'hi': "कटोरी",
      'hinglish': "Katori",
      'te': "గిన్నె",
      'ta': "கிண்ணம்",
      'pa': "ਕਟੋਰੀ",
      'bho': "कटोरी",
      'mr': "वाटी",
      'sa': "पात्रम्",
    }),
  ),
  WordPair(
    {
      'en': "Flower",
      'hi': "फूल",
      'hinglish': "Phool",
      'te': "పువ్వు",
      'ta': "பூ",
      'pa': "ਫੁੱਲ",
      'bho': "फूल",
      'mr': "फूल",
      'sa': "पुष्पम्",
    },
    MmThing('🌸', {
      'en': "Garden",
      'hi': "बगिया",
      'hinglish': "Bagiya",
      'te': "తోట",
      'ta': "தோட்டம்",
      'pa': "ਬਗੀਚਾ",
      'bho': "फुलवारी",
      'mr': "बाग",
      'sa': "उद्यानम्",
    }),
  ),
  WordPair(
    {
      'en': "Sun",
      'hi': "सूरज",
      'hinglish': "Sooraj",
      'te': "సూర్యుడు",
      'ta': "சூரியன்",
      'pa': "ਸੂਰਜ",
      'bho': "सुरुज",
      'mr': "सूर्य",
      'sa': "सूर्यः",
    },
    MmThing('☀️', {
      'en': "Light",
      'hi': "रोशनी",
      'hinglish': "Roshni",
      'te': "వెలుగు",
      'ta': "வெளிச்சம்",
      'pa': "ਰੋਸ਼ਨੀ",
      'bho': "अंजोर",
      'mr': "प्रकाश",
      'sa': "प्रकाशः",
    }),
  ),
  WordPair(
    {
      'en': "Water",
      'hi': "पानी",
      'hinglish': "Paani",
      'te': "నీళ్లు",
      'ta': "தண்ணீர்",
      'pa': "ਪਾਣੀ",
      'bho': "पानी",
      'mr': "पाणी",
      'sa': "जलम्",
    },
    MmThing('💧', {
      'en': "Glass",
      'hi': "गिलास",
      'hinglish': "Glass",
      'te': "గ్లాసు",
      'ta': "குவளை",
      'pa': "ਗਲਾਸ",
      'bho': "गिलास",
      'mr': "ग्लास",
      'sa': "चषकः",
    }),
  ),
  WordPair(
    {
      'en': "Book",
      'hi': "किताब",
      'hinglish': "Kitaab",
      'te': "పుస్తకం",
      'ta': "புத்தகம்",
      'pa': "ਕਿਤਾਬ",
      'bho': "किताब",
      'mr': "पुस्तक",
      'sa': "पुस्तकम्",
    },
    MmThing('📖', {
      'en': "Story",
      'hi': "कहानी",
      'hinglish': "Kahani",
      'te': "కథ",
      'ta': "கதை",
      'pa': "ਕਹਾਣੀ",
      'bho': "कहानी",
      'mr': "गोष्ट",
      'sa': "कथा",
    }),
  ),
  WordPair(
    {
      'en': "Tea",
      'hi': "चाय",
      'hinglish': "Chai",
      'te': "టీ",
      'ta': "தேநீர்",
      'pa': "ਚਾਹ",
      'bho': "चाय",
      'mr': "चहा",
      'sa': "चायम्",
    },
    MmThing('☕', {
      'en': "Cup",
      'hi': "प्याली",
      'hinglish': "Pyaali",
      'te': "కప్పు",
      'ta': "கோப்பை",
      'pa': "ਪਿਆਲੀ",
      'bho': "कप",
      'mr': "कप",
      'sa': "पानपात्रम्",
    }),
  ),
  WordPair(
    {
      'en': "Stars",
      'hi': "तारे",
      'hinglish': "Taare",
      'te': "నక్షత్రాలు",
      'ta': "நட்சத்திரம்",
      'pa': "ਤਾਰੇ",
      'bho': "तरई",
      'mr': "तारे",
      'sa': "तारकाः",
    },
    MmThing('⭐', {
      'en': "Sky",
      'hi': "आसमान",
      'hinglish': "Aasman",
      'te': "ఆకాశం",
      'ta': "வானம்",
      'pa': "ਅਸਮਾਨ",
      'bho': "असमान",
      'mr': "आकाश",
      'sa': "आकाशः",
    }),
  ),
  WordPair(
    {
      'en': "Car",
      'hi': "गाड़ी",
      'hinglish': "Gaadi",
      'te': "కారు",
      'ta': "வண்டி",
      'pa': "ਗੱਡੀ",
      'bho': "गाड़ी",
      'mr': "गाडी",
      'sa': "यानम्",
    },
    MmThing('🚗', {
      'en': "Road",
      'hi': "सड़क",
      'hinglish': "Sadak",
      'te': "రోడ్డు",
      'ta': "சாலை",
      'pa': "ਸੜਕ",
      'bho': "सड़क",
      'mr': "रस्ता",
      'sa': "मार्गः",
    }),
  ),
  WordPair(
    {
      'en': "Teeth",
      'hi': "दाँत",
      'hinglish': "Daant",
      'te': "పళ్లు",
      'ta': "பல்",
      'pa': "ਦੰਦ",
      'bho': "दाँत",
      'mr': "दात",
      'sa': "दन्ताः",
    },
    MmThing('🪥', {
      'en': "Brush",
      'hi': "ब्रश",
      'hinglish': "Brush",
      'te': "బ్రష్",
      'ta': "பிரஷ்",
      'pa': "ਬੁਰਸ਼",
      'bho': "ब्रश",
      'mr': "ब्रश",
      'sa': "कूर्चः",
    }),
  ),
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
// Stories live in mom_stories.dart (all languages).
const storyReadSeconds = 20;

/// Random story index, never repeating the previous one back to back.
int nextStoryIndex(int? previous, Random rng) {
  var n = rng.nextInt(stories.length);
  if (previous != null && n == previous) n = (n + 1) % stories.length;
  return n;
}

int storyStars(int correct) => correct.clamp(0, 3);
