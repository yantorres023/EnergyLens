import 'dart:io';

import 'package:energylens/domain/tariff_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Tariff data is code: these tests run in CI on every change.
void main() {
  final raw = File('assets/data/gb_price_cap_electricity.json')
      .readAsStringSync();
  final ds = TariffDataset.parse(raw);

  test('bundled dataset passes every integrity rule', () {
    expect(ds.validate(), isEmpty);
    expect(ds.versions, isNotEmpty);
    expect(ds.currency, 'GBP');
  });

  test('unique ids, valid dates, https sources, verification metadata', () {
    final ids = ds.versions.map((v) => v.tariffId).toList();
    expect(ids.toSet().length, ids.length);
    for (final v in ds.versions) {
      expect(v.effectiveTo.isBefore(v.effectiveFrom), isFalse);
      expect(Uri.parse(v.sourceUrl).scheme, 'https');
      expect(v.sourceAuthority, isNotEmpty);
      expect(v.verificationStatus, isNot(VerificationStatus.unknown));
      expect(v.standingChargeMilliPencePerDay, greaterThanOrEqualTo(0));
      for (final r in v.unitRatesMilliPence.values) {
        expect(r, greaterThanOrEqualTo(0));
      }
    }
  });

  test('versions within a series are contiguous (no gaps, no overlaps)', () {
    final list = [...ds.versions]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    for (var i = 1; i < list.length; i++) {
      expect(
        list[i].effectiveFrom.difference(list[i - 1].effectiveTo).inDays,
        1,
        reason: '${list[i - 1].tariffId} → ${list[i].tariffId}',
      );
    }
  });

  test('published figures match the sources recorded in TARIFF_DATA.md', () {
    final q4 = ds.versionFor(d(2026, 10, 15))!;
    expect(q4.tariffId, 'gb-cap-elec-avg-dd-single-2026q4');
    expect(q4.singleRateMilliPence, m('26.32'));
    expect(q4.standingChargeMilliPencePerDay, m('54.83'));
    expect(q4.vatBasisPoints, 0);
    final q3 = ds.versionFor(d(2026, 9, 30))!;
    expect(q3.singleRateMilliPence, m('26.11'));
    expect(q3.vatBasisPoints, 500);
    // Ex-VAT derivation: 26.11 / 1.05 = 24.867.
    expect(q3.unitRateExVatMilliPence, 24867);
    expect(q3.standingExVatMilliPencePerDay, 54467);
  });

  test('lookup and next version', () {
    expect(ds.versionFor(d(2025, 12, 31)), isNull);
    expect(ds.nextVersionAfter(d(2026, 9, 30))!.tariffId, endsWith('2026q4'));
    expect(ds.nextVersionAfter(d(2026, 12, 31)), isNull);
  });

  test('staleness: never silently apply outdated reference data', () {
    expect(ds.isStale(d(2026, 10, 1)), isFalse);
    // After the last published version ends, the data is stale.
    expect(ds.isStale(d(2027, 1, 1)), isTrue);
    // Too long since last verification also counts as stale.
    final old = TariffDataset.parse(
      raw.replaceAll(
        '"last_verified_at": "2026-09-25"',
        '"last_verified_at": "2026-05-01"',
      ),
    );
    expect(old.isStale(d(2026, 12, 1)), isTrue);
  });

  group('validator catches broken data', () {
    String mutate(String from, String to) => raw.replaceFirst(from, to);

    test('duplicate ids', () {
      final bad = TariffDataset.parse(
        mutate(
          'gb-cap-elec-avg-dd-single-2026q2',
          'gb-cap-elec-avg-dd-single-2026q1',
        ),
      );
      expect(bad.validate().join(), contains('duplicate'));
    });
    test('overlapping versions', () {
      final bad = TariffDataset.parse(
        mutate('"effective_to": "2026-03-31"', '"effective_to": "2026-04-05"'),
      );
      expect(bad.validate().join(), contains('overlaps'));
    });
    test('negative and implausible rates', () {
      expect(
        TariffDataset.parse(mutate('"rate": "27.69"', '"rate": "-1"'))
            .validate()
            .join(),
        contains('negative rate'),
      );
      expect(
        TariffDataset.parse(mutate('"rate": "27.69"', '"rate": "2769"'))
            .validate()
            .join(),
        contains('implausible'),
      );
    });
    test('non-https source and wrong currency', () {
      final bad = TariffDataset.parse(
        mutate(
          '"source_url": "https://www.ofgem',
          '"source_url": "http://www.ofgem',
        ).replaceFirst(
          '"currency": "GBP",\n      "effective_from"',
          '"currency": "EUR",\n      "effective_from"',
        ),
      );
      final problems = bad.validate().join('\n');
      expect(problems, contains('https'));
      expect(problems, contains('currency'));
    });
    test('unparseable values throw with details', () {
      expect(
        () => TariffDataset.parse(
          mutate('"standing_charge": "54.75"', '"standing_charge": "abc"'),
        ),
        throwsA(isA<TariffDataException>()),
      );
    });
  });
}
