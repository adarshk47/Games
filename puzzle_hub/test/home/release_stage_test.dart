import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/release_stage.dart';

void main() {
  tearDown(() => ReleaseStage.debugSet(ReleaseStage.fallback));

  test('Firestore stage field and dates pick the stage', () {
    final now = DateTime.parse('2026-11-20T12:00:00+05:30');
    expect(ReleaseStage.stageFor({'stage': 1}, now), 1);
    expect(ReleaseStage.stageFor({'stage': 2}, now), 2);
    expect(ReleaseStage.stageFor({'stage': 9}, now), 3);
    // Dates raise the stage once reached (India time).
    expect(ReleaseStage.stageFor({'stage': 1, 'v2From': '2026-11-15', 'v3From': '2026-12-15'}, now), 2);
    expect(ReleaseStage.stageFor({'stage': 1, 'v2From': '2026-11-21'}, now), 1);
    expect(ReleaseStage.stageFor({'stage': 1, 'v3From': '2026-11-20'}, now), 3);
    expect(ReleaseStage.stageFor({}, now), ReleaseStage.fallback);
  });

  test('per-game on / soon / off overrides', () {
    ReleaseStage.debugSet(1, games: {'business': 'on', 'dominoes': 'soon', 'chess': 'off'});
    expect(gameComingSoon('business'), isFalse); // stage 1 would say soon
    expect(gameComingSoon('dominoes'), isTrue);
    expect(gameComingSoon('brain_age'), isTrue); // no override: stage rule
    expect(gameHidden('chess'), isTrue);
    expect(gameHidden('ludo'), isFalse);
    ReleaseStage.debugSet(3);
    expect(gameComingSoon('brain_age'), isFalse);
    expect(kStageSfxDir, 'sfx_v3');
    expect(kStageTheme, 'newyear');
  });
}
