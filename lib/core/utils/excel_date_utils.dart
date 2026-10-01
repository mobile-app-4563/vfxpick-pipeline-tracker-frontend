import 'package:excel/excel.dart';

/// Shared date handling for Excel/CSV imports and grid displays.
///
/// The production template stores ETA / Shots-Received-Date cells with an
/// `mmm-yy` number format — Excel *displays* "May-25" / "Mar-30" even though
/// the underlying cell holds the 1st of a month. Those cells are a genuine
/// trap: the label is a month/day ("May 25") but the value carries a year
/// ("May 2025"), so reading the cell literally gives the wrong date. Shots
/// Received Date really is month/year; **ETA is always a day**.
///
/// This file centralises three rules:
///
/// 1. [excelDateToIso] — bulletproof conversion of any Excel/CSV cell value
///    (all `CellValue` subclasses, numeric serials, and common text formats)
///    into an exact `yyyy-MM-dd` string, returning `null` for anything that
///    is NOT a valid date (never raw garbage text). It reads cells literally,
///    so it is right for Shots Received Date and wrong for ETA.
/// 2. [formatDateLikeExcel] — display formatter that mirrors what Excel
///    shows: month-year data (day == 1) renders as "May-25", full dates keep
///    their day ("2025-05-15").
/// 3. [excelEtaToIso] — the ETA rule, used for **every** ETA column. An ETA
///    is month/day, so a `mmm-yy` cell holding 1 Aug 2025 becomes 25 Aug of
///    the current year (Excel's "Aug-25" is the 25th of August, not 2025).
///    Without this, ETAs rendered as "Aug-26" and opened the date picker on
///    the 1st of the month.
///
/// Excel serial dates count days since 1899-12-30 (the fake 1900 leap year).
final DateTime _excelEpoch = DateTime(1899, 12, 30);

/// Lower bound for a plausible Excel date serial (1900-01-01).
const int _minSerial = 1;

/// Upper bound for a plausible Excel date serial (≈ 2091-12-31).
const int _maxSerial = 69999;

