import 'calculator.dart';
import 'comparison.dart';
import 'fixed_point.dart';
import 'models.dart';
import 'tariff_reference.dart';

enum InsightKind {
  reconciliationMismatch,
  mainDriver,
  vatChange,
  estimatedReading,
  standingChargeShare,
  dailyUsageUp,
  unitRateUp,
  economy7Split,
  capChangePreview,
}

enum Confidence { high, medium, low }

/// A finding tied to a calculation. Insights carry the numbers they are
/// based on; the UI renders text from them. No insight promises savings.
class Insight {
  const Insight({
    required this.kind,
    required this.provenance,
    required this.confidence,
    this.amountPence,
    this.valueMilli,
    this.secondaryMilli,
    this.effect,
    this.suggestedAction,
    this.referenceVersion,
  });

  final InsightKind kind;
  final Provenance provenance;
  final Confidence confidence;
  final int? amountPence;
  final int? valueMilli;
  final int? secondaryMilli;
  final EffectType? effect;
  final ActionType? suggestedAction;
  final TariffVersion? referenceVersion;
}

class InsightEngine {
  const InsightEngine({this.calculator = const BillCalculator()});
  final BillCalculator calculator;

  /// Insights for [current] (optionally compared to [previous]).
  /// [reference] is the bundled cap dataset; it is only used when not stale
  /// on [today], and only for clearly-labelled ESTIMATED previews.
  List<Insight> build({
    required Bill current,
    Bill? previous,
    required Household household,
    TariffDataset? reference,
    required DateTime today,
  }) {
    final c = calculator.calculate(current);
    final out = <Insight>[];

    if (c.reconciliation == ReconciliationStatus.mismatch) {
      out.add(
        Insight(
          kind: InsightKind.reconciliationMismatch,
          provenance: Provenance.calculated,
          confidence: Confidence.high,
          amountPence: c.reconciliationDifferencePence,
        ),
      );
    }

    if (current.usageIsEstimated) {
      out.add(
        const Insight(
          kind: InsightKind.estimatedReading,
          provenance: Provenance.estimated,
          confidence: Confidence.high,
          suggestedAction: ActionType.submitMeterReading,
        ),
      );
    }

    BillComparison? cmp;
    if (previous != null) {
      cmp = BillComparison.fromCalculations(
        previous,
        current,
        calculator.calculate(previous),
        c,
      );
      final main = cmp.mainDriver;
      if (main != null) {
        out.add(
          Insight(
            kind: InsightKind.mainDriver,
            provenance: Provenance.calculated,
            confidence: cmp.caveats.isEmpty ? Confidence.high : Confidence.medium,
            amountPence: main.amountPence,
            effect: main.type,
            suggestedAction: _actionForEffect(main.type, current, household),
          ),
        );
      }
      final vat = cmp.effect(EffectType.vatRate);
      if (vat != 0 && main?.type != EffectType.vatRate) {
        out.add(
          Insight(
            kind: InsightKind.vatChange,
            provenance: Provenance.calculated,
            confidence: Confidence.high,
            amountPence: vat,
            effect: EffectType.vatRate,
          ),
        );
      }
      final p0 = cmp.previousCalc.kwhPerDayMilli;
      final p1 = c.kwhPerDayMilli;
      // ≥10% more per day.
      if (p0 > 0 && (p1 - p0) * 10 >= p0 && main?.type != EffectType.dailyUsage) {
        out.add(
          Insight(
            kind: InsightKind.dailyUsageUp,
            provenance: current.usageIsEstimated || previous.usageIsEstimated
                ? Provenance.estimated
                : Provenance.calculated,
            confidence: cmp.caveats.contains(ComparisonCaveat.differentSeasons)
                ? Confidence.low
                : Confidence.medium,
            valueMilli: p0,
            secondaryMilli: p1,
            amountPence: cmp.effect(EffectType.dailyUsage),
            suggestedAction: ActionType.reduceDailyUsage,
          ),
        );
      }
      final rate = cmp.effect(EffectType.unitRate);
      if (rate > 0 && main?.type != EffectType.unitRate) {
        out.add(
          Insight(
            kind: InsightKind.unitRateUp,
            provenance: Provenance.calculated,
            confidence: Confidence.high,
            amountPence: rate,
            suggestedAction: ActionType.checkTariffQuote,
          ),
        );
      }
    }

    // Fixed-charge awareness: the part of the bill usage can't change.
    final share = c.standingSharePermille;
    if (share >= 150) {
      out.add(
        Insight(
          kind: InsightKind.standingChargeShare,
          provenance: Provenance.calculated,
          confidence: Confidence.high,
          valueMilli: share,
          amountPence: c.standingPence +
              (c.netPence == 0
                  ? 0
                  : divRoundHalfAwayFromZero(
                      c.vatPence * c.standingPence,
                      c.netPence,
                    )),
        ),
      );
    }

    final e7 = _economy7(current, c, reference, today);
    if (e7 != null) out.add(e7);

    final preview = _capPreview(current, c, household, reference, today);
    if (preview != null) out.add(preview);

    return out;
  }

