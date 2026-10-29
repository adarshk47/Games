import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/audio.dart';
import 'package:puzzle_hub/core/release_stage.dart';

void main() {
  test('every release has a full sound-effect set', () {
    for (final dir in ['sfx_v1', 'sfx_v2', 'sfx_v3']) {
      for (final s in Sound.values) {
        final f = File('assets/audio/$dir/${s.name}.wav');
        expect(f.existsSync() && f.lengthSync() > 1000, isTrue, reason: f.path);
      }
    }
    expect(kStageSfxDir, 'sfx_v$kStage');
  });
}
