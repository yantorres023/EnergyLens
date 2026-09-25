import 'dates.dart';
import 'fixed_point.dart';
import 'models.dart';

enum LineKind { standingCharge, energy, vat, adjustment }

/// One calculated line of a bill.
class CalcLine {
  const CalcLine({
    required this.kind,
    required this.label,
    required this.amountPence,
    this.periodIndex,
    this.register,
    this.quantityMilli,
    this.rateMilliPence,
  });

  final LineKind kind;
  final String label;
  final int amountPence;
  final int? periodIndex;
  final Register? register;

  /// Days × 1000 for standing charge lines, milli-kWh for energy lines.
  final int? quantityMilli;
  final int? rateMilliPence;
}

enum ReconciliationStatus { matches, mismatch, noStatedTotal }

enum CalcWarning {
  ratePeriodsOverlap,
  ratePeriodsHaveGap,
  endBeforeStart,
  negativeUsage,
  negativeRate,
  vatOutOfRange,
  noUsageRecorded,
  estimatedReading,
  veryHighUsage,
}

class ValidationError implements Exception {
  ValidationError(this.message);
  final String message;
  @override
  String toString() => 'ValidationError: $message';
}

/// Result of recomputing a bill. Every amount is CALCULATED from the user's
/// inputs; nothing here is fetched or guessed.
class BillCalculation {
  const BillCalculation({
    required this.lines,
    required this.days,
    required this.kwhMilli,
    required this.kwhMilliByRegister,
    required this.energyPenceByRegister,
    required this.standingPence,
    required this.energyPence,
    required this.netPence,
    required this.vatPence,
    required this.adjustmentsPence,
    required this.totalPence,
    required this.reconciliation,
    required this.reconciliationDifferencePence,
    required this.warnings,
  });

  final List<CalcLine> lines;
  final int days;
  final int kwhMilli;
  final Map<Register, int> kwhMilliByRegister;

  /// Energy cost per register, **excluding VAT**.
  final Map<Register, int> energyPenceByRegister;

  /// Standing charges, excluding VAT.
  final int standingPence;

  /// Energy charges, excluding VAT.
  final int energyPence;

  /// standing + energy, excluding VAT and adjustments.
  final int netPence;
  final int vatPence;
  final int adjustmentsPence;
  final int totalPence;
  final ReconciliationStatus reconciliation;

  /// calculated total − stated total (null if nothing stated).
  final int? reconciliationDifferencePence;
  final Set<CalcWarning> warnings;

  /// Total cost per day, pence ×1000 (for display with decimals).
  int get costPerDayMilliPence =>
      days == 0 ? 0 : divRoundHalfAwayFromZero(totalPence * milli, days);

  /// Average kWh per day, milli-kWh.
  int get kwhPerDayMilli =>
      days == 0 ? 0 : divRoundHalfAwayFromZero(kwhMilli, days);

  /// Share of consumption on the night register, in per-mille (0–1000).
  int? get nightSharePermille {
    final night = kwhMilliByRegister[Register.night];
    if (night == null || kwhMilli == 0) return null;
    return divRoundHalfAwayFromZero(night * 1000, kwhMilli);
  }

  /// Standing charge incl. its VAT as a share of the total, per-mille.
  int get standingSharePermille {
    if (totalPence <= 0) return 0;
    final grossStanding = netPence == 0
        ? standingPence
        : standingPence + divRoundHalfAwayFromZero(vatPence * standingPence, netPence);
    return divRoundHalfAwayFromZero(grossStanding * 1000, totalPence);
  }
}

class BillCalculator {
  const BillCalculator({this.reconciliationTolerancePence = 5});

  /// Allowed |calculated − stated| before flagging a mismatch. Suppliers
  /// round per line and per rate period differently; 5p absorbs that.
  final int reconciliationTolerancePence;

  /// Anything above this many kWh/day is flagged for a double-check (a typing
  /// slip such as 3000 instead of 300 is far more common than a 100 kWh/day
  /// home). The bill is still calculated.
  static const int veryHighKwhPerDayMilli = 100 * milli;

