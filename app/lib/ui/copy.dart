import '../domain/calculator.dart';
import '../domain/comparison.dart';
import '../domain/fixed_point.dart';
import '../domain/insights.dart';
import '../domain/models.dart';
import 'format.dart';

/// All user-facing explanation text lives here so it can be reviewed for
/// claims (no guarantees, estimates labelled) and later localised.
class Copy {
  static String provenance(Provenance p) => switch (p) {
    Provenance.measured => 'Meter reading',
    Provenance.parsed => 'From pasted text',
    Provenance.userEntered => 'You entered',
    Provenance.calculated => 'Calculated',
    Provenance.estimated => 'Estimate',
  };

  static String confidence(Confidence c) => switch (c) {
    Confidence.high => 'High confidence',
    Confidence.medium => 'Medium confidence',
    Confidence.low => 'Low confidence',
  };

  static String readingType(ReadingType t) => switch (t) {
    ReadingType.actual => 'Actual reading',
    ReadingType.smart => 'Smart meter reading',
    ReadingType.customer => 'Your own reading',
    ReadingType.estimated => 'Estimated reading',
    ReadingType.unknown => 'Not sure',
  };

  static String tariffKind(TariffKind k) => switch (k) {
    TariffKind.standardVariable => 'Standard variable (price-capped)',
    TariffKind.fixed => 'Fixed',
    TariffKind.unknown => 'Not sure',
  };

  static String paymentMethod(PaymentMethod p) => switch (p) {
    PaymentMethod.directDebit => 'Direct Debit',
    PaymentMethod.onReceiptOfBill => 'Pay when I get a bill',
    PaymentMethod.other => 'Other',
  };

  static String meterType(MeterType m) => switch (m) {
    MeterType.singleRate => 'Single rate',
    MeterType.economy7 => 'Economy 7 (day & night rates)',
  };

  static String outcome(ExperimentOutcome o) => switch (o) {
    ExperimentOutcome.improved => 'Improved',
    ExperimentOutcome.noClearChange => 'No clear change',
    ExperimentOutcome.worse => 'Went the other way',
    ExperimentOutcome.inconclusive => 'Can\'t tell yet',
  };

  /// Short label for a change effect, using both bills' figures.
  static String effectLabel(EffectType t, BillComparison c) {
    final p = c.previousCalc;
    final n = c.currentCalc;
    switch (t) {
      case EffectType.periodLength:
        final diff = n.days - p.days;
        final dir = diff > 0 ? 'longer' : 'shorter';
        return 'Billing period ${diff.abs()} day${diff.abs() == 1 ? '' : 's'} $dir';
      case EffectType.dailyUsage:
        final dir = n.kwhPerDayMilli >= p.kwhPerDayMilli ? 'more' : 'less';
        return 'Used $dir per day (${kwh(p.kwhPerDayMilli)} to ${kwh(n.kwhPerDayMilli)})';
      case EffectType.unitRate:
        final up = c.effect(EffectType.unitRate) > 0;
        final range = p.kwhMilli > 0 && n.kwhMilli > 0
            ? ' (${pence(_avgRate(p))} to ${pence(_avgRate(n))} before VAT)'
            : '';
        return '${up ? 'Higher' : 'Lower'} price per kWh$range';
      case EffectType.standingCharge:
        final up = c.effect(EffectType.standingCharge) > 0;
        return '${up ? 'Higher' : 'Lower'} daily standing charge '
            '(${pence(_perDay(p))} to ${pence(_perDay(n))} before VAT)';
      case EffectType.vatRate:
        return 'VAT rate changed (${percentFromBasisPoints(_vatBp(p))} to '
            '${percentFromBasisPoints(_vatBp(n))})';
      case EffectType.adjustments:
        return 'Credits and one-off charges';
    }
  }

  static int _avgRate(BillCalculation c) =>
      divRoundHalfAwayFromZero(c.energyPence * 1000000, c.kwhMilli);

  static int _perDay(BillCalculation c) =>
      divRoundHalfAwayFromZero(c.standingPence * 1000, c.days);

  /// Effective VAT rate, rounded to whole percent in basis points.
  static int _vatBp(BillCalculation c) => c.netPence == 0
      ? 0
      : divRoundHalfAwayFromZero(c.vatPence * 100, c.netPence) * 100;

  static String effectExplanation(EffectType t) => switch (t) {
    EffectType.periodLength =>
      'Bills cover different numbers of days. More days means more standing '
          'charge and, at the same daily usage, more electricity.',
    EffectType.dailyUsage =>
      'How much electricity you used per day. Season and weather change '
          'this a lot, so it is not proof that anything went wrong.',
    EffectType.unitRate =>
      'The price per kWh (excluding VAT). On a standard variable tariff this '
          'follows the Ofgem price cap, which changes every quarter. On '
          'Economy 7 it also reflects when you used electricity.',
    EffectType.standingCharge =>
      'The fixed daily charge you pay whatever you use.',
    EffectType.vatRate =>
      'VAT on domestic electricity in Great Britain is 0% from 1 October '
          '2026 to 31 March 2027 (previously 5%).',
    EffectType.adjustments =>
      'Credits (e.g. Warm Home Discount), discounts, fees and corrections '
          'printed on the bill.',
  };

