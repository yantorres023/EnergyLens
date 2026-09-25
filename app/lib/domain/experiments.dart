import 'calculator.dart';
import 'dates.dart';
import 'direct_debit.dart';
import 'fixed_point.dart';
import 'models.dart';
import 'what_if.dart';

/// Static description of an action the user can choose. Every action has a
/// metric that the *next bill* can verify — that is the product loop.
class ActionDefinition {
  const ActionDefinition({
    required this.type,
    required this.title,
    required this.howTo,
    required this.metricLabel,
    required this.verification,
  });

  final ActionType type;
  final String title;
  final String howTo;
  final String metricLabel;
  final String verification;
}

const actionCatalog = <ActionType, ActionDefinition>{
  ActionType.submitMeterReading: ActionDefinition(
    type: ActionType.submitMeterReading,
    title: 'Send your supplier a meter reading',
    howTo:
        'Your last bill used an estimated reading. Read the meter (or check '
        'your smart meter display) and submit it in your supplier\'s app or '
        'website a few days before your next bill.',
    metricLabel: 'Reading type on the next bill',
    verification: 'Passes if your next bill uses an actual or smart reading.',
  ),
  ActionType.reduceDailyUsage: ActionDefinition(
    type: ActionType.reduceDailyUsage,
    title: 'Use less electricity per day',
    howTo:
        'Pick one or two changes you can keep up for the whole billing '
        'period. EnergyLens cannot tell which appliance uses what; it only '
        'sees your total kWh per day on the next bill.',
    metricLabel: 'Average kWh per day',
    verification:
        'Improved if kWh/day is at least 5% lower on the next bill. Weather '
        'and season also change usage, so a change is not proof of cause.',
  ),
  ActionType.shiftToNight: ActionDefinition(
    type: ActionType.shiftToNight,
    title: 'Move flexible use to your night rate',
    howTo:
        'On Economy 7, run timer-friendly appliances (washing machine, '
        'dishwasher, storage heaters, EV charging) during your night hours. '
        'Check your night hours with your supplier — they vary by meter.',
    metricLabel: 'Share of electricity on the night rate',
    verification: 'Improved if the night share rises by 3 points or more.',
  ),
  ActionType.checkTariffQuote: ActionDefinition(
    type: ActionType.checkTariffQuote,
    title: 'Check a tariff quote against your real usage',
    howTo:
        'Get a quote (from your supplier, a comparison site, or MSE) and '
        'type its unit rate and standing charge into "What if?". EnergyLens '
        're-prices your actual bill. It does not recommend or sell tariffs.',
    metricLabel: 'Next bill vs the same usage at your old prices',
    verification:
        'Improved if your next bill costs less than the same usage would '
        'have cost at your previous prices.',
  ),
  ActionType.reviewDirectDebit: ActionDefinition(
    type: ActionType.reviewDirectDebit,
    title: 'Review your Direct Debit',
    howTo:
        'Compare your Direct Debit with the estimate from your bills. If it '
        'looks off, ask your supplier to review it — you can ask them to '
        'explain how they set it.',
    metricLabel: 'Direct Debit vs estimated need',
    verification:
        'Improved if the Direct Debit check says "about right" after the '
        'next bill.',
  ),
};

class ExperimentEvaluation {
  const ExperimentEvaluation({
    required this.outcome,
    required this.resultMetricMilli,
    this.counterfactualSavingPence,
    this.caveats = const {},
  });

  final ExperimentOutcome outcome;
  final int resultMetricMilli;

  /// CALCULATED: for usage actions, the kWh/day change priced at the result
  /// bill's average price; for tariff actions, old prices − actual.
  final int? counterfactualSavingPence;
  final Set<String> caveats;
}

class ExperimentEngine {
  const ExperimentEngine({this.calculator = const BillCalculator()});
  final BillCalculator calculator;

  /// Baseline metric for [action] from [baseline].
  int baselineMetric(ActionType action, Bill baseline, {int? directDebit}) {
    final c = calculator.calculate(baseline);
    switch (action) {
      case ActionType.submitMeterReading:
        return baseline.usageIsEstimated ? 0 : 1;
      case ActionType.reduceDailyUsage:
        return c.kwhPerDayMilli;
      case ActionType.shiftToNight:
        return c.nightSharePermille ?? 0;
      case ActionType.checkTariffQuote:
        return c.totalPence;
      case ActionType.reviewDirectDebit:
        return directDebit ?? 0;
    }
  }

  SavingsExperiment start({
    required String id,
    required ActionType action,
    required Bill baseline,
    required DateTime now,
    int? directDebit,
  }) {
    return SavingsExperiment(
      id: id,
      householdId: baseline.householdId,
      action: action,
      baselineBillId: baseline.id,
      startedAt: now,
      baselineMetricMilli: baselineMetric(
        action,
        baseline,
        directDebit: directDebit,
      ),
    );
  }

  /// Is [candidate] a valid "next bill" for an experiment on [baseline]?
  static bool isLaterBill(Bill baseline, Bill candidate) =>
      candidate.id != baseline.id &&
      !dateOnly(candidate.periodStart).isBefore(dateOnly(baseline.periodEnd));

