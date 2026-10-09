import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/cloud_service.dart';
import 'package:puzzle_hub/core/cloud/leaderboard_service.dart';
import 'package:puzzle_hub/core/cloud/referral_service.dart';

void main() {
  group('referral', () {
    test('invite link carries ref_<uid>', () {
      expect(ReferralService.inviteLink('abc123XYZ'),
          'https://play.google.com/store/apps/details?id=com.memorypuzzle.app&referrer=ref_abc123XYZ');
      expect(ReferralService.inviteText('abc123XYZ', 'Asha'), contains('referrer=ref_abc123XYZ'));
    });

    test('parseInviter handles the formats Play may return', () {
      expect(ReferralService.parseInviter('ref_Uid12345'), 'Uid12345');
      expect(ReferralService.parseInviter('referrer=ref_Uid12345'), 'Uid12345');
      expect(ReferralService.parseInviter('utm_source=x&referrer=ref_Uid12345&utm_medium=y'), 'Uid12345');
      expect(ReferralService.parseInviter('referrer%3Dref_Uid12345'), 'Uid12345');
      expect(ReferralService.parseInviter('utm_source=google-play&utm_medium=organic'), isNull);
      expect(ReferralService.parseInviter('ref_ab'), isNull, reason: 'too short to be a uid');
      expect(ReferralService.parseInviter('pref_Uid12345'), isNull);
      expect(ReferralService.parseInviter(null), isNull);
      expect(ReferralService.parseInviter(''), isNull);
    });

    test('hasCompletedLevel', () {
      expect(ReferralService.hasCompletedLevel({}), isFalse);
      expect(ReferralService.hasCompletedLevel({'rec.sudoku.plays': 3, 'rec.sudoku.levels': 0}), isFalse);
      expect(ReferralService.hasCompletedLevel({'rec.arrows.levels': 1}), isTrue);
    });
  });

  group('leaderboard', () {
    test('boards: score games + chess wins + total stars, unique ids', () {
      expect(leaderboards.map((b) => b.id).toSet().length, leaderboards.length);
      expect(leaderboards.map((b) => b.id), containsAll(['game_2048', 'focus_color', 'memory_boost', 'block_puzzle', 'chess', 'total_stars']));
      expect(boardForGame('game_2048')!.id, 'game_2048');
      expect(boardForGame('sudoku'), isNull);
      expect(totalStarsBoard.gameId, isNull);
      expect(boardForGame('chess')!.metric, BoardMetric.wins);
    });

    test('totalStarsOf sums every stars key', () {
      expect(
        totalStarsOf({
          'arrows.easy.stars.1': 3,
          'flow.a.stars.2': 2,
          'mom.match.stars.0': 1,
          'x.stars': 2,
          'rec.sudoku.best': 900,
          'arrows.easy.completed': 7,
          'bad.stars.1': 'x',
          'neg.stars.1': -4,
        }),
        8,
      );
    });
  });

  test('cloud is unavailable in tests (no Firebase) and services are no-ops', () async {
    expect(CloudService.available, isFalse);
    expect(LeaderboardService.I.canSubmit, isFalse);
  });
}