  static String caveat(ComparisonCaveat c) => switch (c) {
    ComparisonCaveat.differentSeasons =>
      'The bills are in different seasons. Heating and lighting needs differ, '
          'so usage changes may be seasonal.',
    ComparisonCaveat.estimatedReading =>
      'At least one bill used an estimated reading, so usage figures may be '
          'corrected later.',
    ComparisonCaveat.gapBetweenBills =>
      'There is a gap between these bills. A bill may be missing.',
    ComparisonCaveat.overlappingPeriods =>
      'These bills overlap in time. One may be a corrected re-bill.',
    ComparisonCaveat.meterTypeChanged =>
      'One bill is Economy 7 and the other single-rate. The price effect '
          'includes the change in when you used electricity.',
    ComparisonCaveat.reconciliationMismatch =>
      'A bill\'s calculated total doesn\'t match the total printed on it. '
          'Check that bill\'s values first.',
  };

  /// Title and body for an insight. [comparison] is passed when available.
  static (String, String) insight(Insight i, {BillComparison? comparison}) {
    switch (i.kind) {
      case InsightKind.reconciliationMismatch:
        final diff = i.amountPence ?? 0;
        return (
          'These numbers don\'t match your bill',
          'From the values entered we calculate ${money(diff.abs())} '
              '${diff > 0 ? 'more' : 'less'} than the total printed on your bill. '
              'A value may be mistyped, or the bill includes a charge EnergyLens '
              'doesn\'t model yet. Check the rates, kWh and dates.',
        );
      case InsightKind.mainDriver:
        final amount = i.amountPence ?? 0;
        final label = comparison == null
            ? 'Biggest change'
            : effectLabel(i.effect!, comparison);
        return (
          'Main reason: $label',
          '${amount > 0 ? 'Added' : 'Saved'} ${money(amount.abs())} compared with '
              'your previous bill. ${effectExplanation(i.effect!)}',
        );
      case InsightKind.vatChange:
        final amount = i.amountPence ?? 0;
        return (
          'VAT change: ${money(amount, signed: true)}',
          '${effectExplanation(EffectType.vatRate)} The 0% rate is temporary; '
              'unless it is extended, VAT is due to return to 5% on 1 April 2027.',
        );
      case InsightKind.estimatedReading:
        return (
          'This bill used an estimated reading',
          'Your supplier estimated your usage, so the real figure could be '
              'higher or lower and a later bill may correct it. Sending a meter '
              'reading makes the next bill accurate. Under Ofgem\'s back-billing '
              'rules, suppliers generally can\'t charge for energy used more than '
              '12 months ago if they failed to bill you correctly.',
        );
      case InsightKind.standingChargeShare:
        return (
          '${money(i.amountPence ?? 0)} (${percentFromPermille(i.valueMilli ?? 0)}) '
              'of this bill is the standing charge',
          'You pay this daily however much you use. Using less electricity '
              'won\'t reduce it; only a different tariff can.',
        );
      case InsightKind.dailyUsageUp:
        return (
          'Daily use rose from ${kwh(i.valueMilli ?? 0)} to ${kwh(i.secondaryMilli ?? 0)}',
          'That accounts for ${money((i.amountPence ?? 0).abs())} of the change. '
              'Colder, darker months usually raise usage; if the season hasn\'t '
              'changed, look for new appliances or habits.',
        );
      case InsightKind.unitRateUp:
        return (
          'Higher prices added ${money(i.amountPence ?? 0)}',
          'Your price per kWh rose. On a standard variable tariff this follows '
              'the Ofgem price cap. You can check any quote against your real '
              'usage with "What if?".',
        );
      case InsightKind.economy7Split:
        final share = percentFromPermille(i.valueMilli ?? 0);
        final be = i.secondaryMilli;
        final ref = i.referenceVersion;
        if (be != null && ref != null) {
          final enough = (i.valueMilli ?? 0) >= be;
          return (
            '$share of your electricity was on the night rate',
            'At your day and night prices, Economy 7 only beats a single-rate '
                'price like the GB-average cap (${pence(ref.singleRateMilliPence)}'
                '/kWh incl. VAT) if at least ${percentFromPermille(be)} of use is at '
                'night. You are ${enough ? 'above' : 'below'} that. This is an '
                'estimate: single-rate prices vary by region and supplier.',
          );
        }
        return (
          '$share of your electricity was on the night rate',
          'Moving flexible use (washing, dishwasher, storage heating, EV) into '
              'your night hours lowers your average price per kWh.',
        );
      case InsightKind.capChangePreview:
        final ref = i.referenceVersion!;
        final diff = i.amountPence ?? 0;
        return (
          'Estimate: prices change on ${date(ref.effectiveFrom)}',
          'If your prices move like the GB-average price cap, this bill\'s usage '
              'would cost about ${money(i.valueMilli ?? 0)} '
              '(${money(diff, signed: true)}). This is an estimate — your region, '
              'payment method and tariff decide your actual prices.',
        );
    }
  }

  static const methodology =
      'EnergyLens recalculates your bill from the figures on it: days × '
      'standing charge, plus kWh × unit rate, plus VAT, plus any credits. It '
      'then splits the difference between two bills into parts that add up '
      'exactly to the change. The split is an explanation, not something your '
      'supplier publishes, and amounts are rounded to the penny.';

  static String vatPercent(int bp) => percentFromBasisPoints(bp);

  static String milliText(int? v) => v == null ? '' : formatMilli(v);
}
