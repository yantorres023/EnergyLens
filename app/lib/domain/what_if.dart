import 'calculator.dart';
import 'fixed_point.dart';
import 'models.dart';

/// Alternative prices typed in by the user (e.g. a quote from a comparison
/// site or a supplier's fixed deal). EnergyLens has no tariff catalogue and
/// takes no commission, so it never suggests *which* tariff to pick.
class AlternativeRates {
  const AlternativeRates({
    required this.standingChargeMilliPencePerDay,
    required this.unitRatesMilliPence,
    this.ratesIncludeVat = false,
  });

  final int standingChargeMilliPencePerDay;

  /// Register → unit rate. For a single-rate quote on an Economy 7 bill, give
  /// only [Register.single]; all usage is then priced at that rate.
  final Map<Register, int> unitRatesMilliPence;
  final bool ratesIncludeVat;
}

class WhatIfResult {
  const WhatIfResult({
    required this.actual,
    required this.alternative,
    required this.alternativeBill,
  });

  final BillCalculation actual;
  final BillCalculation alternative;
  final Bill alternativeBill;

  /// Positive = the alternative would have been cheaper for this bill's
  /// usage. CALCULATED for this period only — not a forecast.
  int get savingPence => actual.totalPence - alternative.totalPence;
}

class WhatIfCalculator {
  const WhatIfCalculator({this.calculator = const BillCalculator()});
  final BillCalculator calculator;

  /// Re-prices [bill]'s exact usage and days at [rates], keeping each rate
  /// period's VAT rate and the bill's adjustments.
  WhatIfResult reprice(Bill bill, AlternativeRates rates) {
    final single = rates.unitRatesMilliPence[Register.single];
    final periods = bill.ratePeriods.map((p) {
      List<RegisterUsage> regs;
      if (single != null && rates.unitRatesMilliPence.length == 1) {
        final total = p.registers.fold(0, (s, r) => s + r.kwhMilli);
        regs = [
          RegisterUsage(
            register: Register.single,
            kwhMilli: total,
            unitRateMilliPence: single,
          ),
        ];
      } else {
        regs = p.registers.map((r) {
          final rate = rates.unitRatesMilliPence[r.register];
          if (rate == null) {
            throw ValidationError(
              'Enter a ${r.register.name} rate for the alternative tariff.',
            );
          }
          return r.copyWith(unitRateMilliPence: rate);
        }).toList();
      }
      return p.copyWith(
        standingChargeMilliPencePerDay: rates.standingChargeMilliPencePerDay,
        registers: regs,
      );
    }).toList();
    final alt = bill.copyWith(
      ratePeriods: periods,
      ratesIncludeVat: rates.ratesIncludeVat,
      clearStatedTotal: true,
    );
    return WhatIfResult(
      actual: calculator.calculate(bill),
      alternative: calculator.calculate(alt),
      alternativeBill: alt,
    );
  }

  /// What [result] would have cost at [baseline]'s prices (last rate period
  /// of the baseline). Used to verify tariff actions on the next bill.
  WhatIfResult atBaselinePrices(Bill result, Bill baseline) {
    final last = baseline.ratePeriods.last;
    final rates = <Register, int>{
      for (final r in last.registers) r.register: r.unitRateMilliPence,
    };
    final resultRegisters = result.ratePeriods
        .expand((p) => p.registers)
        .map((r) => r.register)
        .toSet();
    if (!resultRegisters.every(rates.containsKey)) {
      // Different meter type: fall back to the baseline's average ex-VAT
      // price per kWh, and express the standing charge ex-VAT too.
      final calc = calculator.calculate(baseline);
      final avg = calc.kwhMilli == 0
          ? 0
          : divRoundHalfAwayFromZero(calc.energyPence * 1000000, calc.kwhMilli);
      final standingExVat = baseline.ratesIncludeVat
          ? divRoundHalfAwayFromZero(
              last.standingChargeMilliPencePerDay * 10000,
              10000 + last.vatBasisPoints,
            )
          : last.standingChargeMilliPencePerDay;
      return reprice(
        result,
        AlternativeRates(
          standingChargeMilliPencePerDay: standingExVat,
          unitRatesMilliPence: {Register.single: avg},
        ),
      );
    }
    return reprice(
      result,
      AlternativeRates(
        standingChargeMilliPencePerDay: last.standingChargeMilliPencePerDay,
        unitRatesMilliPence: rates,
        ratesIncludeVat: baseline.ratesIncludeVat,
      ),
    );
  }
}
