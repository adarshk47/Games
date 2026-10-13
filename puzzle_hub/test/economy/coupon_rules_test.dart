import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/coupon_service.dart';

void main() {
  test('open coupons work for everyone', () {
    expect(CouponService.allowedFor({'active': true}, 'u1', 'a@b.c'), isTrue);
    expect(CouponService.allowedFor({'active': true, 'uids': []}, 'u1', null), isTrue);
  });

  test('assigned coupons only work for the listed players', () {
    final d = {
      'active': true,
      'uids': ['u1'],
      'emails': ['Friend@Gmail.com'],
    };
    expect(CouponService.allowedFor(d, 'u1', null), isTrue);
    expect(CouponService.allowedFor(d, 'u2', ' friend@gmail.com '), isTrue);
    expect(CouponService.allowedFor(d, 'u2', 'other@gmail.com'), isFalse);
    expect(CouponService.allowedFor(d, null, null), isFalse);
  });
}
