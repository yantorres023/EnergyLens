import 'package:energylens/domain/fixed_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('divRoundHalfAwayFromZero', () {
    test('rounds halves away from zero symmetrically', () {
      expect(divRoundHalfAwayFromZero(5, 10), 1);
      expect(divRoundHalfAwayFromZero(4, 10), 0);
      expect(divRoundHalfAwayFromZero(-5, 10), -1);
      expect(divRoundHalfAwayFromZero(-4, 10), 0);
      expect(divRoundHalfAwayFromZero(15, 10), 2);
      expect(divRoundHalfAwayFromZero(7, -2), -4);
    });

    test('rejects zero denominator', () {
      expect(() => divRoundHalfAwayFromZero(1, 0), throwsArgumentError);
    });
  });

  group('costPence', () {
    test('300 kWh at 26.32p = £78.96', () {
      expect(costPence(300000, 26320), 7896);
    });
    test('30 days at 54.83p = 1644.9p → 1645p', () {
      expect(costPence(30000, 54830), 1645);
    });
    test('half a penny rounds up, negative half rounds down', () {
      expect(costPence(1000, 500), 1);
      expect(costPence(-1000, 500), -1);
    });
    test('very high usage does not overflow', () {
      // 1,000,000 kWh at 100p/kWh = £1,000,000.
      expect(costPence(1000000 * 1000, 100 * 1000), 100000000);
    });
  });

  group('parseMilli', () {
    test('parses decimals exactly without floating point', () {
      expect(parseMilli('26.32'), 26320);
      expect(parseMilli('54.8'), 54800);
      expect(parseMilli('0.1'), 100);
      expect(parseMilli('.5'), 500);
      expect(parseMilli('1,234.5'), 1234500);
      expect(parseMilli('-3'), -3000);
      expect(parseMilli('+7'), 7000);
    });
    test('rounds beyond three decimals', () {
      expect(parseMilli('26.3205'), 26321);
      expect(parseMilli('26.3204'), 26320);
      expect(parseMilli('-0.0005'), -1);
    });
    test('rejects junk', () {
      expect(parseMilli(''), isNull);
      expect(parseMilli('abc'), isNull);
      expect(parseMilli('1.2.3'), isNull);
      expect(parseMilli('12p'), isNull);
    });
  });

  group('parsePoundsToPence', () {
    test('handles symbols, commas and credit notations', () {
      expect(parsePoundsToPence('£123.45'), 12345);
      expect(parsePoundsToPence('1,234.50'), 123450);
      expect(parsePoundsToPence('-5'), -500);
      expect(parsePoundsToPence('£12.00 CR'), -1200);
      expect(parsePoundsToPence('(12.00)'), -1200);
      expect(parsePoundsToPence('£0.005'), 1);
      expect(parsePoundsToPence('x'), isNull);
    });
  });

  test('formatMilli trims zeros', () {
    expect(formatMilli(26320), '26.32');
    expect(formatMilli(54000), '54');
    expect(formatMilli(54000, minDecimals: 2), '54.00');
    expect(formatMilli(-1500), '-1.5');
  });
}
