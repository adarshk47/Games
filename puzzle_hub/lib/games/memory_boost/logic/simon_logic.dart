import 'dart:math';

enum SequenceResult { wrong, correct, complete }

class SimonLogic {
  final Random _rng;
  final int pads;
  final List<int> sequence = [];
  int _pos = 0;

  SimonLogic({Random? rng, this.pads = 4}) : _rng = rng ?? Random();

  int get streak => sequence.isEmpty ? 0 : sequence.length - 1;
  int get length => sequence.length;

  /// Appends a new random step and resets input position.
  int addStep() {
    final s = _rng.nextInt(pads);
    sequence.add(s);
    _pos = 0;
    return s;
  }

  /// Checks the next pad the player tapped.
  SequenceResult input(int pad) {
    if (_pos >= sequence.length || sequence[_pos] != pad) return SequenceResult.wrong;
    _pos++;
    return _pos == sequence.length ? SequenceResult.complete : SequenceResult.correct;
  }

  void reset() {
    sequence.clear();
    _pos = 0;
  }

  /// Milliseconds each pad is lit; shrinks slowly with sequence length.
  static int stepMillis(int length) => max(220, 600 - (length - 1) * 20);
}
