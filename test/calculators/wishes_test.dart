import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/wishes/domain/wish_calculator.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

void main() {
  final now = DateTime.utc(2026, 12, 31, 10);
  test('8000 primogems, fifteen days and active Welkin yields 64 wishes', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(days: 15)),
        primogems: 8000,
        welkinDays: 25,
      ),
    );
    expect(r.nowWishes, 50);
    expect(r.projected, 64);
    expect(r.remainder, 10);
    expect(r.welkinClaims, 15);
    expect(r.commissionClaims, 15);
  });
  test('Zero horizon does not grant any daily rewards', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now,
        welkinDays: 30,
        welkinTodayClaimed: false,
        commissionsTodayClaimed: false,
      ),
    );
    expect(r.projected, 0);
    expect(r.welkinClaims, 0);
    expect(r.commissionClaims, 0);
  });
  test('Welkin expires even on missed days and does not renew', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(days: 10)),
        welkinDays: 3,
        welkinTodayClaimed: false,
        commissionsTodayClaimed: false,
        skippedLoginDays: {'2027-01-01'},
      ),
    );
    expect(r.welkinClaims, 2);
    expect(r.commissionClaims, 10);
  });
  test('Server reset boundary includes exactly one new day', () {
    final before = DateTime.utc(2026, 11, 23, 8, 59, 59);
    final r = calculateWishes(
      WishInput(
        now: before,
        target: DateTime.utc(2026, 11, 23, 9),
        welkinDays: 2,
      ),
    );
    expect(r.commissionClaims, 1);
    expect(r.welkinClaims, 1);
    expect(gameDay(before, GameServer.america), DateTime.utc(2026, 11, 22));
    expect(
      gameDay(DateTime.utc(2026, 11, 23, 3), GameServer.europe),
      DateTime.utc(2026, 11, 23),
    );
    expect(
      gameDay(DateTime.utc(2026, 11, 22, 20), GameServer.asia),
      DateTime.utc(2026, 11, 23),
    );
  });
  test('No claimed rewards counted twice on current day', () {
    final claimed = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(hours: 1)),
        welkinDays: 2,
      ),
    );
    final unclaimed = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(hours: 1)),
        welkinDays: 2,
        welkinTodayClaimed: false,
        commissionsTodayClaimed: false,
      ),
    );
    expect(claimed.breakdown['Bendición prevista'], 0);
    expect(unclaimed.breakdown['Bendición prevista'], 90);
    expect(unclaimed.breakdown['Encargos previstos'], 60);
  });
  test('Crystals opt-in, integer remainders, fate types stay separate', () {
    final a = calculateWishes(
      WishInput(
        now: now,
        target: now,
        primogems: 159,
        crystals: 1,
        intertwined: 4,
        acquaint: 9,
      ),
    );
    final b = calculateWishes(
      WishInput(
        now: now,
        target: now,
        primogems: 159,
        crystals: 1,
        convertCrystals: true,
        intertwined: 4,
        acquaint: 9,
        useAcquaint: true,
      ),
    );
    expect(a.projected, 4);
    expect(a.remainder, 159);
    expect(a.otherFates, 9);
    expect(b.projected, 10);
    expect(b.remainder, 0);
    expect(b.otherFates, 4);
  });
  test('Monthly dust allowance resets over year boundary, budget does not', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(days: 1)),
        commissions: false,
        dust: 450,
        dustUsedThisMonth: 4,
        purchases: [
          DustPurchase(DateTime.utc(2026, 12, 31), 1),
          DustPurchase(DateTime.utc(2027, 1, 1), 5),
        ],
      ),
    );
    expect(r.nowWishes, 1);
    expect(r.projected, 6);
    expect(r.remainingDust, 0);
  });
  test('Reject insufficient currencies and excess monthly purchases', () {
    for (final i in [
      WishInput(now: now, target: now, glitter: 4, glitterWishes: 1),
      WishInput(
        now: now,
        target: now,
        dust: 74,
        purchases: [DustPurchase(DateTime.utc(2026, 12, 31), 1)],
      ),
      WishInput(
        now: now,
        target: now,
        dust: 1000,
        dustUsedThisMonth: 5,
        purchases: [DustPurchase(DateTime.utc(2026, 12, 31), 1)],
      ),
    ]) {
      expect(() => calculateWishes(i), throwsA(isA<CalculationException>()));
    }
  });
  test('Explicit glitter canjes only, no automatic future earnings', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now,
        glitter: 20,
        glitterWishes: 3,
        dust: 1000,
      ),
    );
    expect(r.projected, 3);
    expect(r.remainingGlitter, 5);
    expect(r.remainingDust, 1000);
  });
  test('Manual confirmed and estimated rewards are separate', () {
    final r = calculateWishes(
      WishInput(
        now: now,
        target: now.add(const Duration(days: 1)),
        commissions: false,
        rewards: [
          WishReward(DateTime.utc(2027, 1, 1), 160, confirmed: true),
          WishReward(DateTime.utc(2027, 1, 1), 200),
        ],
      ),
    );
    expect(r.projected, 1);
    expect(r.withEstimates, 2);
    expect(r.estimatedRemainder, 40);
  });
  test('Reject negative values, invalid dates, out-of-range entries', () {
    expect(() => parseDay('2026-02-30'), throwsA(isA<CalculationException>()));
    expect(
      () => calculateWishes(WishInput(now: now, target: now, primogems: -1)),
      throwsA(isA<CalculationException>()),
    );
    expect(
      () => calculateWishes(
        WishInput(now: now, target: now, skippedLoginDays: {'2027-01-01'}),
      ),
      throwsA(isA<CalculationException>()),
    );
    expect(
      () => calculateWishes(
        WishInput(now: now, target: now.subtract(const Duration(seconds: 1))),
      ),
      throwsA(isA<CalculationException>()),
    );
  });
}
