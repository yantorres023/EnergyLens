// Validates bundled tariff reference data. Run in CI:
//   dart run tool/validate_tariffs.dart
// Exits non-zero on any integrity problem, and warns (non-fatal) when the
// data will go stale within 21 days so a data update is scheduled in time.
import 'dart:io';

import 'package:energylens/domain/tariff_reference.dart';

void main(List<String> args) {
  final files = Directory('assets/data')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));
  var failed = false;
  for (final f in files) {
    try {
      final ds = TariffDataset.parse(f.readAsStringSync());
      final problems = ds.validate();
      if (problems.isEmpty) {
        stdout.writeln('OK   ${f.path}: ${ds.versions.length} versions');
      } else {
        failed = true;
        stderr.writeln('FAIL ${f.path}');
        for (final p in problems) {
          stderr.writeln('  - $p');
        }
      }
      final soon = DateTime.now().toUtc().add(const Duration(days: 21));
      if (ds.isStale(soon)) {
        stdout.writeln(
          '::warning::${f.path} has no verified version covering '
          '${soon.toIso8601String().substring(0, 10)}. Add the next Ofgem '
          'cap period (published ~5 weeks before each quarter).',
        );
      }
      final unverified = ds.versions
          .where(
            (v) => v.verificationStatus != VerificationStatus.verifiedOfficial,
          )
          .map((v) => v.tariffId);
      if (unverified.isNotEmpty) {
        stdout.writeln(
          '::warning::Not yet verified line-by-line against official tables: '
          '${unverified.join(', ')}',
        );
      }
    } on TariffDataException catch (e) {
      failed = true;
      stderr.writeln('FAIL ${f.path}\n$e');
    }
  }
  if (failed) exit(1);
}