  ActionType? _actionForEffect(
    EffectType t,
    Bill current,
    Household household,
  ) {
    switch (t) {
      case EffectType.dailyUsage:
        return current.usageIsEstimated
            ? ActionType.submitMeterReading
            : ActionType.reduceDailyUsage;
      case EffectType.unitRate:
      case EffectType.standingCharge:
        return ActionType.checkTariffQuote;
      case EffectType.periodLength:
      case EffectType.vatRate:
      case EffectType.adjustments:
        return household.paymentMethod == PaymentMethod.directDebit &&
                household.directDebitMonthlyPence != null
            ? ActionType.reviewDirectDebit
            : null;
    }
  }

  /// Economy 7 break-even: the night share at which the user's day/night
  /// rates cost the same as the GB-average single rate for the period.
  /// ESTIMATED (regional single rates differ from the average).
  Insight? _economy7(
    Bill bill,
    BillCalculation c,
    TariffDataset? reference,
    DateTime today,
  ) {
    final night = c.nightSharePermille;
    if (night == null) return null;
    final p = bill.ratePeriods.last;
    int? dayRate;
    int? nightRate;
    for (final r in p.registers) {
      if (r.register == Register.day) dayRate = r.unitRateMilliPence;
      if (r.register == Register.night) nightRate = r.unitRateMilliPence;
    }
    if (dayRate == null || nightRate == null || dayRate <= nightRate) {
      return null;
    }
    int? breakEven;
    TariffVersion? ref;
    if (reference != null && !reference.isStale(today)) {
      ref = reference.versionFor(bill.periodEnd);
      if (ref != null) {
        // Compare like with like: convert the reference to the bill's VAT
        // convention.
        final single = bill.ratesIncludeVat
            ? ref.singleRateMilliPence
            : ref.unitRateExVatMilliPence;
        if (single < dayRate) {
          // share* = (day − single) / (day − night), per-mille.
          breakEven = divRoundHalfAwayFromZero(
            (dayRate - single) * 1000,
            dayRate - nightRate,
          );
        }
      }
    }
    return Insight(
      kind: InsightKind.economy7Split,
      provenance: breakEven == null ? Provenance.calculated : Provenance.estimated,
      confidence: breakEven == null ? Confidence.high : Confidence.low,
      valueMilli: night,
      secondaryMilli: breakEven,
      referenceVersion: ref,
      suggestedAction: ActionType.shiftToNight,
    );
  }

  /// "If your prices move like the GB-average cap on <date>…" — ESTIMATED.
  /// Only for standard variable tariffs and only with fresh reference data.
  Insight? _capPreview(
    Bill bill,
    BillCalculation c,
    Household household,
    TariffDataset? reference,
    DateTime today,
  ) {
    if (household.tariffKind != TariffKind.standardVariable) return null;
    if (reference == null || reference.isStale(today)) return null;
    final now = reference.versionFor(bill.periodEnd);
    final next = reference.nextVersionAfter(bill.periodEnd);
    if (now == null || next == null) return null;
    if (c.days == 0) return null;

    // Scale the user's own ex-VAT prices by the GB-average ex-VAT change,
    // then apply the next period's VAT. Deterministic, but an estimate.
    final unitNow = now.unitRateExVatMilliPence;
    final unitNext = next.unitRateExVatMilliPence;
    final standNow = now.standingExVatMilliPencePerDay;
    final standNext = next.standingExVatMilliPencePerDay;
    if (unitNow == 0 || standNow == 0) return null;

    final energyNext = divRoundHalfAwayFromZero(c.energyPence * unitNext, unitNow);
    final standingNext = divRoundHalfAwayFromZero(
      c.standingPence * standNext,
      standNow,
    );
    final netNext = energyNext + standingNext;
    final vatNext = divRoundHalfAwayFromZero(netNext * next.vatBasisPoints, 10000);
    final totalNext = netNext + vatNext;
    final currentGross = c.netPence + c.vatPence;
    return Insight(
      kind: InsightKind.capChangePreview,
      provenance: Provenance.estimated,
      confidence: Confidence.low,
      amountPence: totalNext - currentGross,
      valueMilli: totalNext,
      referenceVersion: next,
    );
  }
}
