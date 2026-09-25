import 'calculator.dart';
import 'fixed_point.dart';
import 'models.dart';

enum DirectDebitVerdict { aboutRight, likelyTooLow, likelyTooHigh }

enum DirectDebitConfidence { low, medium }

/// "Is my Direct Debit right?" — an ESTIMATE, never a measured fact.
///
/// Method (deterministic):
/// 1. Average daily usage across the given bills (total kWh ÷ total days).
/// 2. Price that usage for 365 days at the **latest bill's** latest rates,
///    VAT included, adjustments excluded.
/// 3. Suggested monthly = (annual cost − current credit balance) ÷ 12.
/// 4. Compare with the current Direct Debit; within ±10% counts as
///    "about right".
///
/// Limitation stated in the UI: a year of usage is not flat — winter bills
/// are usually higher — so fewer than 180 days of bills gives LOW
/// confidence.
class DirectDebitCheck {
  const DirectDebitCheck._({
    required this.daysOfData,
    required this.kwhPerDayMilli,
    required this.annualCostPence,
    required this.suggestedMonthlyPence,
    required this.currentMonthlyPence,
    required this.verdict,
    required this.confidence,
    required this.balancePence,
  });

  final int daysOfData;
  final int kwhPerDayMilli;
  final int annualCostPence;
  final int suggestedMonthlyPence;
  final int currentMonthlyPence;
  final DirectDebitVerdict verdict;
  final DirectDebitConfidence confidence;
  final int balancePence;

  int get monthlyDifferencePence => currentMonthlyPence - suggestedMonthlyPence;

  static const int toleranceBasisPoints = 1000;
  static const int mediumConfidenceDays = 180;

  static DirectDebitCheck? run({
    required List<Bill> bills,
    required int currentMonthlyPence,
    BillCalculator calculator = const BillCalculator(),
  }) {
    if (bills.isEmpty || currentMonthlyPence <= 0) return null;
    final sorted = [...bills]
      ..sort((a, b) => a.periodEnd.compareTo(b.periodEnd));
    var days = 0;
    var kwh = 0;
    for (final b in sorted) {
      final c = calculator.calculate(b);
      days += c.days;
      kwh += c.kwhMilli;
    }
    if (days == 0) return null;
    final latest = sorted.last;
    final latestCalc = calculator.calculate(latest);
    final period = latest.ratePeriods.last;

    // Annual kWh per register, keeping the latest bill's register split.
    final annualKwh = divRoundHalfAwayFromZero(kwh * 365, days);
    final regs = period.registers;
    final latestTotalKwh = latestCalc.kwhMilli;
    var remaining = annualKwh;
    final priced = <RegisterUsage>[];
    for (var i = 0; i < regs.length; i++) {
      final share = i == regs.length - 1
          ? remaining
          : (latestTotalKwh == 0
                ? divRoundHalfAwayFromZero(annualKwh, regs.length)
                : divRoundHalfAwayFromZero(
                    annualKwh *
                        (latestCalc.kwhMilliByRegister[regs[i].register] ?? 0),
                    latestTotalKwh,
                  ));
      remaining -= share;
      priced.add(regs[i].copyWith(kwhMilli: share));
    }
    final yearBill = Bill(
      id: 'dd-projection',
      householdId: latest.householdId,
      ratePeriods: [
        period.copyWith(
          start: DateTime.utc(2001, 1, 1),
          end: DateTime.utc(2001, 12, 31),
          registers: priced,
        ),
      ],
      ratesIncludeVat: latest.ratesIncludeVat,
      createdAt: DateTime.utc(2001),
    );
    final annual = calculator.calculate(yearBill).totalPence;
    final balance = latest.closingBalancePence ?? 0;
    final suggested = divRoundHalfAwayFromZero(annual - balance, 12);
    final suggestedClamped = suggested < 0 ? 0 : suggested;

    final tolerance = divRoundHalfAwayFromZero(
      suggestedClamped * toleranceBasisPoints,
      10000,
    );
    DirectDebitVerdict verdict;
    if (currentMonthlyPence < suggestedClamped - tolerance) {
      verdict = DirectDebitVerdict.likelyTooLow;
    } else if (currentMonthlyPence > suggestedClamped + tolerance) {
      verdict = DirectDebitVerdict.likelyTooHigh;
    } else {
      verdict = DirectDebitVerdict.aboutRight;
    }
    return DirectDebitCheck._(
      daysOfData: days,
      kwhPerDayMilli: divRoundHalfAwayFromZero(kwh, days),
      annualCostPence: annual,
      suggestedMonthlyPence: suggestedClamped,
      currentMonthlyPence: currentMonthlyPence,
      verdict: verdict,
      confidence: days >= mediumConfidenceDays
          ? DirectDebitConfidence.medium
          : DirectDebitConfidence.low,
      balancePence: balance,
    );
  }
}
