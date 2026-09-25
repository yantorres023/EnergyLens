import 'dart:convert';

import 'dates.dart';
import 'fixed_point.dart';

/// How well a reference-data row has been checked.
enum VerificationStatus {
  /// Checked line-by-line against the official publication.
  verifiedOfficial,

  /// Taken from a search-result extract of the official page; must be
  /// re-verified by a human before release.
  searchExtract,

  unknown,
}

class TariffVersion {
  const TariffVersion({
    required this.tariffId,
    required this.seriesId,
    required this.provider,
    required this.region,
    required this.paymentMethod,
    required this.meterType,
    required this.currency,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.standingChargeMilliPencePerDay,
    required this.unitRatesMilliPence,
    required this.vatBasisPoints,
    required this.sourceUrl,
    required this.sourceAuthority,
    required this.lastVerifiedAt,
    required this.verificationStatus,
  });

  final String tariffId;
  final String seriesId;
  final String provider;
  final String region;
  final String paymentMethod;
  final String meterType;
  final String currency;
  final DateTime effectiveFrom;

  /// Inclusive.
  final DateTime effectiveTo;

  /// VAT-inclusive, as published.
  final int standingChargeMilliPencePerDay;

  /// register name → VAT-inclusive unit rate.
  final Map<String, int> unitRatesMilliPence;
  final int vatBasisPoints;
  final String sourceUrl;
  final String sourceAuthority;
  final DateTime lastVerifiedAt;
  final VerificationStatus verificationStatus;

  bool covers(DateTime day) => isWithin(day, effectiveFrom, effectiveTo);

  int get singleRateMilliPence => unitRatesMilliPence['single'] ?? 0;

  /// Ex-VAT values, derived deterministically (CALCULATED).
  int get unitRateExVatMilliPence => divRoundHalfAwayFromZero(
    singleRateMilliPence * 10000,
    10000 + vatBasisPoints,
  );

  int get standingExVatMilliPencePerDay => divRoundHalfAwayFromZero(
    standingChargeMilliPencePerDay * 10000,
    10000 + vatBasisPoints,
  );
}

class TariffDataException implements Exception {
  TariffDataException(this.problems);
  final List<String> problems;
  @override
  String toString() => 'TariffDataException:\n${problems.join('\n')}';
}

/// A versioned reference dataset (the Ofgem cap averages bundled with the
/// app). Treated as code: [validate] runs in unit tests and CI.
class TariffDataset {
  TariffDataset({
    required this.datasetId,
    required this.currency,
    required this.versions,
  });

  final String datasetId;
  final String currency;
  final List<TariffVersion> versions;

  /// Days after which unverified reference data is treated as stale even if
  /// a version covers the date.
  static const int maxVerificationAgeDays = 120;