/// Formats [date] as `yyyy-MM-dd` (matches the backend `to_iso` output).
String _iso(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Month abbreviations used by the "MMM-YY" display format.
const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthNamesLower = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// Converts an Excel serial number (days since 1899-12-30) to a [DateTime].
DateTime _fromExcelSerial(num serial) {
  return _excelEpoch.add(Duration(days: serial.floor()));
}

/// Resolves an Excel-style 2-digit year ("25" → 2025, "30" → 1930) using the
/// same 1930–2029 window Excel itself applies.
int _resolveTwoDigitYear(int yy) => yy >= 30 ? 1900 + yy : 2000 + yy;

/// Parses a named month ("May", "may", "MAR", "March", "September") into
/// 1–12, or 0 when unknown. Full month names are matched by their first
/// three letters, so "September" / "Sept" both resolve to 9.
int _monthNumber(String name) {
  final clean = name.trim().toLowerCase();
  if (clean.length < 3) return 0;
  return _monthNamesLower.indexOf(clean.substring(0, 3)) + 1;
}

/// Shared ISO conversion for an Excel/CSV cell value.
///
/// Handles every `CellValue` subtype the excel package produces:
/// `DateCellValue` / `DateTimeCellValue` (exact y/m/d), `IntCellValue` /
/// `DoubleCellValue` / raw `num` (serial), `TimeCellValue` (time-only → null),
/// `TextCellValue` (plain text), plus every common date text format. Returns
/// `null` — never a partial value — when the input cannot be a date.
///
/// [monthYearFirst] resolves the classic "MMM-NN" ambiguity:
/// * `false` (**default — every grid date column**): the years are always
///   skipped, only the month and the day are kept. A 1–2 digit number that
///   follows a month is therefore the **DAY of the current year**, whatever
///   the separator or month spelling: "Sep-01", "05-25", "3/26", "7/18"
///   all resolve to that day in the running year.
/// * `true` (only used by the grid header filters): "May-25" → **May 1st
///   2025** — the template's `mmm-yy` format is always the 1st of the month,
///   so a 2-digit number is read as a year.
/// In BOTH modes a 4-digit number ("May-2025", "5/2026") is a real year → the
/// 1st of the month, and so is a 2-digit number that cannot be a day
/// ("May-99", "7/45").
String? excelDateToIso(dynamic value, {bool monthYearFirst = false}) {
  if (value == null) return null;

  // ── Native cell values from the excel package ──────────────────────────
  if (value is DateCellValue) {
    return _iso(DateTime(value.year, value.month, value.day));
  }
  if (value is DateTimeCellValue) {
    return _iso(DateTime(value.year, value.month, value.day));
  }
  if (value is TimeCellValue) {
    // Time-only (h:mm) cells are durations, not dates.
    return null;
  }
  if (value is DateTime) {
    return _iso(value);
  }

  num? serial;
  if (value is num) {
    serial = value;
  } else if (value is IntCellValue) {
    serial = value.value;
  } else if (value is DoubleCellValue) {
    serial = value.value;
  }
  if (serial != null) {
    if (serial < _minSerial || serial > _maxSerial) return null;
    return _iso(_fromExcelSerial(serial));
  }

  // ── Text values (TextCellValue.toString() is the plain text) ───────────
  final text = value.toString().trim();
  if (text.isEmpty) return null;

  // Numeric text (e.g. "45783" from an unformatted cell) → serial date.
  // A bare 4-digit year ("2025") is a YEAR, not a serial, and "2025.05" /
  // "2025/05" are YEAR-FIRST dates, not serials — both fall through to the
  // date-format regexes below instead of becoming tiny (1905-era) serials.
  final numericText = num.tryParse(text);
  if (numericText != null) {
    if (text.length == 4 && text[0] != '-') {
      final year = numericText.toInt();
      if (year >= 1000 && year <= 9999) return _iso(DateTime(year, 1, 1));
    }
    if (!RegExp(r'^\d{4}[-/.]').hasMatch(text)) {
      if (numericText < _minSerial || numericText > _maxSerial) return null;
      return _iso(_fromExcelSerial(numericText));
    }
  }

  // ISO / standard formats ("2025-05-01", "2025-05-01T00:00:00.000Z").
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return _iso(parsed);
  }

  // yyyy-MM-dd with slash/dot separators ("2025/05/01", "2025.05.01").
  final isoSlash = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$')
      .firstMatch(text);
  if (isoSlash != null) {
    final year = int.parse(isoSlash.group(1)!);
    final month = int.parse(isoSlash.group(2)!);
    final day = int.parse(isoSlash.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day);
    if (dt.day != day) return null;
    return _iso(dt);
  }

  // yyyy-MM (year + month only → the 1st of the month).
  final yearMonth = RegExp(r'^(\d{4})[-/.](\d{1,2})$').firstMatch(text);
  if (yearMonth != null) {
    final year = int.parse(yearMonth.group(1)!);
    final month = int.parse(yearMonth.group(2)!);
    if (month < 1 || month > 12) return null;
    return _iso(DateTime(year, month, 1));
  }

  // dd-MM-yyyy / dd/MM/yyyy / dd.MM.yyyy (day-first, common in VFX sheets)
  // — with 2-digit years ("01-05-25", "25/5/25") resolved via Excel's
  // 1930–2029 window.
  final dayFirst = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$')
      .firstMatch(text);
  if (dayFirst != null) {
    final first = int.parse(dayFirst.group(1)!);
    final second = int.parse(dayFirst.group(2)!);
    var year = int.parse(dayFirst.group(3)!);
    if (year < 100) year = _resolveTwoDigitYear(year);
    int day, month;
    if (first > 12 && second <= 12) {
      day = first;
      month = second;
    } else if (second > 12 && first <= 12) {
      day = second;
      month = first;
    } else {
      day = first;
      month = second; // ambiguous → treat as day-first
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day);
    if (dt.day != day) return null;
    return _iso(dt);
  }

  // "25 May 2025" / "25-May-2025" / "25 May 25" (day + named month + year).
  final dayNamed = RegExp(r'^(\d{1,2})[-/.\s]([A-Za-z]{3,9})[-/.\s](\d{2,4})$')
      .firstMatch(text);
  if (dayNamed != null) {
    final day = int.parse(dayNamed.group(1)!);
    final month = _monthNumber(dayNamed.group(2)!);
    final yearRaw = int.parse(dayNamed.group(3)!);
    final year = yearRaw < 100 ? _resolveTwoDigitYear(yearRaw) : yearRaw;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day);
    if (dt.day != day) return null;
    return _iso(dt);
  }

  // "May 25, 2025" / "May 25 2025" (named month + day + year).
  final namedDay = RegExp(r'^([A-Za-z]{3,9})[-/.\s](\d{1,2})[,.\s]+(\d{2,4})$')
      .firstMatch(text);
  if (namedDay != null) {
    final month = _monthNumber(namedDay.group(1)!);
    final day = int.parse(namedDay.group(2)!);
    final yearRaw = int.parse(namedDay.group(3)!);
    final year = yearRaw < 100 ? _resolveTwoDigitYear(yearRaw) : yearRaw;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day);
    if (dt.day != day) return null;
    return _iso(dt);
  }

  // Numeric month + number ("05-2025", "5/2025", "05-25", "3/26", "7/18").
  //
  // This is the numeric twin of the "MMM-NN" case below and MUST follow the
  // same rule: the years are always skipped, so a 1–2 digit number is the DAY
  // of the current year. Reading "7/18" as July 2018 (the 1st!) is exactly how
  // every imported date ended up showing a YEAR instead of a day, so the
  // 2-digit day branch is deliberately checked before any year interpretation.
  final numericMonthYear = RegExp(r'^(\d{1,2})[-/.\s](\d{1,4})$')
      .firstMatch(text);
  if (numericMonthYear != null) {
    final month = int.parse(numericMonthYear.group(1)!);
    final rawNumber = numericMonthYear.group(2)!;
    var number = int.parse(rawNumber);
    if (month < 1 || month > 12) return null;

    if (monthYearFirst) {
      // Header-filter mode: a 2-digit number is a YEAR ("May-25" = 2025).
      if (number == 0) return null;
      if (number < 100) number = _resolveTwoDigitYear(number);
      return _iso(DateTime(number, month, 1));
    }

    // Default mode — a 1–2 digit number is the DAY.
    if (rawNumber.length <= 2) {
      if (number < 1 || number > 31) return null;
      final now = DateTime.now();
      final day = DateTime(now.year, month, number);
      // Reject impossible days ("2/30" would roll over to March).
      if (day.month != month || day.day != number) return null;
      return _iso(day);
    }

    // 3–4 digit number → a real year ("5/2026") → the 1st of the month.
    if (number == 0) return null;
    if (number < 100) number = _resolveTwoDigitYear(number);
    return _iso(DateTime(number, month, 1));
  }

  // "Sep-01" (MMM-DD, no year) → a day of the CURRENT year by default (the
  // daily "today pickout" files type ETA as month-abbrev + day), or the 1st
  // of the month when [monthYearFirst] is set (production mmm-yy template).
  //
  // "May 2025" / "May-25" / "May 25" (month-year only → the 1st of the
  // month, exactly like the template's mmm-yy cells) still works when the
  // number is a real year (4 digits, or 2 digits > 31).
  final monthYear = RegExp(r'^([A-Za-z]{3,9})[-/.\s](\d{1,4})$')
      .firstMatch(text);
  if (monthYear != null) {
    final month = _monthNumber(monthYear.group(1)!);
    if (month < 1 || month > 12) return null;
    final value = int.parse(monthYear.group(2)!);
    if (monthYearFirst) {
      // Production template: "May-25" / "Mar-30" → the 1st of the month.
      if (value == 0) return null;
      final year = value < 100 ? _resolveTwoDigitYear(value) : value;
      return _iso(DateTime(year, month, 1));
    }
    if (value >= 1 && value <= 31) {
      // "MMM-DD" — a day in the current year (daily pickout files).
      final now = DateTime.now();
      final dt = DateTime(now.year, month, value);
      // Reject impossible days like Feb 30 (DateTime would roll them over).
      if (dt.day != value) return null;
      return _iso(dt);
    }
    if (value == 0) return null;
    final year = value < 100 ? _resolveTwoDigitYear(value) : value;
    return _iso(DateTime(year, month, 1));
  }

  // "5-May" / "01-May" (day + named month, no year) → day of the current
  // year (mirrors the MMM-DD daily pickout convention).
  final dayMonth = RegExp(r'^(\d{1,2})[-/.\s]([A-Za-z]{3,9})$')
      .firstMatch(text);
  if (dayMonth != null) {
    final day = int.parse(dayMonth.group(1)!);
    final month = _monthNumber(dayMonth.group(2)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final now = DateTime.now();
    final dt = DateTime(now.year, month, day);
    if (dt.day != day) return null;
    return _iso(dt);
  }

  return null;
}

