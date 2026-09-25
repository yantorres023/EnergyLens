import '../domain/fixed_point.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _group(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// £1,234.56 / −£12.00. Integer-only; no floating point.
String money(int pence, {bool signed = false}) {
  final neg = pence < 0;
  final p = pence.abs();
  final body = '£${_group(p ~/ 100)}.${(p % 100).toString().padLeft(2, '0')}';
  if (neg) return '−$body';
  if (signed && pence > 0) return '+$body';
  return body;
}

/// "26.32p" from milli-pence.
String pence(int milliPence) => '${formatMilli(milliPence, minDecimals: 2)}p';

/// "11.5 kWh" from milli-kWh, one decimal.
String kwh(int milliKwh, {int decimals = 1}) {
  final neg = milliKwh < 0;
  final v = milliKwh.abs();
  var body = '';
  if (decimals == 0) {
    body = _group(divRoundHalfAwayFromZero(v, 1000));
  } else {
    final tenths = divRoundHalfAwayFromZero(v, 100);
    body = '${_group(tenths ~/ 10)}.${tenths % 10}';
  }
  return '${neg ? '−' : ''}$body kWh';
}

/// "12.5%" from per-mille.
String percentFromPermille(int permille) {
  final neg = permille < 0;
  final v = permille.abs();
  final whole = v ~/ 10;
  final frac = v % 10;
  return '${neg ? '−' : ''}$whole${frac == 0 ? '' : '.$frac'}%';
}

String percentFromBasisPoints(int bp) {
  final whole = bp ~/ 100;
  final frac = bp % 100;
  if (frac == 0) return '$whole%';
  return '$whole.${frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}%';
}

String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String dateRange(DateTime a, DateTime b) {
  if (a.year == b.year) {
    return '${a.day} ${_months[a.month - 1]} – ${date(b)}';
  }
  return '${date(a)} – ${date(b)}';
}
