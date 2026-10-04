import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/maze_escape/labyrinth_game.dart';
import 'package:puzzle_hub/games/maze_escape/maze_escape_screen.dart';
import 'package:puzzle_hub/games/maze_escape/logic/levels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  testWidgets('tier select and labyrinth render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('mode-labyrinth')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Extreme'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(const MaterialApp(home: LabyrinthGame(tier: MazeTier.hard, level: 9)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.flashlight_on_rounded));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
