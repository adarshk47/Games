import 'dart:math';

/// Random number string of [digits] digits, no leading zero.
String generateNumber(int digits, [Random? rng]) {
  final r = rng ?? Random();
  final sb = StringBuffer()..write(1 + r.nextInt(9));
  for (var i = 1; i < digits; i++) {
    sb.write(r.nextInt(10));
  }
  return sb.toString();
}

/// How long to show a number: proportional to its length.
Duration displayDuration(int digits) => Duration(milliseconds: 800 + 700 * digits);

bool isCorrectAnswer(String number, String answer) => number == answer.trim();

/// Digits for a given level (level 1 = 1 digit).
int digitsForLevel(int level, [int start = 1]) => start + level - 1;
