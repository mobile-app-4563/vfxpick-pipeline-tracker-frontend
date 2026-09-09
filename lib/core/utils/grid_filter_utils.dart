import 'excel_date_utils.dart';

/// Shared text matching used by every grid header filter in the app.
///
/// The header filters receive whatever the user typed and must match:
///  * **Text columns** case-insensitively.
///  * **Date columns** no matter which representation the user types — the
///    raw stored value ("2025-05-01"), the Excel-style label the grid shows
///    ("May-25"), or a variant with different punctuation/whitespace
///    ("may 25", "05/2025", "2025-05-01T00:00:00").
///  * **Numeric columns** without ever treating a bare number (frame counts,
///    man-days, bids…) as an Excel date serial.
///
/// Matching is deliberately permissive:
///   1. plain case-insensitive substring against the raw cell text;
///   2. substring again after stripping punctuation/whitespace on both sides
///      ("1,000" == "1000", "May-25" == "may 25", "10/05/2025" ==
///      "10-05-2025");
///   3. when the cell actually holds a date, match against its ISO form and
///      its Excel-style rendered label too.
bool gridTextContains(dynamic cell, String query) {
  final rawQuery = query.trim();
  if (rawQuery.isEmpty) return true;
  if (cell == null) return false;

  final text = cell.toString();
  if (text.trim().isEmpty) return false;

  final q = rawQuery.toLowerCase();
  final lowerText = text.toLowerCase();
  if (lowerText.contains(q)) return true;

  // Punctuation / whitespace-insensitive pass — lets users type what they
  // see even when they use a different separator ("May-25" vs "may 25",
  // "10/05/2025" vs "10-05-2025", "1,000" vs "1000", "Inhouse / FL" vs
  // "Inhouse/FL").
  final compactCell = _compact(lowerText);
  final compactQuery = _compact(q);
  if (compactQuery.isNotEmpty && compactCell.contains(compactQuery)) {
    return true;
  }

  // Date-aware pass: cells are often stored as ISO ("2025-05-01") but shown
  // to the user as Excel-style labels ("May-25"). Accept either form, again
  // with the punctuation/whitespace-insensitive pass applied to each form so
  // "may 25" matches "May-25".
  final date = _cellAsDate(cell);
  if (date != null) {
    final iso = _iso(date);
    final label = formatDateLikeExcelD(date);
    for (final form in <String>[iso, label]) {
      final lowerForm = form.toLowerCase();
      if (lowerForm.contains(q) ||
          (compactQuery.isNotEmpty &&
              _compact(lowerForm).contains(compactQuery))) {
        return true;
      }
    }
  }
  return false;
}

/// Case-insensitive equality used by single-select / dropdown header filters
/// (status, supervisor status, artist status…) so "wip" matches "WIP" and
/// "Inhouse/fl" matches "Inhouse / FL" (whitespace is ignored, matching the
/// chip-label normalizers used by the other grids). An empty [b] matches
/// everything (the "no filter" state).
bool gridEqualsIgnoreCase(dynamic a, String b) {
  final sb = b.trim();
  if (sb.isEmpty) return true;
  if (a == null) return false;
  return _collapseWhitespace(a.toString()) == _collapseWhitespace(sb);
}

/// Case-insensitive set membership for chip/multi-select filters. Mirrors the
/// "Blank" chip convention used by the other grids: a row with an empty cell
/// matches when the set contains a "Blank" option.
bool gridSetContainsIgnoreCase(dynamic value, Set<String> selected) {
  if (selected.isEmpty) return true;
  final v = _collapseWhitespace((value ?? '').toString());
  if (v.isEmpty) {
    return selected.any((s) => _collapseWhitespace(s) == 'blank');
  }
  return selected.any((s) => _collapseWhitespace(s) == v);
}

final RegExp _stripToAlnum = RegExp('[^a-z0-9]');
final RegExp _digitsAndSeparatorsOnly = RegExp(r'^[\d\s./\-,]+$');
final RegExp _whitespace = RegExp(r'\s+');

String _compact(String s) => s.replaceAll(_stripToAlnum, '');

/// Lower-case and drop all whitespace so "Inhouse / FL" == "inhouse/fl" and
/// "Approved Internal" == "approvedinternal".
String _collapseWhitespace(String s) =>
    s.toLowerCase().replaceAll(_whitespace, '');

final RegExp _monthWord = RegExp(
  r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
  caseSensitive: false,
);

/// True when [text] could plausibly hold a date. Bare numbers are excluded on
/// purpose so numeric grid columns (frames, man-days, bids) are never parsed
/// as Excel date serials (e.g. "100" → 1900-04-09).
bool _looksDateText(String text) {
  if (text.isEmpty) return false;
  if (num.tryParse(text) != null) return false;
  if (_monthWord.hasMatch(text)) return true; // "May-25", "25 May 2025", ...
  if (_digitsAndSeparatorsOnly.hasMatch(text)) {
    return true; // "10/05/2025", "2025-05-01", "05-2025"
  }
  return DateTime.tryParse(text) != null; // "2025-05-01T00:00:00.000Z"
}

DateTime? _cellAsDate(dynamic cell) {
  if (cell == null) return null;
  if (cell is DateTime) return cell;
  if (cell is num) return null;
  final text = cell.toString().trim();
  if (!_looksDateText(text)) return null;
  final iso = excelDateToIso(text, monthYearFirst: true);
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso);
}

String _iso(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
