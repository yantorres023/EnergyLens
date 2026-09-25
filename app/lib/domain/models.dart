import 'dates.dart';

/// Where a value came from. Shown next to every number in the UI so an
/// estimate is never presented as a measured fact.
enum Provenance {
  /// Read from a meter by the supplier or a smart meter (bill says "actual").
  measured,

  /// Extracted from pasted bill text and confirmed by the user.
  parsed,

  /// Typed in by the user.
  userEntered,

  /// Derived by deterministic arithmetic from other values.
  calculated,

  /// A projection or a value based on an estimated meter reading.
  estimated,
}

/// How the bill's closing meter reading was obtained.
enum ReadingType { actual, smart, customer, estimated, unknown }

enum MeterType { singleRate, economy7 }

enum TariffKind { standardVariable, fixed, unknown }

enum PaymentMethod { directDebit, onReceiptOfBill, other }

/// Unit-rate register on the meter.
enum Register { single, day, night }

enum AdjustmentKind { credit, discount, correction, fee, other }

enum BillSource { manual, pastedText }

/// GB electricity regions (distribution areas). Only used to label reference
/// data; the calculator always uses the rates printed on the user's bill.
enum GbRegion {
  unknown('Not sure'),
  eastEngland('East of England'),
  eastMidlands('East Midlands'),
  london('London'),
  merseysideNorthWales('Merseyside & North Wales'),
  westMidlands('West Midlands'),
  northEast('North East England'),
  northWest('North West England'),
  northScotland('North Scotland'),
  southScotland('South Scotland'),
  southEast('South East England'),
  southern('Southern England'),
  southWales('South Wales'),
  southWest('South West England'),
  yorkshire('Yorkshire');

