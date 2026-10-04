import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/continue_offer.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: the shared offer / result dialogs overflowed on 320x480 phones.
void main() {
  Future<BuildContext> open(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'coins': 500});
    await Storage.init();
    t.view.physicalSize = const Size(320, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    return ctx;
  }

  testWidgets('continue offer fits a 320x480 screen', (t) async {
    final ctx = await open(t);
    showContinueOffer(ctx, OfferKind.unlockLevel);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('premium result dialog fits a 320x480 screen', (t) async {
    final ctx = await open(t);
    showPremiumDialog(ctx,
        title: 'Level complete!',
        message: 'Bahut badhiya! Aapne ye level 3 star ke saath poora kiya.',
        stars: 3,
        actions: [DialogAction('Levels', () {}), DialogAction('Replay', () {}), DialogAction('Next level', () {}, primary: true)]);
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
