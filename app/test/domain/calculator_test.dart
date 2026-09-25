import 'package:energylens/domain/calculator.dart';
import 'package:energylens/domain/dates.dart';
import 'package:energylens/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const calc = BillCalculator();

  group('single rate, VAT added', () {
    test('known bill: 30 days, 300 kWh @ 24.87p, 54.47p/day, 5% VAT', () {
      final c = calc.calculate(septemberBill());
      expect(c.days, 30);
      expect(c.standingPence, 1634); // 1634.1
      expect(c.energyPence, 7461);
      expect(c.netPence, 9095);
      expect(c.vatPence, 455); // 454.75
      expect(c.totalPence, 9550);
      expect(c.kwhMilli, 300000);
      expect(c.kwhPerDayMilli, 10000);
      expect(c.reconciliation, ReconciliationStatus.noStatedTotal);
    });

    test('GB average cap Q4 2026: 31 days, 250 kWh, no VAT', () {
      final c = calc.calculate(
        bill('q4', [
          period(
            d(2026, 10, 1),
            d(2026, 10, 31),
            kwh: '250',
            rate: '26.32',
            standing: '54.83',
            vatBp: 0,
          ),
        ]),
      );
      expect(c.standingPence, 1700); // 1699.73
      expect(c.energyPence, 6580);
      expect(c.vatPence, 0);
      expect(c.totalPence, 8280);
    });

    test('fixed charge only (zero usage) still costs the standing charge', () {
      final c = calc.calculate(
        bill('zero', [
          period(d(2026, 9, 1), d(2026, 9, 30), kwh: '0', rate: '24.87', standing: '54.47'),
        ]),
      );
      expect(c.energyPence, 0);
      expect(c.vatPence, 82); // 81.7
      expect(c.totalPence, 1716);
      expect(c.warnings, contains(CalcWarning.noUsageRecorded));
      expect(c.standingSharePermille, 1000);
    });

    test('flat rate with no standing charge', () {
      final c = calc.calculate(
        bill('flat', [
          period(d(2026, 9, 1), d(2026, 9, 30), kwh: '100', rate: '30', standing: '0', vatBp: 0),
        ]),
      );
      expect(c.totalPence, 3000);
      expect(c.standingSharePermille, 0);
    });
  });

  group('rates that already include VAT', () {
    test('total equals gross lines; VAT is backed out', () {
      final c = calc.calculate(
        bill('incl', [
          period(d(2026, 7, 1), d(2026, 7, 30), kwh: '300', rate: '26.11', standing: '57.19'),
        ], ratesIncludeVat: true),
      );
      // 30 × 57.19 = 1715.7 → 1716; 300 × 26.11 = 7833; gross 9549.
      expect(c.totalPence, 9549);
      expect(c.netPence, 9094); // 9549 / 1.05 = 9094.29
      expect(c.vatPence, 455);
      expect(c.standingPence + c.energyPence, c.netPence);
    });
  });

  group('rate change within the bill (partial periods)', () {
    test('bill spanning 1 October 2026: price and VAT change mid-bill', () {
      final c = calc.calculate(
        bill('split', [
          period(d(2026, 9, 15), d(2026, 9, 30), kwh: '160', rate: '24.87', standing: '54.47'),
          period(
            d(2026, 10, 1),
            d(2026, 10, 14),
            kwh: '150',
            rate: '26.32',
            standing: '54.83',
            vatBp: 0,
          ),
        ]),
      );
      expect(c.days, 30);
      // P1: 872 + 3979 = 4851, VAT 243. P2: 768 + 3948, VAT 0.
      expect(c.vatPence, 243);
      expect(c.totalPence, 9810);
      expect(c.warnings, isNot(contains(CalcWarning.ratePeriodsHaveGap)));
      expect(c.lines.where((l) => l.kind == LineKind.vat).length, 2);
    });

    test('flags overlapping and gapped rate periods', () {
      final overlap = calc.calculate(
        bill('o', [
          period(d(2026, 9, 1), d(2026, 9, 15), kwh: '1', rate: '1', standing: '1'),
          period(d(2026, 9, 15), d(2026, 9, 30), kwh: '1', rate: '1', standing: '1'),
        ]),
      );
      expect(overlap.warnings, contains(CalcWarning.ratePeriodsOverlap));
      final gap = calc.calculate(
        bill('g', [
          period(d(2026, 9, 1), d(2026, 9, 10), kwh: '1', rate: '1', standing: '1'),
          period(d(2026, 9, 20), d(2026, 9, 30), kwh: '1', rate: '1', standing: '1'),
        ]),
      );
      expect(gap.warnings, contains(CalcWarning.ratePeriodsHaveGap));
    });

    test('unsorted periods are sorted before calculating', () {
      final a = period(d(2026, 9, 1), d(2026, 9, 15), kwh: '10', rate: '20', standing: '50');
      final b = period(d(2026, 9, 16), d(2026, 9, 30), kwh: '10', rate: '25', standing: '50');
      expect(
        calc.calculate(bill('x', [b, a])).totalPence,
        calc.calculate(bill('y', [a, b])).totalPence,
      );
    });
  });

  group('Economy 7', () {
    test('two registers priced separately', () {
      final c = calc.calculate(
        bill('e7', [
          period(
            d(2026, 9, 1),
            d(2026, 9, 30),
            standing: '50',
            dayKwh: '200',
            dayRate: '30',
            nightKwh: '100',
            nightRate: '15',
          ),
        ]),
      );
      expect(c.standingPence, 1500);
      expect(c.energyPenceByRegister[Register.day], 6000);
      expect(c.energyPenceByRegister[Register.night], 1500);
      expect(c.totalPence, 9450);
      expect(c.nightSharePermille, 333);
    });
  });

  group('adjustments and credits', () {
    test('negative adjustment (credit) is applied after VAT', () {
      final c = calc.calculate(
        septemberBill().copyWith(
          adjustments: const [
            Adjustment(label: 'Warm Home Discount', amountPence: -15000, kind: AdjustmentKind.credit),
          ],
        ),
      );
      expect(c.vatPence, 455);
      expect(c.adjustmentsPence, -15000);
      expect(c.totalPence, -5450);
      expect(c.standingSharePermille, 0); // not meaningful when total ≤ 0
    });
  });

  group('reconciliation', () {
    test('matches within 5p tolerance', () {
      expect(calc.calculate(septemberBill(stated: 9550)).reconciliation, ReconciliationStatus.matches);
      expect(calc.calculate(septemberBill(stated: 9545)).reconciliation, ReconciliationStatus.matches);
    });
    test('mismatch beyond tolerance reports the difference', () {
      final c = calc.calculate(septemberBill(stated: 9500));
      expect(c.reconciliation, ReconciliationStatus.mismatch);
      expect(c.reconciliationDifferencePence, 50);
    });
  });

  group('validation', () {
    test('end before start throws', () {
      expect(
        () => calc.calculate(
          bill('bad', [period(d(2026, 9, 30), d(2026, 9, 1), kwh: '1', rate: '1')]),
        ),
        throwsA(isA<ValidationError>()),
      );
    });
    test('no periods throws', () {
      expect(() => calc.calculate(bill('none', const [])), throwsA(isA<ValidationError>()));
    });
    test('negative usage and odd VAT are flagged, not hidden', () {
      final c = calc.calculate(
        bill('neg', [
          period(d(2026, 9, 1), d(2026, 9, 30), kwh: '-5', rate: '20', standing: '50', vatBp: 5000),
        ]),
      );
      expect(c.warnings, containsAll([CalcWarning.negativeUsage, CalcWarning.vatOutOfRange]));
    });
    test('very high usage is flagged but still calculated', () {
      final c = calc.calculate(
        bill('hi', [
          period(d(2026, 9, 1), d(2026, 9, 30), kwh: '30000', rate: '26.32', standing: '54.83'),
        ]),
      );
      expect(c.warnings, contains(CalcWarning.veryHighUsage));
      expect(c.energyPence, 789600);
    });
    test('estimated reading is surfaced as a warning', () {
      final c = calc.calculate(octoberBill(reading: ReadingType.estimated));
      expect(c.warnings, contains(CalcWarning.estimatedReading));
    });
  });

  group('dates', () {
    test('inclusive day count', () {
      expect(inclusiveDays(d(2026, 9, 1), d(2026, 9, 30)), 30);
      expect(inclusiveDays(d(2026, 9, 1), d(2026, 9, 1)), 1);
    });
    test('day counts are not affected by BST ending on 25 Oct 2026', () {
      // Local-time arithmetic would see a 25-hour day here.
      expect(inclusiveDays(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 31);
      expect(inclusiveDays(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), 31);
    });
    test('leap year February', () {
      expect(inclusiveDays(d(2028, 2, 1), d(2028, 2, 29)), 29);
    });
    test('iso round trip and invalid dates', () {
      expect(isoDate(parseIsoDate('2026-10-01')), '2026-10-01');
      expect(() => parseIsoDate('2026-02-30'), throwsFormatException);
    });
  });

  group('meter readings', () {
    test('normal consumption', () {
      expect(MeterConsumption.fromReadings(startMilli: m('12345'), endMilli: m('12645')), m('300'));
    });
    test('meter rollover on a 5-digit meter', () {
      expect(
        MeterConsumption.fromReadings(startMilli: m('99950'), endMilli: m('120'), rolloverDigits: 5),
        m('170'),
      );
    });
    test('lower closing reading without rollover confirmation is rejected', () {
      expect(
        () => MeterConsumption.fromReadings(startMilli: m('500'), endMilli: m('400')),
        throwsA(isA<ValidationError>()),
      );
    });
    test('reading too long for the meter is rejected', () {
      expect(
        () => MeterConsumption.fromReadings(
          startMilli: m('123456'),
          endMilli: m('10'),
          rolloverDigits: 5,
        ),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}
