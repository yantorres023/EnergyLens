import 'calculator.dart';
import 'dates.dart';
import 'fixed_point.dart';
import 'models.dart';

/// The causes a bill change is split into.
enum EffectType {
  /// More/fewer days in the billing period at the same daily usage.
  periodLength,

  /// Using more or less electricity per day.
  dailyUsage,

  /// Unit price per kWh changed.
  unitRate,

  /// Daily standing charge changed.
  standingCharge,

  /// VAT rate changed (e.g. 5% → 0% on 1 October 2026).
  vatRate,

  /// Credits, discounts, fees or corrections differ.
  adjustments,
}

class ChangeEffect {
  const ChangeEffect(this.type, this.amountPence);
  final EffectType type;

  /// Positive = pushed the bill up. VAT on this effect is included.
  final int amountPence;
}

enum ComparisonCaveat {
  /// Bills fall in different seasons — usage naturally differs.
  differentSeasons,

  /// One of the bills used an estimated meter reading.
  estimatedReading,

  /// The bills are not consecutive.
  gapBetweenBills,

  /// The bills overlap in time.
  overlappingPeriods,

  /// One bill is Economy 7 and the other single-rate; unit-rate effect
  /// includes the change in when electricity was used.
  meterTypeChanged,

  /// A bill does not reconcile with its printed total.
  reconciliationMismatch,
}

/// Explains the difference between two bills.
///
/// Method: the change is split algebraically so that the effects **sum
/// exactly** to the difference in totals (each effect is rounded to the
/// penny and any rounding residual is assigned to the largest effect):
///
/// * standing = (d1−d0)·s0 [periodLength] + d1·(s1−s0) [standingCharge]
/// * energy per register r = (d1−d0)·(k0/d0)·u0 [periodLength]
///   + (k1/d1 − k0/d0)·d1·u0 [dailyUsage] + k1·(u1−u0) [unitRate]
/// * VAT: v0 = VAT0/net0. The change in net is grossed up by (1+v0) and
///   spread over the effects above; VAT1 − net1·v0 is the [vatRate] effect.
/// * adjustments = adj1 − adj0.
///
/// s = ex-VAT standing charge per day, k = kWh, u = ex-VAT price per kWh,
/// d = days. All inputs come from [BillCalculation]; the split is an
/// attribution (CALCULATED), the totals are exact.
class BillComparison {
  BillComparison._({
    required this.previous,
    required this.current,
    required this.previousCalc,
    required this.currentCalc,
    required this.effects,
    required this.caveats,
  });

  final Bill previous;
  final Bill current;
  final BillCalculation previousCalc;
  final BillCalculation currentCalc;

  /// Sorted by absolute size, largest first. Zero effects are omitted.
  final List<ChangeEffect> effects;
  final Set<ComparisonCaveat> caveats;

  int get differencePence => currentCalc.totalPence - previousCalc.totalPence;

  /// Percentage change ×10 (e.g. 125 = 12.5%). Null if previous total ≤ 0.
  int? get differencePerMille => previousCalc.totalPence <= 0
      ? null
      : divRoundHalfAwayFromZero(
          differencePence * 1000,
          previousCalc.totalPence,
        );

  int get costPerDayChangeMilliPence =>
      currentCalc.costPerDayMilliPence - previousCalc.costPerDayMilliPence;

  int get kwhPerDayChangeMilli =>
      currentCalc.kwhPerDayMilli - previousCalc.kwhPerDayMilli;

  ChangeEffect? get mainDriver => effects.isEmpty ? null : effects.first;

  int effect(EffectType t) {
    for (final e in effects) {
      if (e.type == t) return e.amountPence;
    }
    return 0;
  }

  static BillComparison compare(
    Bill previous,
    Bill current, {
    BillCalculator calculator = const BillCalculator(),
  }) {
    final c0 = calculator.calculate(previous);
    final c1 = calculator.calculate(current);
    return fromCalculations(previous, current, c0, c1);
  }

