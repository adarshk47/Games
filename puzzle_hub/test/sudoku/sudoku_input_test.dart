import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/sudoku/sudoku_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression for "numbers can't be entered": pick an empty cell, tap the
/// right digit on the pad and check the saved game really changed.
void main() {
  Map<String, dynamic>? save() {
    final s = Storage.getString('sudoku.save');
    return s == null || s.isEmpty ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  for (final size in const [Size(1080, 2373), Size(393, 863), Size(360, 640)]) {
    for (final resume in [false, true]) {
      testWidgets('digit goes into an empty cell at $size (resume: $resume)', (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        t.view.physicalSize = size;
        t.view.devicePixelRatio = size.width > 1000 ? 2.75 : 1;
        if (size.width > 1000) {
          t.view.padding = const FakeViewPadding(top: 120, bottom: 60);
          addTearDown(t.view.resetPadding);
        }
        addTearDown(t.view.resetPhysicalSize);
        await t.pumpWidget(const MaterialApp(home: SudokuScreen()));
        await t.pump(const Duration(milliseconds: 800));
        await t.tap(find.text('Easy').first);
        await t.pump();
        await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
        await t.pump(const Duration(milliseconds: 800));

        if (resume) {
          // Leave and come back through "Continue".
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(const MaterialApp(home: SudokuScreen()));
          await t.pump(const Duration(milliseconds: 800));
          await t.tap(find.text('Resume Easy').first);
          await t.pump(const Duration(milliseconds: 800));
        }

        final before = save()!;
        final cur = (before['c'] as List).cast<int>();
        final sol = (before['s'] as List).cast<int>();
        final i = cur.indexWhere((v) => v == 0);
        expect(i, greaterThanOrEqualTo(0));
        final cell = find.byKey(ValueKey('e$i'));
        expect(cell, findsOneWidget);
        // An empty cell must be a full-size tap target (it was 0 px tall).
        final target = find.ancestor(of: cell, matching: find.byType(GestureDetector)).first;
        expect(t.getSize(target).height, greaterThan(20));
        await t.tap(cell, warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 200));
        // The pad digit itself (not a "remaining" badge with the same number).
        final digit = find.byWidgetPredicate(
          (w) => w is Text && w.data == '${sol[i]}' && w.style?.fontSize == 26,
        );
        await t.tap(digit.last);
        await t.pump(const Duration(milliseconds: 600));
        // Force a save by leaving the screen.
        await t.pumpWidget(const SizedBox());
        final after = save()!;
        expect((after['c'] as List)[i], sol[i], reason: 'cell $i stayed empty');
      });
    }
  }
}
