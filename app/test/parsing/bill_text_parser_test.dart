import 'package:energylens/parsing/bill_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic bill texts modelled on common GB bill layouts. They contain
// fake personal details to prove those are never extracted.
const singleRateBill = '''
Mr A Example
1 Example Street, Exampletown, EX1 1AA
Account number: 12345678
MPAN: 1200 0000 0000 00

Your electricity bill
Billing period: 1 Sep 2026 - 30 Sep 2026

Meter readings
Opening reading 12,345 (actual reading)
Closing reading 12,645 (actual reading)

Electricity used 300 kWh x 24.87p per kWh     £74.61
Standing charge 30 days x 54.47p per day      £16.34
VAT @ 5%                                       £4.55
Total electricity charges                     £95.50

Your estimated annual consumption is 3,650 kWh
Personal projection: £1,150.00 a year
Balance after this bill: £45.20 in credit
''';

const economy7Bill = '''
Statement 01/10/2026 to 31/10/2026
Day units 200 kWh @ 30.00p/kWh   £60.00
Night units 100 kWh @ 15.00p/kWh £15.00
Total units 300 kWh
Standing charge 31 days @ 50.00p/day £15.50
VAT at 0% £0.00
Total charges for this period £90.50
Closing reading 45678 (E) estimated reading
''';

const splitBill = '''
Period 15 September to 14 October 2026
Electricity 160 kWh x 24.87p per kWh
Electricity 150 kWh x 26.32p per kWh
Standing charge 54.47p per day
VAT 5%
VAT 0%
Total £98.10
''';

const poundsRateBill = '''
1st August 2026 to 31st August 2026
Energy used 250 kWh at £0.2611/kWh
Standing charge £0.5719 per day
Total electricity cost £82.71
Smart meter reading
''';

void main() {
  const parser = BillTextParser();

  test('single-rate bill: all key fields, no personal data', () {
    final r = parser.parse(singleRateBill);
    final f = r.fields;
    expect(f[ParsedFieldKey.periodStart]!.value, '2026-09-01');
    expect(f[ParsedFieldKey.periodEnd]!.value, '2026-09-30');
    expect(f[ParsedFieldKey.kwhSingle]!.value, '300');
    expect(f[ParsedFieldKey.kwhSingle]!.confidence, ParseConfidence.high);
    expect(f[ParsedFieldKey.unitRateSingle]!.value, '24.87');
    expect(f[ParsedFieldKey.standingCharge]!.value, '54.47');
    expect(f[ParsedFieldKey.vatPercent]!.value, '5');
    expect(f[ParsedFieldKey.statedTotal]!.value, '9550');
    expect(f[ParsedFieldKey.readingType]!.value, 'actual');
    // Annual projection (3,650 kWh) must not be taken as usage.
    expect(f[ParsedFieldKey.kwhSingle]!.value, isNot('3650'));
    // Nothing that looks like an identifier or address is proposed.
    final allValues = f.values.map((v) => v.value).join(' ');
    expect(allValues, isNot(contains('12345678')));
    expect(allValues, isNot(contains('Example')));
  });

  test('Economy 7 bill with numeric dates and estimated reading', () {
    final f = parser.parse(economy7Bill).fields;
    expect(f[ParsedFieldKey.periodStart]!.value, '2026-10-01');
    expect(f[ParsedFieldKey.periodEnd]!.value, '2026-10-31');
    expect(f[ParsedFieldKey.kwhDay]!.value, '200');
    expect(f[ParsedFieldKey.kwhNight]!.value, '100');
    expect(f[ParsedFieldKey.unitRateDay]!.value, '30.00');
    expect(f[ParsedFieldKey.unitRateNight]!.value, '15.00');
    expect(f.containsKey(ParsedFieldKey.kwhSingle), isFalse);
    expect(f[ParsedFieldKey.standingCharge]!.value, '50.00');
    expect(f[ParsedFieldKey.vatPercent]!.value, '0');
    expect(f[ParsedFieldKey.statedTotal]!.value, '9050');
    expect(f[ParsedFieldKey.readingType]!.value, 'estimated');
  });

  test('split-rate bill is flagged for a second rate period', () {
    final r = parser.parse(splitBill);
    expect(r.fields[ParsedFieldKey.periodStart]!.value, '2026-09-15');
    expect(r.fields[ParsedFieldKey.periodEnd]!.value, '2026-10-14');
    expect(r.fields[ParsedFieldKey.unitRateSingle]!.confidence, ParseConfidence.low);
    expect(r.notes.join(' '), contains('second rate period'));
    expect(r.notes.join(' '), contains('VAT'));
  });

  test('rates written in pounds are converted to pence exactly', () {
    final f = parser.parse(poundsRateBill).fields;
    expect(f[ParsedFieldKey.periodStart]!.value, '2026-08-01');
    expect(f[ParsedFieldKey.unitRateSingle]!.value, '26.11');
    expect(f[ParsedFieldKey.standingCharge]!.value, '57.19');
    expect(f[ParsedFieldKey.kwhSingle]!.value, '250');
    expect(f[ParsedFieldKey.statedTotal]!.value, '8271');
    expect(f[ParsedFieldKey.readingType]!.value, 'smart');
  });

  test('garbage yields nothing rather than guesses', () {
    final r = parser.parse('hello world\n£££\n12 apples');
    expect(r.isEmpty, isTrue);
  });

  test('impossible date ranges are ignored', () {
    final r = parser.parse('30 Sep 2026 - 1 Sep 2026');
    expect(r.fields.containsKey(ParsedFieldKey.periodStart), isFalse);
  });
}
