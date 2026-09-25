import 'package:energylens/domain/calculator.dart';
import 'package:energylens/domain/comparison.dart';
import 'package:energylens/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

int sumEffects(BillComparison c) =>
    c.effects.fold(0, (s, e) => s + e.amountPence);

void main() {
  test('September → October 2026: effects sum exactly to the change', () {
    final c = BillComparison.compare(septemberBill(), octoberBill());
    expect(c.previousCalc.totalPence, 9550);
    expect(c.currentCalc.totalPence, 10675); // 1700 + 8975
    expect(c.differencePence, 1125);
    expect(sumEffects(c), 1125);
    // Hand-computed attribution (pence, ±2 for rounding allocation):
    expect(c.effect(EffectType.dailyUsage), closeTo(810, 2));
    expect(c.effect(EffectType.unitRate), closeTo(519, 2));
    expect(c.effect(EffectType.periodLength), closeTo(318, 2));
    expect(c.effect(EffectType.standingCharge), closeTo(12, 2));
    expect(c.effect(EffectType.vatRate), closeTo(-534, 2));
    expect(c.mainDriver!.type, EffectType.dailyUsage);
    expect(c.caveats, isNot(contains(ComparisonCaveat.gapBetweenBills)));
    // September and October are both autumn.
    expect(c.caveats, isNot(contains(ComparisonCaveat.differentSeasons)));
  });

  test('identical bills produce no effects', () {
    final a = septemberBill(id: 'a');
    final b = bill('b', [
      period(d(2026, 10, 1), d(2026, 10, 30), kwh: '300', rate: '24.87', standing: '54.47'),
    ]);
    final c = BillComparison.compare(a, b);
    expect(c.differencePence, 0);
    expect(c.effects, isEmpty);
  });

  test('only period length changed', () {
    final a = bill('a', [
      period(d(2026, 1, 1), d(2026, 1, 30), kwh: '300', rate: '20', standing: '50', vatBp: 0),
    ]);
    final b = bill('b', [
      period(d(2026, 1, 31), d(2026, 3, 1), kwh: '310', rate: '20', standing: '50', vatBp: 0),
    ]);
    // b: 30 days? 31 Jan → 1 Mar = 30 days. Make it 31 days explicitly:
    final b31 = bill('b31', [
      period(d(2026, 1, 31), d(2026, 3, 2), kwh: '310', rate: '20', standing: '50', vatBp: 0),
    ]);
    expect(b.days, 30);
    final c = BillComparison.compare(a, b31);
    // 1 extra day at 10 kWh/day × 20p + 50p = 250p, all period length.
    expect(c.differencePence, 250);
    expect(c.effects.single.type, EffectType.periodLength);
    expect(c.effects.single.amountPence, 250);
  });

  test('only VAT changed (5% → 0%)', () {
    final a = bill('a', [
      period(d(2026, 9, 1), d(2026, 9, 30), kwh: '300', rate: '20', standing: '50'),
    ]);
    final b = bill('b', [
      period(d(2026, 10, 1), d(2026, 10, 30), kwh: '300', rate: '20', standing: '50', vatBp: 0),
    ]);
    final c = BillComparison.compare(a, b);
    // net 7500, VAT 375.
    expect(c.differencePence, -375);
    expect(c.effects.single.type, EffectType.vatRate);
  });

  test('only standing charge changed', () {
    final a = bill('a', [
      period(d(2026, 9, 1), d(2026, 9, 30), kwh: '300', rate: '20', standing: '50', vatBp: 0),
    ]);
    final b = bill('b', [
      period(d(2026, 10, 1), d(2026, 10, 30), kwh: '300', rate: '20', standing: '60', vatBp: 0),
    ]);
    final c = BillComparison.compare(a, b);
    expect(c.differencePence, 300);
    expect(c.effects.single.type, EffectType.standingCharge);
  });

  test('credits show up as an adjustments effect', () {
    final a = septemberBill(id: 'a');
    final b = bill('b', [
      period(d(2026, 10, 1), d(2026, 10, 30), kwh: '300', rate: '24.87', standing: '54.47'),
    ], adjustments: const [Adjustment(label: 'Credit', amountPence: -2000)]);
    final c = BillComparison.compare(a, b);
    expect(c.differencePence, -2000);
    expect(c.effects.single.type, EffectType.adjustments);
  });

  test('zero-usage previous bill: change is usage, not price', () {
    final a = bill('a', [
      period(d(2026, 9, 1), d(2026, 9, 30), kwh: '0', rate: '20', standing: '50', vatBp: 0),
    ]);
    final b = bill('b', [
      period(d(2026, 10, 1), d(2026, 10, 30), kwh: '100', rate: '20', standing: '50', vatBp: 0),
    ]);
    final c = BillComparison.compare(a, b);
    expect(c.differencePence, 2000);
    expect(c.effect(EffectType.dailyUsage), 2000);
    expect(c.effect(EffectType.unitRate), 0);
  });

  test('Economy 7 vs single-rate is flagged as a meter-type change', () {
    final a = septemberBill(id: 'a');
    final b = bill('b', [
      period(
        d(2026, 10, 1),
        d(2026, 10, 30),
        standing: '54.47',
        dayKwh: '200',
        dayRate: '30',
        nightKwh: '100',
        nightRate: '15',
      ),
    ]);
    final c = BillComparison.compare(a, b);
    expect(c.caveats, contains(ComparisonCaveat.meterTypeChanged));
    expect(sumEffects(c), c.differencePence);
  });

  test('caveats: estimated reading, gap, overlap, mismatch', () {
    final est = BillComparison.compare(
      septemberBill(stated: 1),
      octoberBill(reading: ReadingType.estimated),
    );
    expect(
      est.caveats,
      containsAll([
        ComparisonCaveat.estimatedReading,
        ComparisonCaveat.reconciliationMismatch,
      ]),
    );
    final gap = BillComparison.compare(
      septemberBill(),
      bill('late', [period(d(2026, 11, 1), d(2026, 11, 30), kwh: '1', rate: '1', standing: '1')]),
    );
    expect(gap.caveats, contains(ComparisonCaveat.gapBetweenBills));
    final overlap = BillComparison.compare(
      septemberBill(),
      bill('ov', [period(d(2026, 9, 20), d(2026, 10, 20), kwh: '1', rate: '1', standing: '1')]),
    );
    expect(overlap.caveats, contains(ComparisonCaveat.overlappingPeriods));
  });

  test('property: effects always sum to the difference', () {
    // Deterministic pseudo-random sweep over many combinations.
    var seed = 42;
    int next(int max) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % max;
    }

    for (var i = 0; i < 300; i++) {
      final a = bill('a$i', [
        period(
          d(2026, 1, 1),
          d(2026, 1, 1).add(Duration(days: 20 + next(80))),
          kwh: '${next(2000)}.${next(1000)}',
          rate: '${10 + next(40)}.${next(100)}',
          standing: '${next(80)}.${next(100)}',
          vatBp: next(2) * 500,
        ),
      ], adjustments: [Adjustment(label: 'x', amountPence: next(3000) - 1500)]);
      final start = d(2026, 6, 1);
      final b = bill('b$i', [
        period(
          start,
          start.add(Duration(days: 10 + next(40))),
          kwh: '${next(2000)}',
          rate: '${10 + next(40)}.${next(100)}',
          standing: '${next(80)}.${next(100)}',
          vatBp: next(2) * 500,
        ),
        period(
          start.add(const Duration(days: 51)),
          start.add(Duration(days: 60 + next(30))),
          kwh: '${next(1000)}',
          rate: '${10 + next(40)}.${next(100)}',
          standing: '${next(80)}.${next(100)}',
          vatBp: next(2) * 500,
        ),
      ]);
      final c = BillComparison.compare(a, b);
      expect(sumEffects(c), c.differencePence, reason: 'case $i');
    }
  });

  test('comparison refuses zero-day bills', () {
    // A zero-day bill cannot exist via RatePeriod (inclusive days ≥ 1), so
    // the guard is exercised through the calculator's validation instead.
    expect(
      () => BillComparison.compare(
        septemberBill(),
        bill('bad', [period(d(2026, 10, 2), d(2026, 10, 1))]),
      ),
      throwsA(isA<ValidationError>()),
    );
  });
}
