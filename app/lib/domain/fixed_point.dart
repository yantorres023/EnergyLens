/// Deterministic fixed-point helpers.
///
/// All money is held as integer **pence**. Quantities and rates that need
/// decimals are held as integer **milli-units** (value × 1000):
///
/// * energy: milli-kWh (1 kWh = 1000)
/// * unit rate: milli-pence per kWh (26.32 p/kWh = 26320)
/// * standing charge: milli-pence per day (54.83 p/day = 54830)
///
/// No floating point is used on any path that produces a bill amount.
library;

const int milli = 1000;

/// Divides [numerator] by [denominator] rounding half away from zero.
///
/// This matches the "round to the nearest penny" convention printed on GB
/// bills and is symmetric for credits (negative values).
int divRoundHalfAwayFromZero(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError('denominator must not be zero');
  }
  final negative = (numerator < 0) != (denominator < 0);
  final n = numerator.abs();
  final d = denominator.abs();
  final q = n ~/ d;
  final r = n % d;
  final rounded = (r * 2 >= d) ? q + 1 : q;
  return negative ? -rounded : rounded;
}

/// Cost in pence of [quantityMilli] × [rateMilliPence].
///
/// quantity (×1000) × rate (×1000) = pence × 1,000,000.
int costPence(int quantityMilli, int rateMilliPence) {
  return divRoundHalfAwayFromZero(quantityMilli * rateMilliPence, 1000000);
}

/// Parses a decimal string such as `"26.32"`, `"54.8"` or `"-3"` into
/// milli-units without going through floating point.
///
/// Returns `null` for anything that is not a plain decimal number. More than
/// three decimal places are rounded half away from zero.
int? parseMilli(String input) {
  var s = input.trim().replaceAll(',', '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(s)) return null;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
  var frac = parts.length > 1 ? parts[1] : '';
  var value = whole * milli;
  if (frac.isNotEmpty) {
    final extra = frac.length > 3 ? frac.substring(3) : '';
    frac = frac.length > 3 ? frac.substring(0, 3) : frac.padRight(3, '0');
    value += int.parse(frac);
    if (extra.isNotEmpty && int.parse(extra[0]) >= 5) value += 1;
  }
  return negative ? -value : value;
}

/// Parses a money string in pounds (e.g. `"£123.45"`, `"123.4"`, `"-5"`)
/// into pence. Returns `null` if unparseable.
int? parsePoundsToPence(String input) {
  var s = input.trim().replaceAll('£', '').replaceAll(',', '').trim();
  var negative = false;
  // Bills commonly print credits as "£12.00 CR" or "(12.00)".
  final upper = s.toUpperCase();
  if (upper.endsWith('CR')) {
    negative = true;
    s = s.substring(0, s.length - 2).trim();
  }
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  final m = parseMilli(s);
  if (m == null) return null;
  // milli-pounds → pence: divide by 10 with rounding.
  final pence = divRoundHalfAwayFromZero(m, 10);
  return negative ? -pence.abs() : pence;
}

/// Formats milli-units as a trimmed decimal string (26320 → "26.32").
String formatMilli(int value, {int minDecimals = 0}) {
  final negative = value < 0;
  final v = value.abs();
  final whole = v ~/ milli;
  var frac = (v % milli).toString().padLeft(3, '0');
  while (frac.length > minDecimals && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final body = frac.isEmpty ? '$whole' : '$whole.$frac';
  return negative ? '-$body' : body;
}
