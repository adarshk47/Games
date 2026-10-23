import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/cloud/sync_merge.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/home/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a newer "delete records" wins over the old cloud records', () {
    final r = SyncMerge.merge(
      local: {'recreset.chess.last': 200, 'rec.2048.best': 50},
      remote: {
        'rec.chess.wins': 9,
        'rec.chess.t.easy.wins': 3,
        'rec.2048.best': 80,
        'recreset.chess.last': 100,
      },
    ).values;
    expect(r.containsKey('rec.chess.wins'), isFalse);
    expect(r.containsKey('rec.chess.t.easy.wins'), isFalse);
    expect(r['recreset.chess.last'], 200);
    expect(r['rec.2048.best'], 80, reason: 'other games merge as before');
  });

  test('records made after the reset on another phone are kept', () {
    final r = SyncMerge.merge(
      local: {'recreset.chess.last': 200, 'rec.chess.wins': 1},
      remote: {'recreset.chess.last': 200, 'rec.chess.wins': 2},
    ).values;
    expect(r['rec.chess.wins'], 2);
  });

  group('records page', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Storage.init();
      Storage.userPrefix = '';
      await Storage.setInt('rec.chess.plays', 4);
      await Storage.setInt('rec.chess.wins', 2);
      await Storage.setInt('rec.chess.t.easy.wins', 2);
      AdsService.debugForceEnabled = true;
    });
    tearDown(() {
      AdsService.debugForceEnabled = false;
      AdsService.rewardedOverride = null;
    });

    Future<void> deleteChess(WidgetTester t) async {
      t.view.physicalSize = const Size(430, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(const MaterialApp(home: GameRecordsScreen()));
      await t.pump(const Duration(milliseconds: 500));
      await t.scrollUntilVisible(find.byKey(const ValueKey('records_reset_chess')), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(const ValueKey('records_reset_chess')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('records_reset_chess')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('records_reset_confirm')));
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('deleting needs a watched ad', (t) async {
      AdsService.rewardedOverride = (_) async => false; // ad not finished
      await deleteChess(t);
      expect(Rewards.plays('chess'), 4);

      AdsService.rewardedOverride = (_) async => true;
      await deleteChess(t);
      expect(Rewards.plays('chess'), 0);
      expect(Rewards.winsIn('chess', 'easy'), 0);
      expect(Storage.getInt('recreset.chess.last'), greaterThan(0));
      expect(find.byKey(const ValueKey('records_reset_chess')), findsNothing);
    });
  });
}
