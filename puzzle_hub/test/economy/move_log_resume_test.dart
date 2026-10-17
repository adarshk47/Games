import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/move_log.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';
import 'package:puzzle_hub/games/screw_jam/screw_jam_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
  });

  test('move log keeps the moves of one level and forgets them when cleared', () {
    final log = MoveLog('x.inprogress')..start(3);
    log.add(5);
    log.add([1, 2]);
    expect(MoveLog('x.inprogress').savedFor(3), [5, [1, 2]]);
    expect(MoveLog('x.inprogress').savedFor(4), isNull);
    log.pop();
    expect(MoveLog('x.inprogress').savedFor(3), [5]);
    log.clear();
    expect(MoveLog('x.inprogress').savedFor(3), isNull);
  });

  testWidgets('Screw Jam continues a level left half-way', (t) async {
    t.view.physicalSize = const Size(400, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    // A level with two moves already played.
    final g = SjGame(sjGenerate(SjTier.easy, 1));
    final first = [for (var i = 0; i < g.level.screws.length; i++) i].where(g.canTap).take(1).toList();
    g.tap(first.first);
    final second = [for (var i = 0; i < g.level.screws.length; i++) i].firstWhere(g.canTap);
    MoveLog('screw_jam.easy.inprogress')
      ..start(1)
      ..add(first.first)
      ..add(second);
    await t.pumpWidget(const MaterialApp(home: ScrewJamGame(tier: SjTier.easy, level: 1)));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(MoveLog('screw_jam.easy.inprogress').savedFor(1), [first.first, second]);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