  BillCalculation calculate(Bill bill) {
    if (bill.ratePeriods.isEmpty) {
      throw ValidationError('A bill needs at least one rate period.');
    }
    final warnings = <CalcWarning>{};
    final periods = [...bill.ratePeriods]
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      if (dateOnly(p.end).isBefore(dateOnly(p.start))) {
        throw ValidationError('A rate period ends before it starts.');
      }
      if (p.vatBasisPoints < 0 || p.vatBasisPoints > 2000) {
        warnings.add(CalcWarning.vatOutOfRange);
      }
      if (p.standingChargeMilliPencePerDay < 0) {
        warnings.add(CalcWarning.negativeRate);
      }
      for (final r in p.registers) {
        if (r.kwhMilli < 0) warnings.add(CalcWarning.negativeUsage);
        if (r.unitRateMilliPence < 0) warnings.add(CalcWarning.negativeRate);
      }
      if (i > 0) {
        final prevEnd = dateOnly(periods[i - 1].end);
        final start = dateOnly(p.start);
        if (!start.isAfter(prevEnd)) {
          warnings.add(CalcWarning.ratePeriodsOverlap);
        } else if (start.difference(prevEnd).inDays > 1) {
          warnings.add(CalcWarning.ratePeriodsHaveGap);
        }
      }
    }

    final lines = <CalcLine>[];
    final kwhByRegister = <Register, int>{};
    final energyByRegister = <Register, int>{};
    var standing = 0;
    var energy = 0;
    var vat = 0;
    var days = 0;
    final multi = periods.length > 1;

    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      final d = p.days;
      days += d;
      final suffix = multi ? ' (${isoDate(p.start)} to ${isoDate(p.end)})' : '';

      final standingLine = costPence(d * milli, p.standingChargeMilliPencePerDay);
      lines.add(
        CalcLine(
          kind: LineKind.standingCharge,
          label: 'Standing charge$suffix',
          amountPence: standingLine,
          periodIndex: i,
          quantityMilli: d * milli,
          rateMilliPence: p.standingChargeMilliPencePerDay,
        ),
      );
      var periodGross = standingLine;

      for (final r in p.registers) {
        final amount = costPence(r.kwhMilli, r.unitRateMilliPence);
        periodGross += amount;
        kwhByRegister[r.register] = (kwhByRegister[r.register] ?? 0) + r.kwhMilli;
        lines.add(
          CalcLine(
            kind: LineKind.energy,
            label: '${_registerLabel(r.register)}$suffix',
            amountPence: amount,
            periodIndex: i,
            register: r.register,
            quantityMilli: r.kwhMilli,
            rateMilliPence: r.unitRateMilliPence,
          ),
        );
      }

