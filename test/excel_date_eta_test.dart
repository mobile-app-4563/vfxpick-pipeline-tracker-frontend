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

    test('a month-1st date renders as "May-01", never the year', () {
      // \"May-25\" used to be the month-year label here and read as the year
      // 2025, which is exactly the bug: years are never rendered.
      expect(formatDateLikeExcel('2025-05-01'), 'May-01');
    });

    test('a date outside the current year still shows month + day', () {
      expect(formatDateLikeExcel('2025-05-15'), 'May-15');
    });

    test('null/empty → empty string', () {
      expect(formatDateLikeExcel(null), '');
      expect(formatDateLikeExcel(''), '');
    });
  });

  // The real jan_dec_full.xlsx ETA cells are Excel SERIAL dates carrying a
  // `mmm-yy` number format: the cell holds 1 Aug 2025 but Excel shows
  // "Aug-25". Excel is showing a DAY there, not a year, and an ETA always
  // means a day — so the two-digit number must be re-read as the day.
  group('excelEtaToIso — mmm-yy serials are month/DAY, not month/year', () {
    /// Excel serial for [d] — days since 1899-12-30, the fake-1900 epoch.
    int serial(DateTime d) => d.difference(DateTime(1899, 12, 30)).inDays;

    final year = DateTime.now().year;

    test('the fixtures really are the serials from the workbook', () {
      expect(serial(DateTime(2025, 8, 1)), 45870);
      expect(serial(DateTime(2016, 9, 1)), 42614);
    });

    test(
      'serial 45870 (Excel shows "Aug-25") → 25 Aug of the current year',
      () {
        final iso = excelEtaToIso(45870);
        expect(iso, '$year-08-25');
        expect(formatDateLikeExcel(iso), 'Aug-25');
      },
    );

    test(
      'serial 42614 (Excel shows "Sep-16") → 16 Sep of the current year',
      () {
        final iso = excelEtaToIso(42614);
        expect(iso, '$year-09-16');
        expect(formatDateLikeExcel(iso), 'Sep-16');
      },
    );

    test('the same serials as TEXT take the identical path', () {
      expect(excelEtaToIso('45870'), '$year-08-25');
      expect(excelEtaToIso('42614'), '$year-09-16');
    });

    test('a genuine day in the serial is never overwritten', () {
      // 15 Aug 2025 → Excel displays the full date, so nothing to re-read.
      expect(excelEtaToIso(serial(DateTime(2025, 8, 15))), '$year-08-15');
    });

    test(
      'a typed MMM-DD string is left alone (its number is already a day)',
      () {
        expect(excelEtaToIso('Aug-25'), '$year-08-25');
        expect(excelEtaToIso('Sep-16'), '$year-09-16');
      },
    );

    test('a two-digit number that cannot be a day keeps the 1st', () {
      // 1 Apr 2032 → Excel shows "Apr-32"; 32 is not a day of any month.
      expect(excelEtaToIso(serial(DateTime(2032, 4, 1))), '$year-04-01');
    });

    test('a day past the end of a short month keeps the 1st', () {
      // 1 Apr 2031 → Excel shows "Apr-31", but April has only 30 days.
      expect(excelEtaToIso(serial(DateTime(2031, 4, 1))), '$year-04-01');
      // 1 Feb 2030 → Excel shows "Feb-30", which exists in no month at all.
      expect(excelEtaToIso(serial(DateTime(2030, 2, 1))), '$year-02-01');
    });

    test('4-digit years are still years, not days', () {
      expect(excelEtaToIso('May 2025'), '$year-05-01');
    });

    test('non-dates stay null', () {
      expect(excelEtaToIso('N/A'), isNull);
      expect(excelEtaToIso('TBD'), isNull);
      expect(excelEtaToIso(null), isNull);
      expect(excelEtaToIso(''), isNull);
    });
  });
}
