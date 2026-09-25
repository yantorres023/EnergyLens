import '../domain/fixed_point.dart';
import '../domain/models.dart';

/// Fields the parser can propose. It deliberately has no field for name,
/// address, account number or MPAN: those are never extracted or stored.
enum ParsedFieldKey {
  periodStart,
  periodEnd,
  kwhSingle,
  kwhDay,
  kwhNight,
  unitRateSingle,
  unitRateDay,
  unitRateNight,
  standingCharge,
  vatPercent,
  statedTotal,
  readingType,
}

enum ParseConfidence { high, low }

/// A proposed value. **Untrusted** until the user confirms it on the review
/// screen; nothing is calculated from a ParsedField directly.
class ParsedField {
  const ParsedField({
    required this.key,
    required this.value,
    required this.sourceSnippet,
    required this.confidence,
  });

  final ParsedFieldKey key;

  /// Normalised value as text: ISO date, decimal kWh/pence, pence integer
  /// for totals, or a [ReadingType] name.
  final String value;

  /// The fragment of pasted text the value came from, shown to the user.
  final String sourceSnippet;
  final ParseConfidence confidence;
}

class ParseResult {
  const ParseResult(this.fields, this.notes);
  final Map<ParsedFieldKey, ParsedField> fields;

  /// Human-readable notes, e.g. "found 2 different unit rates".
  final List<String> notes;

  bool get isEmpty => fields.isEmpty;
}

