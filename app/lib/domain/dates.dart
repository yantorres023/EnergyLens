/// Calendar-date helpers.
///
/// Billing periods are calendar dates, not instants. Every date is normalised
/// to UTC midnight so that day counts never drift across the GB clock changes
/// (last Sunday of March / October), when a local-time day is 23 or 25 hours.
library;

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Number of days from [start] to [end], **both inclusive**, which is how GB
/// bills count days for standing charges ("1 Sep – 30 Sep: 30 days").
int inclusiveDays(DateTime start, DateTime end) {
  final s = dateOnly(start);
  final e = dateOnly(end);
  return e.difference(s).inDays + 1;
}

String isoDate(DateTime d) {
  final u = dateOnly(d);
  final m = u.month.toString().padLeft(2, '0');
  final day = u.day.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-$m-$day';
}

DateTime parseIsoDate(String s) {
  final parts = s.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected yyyy-mm-dd', s);
  }
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  final result = DateTime.utc(y, m, d);
  if (result.year != y || result.month != m || result.day != d) {
    throw FormatException('Invalid calendar date', s);
  }
  return result;
}

bool isWithin(DateTime day, DateTime start, DateTime end) {
  final d = dateOnly(day);
  return !d.isBefore(dateOnly(start)) && !d.isAfter(dateOnly(end));
}

/// Meteorological season index used only for "seasons differ" caveats:
/// 0 = winter (Dec–Feb), 1 = spring, 2 = summer, 3 = autumn.
int seasonOf(DateTime d) {
  switch (d.month) {
    case 12:
    case 1:
    case 2:
      return 0;
    case 3:
    case 4:
    case 5:
      return 1;
    case 6:
    case 7:
    case 8:
      return 2;
    default:
      return 3;
  }
}

/// The date halfway through a period, used to decide which season a bill
/// mostly belongs to.
DateTime midpoint(DateTime start, DateTime end) {
  final days = inclusiveDays(start, end);
  return dateOnly(start).add(Duration(days: (days - 1) ~/ 2));
}
