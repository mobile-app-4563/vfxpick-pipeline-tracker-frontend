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

/// Parses a named month ("May", "may", "MAR") into 1–12, or 0 when unknown.
int _monthNumber(String name) {
  return _monthNamesLower.indexOf(name.toLowerCase()) + 1;
}

/// Shared ISO conversion for an Excel/CSV cell value.
///
/// Handles every `CellValue` subtype the excel package produces:
/// `DateCellValue` / `DateTimeCellValue` (exact y/m/d), `IntCellValue` /
/// `DoubleCellValue` / raw `num` (serial), `TimeCellValue` (time-only → null),
/// `TextCellValue` (plain text), plus every common date text format. Returns
/// `null` — never a partial value — when the input cannot be a date.
String? excelDateToIso(dynamic value) {
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
  final numericText = num.tryParse(text);
  if (numericText != null) {
    if (numericText < _minSerial || numericText > _maxSerial) return null;
    return _iso(_fromExcelSerial(numericText));
  }

  // ISO / standard formats ("2025-05-01", "2025-05-01T00:00:00.000Z").
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return _iso(parsed);
  }

  // dd-MM-yyyy / dd/MM/yyyy / dd.MM.yyyy (day-first, common in VFX sheets).
  final dayFirst = RegExp(
    r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$',
  ).firstMatch(text);
  if (dayFirst != null) {
    final first = int.parse(dayFirst.group(1)!);
    final second = int.parse(dayFirst.group(2)!);
    final year = int.parse(dayFirst.group(3)!);
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
    return _iso(DateTime(year, month, day));
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
    return _iso(DateTime(year, month, day));
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
    return _iso(DateTime(year, month, day));
  }

  // "May 2025" / "May-25" / "May 25" (month-year only → the 1st of the month,
  // exactly like the template's mmm-yy cells).
  final monthYear = RegExp(
    r'^([A-Za-z]{3,9})[-/.\s](\d{2,4})$',
  ).firstMatch(text);
  if (monthYear != null) {
    final month = _monthNumber(monthYear.group(1)!);
    final yearRaw = int.parse(monthYear.group(2)!);
    final year = yearRaw < 100 ? _resolveTwoDigitYear(yearRaw) : yearRaw;
    if (month < 1 || month > 12) return null;
    return _iso(DateTime(year, month, 1));
  }

  return null;
}

/// "May-25" style label for a month-year (day == 1) date.
String monthYearLabel(DateTime d) =>
    '${_monthAbbreviations[d.month - 1]}-${d.year.toString().padLeft(2, '0').substring(2)}';

/// Formats a date exactly the way the Excel template shows it: month-year
/// data (day == 1) becomes "May-25"; full dates stay `yyyy-MM-dd`.
/// Returns an empty string for null/invalid input.
String formatDateLikeExcel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  if (d.day == 1) return monthYearLabel(d);
  return _iso(d);
}

/// [formatDateLikeExcel] for an already-parsed [DateTime].
String formatDateLikeExcelD(DateTime? d) {
  if (d == null) return '';
  if (d.day == 1) return monthYearLabel(d);
  return _iso(d);
}