/// Heuristic, offline, deterministic parser for text copied from a GB
/// electricity bill (PDF or supplier web page).
///
/// Workflow: IMPORT (paste) → PARSE (this) → SHOW → USER CONFIRMS/CORRECTS →
/// CALCULATE. The pasted text itself is never persisted.
class BillTextParser {
  const BillTextParser();

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _num = r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)';

  ParseResult parse(String text) {
    final fields = <ParsedFieldKey, ParsedField>{};
    final notes = <String>[];
    // Normalise whitespace and common PDF artefacts.
    final normalised = text
        .replaceAll(' ', ' ')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('\r', '');
    final lines = normalised
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    _parsePeriod(normalised, fields);

    // Ignore projections: "annual consumption", "estimated annual cost" etc.
    bool isProjection(String l) => RegExp(
      r'annual|a year|per year|projected|next 12|12 months|personal projection|typical',
      caseSensitive: false,
    ).hasMatch(l);

    final unitRates = <String, List<_Hit>>{
      'single': [],
      'day': [],
      'night': [],
    };
    final kwh = <String, List<_Hit>>{'single': [], 'day': [], 'night': []};

    for (final line in lines) {
      if (isProjection(line)) continue;
      final lower = line.toLowerCase();
      // "per day" on standing-charge lines must not make a line "day rate".
      final reg =
          RegExp(
            r'night|off-?\s?peak|low rate',
            caseSensitive: false,
          ).hasMatch(line)
          ? 'night'
          : RegExp(
              r'(^|\s)day[\s-]*(rate|units?|usage|time|electricity|kwh)|^day\b|\bpeak rate',
              caseSensitive: false,
            ).hasMatch(line)
          ? 'day'
          : 'single';

      // Unit rate: "26.32p per kWh", "26.32p/kWh", "26.320 pence per kWh",
      // "£0.2632/kWh".
      for (final m in RegExp(
        '$_num\\s*(?:p|pence)\\s*(?:per|/)\\s*kwh',
        caseSensitive: false,
      ).allMatches(line)) {
        unitRates[reg]!.add(_Hit(m.group(1)!, line));
      }
      for (final m in RegExp(
        '£\\s*(0\\.\\d+)\\s*(?:per|/)\\s*kwh',
        caseSensitive: false,
      ).allMatches(line)) {
        // Shift the decimal point two places without floating point:
        // "0.2632" pounds → "26.32" pence.
        final digits = m.group(1)!.split('.')[1].padRight(2, '0');
        final pence =
            '${int.parse(digits.substring(0, 2))}'
            '${digits.length > 2 ? '.${digits.substring(2)}' : ''}';
        unitRates[reg]!.add(_Hit(pence, line));
      }

      // kWh used: a number followed by kWh that is NOT a rate.
      for (final m in RegExp(
        '$_num\\s*kwh(?!\\s*\\))',
        caseSensitive: false,
      ).allMatches(line)) {
        final before = line.substring(0, m.start).toLowerCase();
        if (before.endsWith('per ') || before.endsWith('/')) continue;
        final after = line.substring(m.end).toLowerCase();
        if (after.trimLeft().startsWith('per') || after.startsWith('/')) {
          // "kWh per day" averages are not totals.
          continue;
        }
        kwh[reg]!.add(_Hit(m.group(1)!.replaceAll(',', ''), line));
      }

      // Standing charge: "54.83p per day", "54.83p/day", "x 54.83p" on a
      // standing-charge line.
      final standing = RegExp(
        '$_num\\s*(?:p|pence)\\s*(?:per|/|a)\\s*day',
        caseSensitive: false,
      ).firstMatch(line);
      if (standing != null &&
          !fields.containsKey(ParsedFieldKey.standingCharge)) {
        fields[ParsedFieldKey.standingCharge] = ParsedField(
          key: ParsedFieldKey.standingCharge,
          value: standing.group(1)!,
          sourceSnippet: line,
          confidence: ParseConfidence.high,
        );
      } else if (!fields.containsKey(ParsedFieldKey.standingCharge) &&
          RegExp(
            r'£\s*(0\.\d+)\s*(?:per|/|a)\s*day',
            caseSensitive: false,
          ).hasMatch(line)) {
        final pm = RegExp(
          r'£\s*0\.(\d+)\s*(?:per|/|a)\s*day',
          caseSensitive: false,
        ).firstMatch(line)!;
        final digits = pm.group(1)!.padRight(2, '0');
        fields[ParsedFieldKey.standingCharge] = ParsedField(
          key: ParsedFieldKey.standingCharge,
          value:
              '${int.parse(digits.substring(0, 2))}'
              '${digits.length > 2 ? '.${digits.substring(2)}' : ''}',
          sourceSnippet: line,
          confidence: ParseConfidence.high,
        );
      } else if (lower.contains('standing') &&
          !fields.containsKey(ParsedFieldKey.standingCharge)) {
        final m = RegExp(
          '(?:x|@|at)\\s*$_num\\s*p\\b',
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          fields[ParsedFieldKey.standingCharge] = ParsedField(
            key: ParsedFieldKey.standingCharge,
            value: m.group(1)!,
            sourceSnippet: line,
            confidence: ParseConfidence.low,
          );
        }
      }

      // VAT: "VAT @ 5%", "VAT at 0%", "VAT (5%)".
      final vat = RegExp(
        r'vat\s*(?:@|at|\()?\s*(\d{1,2}(?:\.\d+)?)\s*%',
        caseSensitive: false,
      ).firstMatch(line);
      if (vat != null) {
        final existing = fields[ParsedFieldKey.vatPercent];
        if (existing == null) {
          fields[ParsedFieldKey.vatPercent] = ParsedField(
            key: ParsedFieldKey.vatPercent,
            value: vat.group(1)!,
            sourceSnippet: line,
            confidence: ParseConfidence.high,
          );
        } else if (existing.value != vat.group(1)) {
          notes.add(
            'More than one VAT rate found (${existing.value}% and '
            '${vat.group(1)}%). If your prices changed during this bill, add a '
            'second rate period.',
          );
        }
      }

      // Total: "Total electricity charges £123.45", "Total charges for this
      // period £..", "Total cost £..".
      if (RegExp(r'total', caseSensitive: false).hasMatch(line) &&
          !RegExp(
            r'balance|paid|payment|annual|kwh',
            caseSensitive: false,
          ).hasMatch(line)) {
        final money = RegExp(
          r'(-?£\s*-?[\d,]+\.\d{2}(?:\s*CR)?)',
          caseSensitive: false,
        ).allMatches(line).toList();
        if (money.isNotEmpty) {
          final pence = parsePoundsToPence(
            money.last.group(1)!.replaceAll(' ', ''),
          );
          final isElectric = lower.contains('electric');
          final existing = fields[ParsedFieldKey.statedTotal];
          if (pence != null &&
              (existing == null ||
                  (isElectric && existing.confidence == ParseConfidence.low))) {
            fields[ParsedFieldKey.statedTotal] = ParsedField(
              key: ParsedFieldKey.statedTotal,
              value: '$pence',
              sourceSnippet: line,
              confidence: isElectric
                  ? ParseConfidence.high
                  : ParseConfidence.low,
            );
          }
        }
      }

      // Reading type.
      if (!fields.containsKey(ParsedFieldKey.readingType)) {
        ReadingType? rt;
        if (RegExp(
              r'\bestimated?\b|\(e\)',
              caseSensitive: false,
            ).hasMatch(line) &&
            RegExp(r'read', caseSensitive: false).hasMatch(line)) {
          rt = ReadingType.estimated;
        } else if (RegExp(r'smart', caseSensitive: false).hasMatch(line) &&
            RegExp(r'read', caseSensitive: false).hasMatch(line)) {
          rt = ReadingType.smart;
        } else if (RegExp(
              r'\bactual\b|\(a\)',
              caseSensitive: false,
            ).hasMatch(line) &&
            RegExp(r'read', caseSensitive: false).hasMatch(line)) {
          rt = ReadingType.actual;
        } else if (RegExp(
          r'customer read|your read|\(c\)',
          caseSensitive: false,
        ).hasMatch(line)) {
          rt = ReadingType.customer;
        }
        if (rt != null) {
          fields[ParsedFieldKey.readingType] = ParsedField(
            key: ParsedFieldKey.readingType,
            value: rt.name,
            sourceSnippet: line,
            confidence: ParseConfidence.low,
          );
        }
      }
    }

    void pick(String reg, ParsedFieldKey rateKey, ParsedFieldKey kwhKey) {
      final rates = unitRates[reg]!;
      if (rates.isNotEmpty) {
        final distinct = rates.map((h) => h.value).toSet();
        if (distinct.length > 1) {
          notes.add(
            'Found ${distinct.length} different ${reg == 'single' ? '' : '$reg '}'
            'unit rates (${distinct.join(', ')}p). The first is filled in; if '
            'your prices changed during this bill, add a second rate period.',
          );
        }
        fields[rateKey] = ParsedField(
          key: rateKey,
          value: rates.first.value,
          sourceSnippet: rates.first.line,
          confidence: distinct.length == 1
              ? ParseConfidence.high
              : ParseConfidence.low,
        );
      }
      final uses = kwh[reg]!;
      if (uses.isNotEmpty) {
        // Prefer a kWh that sits on the same line as a rate ("312 kWh x
        // 26.32p") — that is the billed quantity.
        final withRate = uses.where(
          (h) => RegExp(
            r'(?:x|@|at)\s*[\d.]+\s*p',
            caseSensitive: false,
          ).hasMatch(h.line),
        );
        final chosen = withRate.isNotEmpty ? withRate.first : uses.first;
        fields[kwhKey] = ParsedField(
          key: kwhKey,
          value: chosen.value,
          sourceSnippet: chosen.line,
          confidence: withRate.isNotEmpty
              ? ParseConfidence.high
              : ParseConfidence.low,
        );
      }
    }

    pick('single', ParsedFieldKey.unitRateSingle, ParsedFieldKey.kwhSingle);
    pick('day', ParsedFieldKey.unitRateDay, ParsedFieldKey.kwhDay);
    pick('night', ParsedFieldKey.unitRateNight, ParsedFieldKey.kwhNight);

    // If day/night were found, a "single" match is usually a subtotal.
    if (fields.containsKey(ParsedFieldKey.kwhDay) &&
        fields.containsKey(ParsedFieldKey.kwhNight)) {
      fields.remove(ParsedFieldKey.kwhSingle);
      fields.remove(ParsedFieldKey.unitRateSingle);
    }

    return ParseResult(fields, notes);
  }

  void _parsePeriod(String text, Map<ParsedFieldKey, ParsedField> fields) {
    final month = r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?';
    // "1 Sep 2026 - 30 Sep 2026" / "01 September 2026 to 30 September 2026"
    final named = RegExp(
      '(\\d{1,2})(?:st|nd|rd|th)?\\s+$month\\s*(\\d{4})?\\s*(?:-|to|until)\\s*'
      '(\\d{1,2})(?:st|nd|rd|th)?\\s+$month\\s*(\\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      final endYear = int.parse(named.group(6)!);
      final startMonth =
          _months[named.group(2)!.toLowerCase().substring(0, 3)]!;
      final endMonth = _months[named.group(5)!.toLowerCase().substring(0, 3)]!;
      final startYear = named.group(3) != null
          ? int.parse(named.group(3)!)
          : (startMonth > endMonth ? endYear - 1 : endYear);
      _addPeriod(
        fields,
        DateTime.utc(startYear, startMonth, int.parse(named.group(1)!)),
        DateTime.utc(endYear, endMonth, int.parse(named.group(4)!)),
        named.group(0)!,
      );
      return;
    }
    // "01/09/2026 - 30/09/2026" (UK day-first)
    final numeric = RegExp(
      r'(\d{1,2})/(\d{1,2})/(\d{2,4})\s*(?:-|to|until)\s*(\d{1,2})/(\d{1,2})/(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (numeric != null) {
      int year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
      _addPeriod(
        fields,
        DateTime.utc(
          year(numeric.group(3)!),
          int.parse(numeric.group(2)!),
          int.parse(numeric.group(1)!),
        ),
        DateTime.utc(
          year(numeric.group(6)!),
          int.parse(numeric.group(5)!),
          int.parse(numeric.group(4)!),
        ),
        numeric.group(0)!,
      );
    }
  }

  void _addPeriod(
    Map<ParsedFieldKey, ParsedField> fields,
    DateTime start,
    DateTime end,
    String snippet,
  ) {
    // Reject impossible dates that DateTime silently rolls over (31/02).
    if (end.isBefore(start)) return;
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    fields[ParsedFieldKey.periodStart] = ParsedField(
      key: ParsedFieldKey.periodStart,
      value: iso(start),
      sourceSnippet: snippet,
      confidence: ParseConfidence.high,
    );
    fields[ParsedFieldKey.periodEnd] = ParsedField(
      key: ParsedFieldKey.periodEnd,
      value: iso(end),
      sourceSnippet: snippet,
      confidence: ParseConfidence.high,
    );
  }
}

class _Hit {
  _Hit(this.value, this.line);
  final String value;
  final String line;
}