  static TariffDataset parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, Object?>;
    final problems = <String>[];
    final versions = <TariffVersion>[];
    final rawVersions = (root['versions'] as List?) ?? const [];
    for (var i = 0; i < rawVersions.length; i++) {
      final v = (rawVersions[i] as Map).cast<String, Object?>();
      try {
        final rates = <String, int>{};
        for (final r in (v['unit_rates']! as List)) {
          final m = (r as Map).cast<String, Object?>();
          final value = parseMilli(m['rate']! as String);
          if (value == null) throw FormatException('bad rate ${m['rate']}');
          rates[m['register']! as String] = value;
        }
        final standing = parseMilli(v['standing_charge']! as String);
        if (standing == null) throw const FormatException('bad standing');
        versions.add(
          TariffVersion(
            tariffId: v['tariff_id']! as String,
            seriesId: v['series_id']! as String,
            provider: v['provider']! as String,
            region: v['region']! as String,
            paymentMethod: v['payment_method']! as String,
            meterType: v['meter_type']! as String,
            currency: v['currency']! as String,
            effectiveFrom: parseIsoDate(v['effective_from']! as String),
            effectiveTo: parseIsoDate(v['effective_to']! as String),
            standingChargeMilliPencePerDay: standing,
            unitRatesMilliPence: rates,
            vatBasisPoints: v['vat_basis_points']! as int,
            sourceUrl: v['source_url']! as String,
            sourceAuthority: v['source_authority']! as String,
            lastVerifiedAt: parseIsoDate(v['last_verified_at']! as String),
            verificationStatus: switch (v['verification_status']) {
              'verified_official' => VerificationStatus.verifiedOfficial,
              'search_extract' => VerificationStatus.searchExtract,
              _ => VerificationStatus.unknown,
            },
          ),
        );
      } catch (e) {
        problems.add('version[$i]: cannot parse ($e)');
      }
    }
    if (problems.isNotEmpty) throw TariffDataException(problems);
    return TariffDataset(
      datasetId: root['dataset_id']! as String,
      currency: root['currency']! as String,
      versions: versions,
    );
  }

  /// Returns a list of integrity problems; empty means valid.
  List<String> validate() {
    final problems = <String>[];
    final ids = <String>{};
    for (final v in versions) {
      if (!ids.add(v.tariffId)) {
        problems.add('duplicate tariff_id ${v.tariffId}');
      }
      if (v.effectiveTo.isBefore(v.effectiveFrom)) {
        problems.add('${v.tariffId}: effective_to before effective_from');
      }
      if (v.currency != 'GBP' || v.currency != currency) {
        problems.add('${v.tariffId}: currency ${v.currency} not GBP');
      }
      if (v.standingChargeMilliPencePerDay < 0) {
        problems.add('${v.tariffId}: negative standing charge');
      }
      if (v.unitRatesMilliPence.isEmpty) {
        problems.add('${v.tariffId}: no unit rates');
      }
      v.unitRatesMilliPence.forEach((reg, rate) {
        if (rate < 0) problems.add('${v.tariffId}: negative rate for $reg');
        // Sanity bound: GB unit rates have never exceeded ~£1/kWh even
        // under the 2022 crisis cap. A value above it is a unit mistake.
        if (rate > 100 * milli) {
          problems.add('${v.tariffId}: implausible rate for $reg');
        }
      });
      if (v.standingChargeMilliPencePerDay > 200 * milli) {
        problems.add('${v.tariffId}: implausible standing charge');
      }
      if (v.vatBasisPoints < 0 || v.vatBasisPoints > 2000) {
        problems.add('${v.tariffId}: VAT out of range');
      }
      final uri = Uri.tryParse(v.sourceUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        problems.add('${v.tariffId}: source_url must be https');
      }
      if (v.sourceAuthority.trim().isEmpty) {
        problems.add('${v.tariffId}: missing source_authority');
      }
      if (v.verificationStatus == VerificationStatus.unknown) {
        problems.add('${v.tariffId}: unknown verification_status');
      }
      if (v.lastVerifiedAt.isBefore(
        v.effectiveFrom.subtract(const Duration(days: 60)),
      )) {
        problems.add(
          '${v.tariffId}: last_verified_at predates publication window',
        );
      }
    }
    // No overlapping versions within one series.
    final bySeries = <String, List<TariffVersion>>{};
    for (final v in versions) {
      bySeries.putIfAbsent(v.seriesId, () => []).add(v);
    }
    bySeries.forEach((series, list) {
      list.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
      for (var i = 1; i < list.length; i++) {
        if (!list[i].effectiveFrom.isAfter(list[i - 1].effectiveTo)) {
          problems.add(
            '$series: ${list[i - 1].tariffId} overlaps ${list[i].tariffId}',
          );
        }
      }
    });
    return problems;
  }

  TariffVersion? versionFor(DateTime day, {String? seriesId}) {
    for (final v in versions) {
      if (seriesId != null && v.seriesId != seriesId) continue;
      if (v.covers(day)) return v;
    }
    return null;
  }

  /// The version after the one covering [day], if published.
  TariffVersion? nextVersionAfter(DateTime day, {String? seriesId}) {
    TariffVersion? best;
    for (final v in versions) {
      if (seriesId != null && v.seriesId != seriesId) continue;
      if (v.effectiveFrom.isAfter(dateOnly(day)) &&
          (best == null || v.effectiveFrom.isBefore(best.effectiveFrom))) {
        best = v;
      }
    }
    return best;
  }

  /// Reference data is stale when nothing covers [today] or the covering
  /// version was last checked too long ago. Stale data is **never** applied
  /// silently: the UI hides projections that depend on it and says why.
  bool isStale(DateTime today) {
    final v = versionFor(today);
    if (v == null) return true;
    return dateOnly(today).difference(v.lastVerifiedAt).inDays >
        maxVerificationAgeDays;
  }
}
