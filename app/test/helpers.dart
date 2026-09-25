import 'package:energylens/domain/fixed_point.dart';
import 'package:energylens/domain/models.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

int m(String decimal) => parseMilli(decimal)!;

RatePeriod period(
  DateTime start,
  DateTime end, {
  String kwh = '0',
  String rate = '0',
  String standing = '0',
  int vatBp = 500,
  String? dayKwh,
  String? dayRate,
  String? nightKwh,
  String? nightRate,
}) {
  final regs = dayKwh != null
      ? [
          RegisterUsage(
            register: Register.day,
            kwhMilli: m(dayKwh),
            unitRateMilliPence: m(dayRate!),
          ),
          RegisterUsage(
            register: Register.night,
            kwhMilli: m(nightKwh!),
            unitRateMilliPence: m(nightRate!),
          ),
        ]
      : [
          RegisterUsage(
            register: Register.single,
            kwhMilli: m(kwh),
            unitRateMilliPence: m(rate),
          ),
        ];
  return RatePeriod(
    start: start,
    end: end,
    standingChargeMilliPencePerDay: m(standing),
    registers: regs,
    vatBasisPoints: vatBp,
  );
}

Bill bill(
  String id,
  List<RatePeriod> periods, {
  List<Adjustment> adjustments = const [],
  bool ratesIncludeVat = false,
  int? statedTotalPence,
  ReadingType readingType = ReadingType.actual,
  int? closingBalancePence,
  String householdId = 'h1',
}) => Bill(
  id: id,
  householdId: householdId,
  ratePeriods: periods,
  adjustments: adjustments,
  ratesIncludeVat: ratesIncludeVat,
  statedTotalPence: statedTotalPence,
  readingType: readingType,
  closingBalancePence: closingBalancePence,
  createdAt: DateTime.utc(2026, 9, 25),
);

/// 1–30 Sep 2026, 300 kWh @ 24.87p, 54.47p/day, VAT 5% → £95.50.
Bill septemberBill({String id = 'sep', int? stated}) => bill(id, [
  period(d(2026, 9, 1), d(2026, 9, 30), kwh: '300', rate: '24.87', standing: '54.47'),
], statedTotalPence: stated);

/// 1–31 Oct 2026, 341 kWh @ 26.32p, 54.83p/day, VAT 0% → £106.75.
Bill octoberBill({String id = 'oct', ReadingType reading = ReadingType.actual}) =>
    bill(id, [
      period(
        d(2026, 10, 1),
        d(2026, 10, 31),
        kwh: '341',
        rate: '26.32',
        standing: '54.83',
        vatBp: 0,
      ),
    ], readingType: reading);