  static BillComparison fromCalculations(
    Bill previous,
    Bill current,
    BillCalculation c0,
    BillCalculation c1,
  ) {
    final d0 = c0.days.toDouble();
    final d1 = c1.days.toDouble();
    if (d0 <= 0 || d1 <= 0) {
      throw ValidationError('Both bills need at least one day.');
    }

    final caveats = <ComparisonCaveat>{};
    final sameRegisters =
        c0.kwhMilliByRegister.keys.toSet().containsAll(
          c1.kwhMilliByRegister.keys,
        ) &&
        c1.kwhMilliByRegister.keys.toSet().containsAll(
          c0.kwhMilliByRegister.keys,
        );
    if (!sameRegisters) caveats.add(ComparisonCaveat.meterTypeChanged);

    // Per-register (or aggregated) kWh and ex-VAT energy cost.
    Map<String, List<double>> buckets(BillCalculation c) {
      if (sameRegisters) {
        return {
          for (final r in c.kwhMilliByRegister.keys)
            r.name: [
              c.kwhMilliByRegister[r]! / milli,
              (c.energyPenceByRegister[r] ?? 0).toDouble(),
            ],
        };
      }
      return {
        'all': [c.kwhMilli / milli, c.energyPence.toDouble()],
      };
    }

    final b0 = buckets(c0);
    final b1 = buckets(c1);
    final keys = {...b0.keys, ...b1.keys};

    var periodLength = 0.0;
    var dailyUsage = 0.0;
    var unitRate = 0.0;
    for (final key in keys) {
      final k0 = b0[key]?[0] ?? 0.0;
      final e0 = b0[key]?[1] ?? 0.0;
      final k1 = b1[key]?[0] ?? 0.0;
      final e1 = b1[key]?[1] ?? 0.0;
      // Price per kWh: if a bill had no usage on this register, borrow the
      // other bill's price so the whole change is usage, not price.
      final u1 = k1 > 0 ? e1 / k1 : (k0 > 0 ? e0 / k0 : 0.0);
      final u0 = k0 > 0 ? e0 / k0 : u1;
      periodLength += (d1 - d0) * (k0 / d0) * u0;
      dailyUsage += (k1 / d1 - k0 / d0) * d1 * u0;
      // Anything the kWh×price model doesn't capture (rounding) lands here so
      // the energy effects sum to e1 − e0.
      unitRate += (e1 - e0) - ((k1 - k0) * u0);
    }

    final s0 = c0.standingPence / d0;
    final s1 = c1.standingPence / d1;
    periodLength += (d1 - d0) * s0;
    final standingCharge = d1 * (s1 - s0);
    // Close standing to exact integer difference.
    final standingResidual =
        (c1.standingPence - c0.standingPence) -
        ((d1 - d0) * s0 + standingCharge);

    final v0 = c0.netPence == 0 ? 0.0 : c0.vatPence / c0.netPence;
    final gross = 1 + v0;
    final vatRate = c1.vatPence - c1.netPence * v0;

    final raw = <EffectType, double>{
      EffectType.periodLength: periodLength * gross,
      EffectType.dailyUsage: dailyUsage * gross,
      EffectType.unitRate: unitRate * gross,
      EffectType.standingCharge: (standingCharge + standingResidual) * gross,
      EffectType.vatRate: vatRate,
      EffectType.adjustments: (c1.adjustmentsPence - c0.adjustmentsPence)
          .toDouble(),
    };

    final target = c1.totalPence - c0.totalPence;
    final rounded = <EffectType, int>{
      for (final e in raw.entries) e.key: e.value.round(),
    };
    final residual = target - rounded.values.fold<int>(0, (s, v) => s + v);
    if (residual != 0) {
      // Give the rounding residual to the largest effect.
      final largest = rounded.entries.reduce(
        (a, b) => raw[a.key]!.abs() >= raw[b.key]!.abs() ? a : b,
      );
      rounded[largest.key] = largest.value + residual;
    }

    final effects =
        rounded.entries
            .where((e) => e.value != 0)
            .map((e) => ChangeEffect(e.key, e.value))
            .toList()
          ..sort((a, b) => b.amountPence.abs().compareTo(a.amountPence.abs()));

    if (seasonOf(midpoint(previous.periodStart, previous.periodEnd)) !=
        seasonOf(midpoint(current.periodStart, current.periodEnd))) {
      caveats.add(ComparisonCaveat.differentSeasons);
    }
    if (previous.usageIsEstimated || current.usageIsEstimated) {
      caveats.add(ComparisonCaveat.estimatedReading);
    }
    final gap = dateOnly(
      current.periodStart,
    ).difference(dateOnly(previous.periodEnd)).inDays;
    if (gap > 1) caveats.add(ComparisonCaveat.gapBetweenBills);
    if (gap < 1) caveats.add(ComparisonCaveat.overlappingPeriods);
    if (c0.reconciliation == ReconciliationStatus.mismatch ||
        c1.reconciliation == ReconciliationStatus.mismatch) {
      caveats.add(ComparisonCaveat.reconciliationMismatch);
    }

    return BillComparison._(
      previous: previous,
      current: current,
      previousCalc: c0,
      currentCalc: c1,
      effects: effects,
      caveats: caveats,
    );
  }
}
