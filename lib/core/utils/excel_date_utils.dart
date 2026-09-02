import 'package:excel/excel.dart';

/// Shared date handling for Excel/CSV imports and grid displays.
///
/// The production template stores ETA / Shots-Received-Date cells with an
/// `mmm-yy` number format — Excel displays "May-25" / "Mar-30" but the
/// underlying value is always the 1st of the month (day == 1). Grids used to
/// render those as "May 1" / "Mar 1", which looked like a corrupt "1st date".
/// This file centralises two rules:
///
/// 1. [excelDateToIso] — bulletproof conversion of any Excel/CSV cell value
///    (all `CellValue` subclasses, numeric serials, and common text formats)
///    into an exact `yyyy-MM-dd` string, returning `null` for anything that
///    is NOT a valid date (never raw garbage text).
/// 2. [formatDateLikeExcel] — display formatter that mirrors what Excel
///    shows: month-year data (day == 1) renders as "May-25", full dates keep
///    their day ("2025-05-15").
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
/// * `false` (default, daily pickout files): "Sep-01" → September 1st of the
///   **current** year (the pickouts page types ETA as month-abbrev + day).
/// * `true` (production template, `mmm-yy` cells): "May-25" → **May 1st 2025**
///   (the template's `mmm-yy` format is always the 1st of the month, so a
///   2-digit number is a year, never a day).
/// In BOTH modes a 4-digit number ("May-2025") or a 2-digit number outside the
/// 01–31 day range ("May-99") is a year → the 1st of the month.
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
  final isoSlash = RegExp(
    r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$',
  ).firstMatch(text);
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
  final dayFirst = RegExp(
    r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
  ).firstMatch(text);
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
  final dayNamed = RegExp(
    r'^(\d{1,2})[-/.\s]([A-Za-z]{3,9})[-/.\s](\d{2,4})$',
  ).firstMatch(text);
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
  final namedDay = RegExp(
    r'^([A-Za-z]{3,9})[-/.\s](\d{1,2})[,.\s]+(\d{2,4})$',
  ).firstMatch(text);
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

  // Numeric month-year ("05-2025", "5/2025", "05-25") → the 1st of the
  // month. "05-25" is the numeric twin of the template's "May-25".
  final numericMonthYear = RegExp(
    r'^(\d{1,2})[-/.\s](\d{2,4})$',
  ).firstMatch(text);
  if (numericMonthYear != null) {
    final month = int.parse(numericMonthYear.group(1)!);
    var year = int.parse(numericMonthYear.group(2)!);
    if (month < 1 || month > 12) return null;
    if (year < 100) year = _resolveTwoDigitYear(year);
    return _iso(DateTime(year, month, 1));
  }

  // "Sep-01" (MMM-DD, no year) → a day of the CURRENT year by default (the
  // daily "today pickout" files type ETA as month-abbrev + day), or the 1st
  // of the month when [monthYearFirst] is set (production mmm-yy template).
  //
  // "May 2025" / "May-25" / "May 25" (month-year only → the 1st of the
  // month, exactly like the template's mmm-yy cells) still works when the
  // number is a real year (4 digits, or 2 digits > 31).
  final monthYear = RegExp(
    r'^([A-Za-z]{3,9})[-/.\s](\d{1,4})$',
  ).firstMatch(text);
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
  final dayMonth = RegExp(
    r'^(\d{1,2})[-/.\s]([A-Za-z]{3,9})$',
  ).firstMatch(text);
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

String monthYearLabel(DateTime d) =>
    '${_monthAbbreviations[d.month - 1]}-${d.year.toString().padLeft(2, '0').substring(2)}';

String monthDayLabel(DateTime d) =>
    '${_monthAbbreviations[d.month - 1]}-${d.day.toString().padLeft(2, '0')}';

String formatDateLikeExcel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  if (d.year == DateTime.now().year) return monthDayLabel(d);
  if (d.day == 1) return monthYearLabel(d);
  return _iso(d);
}

/// [formatDateLikeExcel] for an already-parsed [DateTime].
String formatDateLikeExcelD(DateTime? d) {
  if (d == null) return '';
  if (d.year == DateTime.now().year) return monthDayLabel(d);
  if (d.day == 1) return monthYearLabel(d);
  return _iso(d);
}