  const GbRegion(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// The household. Deliberately holds **no** name, address, MPAN or account
/// number (see docs/engineering/SECURITY.md).
class Household {
  const Household({
    required this.id,
    this.nickname = 'My home',
    this.region = GbRegion.unknown,
    this.meterType = MeterType.singleRate,
    this.tariffKind = TariffKind.unknown,
    this.paymentMethod = PaymentMethod.directDebit,
    this.directDebitMonthlyPence,
  });

  final String id;
  final String nickname;
  final GbRegion region;
  final MeterType meterType;
  final TariffKind tariffKind;
  final PaymentMethod paymentMethod;

  /// Current monthly Direct Debit, user-entered.
  final int? directDebitMonthlyPence;

  Household copyWith({
    String? nickname,
    GbRegion? region,
    MeterType? meterType,
    TariffKind? tariffKind,
    PaymentMethod? paymentMethod,
    int? directDebitMonthlyPence,
    bool clearDirectDebit = false,
  }) {
    return Household(
      id: id,
      nickname: nickname ?? this.nickname,
      region: region ?? this.region,
      meterType: meterType ?? this.meterType,
      tariffKind: tariffKind ?? this.tariffKind,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      directDebitMonthlyPence: clearDirectDebit
          ? null
          : (directDebitMonthlyPence ?? this.directDebitMonthlyPence),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'region': region.name,
    'meterType': meterType.name,
    'tariffKind': tariffKind.name,
    'paymentMethod': paymentMethod.name,
    'directDebitMonthlyPence': directDebitMonthlyPence,
  };

  factory Household.fromJson(Map<String, Object?> j) => Household(
    id: j['id']! as String,
    nickname: (j['nickname'] as String?) ?? 'My home',
    region: _enumByName(GbRegion.values, j['region'], GbRegion.unknown),
    meterType: _enumByName(
      MeterType.values,
      j['meterType'],
      MeterType.singleRate,
    ),
    tariffKind: _enumByName(
      TariffKind.values,
      j['tariffKind'],
      TariffKind.unknown,
    ),
    paymentMethod: _enumByName(
      PaymentMethod.values,
      j['paymentMethod'],
      PaymentMethod.directDebit,
    ),
    directDebitMonthlyPence: j['directDebitMonthlyPence'] as int?,
  );
}

/// Consumption and price for one meter register inside a rate period.
class RegisterUsage {
  const RegisterUsage({
    required this.register,
    required this.kwhMilli,
    required this.unitRateMilliPence,
  });

  final Register register;

  /// Energy used, in milli-kWh.
  final int kwhMilli;

  /// Unit rate in milli-pence per kWh (26.32 p/kWh → 26320).
  final int unitRateMilliPence;

  RegisterUsage copyWith({int? kwhMilli, int? unitRateMilliPence}) =>
      RegisterUsage(
        register: register,
        kwhMilli: kwhMilli ?? this.kwhMilli,
        unitRateMilliPence: unitRateMilliPence ?? this.unitRateMilliPence,
      );

  Map<String, Object?> toJson() => {
    'register': register.name,
    'kwhMilli': kwhMilli,
    'unitRateMilliPence': unitRateMilliPence,
  };

  factory RegisterUsage.fromJson(Map<String, Object?> j) => RegisterUsage(
    register: _enumByName(Register.values, j['register'], Register.single),
    kwhMilli: j['kwhMilli']! as int,
    unitRateMilliPence: j['unitRateMilliPence']! as int,
  );
}

/// A span of the bill during which one set of prices applied. Most bills have
/// one; a bill that crosses a price-cap change (e.g. 1 October) has two.
class RatePeriod {
  const RatePeriod({
    required this.start,
    required this.end,
    required this.standingChargeMilliPencePerDay,
    required this.registers,
    required this.vatBasisPoints,
  });

  final DateTime start;

  /// Inclusive.
  final DateTime end;
  final int standingChargeMilliPencePerDay;
  final List<RegisterUsage> registers;

  /// VAT rate in basis points: 5% = 500, 0% = 0.
  final int vatBasisPoints;

  int get days => inclusiveDays(start, end);

  int get kwhMilli => registers.fold(0, (sum, r) => sum + r.kwhMilli);

  RatePeriod copyWith({
    DateTime? start,
    DateTime? end,
    int? standingChargeMilliPencePerDay,
    List<RegisterUsage>? registers,
    int? vatBasisPoints,
  }) => RatePeriod(
    start: start ?? this.start,
    end: end ?? this.end,
    standingChargeMilliPencePerDay:
        standingChargeMilliPencePerDay ?? this.standingChargeMilliPencePerDay,
    registers: registers ?? this.registers,
    vatBasisPoints: vatBasisPoints ?? this.vatBasisPoints,
  );

  Map<String, Object?> toJson() => {
    'start': isoDate(start),
    'end': isoDate(end),
    'standingChargeMilliPencePerDay': standingChargeMilliPencePerDay,
    'registers': registers.map((r) => r.toJson()).toList(),
    'vatBasisPoints': vatBasisPoints,
  };

  factory RatePeriod.fromJson(Map<String, Object?> j) => RatePeriod(
    start: parseIsoDate(j['start']! as String),
    end: parseIsoDate(j['end']! as String),
    standingChargeMilliPencePerDay: j['standingChargeMilliPencePerDay']! as int,
    registers: (j['registers']! as List)
        .map((e) => RegisterUsage.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    vatBasisPoints: j['vatBasisPoints']! as int,
  );
}

/// A credit, discount, fee or correction printed on the bill. Applied after
/// VAT, as final amounts (this is how GB bills show e.g. Warm Home Discount).
class Adjustment {
  const Adjustment({
    required this.label,
    required this.amountPence,
    this.kind = AdjustmentKind.other,
  });

  final String label;

  /// Negative for credits.
  final int amountPence;
  final AdjustmentKind kind;

  Map<String, Object?> toJson() => {
    'label': label,
    'amountPence': amountPence,
    'kind': kind.name,
  };

  factory Adjustment.fromJson(Map<String, Object?> j) => Adjustment(
    label: j['label']! as String,
    amountPence: j['amountPence']! as int,
    kind: _enumByName(AdjustmentKind.values, j['kind'], AdjustmentKind.other),
  );
}

/// Records that the user changed a value that the parser had extracted.
class UserCorrection {
  const UserCorrection({
    required this.field,
    required this.parsedValue,
    required this.correctedValue,
  });

  final String field;
  final String parsedValue;
  final String correctedValue;

  Map<String, Object?> toJson() => {
    'field': field,
    'parsedValue': parsedValue,
    'correctedValue': correctedValue,
  };

  factory UserCorrection.fromJson(Map<String, Object?> j) => UserCorrection(
    field: j['field']! as String,
    parsedValue: j['parsedValue']! as String,
    correctedValue: j['correctedValue']! as String,
  );
}

class Bill {
  const Bill({
    required this.id,
    required this.householdId,
    required this.ratePeriods,
    this.adjustments = const [],
    this.ratesIncludeVat = false,
    this.statedTotalPence,
    this.readingType = ReadingType.unknown,
    this.supplierName,
    this.source = BillSource.manual,
    this.fieldProvenance = const {},
    this.corrections = const [],
    this.closingBalancePence,
    required this.createdAt,
  });

  final String id;
  final String householdId;

  /// Sorted, non-overlapping. Bill period = first start … last end.
  final List<RatePeriod> ratePeriods;
  final List<Adjustment> adjustments;

  /// True when the unit rate and standing charge the user typed already
  /// include VAT (some bills print VAT-inclusive prices).
  final bool ratesIncludeVat;

  /// The electricity total printed on the bill, for reconciliation.
  final int? statedTotalPence;
  final ReadingType readingType;

  /// Optional, free text (e.g. "Octopus"). Not an identifier.
  final String? supplierName;
  final BillSource source;

  /// Provenance of each input field, keyed by field name.
  final Map<String, Provenance> fieldProvenance;
  final List<UserCorrection> corrections;

  /// Account balance after this bill: positive = in credit.
  final int? closingBalancePence;
  final DateTime createdAt;

  DateTime get periodStart => ratePeriods.first.start;
  DateTime get periodEnd => ratePeriods.last.end;
  int get days => inclusiveDays(periodStart, periodEnd);

  bool get isEconomy7 => ratePeriods.any(
    (p) => p.registers.any((r) => r.register != Register.single),
  );

  bool get usageIsEstimated => readingType == ReadingType.estimated;

  Bill copyWith({
    List<RatePeriod>? ratePeriods,
    List<Adjustment>? adjustments,
    bool? ratesIncludeVat,
    int? statedTotalPence,
    bool clearStatedTotal = false,
    ReadingType? readingType,
    String? supplierName,
    Map<String, Provenance>? fieldProvenance,
    List<UserCorrection>? corrections,
    int? closingBalancePence,
  }) => Bill(
    id: id,
    householdId: householdId,
    ratePeriods: ratePeriods ?? this.ratePeriods,
    adjustments: adjustments ?? this.adjustments,
    ratesIncludeVat: ratesIncludeVat ?? this.ratesIncludeVat,
    statedTotalPence: clearStatedTotal
        ? null
        : (statedTotalPence ?? this.statedTotalPence),
    readingType: readingType ?? this.readingType,
    supplierName: supplierName ?? this.supplierName,
    source: source,
    fieldProvenance: fieldProvenance ?? this.fieldProvenance,
    corrections: corrections ?? this.corrections,
    closingBalancePence: closingBalancePence ?? this.closingBalancePence,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'householdId': householdId,
    'ratePeriods': ratePeriods.map((p) => p.toJson()).toList(),
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
    'ratesIncludeVat': ratesIncludeVat,
    'statedTotalPence': statedTotalPence,
    'readingType': readingType.name,
    'supplierName': supplierName,
    'source': source.name,
    'fieldProvenance': fieldProvenance.map((k, v) => MapEntry(k, v.name)),
    'corrections': corrections.map((c) => c.toJson()).toList(),
    'closingBalancePence': closingBalancePence,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory Bill.fromJson(Map<String, Object?> j) => Bill(
    id: j['id']! as String,
    householdId: j['householdId']! as String,
    ratePeriods: (j['ratePeriods']! as List)
        .map((e) => RatePeriod.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    adjustments: ((j['adjustments'] as List?) ?? const [])
        .map((e) => Adjustment.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    ratesIncludeVat: (j['ratesIncludeVat'] as bool?) ?? false,
    statedTotalPence: j['statedTotalPence'] as int?,
    readingType: _enumByName(
      ReadingType.values,
      j['readingType'],
      ReadingType.unknown,
    ),
    supplierName: j['supplierName'] as String?,
    source: _enumByName(BillSource.values, j['source'], BillSource.manual),
    fieldProvenance: ((j['fieldProvenance'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(
        k as String,
        _enumByName(Provenance.values, v, Provenance.userEntered),
      ),
    ),
    corrections: ((j['corrections'] as List?) ?? const [])
        .map((e) => UserCorrection.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    closingBalancePence: j['closingBalancePence'] as int?,
    createdAt: DateTime.parse(j['createdAt']! as String),
  );
}

enum ActionType {
  submitMeterReading,
  reduceDailyUsage,
  shiftToNight,
  checkTariffQuote,
  reviewDirectDebit,
}

enum ExperimentStatus { active, completed, abandoned }

enum ExperimentOutcome { improved, noClearChange, worse, inconclusive }

/// A user-chosen action, verified against the next bill.
class SavingsExperiment {
  const SavingsExperiment({
    required this.id,
    required this.householdId,
    required this.action,
    required this.baselineBillId,
    required this.startedAt,
    required this.baselineMetricMilli,
    this.status = ExperimentStatus.active,
    this.resultBillId,
    this.outcome,
    this.resultMetricMilli,
    this.counterfactualSavingPence,
    this.completedAt,
  });

  final String id;
  final String householdId;
  final ActionType action;
  final String baselineBillId;
  final DateTime startedAt;

  /// Metric at baseline in milli-units (kWh/day, night share ‰ × 1000, …).
  final int baselineMetricMilli;
  final ExperimentStatus status;
  final String? resultBillId;
  final ExperimentOutcome? outcome;
  final int? resultMetricMilli;

  /// For rate-related actions: what the result bill would have cost at the
  /// baseline bill's rates minus what it actually cost. CALCULATED.
  final int? counterfactualSavingPence;
  final DateTime? completedAt;

  SavingsExperiment copyWith({
    ExperimentStatus? status,
    String? resultBillId,
    ExperimentOutcome? outcome,
    int? resultMetricMilli,
    int? counterfactualSavingPence,
    DateTime? completedAt,
  }) => SavingsExperiment(
    id: id,
    householdId: householdId,
    action: action,
    baselineBillId: baselineBillId,
    startedAt: startedAt,
    baselineMetricMilli: baselineMetricMilli,
    status: status ?? this.status,
    resultBillId: resultBillId ?? this.resultBillId,
    outcome: outcome ?? this.outcome,
    resultMetricMilli: resultMetricMilli ?? this.resultMetricMilli,
    counterfactualSavingPence:
        counterfactualSavingPence ?? this.counterfactualSavingPence,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'householdId': householdId,
    'action': action.name,
    'baselineBillId': baselineBillId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'baselineMetricMilli': baselineMetricMilli,
    'status': status.name,
    'resultBillId': resultBillId,
    'outcome': outcome?.name,
    'resultMetricMilli': resultMetricMilli,
    'counterfactualSavingPence': counterfactualSavingPence,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory SavingsExperiment.fromJson(Map<String, Object?> j) =>
      SavingsExperiment(
        id: j['id']! as String,
        householdId: j['householdId']! as String,
        action: _enumByName(
          ActionType.values,
          j['action'],
          ActionType.reduceDailyUsage,
        ),
        baselineBillId: j['baselineBillId']! as String,
        startedAt: DateTime.parse(j['startedAt']! as String),
        baselineMetricMilli: j['baselineMetricMilli']! as int,
        status: _enumByName(
          ExperimentStatus.values,
          j['status'],
          ExperimentStatus.active,
        ),
        resultBillId: j['resultBillId'] as String?,
        outcome: j['outcome'] == null
            ? null
            : _enumByName(
                ExperimentOutcome.values,
                j['outcome'],
                ExperimentOutcome.inconclusive,
              ),
        resultMetricMilli: j['resultMetricMilli'] as int?,
        counterfactualSavingPence: j['counterfactualSavingPence'] as int?,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt']! as String),
      );
}

class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.analyticsOptIn = false,
    this.activeHouseholdId,
  });

  final bool onboardingCompleted;

  /// Local-only event log. Nothing is ever transmitted in V1.
  final bool analyticsOptIn;
  final String? activeHouseholdId;

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? analyticsOptIn,
    String? activeHouseholdId,
  }) => AppSettings(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
    activeHouseholdId: activeHouseholdId ?? this.activeHouseholdId,
  );

  Map<String, Object?> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'analyticsOptIn': analyticsOptIn,
    'activeHouseholdId': activeHouseholdId,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    onboardingCompleted: (j['onboardingCompleted'] as bool?) ?? false,
    analyticsOptIn: (j['analyticsOptIn'] as bool?) ?? false,
    activeHouseholdId: j['activeHouseholdId'] as String?,
  );
}
