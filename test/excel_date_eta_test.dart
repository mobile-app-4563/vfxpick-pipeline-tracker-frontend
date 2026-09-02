import 'package:flutter_test/flutter_test.dart';

import 'package:vfxpick_pipeline/core/utils/excel_date_utils.dart';

void main() {
  group('excelDateToIso — daily pickout ETA text (from real file)', () {
    test('Sep-01 → September 1 of CURRENT year (today)', () {
      final now = DateTime.now();
      final iso = excelDateToIso('Sep-01');
      expect(iso, '${now.year}-09-01');
    });

    test('Sep-02 → September 2 of CURRENT year (tomorrow)', () {
      final now = DateTime.now();
      final iso = excelDateToIso('Sep-02');
      expect(iso, '${now.year}-09-02');
    });

    test('Sep-03 / Sep-04 → current-year September days', () {
      final now = DateTime.now();
      expect(excelDateToIso('Sep-03'), '${now.year}-09-03');
      expect(excelDateToIso('Sep-04'), '${now.year}-09-04');
    });

    test('lowercase/spaces also work (sep 01)', () {
      final now = DateTime.now();
      expect(excelDateToIso('sep 01'), '${now.year}-09-01');
    });

    test('2-digit value ≤ 31 is a DAY, not a year', () {
      final now = DateTime.now();
      expect(excelDateToIso('May-25'), '${now.year}-05-25');
    });

    test('4-digit value stays month-year → 1st of month', () {
      expect(excelDateToIso('May-2025'), '2025-05-01');
    });

    test('2-digit value > 31 is a year → 1st of month', () {
      expect(excelDateToIso('May-99'), '1999-05-01');
    });

    test('impossible day (Feb-30) → null', () {
      expect(excelDateToIso('Feb-30'), isNull);
    });

    test('non-date text stays null', () {
      expect(excelDateToIso('N/A'), isNull);
      expect(excelDateToIso('TBD'), isNull);
    });
  });

  group('formatDateLikeExcel — display mirrors the source file', () {
    test('current-year date renders as "Sep-01"', () {
      final now = DateTime.now();
      final iso = excelDateToIso('Sep-01')!;
      expect(formatDateLikeExcel(iso), 'Sep-01');
      expect(iso, '${now.year}-09-01');
    });

    test('older month-1st date renders as "May-25" (template mmm-yy)', () {
      expect(formatDateLikeExcel('2025-05-01'), 'May-25');
    });

    test('full date outside current year stays yyyy-MM-dd', () {
      expect(formatDateLikeExcel('2025-05-15'), '2025-05-15');
    });

    test('null/empty → empty string', () {
      expect(formatDateLikeExcel(null), '');
      expect(formatDateLikeExcel(''), '');
    });
  });
}