/// Parses an Excel/CSV date and replaces its year with the current year while
/// preserving its month and day. Returns null when that month/day is invalid
/// in the current year (for example, February 29 in a non-leap year).
String? excelDateToCurrentYearIso(dynamic value, {DateTime? now}) {
  final parsed = excelDateToIso(value);
  if (parsed == null) return null;
  final date = DateTime.tryParse(parsed);
  if (date == null) return null;

  final year = now?.year ?? DateTime.now().year;
  final rebased = DateTime(year, date.month, date.day);
  if (rebased.month != date.month || rebased.day != date.day) return null;
  return _iso(rebased);
}

/// Matches a bare number ("45870"), i.e. an Excel serial rather than a date
/// string ("Aug-25", "25/08/2025").
final RegExp _bareNumber = RegExp(r'^\d+(\.\d+)?$');

/// True when [value] is a *calendar* value — a real date, an Excel serial, or
/// a bare number — rather than a typed date string.
///
/// ETA columns are the only place this distinction matters. Excel stores
/// "Aug-25" in an ETA cell as the **date 1 Aug 2025** with a `mmm-yy` number
/// format, so the cell carries a year where the data means a day. A typed
/// string ("Aug-25") already carries the day and needs no such translation.
bool _isCalendarEtaValue(dynamic value) {
  if (value is DateCellValue ||
      value is DateTimeCellValue ||
      value is DateTime ||
      value is num ||
      value is IntCellValue ||
      value is DoubleCellValue) {
    return true;
  }
  final text = value?.toString().trim() ?? '';
  return text.isNotEmpty && _bareNumber.hasMatch(text);
}

