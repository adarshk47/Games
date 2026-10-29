import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/brain_age.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/brain_age/brain_age_screen.dart';
import 'package:puzzle_hub/games/brain_age/brain_tests.dart';
import 'package:puzzle_hub/games/brain_age/logic/brain_age_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
  });

  test('small age groups from 15, ranges and lookup', () {
    expect(AgeGroup.values.first.from, 15);
    expect(AgeGroup.a21.label, '21–24');
    expect(AgeGroup.a65.label, '65+');
    expect(AgeGroup.of(12), AgeGroup.a15, reason: 'never below 15');
    expect(AgeGroup.of(23), AgeGroup.a21);
    expect(AgeGroup.of(70), AgeGroup.a65);
    // Groups are contiguous.
    for (var i = 1; i < AgeGroup.values.length; i++) {
      expect(AgeGroup.values[i].from, AgeGroup.values[i - 1].to! + 1);
    }
  });

  test('average scores give the own age range; better scores a younger one', () {
    for (final g in AgeGroup.values) {
      final avg = BrainResult(group: g, at: DateTime.now(), scores: {for (final t in BrainTest.values) t: BrainNorms.mean(t, g)});
      expect(avg.brainGroup, g, reason: g.label);
      expect(avg.percentile, 50);
      expect(avg.youngerOrSame, isTrue);
    }
    final g = AgeGroup.a40;
    final great = BrainResult(group: g, at: DateTime.now(), scores: {
      for (final t in BrainTest.values)
        t: BrainNorms.mean(t, g) + (BrainNorms.lowerIsBetter(t) ? -1 : 1) * BrainNorms.sd(t) * 1.5
    });
    expect(great.brainAge, lessThan(40));
    expect(great.percentile, greaterThan(90));
    final slow = BrainResult(group: g, at: DateTime.now(), scores: {BrainTest.reaction: 600});
    expect(slow.brainAge, greaterThan(50));
    expect(slow.youngerOrSame, isFalse);
  });

  test('history, bests, first score and weakest test', () async {
    final g = AgeGroup.a25;
    await BrainStore.setGroup(g);
    expect(BrainStore.group, g);
    await BrainStore.add(BrainResult(group: g, at: DateTime.now(), scores: {
      BrainTest.reaction: 350, BrainTest.memory: 7, BrainTest.math: 18, BrainTest.stroop: 10, BrainTest.pattern: 7,
    }));
    await BrainStore.add(BrainResult(group: g, at: DateTime.now(), scores: {BrainTest.reaction: 290}));
    expect(BrainStore.history().length, 2);
    expect(BrainStore.bestOf(BrainTest.reaction), 290);
    expect(BrainStore.firstOf(BrainTest.reaction), 350);
    expect(BrainStore.weakest(), BrainTest.stroop);
    expect(BrainStore.best(), isNotNull);
  });

  test('question generators: answer is among 4 distinct choices', () {
    final r = math.Random(3);
    for (var i = 0; i < 300; i++) {
      final m = MathQ.make(r, i % 12);
      expect(m.choices.toSet().length, 4);
      expect(m.choices, contains(m.answer));
      final p = PatternQ.make(r, i % 8);
      expect(p.choices.toSet().length, 4);
      expect(p.choices, contains(p.answer));
      expect(p.shown.length, 5);
    }
  });

  test('strings: all 9 languages, identical placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in brainAgeStrings.entries) {
      final want = ph.allMatches(e.value['en']!).map((m) => m[1]).toSet();
      for (final l in AppLang.tableLangs) {
        final s = e.value[l.code];
        expect(s, isNotNull, reason: '${e.key} ${l.code}');
        expect(ph.allMatches(s!).map((m) => m[1]).toSet(), want, reason: '${e.key} ${l.code}');
      }
    }
  });

  testWidgets('pick age, practise mental math, see tip and result range', (t) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final old = brainTestDuration;
    brainTestDuration = (_) => const Duration(milliseconds: 300);
    addTearDown(() => brainTestDuration = old);
    await t.pumpWidget(const MaterialApp(home: BrainAgeScreen()));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('age_a21')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('brain_start')), findsOneWidget);
    final practise = find.byKey(const ValueKey('practice_math'));
    await t.ensureVisible(practise);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(practise);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.byType(BrainRunScreen), findsOneWidget);
    final go = find.byKey(const ValueKey('brain_go'));
    await t.scrollUntilVisible(go, 200, scrollable: find.byType(Scrollable).last);
    await t.tap(go);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(MathTest), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('choice_0')));
    // Let the (real-time) stopwatch run out.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    final next = find.byKey(const ValueKey('brain_next'));
    await t.scrollUntilVisible(next, 200, scrollable: find.byType(Scrollable).last);
    await t.tap(next);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.byKey(const ValueKey('brain_result_age')), findsOneWidget);
    expect(find.textContaining('–'), findsWidgets, reason: 'result shows an age range');
    expect(BrainStore.history().single.scores.keys, [BrainTest.math]);
    expect(t.takeException(), isNull);
  });

  test('odd one out and quick compare generators', () {
    final r = math.Random(7);
    for (var found = 0; found < 30; found++) {
      final q = OddQ.make(r, found);
      expect(q.common, isNot(q.odd));
      expect(q.index, inInclusiveRange(0, q.size * q.size - 1));
      final c = CompareQ.make(r, found);
      expect(c.leftValue, isNot(c.rightValue));
      expect(c.bigger, c.leftValue > c.rightValue ? 0 : 1);
    }
  });
}