      // VAT per rate period, because the VAT rate itself can change at a
      // period boundary (e.g. 5% → 0% on 1 October 2026).
      int periodVat;
      int periodNetStanding;
      final netByRegister = <Register, int>{};
      if (bill.ratesIncludeVat) {
        final periodNet = divRoundHalfAwayFromZero(
          periodGross * 10000,
          10000 + p.vatBasisPoints,
        );
        periodVat = periodGross - periodNet;
        // Split the ex-VAT amount back to its lines proportionally; the
        // largest line absorbs the rounding so the parts sum exactly.
        periodNetStanding = periodGross == 0
            ? 0
            : divRoundHalfAwayFromZero(standingLine * periodNet, periodGross);
        var allocated = periodNetStanding;
        final regs = p.registers;
        for (var k = 0; k < regs.length; k++) {
          final gross = costPence(regs[k].kwhMilli, regs[k].unitRateMilliPence);
          final share = periodGross == 0
              ? 0
              : divRoundHalfAwayFromZero(gross * periodNet, periodGross);
          netByRegister[regs[k].register] =
              (netByRegister[regs[k].register] ?? 0) + share;
          allocated += share;
        }
        final residual = periodNet - allocated;
        if (residual != 0) {
          if (regs.isEmpty) {
            periodNetStanding += residual;
          } else {
            final key = regs.first.register;
            netByRegister[key] = netByRegister[key]! + residual;
          }
        }
      } else {
        periodVat = divRoundHalfAwayFromZero(
          periodGross * p.vatBasisPoints,
          10000,
        );
        periodNetStanding = standingLine;
        for (final r in p.registers) {
          netByRegister[r.register] =
              (netByRegister[r.register] ?? 0) +
              costPence(r.kwhMilli, r.unitRateMilliPence);
        }
      }
      standing += periodNetStanding;
      netByRegister.forEach((k, v) {
        energyByRegister[k] = (energyByRegister[k] ?? 0) + v;
        energy += v;
      });
      vat += periodVat;
      if (periodVat != 0 || !bill.ratesIncludeVat) {
        lines.add(
          CalcLine(
            kind: LineKind.vat,
            label: bill.ratesIncludeVat
                ? 'VAT included above at ${_pct(p.vatBasisPoints)}$suffix'
                : 'VAT at ${_pct(p.vatBasisPoints)}$suffix',
            amountPence: periodVat,
            periodIndex: i,
            rateMilliPence: p.vatBasisPoints,
          ),
        );
      }
    }

    var adjustments = 0;
    for (final a in bill.adjustments) {
      adjustments += a.amountPence;
      lines.add(
        CalcLine(
          kind: LineKind.adjustment,
          label: a.label,
          amountPence: a.amountPence,
        ),
      );
    }

    final kwh = kwhByRegister.values.fold(0, (s, v) => s + v);
    if (kwh == 0) warnings.add(CalcWarning.noUsageRecorded);
    if (bill.usageIsEstimated) warnings.add(CalcWarning.estimatedReading);
    if (days > 0 && kwh > veryHighKwhPerDayMilli * days) {
      warnings.add(CalcWarning.veryHighUsage);
    }

    final net = standing + energy;
    final total = net + vat + adjustments;

    ReconciliationStatus status;
    int? diff;
    if (bill.statedTotalPence == null) {
      status = ReconciliationStatus.noStatedTotal;
    } else {
      diff = total - bill.statedTotalPence!;
      status = diff.abs() <= reconciliationTolerancePence
          ? ReconciliationStatus.matches
          : ReconciliationStatus.mismatch;
    }

    return BillCalculation(
      lines: lines,
      days: days,
      kwhMilli: kwh,
      kwhMilliByRegister: kwhByRegister,
      energyPenceByRegister: energyByRegister,
      standingPence: standing,
      energyPence: energy,
      netPence: net,
      vatPence: vat,
      adjustmentsPence: adjustments,
      totalPence: total,
      reconciliation: status,
      reconciliationDifferencePence: diff,
      warnings: warnings,
    );
  }

  static String _registerLabel(Register r) {
    switch (r) {
      case Register.single:
        return 'Electricity used';
      case Register.day:
        return 'Day-rate electricity';
      case Register.night:
        return 'Night-rate electricity';
    }
  }

  static String _pct(int basisPoints) {
    final whole = basisPoints ~/ 100;
    final frac = basisPoints % 100;
    if (frac == 0) return '$whole%';
    return '$whole.${frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}%';
  }
}

/// Consumption from two meter readings, handling a meter that rolled over
/// (e.g. 99,950 → 00,120 on a 5-digit meter).
class MeterConsumption {
  /// Returns consumption in milli-kWh.
  ///
  /// When [endMilli] < [startMilli] the meter is assumed to have rolled over
  /// only if [rolloverDigits] is given; otherwise an error is thrown, because
  /// a lower reading more often means a typo, a meter exchange or a
  /// corrected estimate.
  static int fromReadings({
    required int startMilli,
    required int endMilli,
    int? rolloverDigits,
  }) {
    if (startMilli < 0 || endMilli < 0) {
      throw ValidationError('Meter readings cannot be negative.');
    }
    if (endMilli >= startMilli) return endMilli - startMilli;
    if (rolloverDigits == null) {
      throw ValidationError(
        'The closing reading is lower than the opening reading. If the meter '
        'went past its maximum and restarted from zero, confirm the number of '
        'digits on the meter; otherwise check the readings.',
      );
    }
    if (rolloverDigits < 4 || rolloverDigits > 8) {
      throw ValidationError('Unexpected number of meter digits.');
    }
    var max = 1;
    for (var i = 0; i < rolloverDigits; i++) {
      max *= 10;
    }
    final maxMilli = max * milli;
    if (startMilli >= maxMilli || endMilli >= maxMilli) {
      throw ValidationError('Reading has more digits than the meter.');
    }
    return (maxMilli - startMilli) + endMilli;
  }
}