/// Parses a cell from an **ETA column** into `yyyy-MM-dd` under the rule
/// "month / day — never month / year".
///
/// An ETA is always a day: "Aug-25" means the 25th of August, and never
/// August 2025. Excel, however, stores those cells as real dates with the
/// `mmm-yy` format, so "Aug-25" arrives as 1 Aug 2025 and a naive parse reads
/// the two-digit number as a year. That is why ETAs rendered as month-year
/// labels and opened the date picker on the 1st of the month.
///
/// 1. Parse the value with [excelDateToIso].
/// 2. When the parse landed on the 1st of a month *and* the cell was a
///    calendar value, re-read the year's last two digits as the DAY, so
///    1 Aug 2025 becomes 25 Aug. A two-digit number that cannot be a day in
///    that month (00, 32–99, 31 April) leaves the 1st in place rather than
///    inventing a day. Typed strings are left alone because their number is
///    already a day.
/// 3. Re-base the year onto the current year — an ETA only ever means a
///    month/day in the running year.
///
/// Returns `null` when the value is not a date at all, or when the resulting
/// day does not exist in the current year (29 February in a non-leap year).
String? excelEtaToIso(dynamic value, {DateTime? now}) {
  final parsed = excelDateToIso(value);
  if (parsed == null) return null;
  final date = DateTime.tryParse(parsed);
  if (date == null) return null;

  var day = date.day;
  if (day == 1 && _isCalendarEtaValue(value)) {
    final fromYear = date.year % 100;
    // Year 2000 is a leap year, so month-length validation accepts Feb 29.
    if (fromYear >= 1 &&
        fromYear <= 31 &&
        DateTime(2000, date.month, fromYear).month == date.month) {
      day = fromYear;
    }
  }

  final year = now?.year ?? DateTime.now().year;
  final result = DateTime(year, date.month, day);
  if (result.month != date.month || result.day != day) return null;
  return _iso(result);
}