  ExperimentEvaluation evaluate({
    required SavingsExperiment experiment,
    required Bill baseline,
    required Bill result,
    List<Bill> allBills = const [],
    int? directDebit,
  }) {
    final c1 = calculator.calculate(result);
    final caveats = <String>{};
    if (seasonOf(midpoint(baseline.periodStart, baseline.periodEnd)) !=
        seasonOf(midpoint(result.periodStart, result.periodEnd))) {
      caveats.add('The two bills fall in different seasons.');
    }
    final estimated = baseline.usageIsEstimated || result.usageIsEstimated;
    if (estimated && experiment.action != ActionType.submitMeterReading) {
      caveats.add('A bill used an estimated reading.');
    }

    switch (experiment.action) {
      case ActionType.submitMeterReading:
        final ok = switch (result.readingType) {
          ReadingType.actual || ReadingType.smart || ReadingType.customer => 1,
          ReadingType.estimated => 0,
          ReadingType.unknown => -1,
        };
        return ExperimentEvaluation(
          outcome: ok == 1
              ? ExperimentOutcome.improved
              : ok == 0
              ? ExperimentOutcome.noClearChange
              : ExperimentOutcome.inconclusive,
          resultMetricMilli: ok < 0 ? 0 : ok,
          caveats: caveats,
        );

      case ActionType.reduceDailyUsage:
        final base = experiment.baselineMetricMilli;
        final now = c1.kwhPerDayMilli;
        final avgPriceMilli = c1.kwhMilli == 0
            ? 0
            : divRoundHalfAwayFromZero(
                (c1.energyPence * (10000 + _vatBp(c1))) * 100,
                c1.kwhMilli,
              );
        // (base − now) kWh/day × days × price (milli-pence/kWh) → pence.
        final saving = divRoundHalfAwayFromZero(
          (base - now) * c1.days * avgPriceMilli,
          1000000,
        );
        return ExperimentEvaluation(
          outcome: estimated
              ? ExperimentOutcome.inconclusive
              : _band(now, base, lowerIsBetter: true, bp: 500),
          resultMetricMilli: now,
          counterfactualSavingPence: saving,
          caveats: caveats,
        );

      case ActionType.shiftToNight:
        final base = experiment.baselineMetricMilli;
        final now = c1.nightSharePermille;
        if (now == null) {
          return ExperimentEvaluation(
            outcome: ExperimentOutcome.inconclusive,
            resultMetricMilli: 0,
            caveats: {...caveats, 'The next bill has no night-rate usage.'},
          );
        }
        final diff = now - base;
        return ExperimentEvaluation(
          outcome: estimated
              ? ExperimentOutcome.inconclusive
              : diff >= 30
              ? ExperimentOutcome.improved
              : diff <= -30
              ? ExperimentOutcome.worse
              : ExperimentOutcome.noClearChange,
          resultMetricMilli: now,
          caveats: caveats,
        );

      case ActionType.checkTariffQuote:
        final counterfactual = const WhatIfCalculator().atBaselinePrices(
          result,
          baseline,
        );
        final saving = counterfactual.alternative.totalPence - c1.totalPence;
        final threshold = divRoundHalfAwayFromZero(c1.totalPence.abs(), 100);
        return ExperimentEvaluation(
          outcome: saving > threshold
              ? ExperimentOutcome.improved
              : saving < -threshold
              ? ExperimentOutcome.worse
              : ExperimentOutcome.noClearChange,
          resultMetricMilli: c1.totalPence,
          counterfactualSavingPence: saving,
          caveats: caveats,
        );

      case ActionType.reviewDirectDebit:
        final dd = directDebit ?? experiment.baselineMetricMilli;
        final bills = allBills.isEmpty ? [baseline, result] : allBills;
        final check = DirectDebitCheck.run(
          bills: bills,
          currentMonthlyPence: dd,
          calculator: calculator,
        );
        if (check == null) {
          return ExperimentEvaluation(
            outcome: ExperimentOutcome.inconclusive,
            resultMetricMilli: dd,
            caveats: caveats,
          );
        }
        return ExperimentEvaluation(
          outcome: check.verdict == DirectDebitVerdict.aboutRight
              ? ExperimentOutcome.improved
              : ExperimentOutcome.noClearChange,
          resultMetricMilli: dd,
          caveats: caveats,
        );
    }
  }

  static int _vatBp(BillCalculation c) => c.netPence == 0
      ? 0
      : divRoundHalfAwayFromZero(c.vatPence * 10000, c.netPence);

  static ExperimentOutcome _band(
    int now,
    int base, {
    required bool lowerIsBetter,
    required int bp,
  }) {
    if (base == 0) return ExperimentOutcome.inconclusive;
    final band = divRoundHalfAwayFromZero(base.abs() * bp, 10000);
    final delta = now - base;
    if (delta.abs() < band) return ExperimentOutcome.noClearChange;
    final better = lowerIsBetter ? delta < 0 : delta > 0;
    return better ? ExperimentOutcome.improved : ExperimentOutcome.worse;
  }
}
