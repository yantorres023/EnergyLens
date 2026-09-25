import 'dart:io';

import 'package:energylens/domain/direct_debit.dart';
import 'package:energylens/domain/experiments.dart';
import 'package:energylens/domain/insights.dart';
import 'package:energylens/domain/models.dart';
import 'package:energylens/domain/tariff_reference.dart';
import 'package:energylens/domain/what_if.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Bill e7Bill({String id = 'e7', String night = '100', DateTime? start}) {
  final s = start ?? d(2026, 10, 1);
  return bill(id, [
    period(
      s,
      s.add(const Duration(days: 29)),
      standing: '50',
      dayKwh: '200',
      dayRate: '30',
      nightKwh: night,
      nightRate: '15',
      vatBp: 0,
    ),
  ]);
}

Bill novemberBill({
  String kwh = '300',
  String rate = '26.32',
  ReadingType reading = ReadingType.actual,
}) => bill('nov', [
  period(
    d(2026, 11, 1),
    d(2026, 11, 30),
    kwh: kwh,
    rate: rate,
    standing: '54.83',
    vatBp: 0,
  ),
], readingType: reading);

void main() {
  final reference = TariffDataset.parse(
    File('assets/data/gb_price_cap_electricity.json').readAsStringSync(),
  );

  group('Direct Debit check (ESTIMATE)', () {
    test('known projection from two bills', () {
      final r = DirectDebitCheck.run(
        bills: [septemberBill(), octoberBill()],
        currentMonthlyPence: 9000,
      )!;
      expect(r.daysOfData, 61);
      expect(r.kwhPerDayMilli, 10508);
      // 641 kWh × 365 / 61 days = 3,835.492 kWh → £1,009.50 + 365 × 54.83p.
      expect(r.annualCostPence, 120963);
      expect(r.suggestedMonthlyPence, 10080);
      expect(r.verdict, DirectDebitVerdict.likelyTooLow);
      expect(r.confidence, DirectDebitConfidence.low);
    });

    test('credit balance reduces the suggested amount', () {
      final r = DirectDebitCheck.run(
        bills: [
          septemberBill(),
          octoberBill().copyWith(closingBalancePence: 12000),
        ],
        currentMonthlyPence: 9000,
      )!;
      expect(r.suggestedMonthlyPence, 9080);
      expect(r.verdict, DirectDebitVerdict.aboutRight);
    });

    test('too high, and never negative', () {
      final r = DirectDebitCheck.run(
        bills: [octoberBill().copyWith(closingBalancePence: 10000000)],
        currentMonthlyPence: 5000,
      )!;
      expect(r.suggestedMonthlyPence, 0);
      expect(r.verdict, DirectDebitVerdict.likelyTooHigh);
    });

    test('no bills or no Direct Debit → no check', () {
      expect(
        DirectDebitCheck.run(bills: const [], currentMonthlyPence: 100),
        isNull,
      );
      expect(
        DirectDebitCheck.run(bills: [octoberBill()], currentMonthlyPence: 0),
        isNull,
      );
    });

    test('medium confidence needs 180+ days', () {
      final long = bill('long', [
        period(
          d(2026, 1, 1),
          d(2026, 6, 30),
          kwh: '1800',
          rate: '25',
          standing: '55',
        ),
      ]);
      final r = DirectDebitCheck.run(bills: [long], currentMonthlyPence: 5000)!;
      expect(r.confidence, DirectDebitConfidence.medium);
    });
  });

  group('What-if (user-entered quote)', () {
    const whatIf = WhatIfCalculator();
    test('re-prices the exact usage of a bill', () {
      final r = whatIf.reprice(
        septemberBill(),
        AlternativeRates(
          standingChargeMilliPencePerDay: m('60'),
          unitRatesMilliPence: {Register.single: m('23')},
        ),
      );
      expect(r.actual.totalPence, 9550);
      expect(r.alternative.totalPence, 9135);
      expect(r.savingPence, 415);
    });

    test(
      'single-rate quote on an Economy 7 bill prices all kWh at one rate',
      () {
        final r = whatIf.reprice(
          e7Bill(),
          AlternativeRates(
            standingChargeMilliPencePerDay: m('50'),
            unitRatesMilliPence: {Register.single: m('25')},
          ),
        );
        expect(r.actual.totalPence, 9000);
        expect(r.alternative.totalPence, 9000);
        expect(r.savingPence, 0);
      },
    );

    test('Economy 7 quote needs both rates', () {
      expect(
        () => whatIf.reprice(
          e7Bill(),
          AlternativeRates(
            standingChargeMilliPencePerDay: m('50'),
            unitRatesMilliPence: {Register.day: m('25')},
          ),
        ),
        throwsA(anything),
      );
    });

    test('bill at its own prices has zero saving', () {
      final r = whatIf.atBaselinePrices(octoberBill(), octoberBill());
      expect(r.savingPence, 0);
    });
  });

  group('Experiments (next-bill verification)', () {
    const engine = ExperimentEngine();

    SavingsExperiment startOn(ActionType a, Bill b) =>
        engine.start(id: 'x', action: a, baseline: b, now: d(2026, 11, 2));

    test('reduce daily usage: improved, with calculated value', () {
      final e = startOn(ActionType.reduceDailyUsage, octoberBill());
      expect(e.baselineMetricMilli, 11000);
      final r = engine.evaluate(
        experiment: e,
        baseline: octoberBill(),
        result: novemberBill(),
      );
      expect(r.outcome, ExperimentOutcome.improved);
      expect(r.resultMetricMilli, 10000);
      expect(r.counterfactualSavingPence, 790);
    });

    test('reduce daily usage: small change is "no clear change"', () {
      final e = startOn(ActionType.reduceDailyUsage, octoberBill());
      final r = engine.evaluate(
        experiment: e,
        baseline: octoberBill(),
        result: novemberBill(kwh: '325'),
      );
      expect(r.outcome, ExperimentOutcome.noClearChange);
    });

    test('estimated reading makes a usage result inconclusive', () {
      final e = startOn(ActionType.reduceDailyUsage, octoberBill());
      final r = engine.evaluate(
        experiment: e,
        baseline: octoberBill(),
        result: novemberBill(reading: ReadingType.estimated),
      );
      expect(r.outcome, ExperimentOutcome.inconclusive);
    });

    test('meter reading action verified by reading type', () {
      final base = octoberBill(reading: ReadingType.estimated);
      final e = startOn(ActionType.submitMeterReading, base);
      expect(e.baselineMetricMilli, 0);
      expect(
        engine
            .evaluate(experiment: e, baseline: base, result: novemberBill())
            .outcome,
        ExperimentOutcome.improved,
      );
      expect(
        engine
            .evaluate(
              experiment: e,
              baseline: base,
              result: novemberBill(reading: ReadingType.estimated),
            )
            .outcome,
        ExperimentOutcome.noClearChange,
      );
    });

    test('tariff action verified against old prices', () {
      final e = startOn(ActionType.checkTariffQuote, octoberBill());
      final r = engine.evaluate(
        experiment: e,
        baseline: octoberBill(),
        result: novemberBill(rate: '24'),
      );
      expect(r.counterfactualSavingPence, 696);
      expect(r.outcome, ExperimentOutcome.improved);
    });

    test('night shift verified by night share', () {
      final base = e7Bill();
      final e = startOn(ActionType.shiftToNight, base);
      expect(e.baselineMetricMilli, 333);
      final r = engine.evaluate(
        experiment: e,
        baseline: base,
        result: e7Bill(id: 'e7b', night: '140', start: d(2026, 10, 31)),
      );
      expect(r.resultMetricMilli, 412);
      expect(r.outcome, ExperimentOutcome.improved);
    });

    test('Direct Debit review', () {
      final e = engine.start(
        id: 'dd',
        action: ActionType.reviewDirectDebit,
        baseline: septemberBill(),
        now: d(2026, 10, 1),
        directDebit: 10000,
      );
      final r = engine.evaluate(
        experiment: e,
        baseline: septemberBill(),
        result: octoberBill(),
        directDebit: 10000,
      );
      expect(r.outcome, ExperimentOutcome.improved);
    });

    test('only later bills can verify an experiment', () {
      expect(
        ExperimentEngine.isLaterBill(octoberBill(), novemberBill()),
        isTrue,
      );
      expect(
        ExperimentEngine.isLaterBill(octoberBill(), septemberBill()),
        isFalse,
      );
      expect(
        ExperimentEngine.isLaterBill(octoberBill(), octoberBill()),
        isFalse,
      );
    });

    test('every action has catalog copy', () {
      for (final a in ActionType.values) {
        expect(actionCatalog[a], isNotNull);
        expect(
          actionCatalog[a]!.howTo.toLowerCase(),
          isNot(contains('guarantee')),
        );
      }
    });
  });

  group('Insights', () {
    const engine = InsightEngine();
    const svt = Household(id: 'h1', tariffKind: TariffKind.standardVariable);

    test(
      'September → October: driver, VAT, price rise, fixed charge share',
      () {
        final list = engine.build(
          current: octoberBill(),
          previous: septemberBill(),
          household: svt,
          reference: reference,
          today: d(2026, 11, 5),
        );
        final kinds = list.map((i) => i.kind).toList();
        expect(kinds.first, InsightKind.mainDriver);
        expect(list.first.effect.toString(), contains('dailyUsage'));
        expect(list.first.suggestedAction, ActionType.reduceDailyUsage);
        expect(
          kinds,
          containsAll([
            InsightKind.vatChange,
            InsightKind.unitRateUp,
            InsightKind.standingChargeShare,
          ]),
        );
        // No Q1 2027 data bundled → no preview after October.
        expect(kinds, isNot(contains(InsightKind.capChangePreview)));
        for (final i in list) {
          expect(i.provenance, isNot(Provenance.measured));
        }
      },
    );

    test(
      'cap preview is an ESTIMATE and only for standard variable tariffs',
      () {
        final list = engine.build(
          current: septemberBill(),
          household: svt,
          reference: reference,
          today: d(2026, 9, 25),
        );
        final p = list.firstWhere(
          (i) => i.kind == InsightKind.capChangePreview,
        );
        expect(p.provenance, Provenance.estimated);
        expect(p.confidence, Confidence.low);
        expect(p.referenceVersion!.tariffId, endsWith('2026q4'));

        final fixed = engine.build(
          current: septemberBill(),
          household: const Household(id: 'h1', tariffKind: TariffKind.fixed),
          reference: reference,
          today: d(2026, 9, 25),
        );
        expect(
          fixed.map((i) => i.kind),
          isNot(contains(InsightKind.capChangePreview)),
        );
      },
    );

    test('stale reference data is never used', () {
      final list = engine.build(
        current: septemberBill(),
        household: svt,
        reference: reference,
        today: d(2027, 6, 1),
      );
      expect(
        list.map((i) => i.kind),
        isNot(contains(InsightKind.capChangePreview)),
      );
    });

    test('estimated reading and mismatch insights', () {
      final list = engine.build(
        current: bill(
          'e',
          [
            period(
              d(2026, 9, 1),
              d(2026, 9, 30),
              kwh: '300',
              rate: '24.87',
              standing: '54.47',
            ),
          ],
          readingType: ReadingType.estimated,
          statedTotalPence: 9000,
        ),
        household: svt,
        today: d(2026, 10, 1),
      );
      final kinds = list.map((i) => i.kind).toList();
      expect(kinds.first, InsightKind.reconciliationMismatch);
      expect(list.first.amountPence, 550);
      final est = list.firstWhere(
        (i) => i.kind == InsightKind.estimatedReading,
      );
      expect(est.suggestedAction, ActionType.submitMeterReading);
    });

    test('Economy 7 break-even against the GB-average single rate', () {
      final list = engine.build(
        current: e7Bill(),
        household: const Household(id: 'h1', meterType: MeterType.economy7),
        reference: reference,
        today: d(2026, 11, 5),
      );
      final e7 = list.firstWhere((i) => i.kind == InsightKind.economy7Split);
      expect(e7.valueMilli, 333);
      expect(e7.secondaryMilli, 245); // (30 − 26.32) / (30 − 15)
      expect(e7.provenance, Provenance.estimated);
    });
  });
}