/// Repairs a date that was **stored before the day/month rule was fixed**.
///
/// An older import read the Excel `mmm-yy` / `M/YY` cells literally, so a value
/// that meant "the 25th of August" was saved as `2025-08-01` — the 1st of
/// August in a meaningless year. That is why every stored grid date rendered as
/// a month-year label ("Aug-25"), which reads as the year 2025 instead of a day.
///
/// The intended day is still recoverable: it is the year's last two digits
/// (`2025` → 25, `1930` → 30, `2018` → 18), which is exactly the rule
/// [excelEtaToIso] applies to a fresh import. Repairing the stored values with
/// it makes existing rows identical to what a re-import now produces, so the
/// grid shows the real day without a database migration.
///
/// Values that are empty, unparseable, not on the 1st of a month, whose
/// two-digit year cannot be a day of that month (00/01, 32–99, 31 April), or
/// that would not exist in the running year are returned **unchanged** — the
/// repair never invents a day and never drops a date.
String? repairStoredMonthDayIso(String? iso) {
  if (iso == null || iso.isEmpty) return iso;
  final date = DateTime.tryParse(iso);
  if (date == null || date.day != 1) return iso;

  final fromYear = date.year % 100;
  // 00/01 carry no recoverable day (they are the 1st either way).
  if (fromYear < 2 || fromYear > 31) return iso;
  // Year 2000 is a leap year, so month-length validation accepts Feb 29.
  if (DateTime(2000, date.month, fromYear).month != date.month) return iso;

  final repaired = DateTime(DateTime.now().year, date.month, fromYear);
  if (repaired.month != date.month || repaired.day != fromYear) return iso;
  return _iso(repaired);
}

/// Applies [repairStoredMonthDayIso] to the date [keys] of a stored row,
/// returning the original map untouched when nothing needed repairing.
Map<String, dynamic> repairStoredRowDates(
  Map<String, dynamic> row,
  Iterable<String> keys,
) {
  Map<String, dynamic>? copy;
  for (final key in keys) {
    final current = row[key];
    if (current is! String) continue;
    final repaired = repairStoredMonthDayIso(current);
    if (repaired != current) {
      copy ??= Map<String, dynamic>.from(row);
      copy[key] = repaired;
    }
  }
  return copy ?? row;
}

String monthYearLabel(DateTime d) =>
    '${_monthAbbreviations[d.month - 1]}-${d.year.toString().padLeft(2, '0').substring(2)}';

String monthDayLabel(DateTime d) =>
    '${_monthAbbreviations[d.month - 1]}-${d.day.toString().padLeft(2, '0')}';

/// Grid display formatter — **always** month + day ("Aug-20"), never a year.
///
/// The years are always skipped across the whole app, so a date is only ever
/// shown by the month and the day it falls on. A date that landed on the 1st
/// (an unavoidable side effect of reading an Excel `mmm-yy` / `M/YY` cell)
/// therefore renders as "Aug-01" rather than the misleading "Aug-26"
/// month-year label, which looked like the year 2026.
String formatDateLikeExcel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return monthDayLabel(d);
}

/// [formatDateLikeExcel] for an already-parsed [DateTime].
String formatDateLikeExcelD(DateTime? d) => d == null ? '' : monthDayLabel(d);
