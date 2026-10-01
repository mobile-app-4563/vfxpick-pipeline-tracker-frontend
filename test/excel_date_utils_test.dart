import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/core/utils/excel_date_utils.dart';

void main() {
  group('excelDateToIso', () {
    test('exact cell values from the mmm-yy template cells', () {
      expect(
        excelDateToIso(DateCellValue(year: 2025, month: 5, day: 1)),
        '2025-05-01',
      );
      expect(
        excelDateToIso(DateCellValue(year: 1930, month: 3, day: 1)),
        '1930-03-01',
      );
      expect(
        excelDateToIso(
          DateTimeCellValue(
            year: 2025,
            month: 5,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
          ),
        ),
        '2025-05-01',
      );
    });

    test('serial numbers (Excel epoch) convert to exact dates', () {
      expect(excelDateToIso(IntCellValue(45783)), '2025-05-06');
      expect(excelDateToIso(DoubleCellValue(45783.75)), '2025-05-06');
      expect(excelDateToIso(45783), '2025-05-06');
      // Out-of-range serials are rejected, not coerced.
      expect(excelDateToIso(0), isNull);
      expect(excelDateToIso(-5), isNull);
      expect(excelDateToIso(99999), isNull);
    });

    test('time-only cells are not dates', () {
      expect(excelDateToIso(TimeCellValue(hour: 10, minute: 30)), isNull);
    });

    test('plain text formats', () {
      expect(excelDateToIso(TextCellValue('2025-05-01')), '2025-05-01');
      expect(excelDateToIso(TextCellValue('45783')), '2025-05-06');
      expect(excelDateToIso('2025-05-01T00:00:00.000Z'), '2025-05-01');
      expect(excelDateToIso('25/05/2025'), '2025-05-25');
      expect(excelDateToIso('25-05-2025'), '2025-05-25');
      expect(excelDateToIso('25-May-2025'), '2025-05-25');
      expect(excelDateToIso('25 May 2025'), '2025-05-25');
      expect(excelDateToIso('May 25, 2025'), '2025-05-25');
    });

    test('month-year text (mmm-yy) becomes the 1st of the month', () {
      // Production template mode: 2-digit values are YEARS (May-25 = May 2025).
      expect(excelDateToIso('May-25', monthYearFirst: true), '2025-05-01');
      expect(excelDateToIso('May 2025', monthYearFirst: true), '2025-05-01');
      expect(excelDateToIso('Mar-30', monthYearFirst: true), '1930-03-01');
      expect(excelDateToIso('may-25', monthYearFirst: true), '2025-05-01');
      expect(excelDateToIso('March-25', monthYearFirst: true), '2025-03-01');
      // 4-digit year → 1st of month regardless of mode.
      expect(excelDateToIso('May-2025'), '2025-05-01');
    });

    test(
      'numeric month + number → the number is the DAY, the year skipped',
      () {
        final now = DateTime.now();
        expect(excelDateToIso('05-25'), '${now.year}-05-25');
        expect(excelDateToIso('7/18'), '${now.year}-07-18');
        expect(excelDateToIso('3/26'), '${now.year}-03-26');
        expect(excelDateToIso('6/30'), '${now.year}-06-30');
        expect(excelDateToIso('5/2'), '${now.year}-05-02');
        // Impossible days are rejected rather than rolled over.
        expect(excelDateToIso('2/30'), isNull);
      },
    );

    test('4-digit numbers after a month are real years', () {
      expect(excelDateToIso('05-2025'), '2025-05-01');
      expect(excelDateToIso('5/2025'), '2025-05-01');
      expect(excelDateToIso('05/2025'), '2025-05-01');
    });

    test('2-digit-year day-first formats are resolved (never null)', () {
      expect(excelDateToIso('01-05-25'), '2025-05-01');
      expect(excelDateToIso('1-5-25'), '2025-05-01');
      expect(excelDateToIso('25-05-25'), '2025-05-25');
      expect(excelDateToIso('05/05/25'), '2025-05-05');
      expect(excelDateToIso('25/5/25'), '2025-05-25');
      expect(excelDateToIso('1/1/25'), '2025-01-01');
    });

    test('slash/dot ISO and year-month formats are parsed', () {
      expect(excelDateToIso('2025/05/01'), '2025-05-01');
      expect(excelDateToIso('2025.05.01'), '2025-05-01');
      expect(excelDateToIso('2025-05'), '2025-05-01');
      expect(excelDateToIso('2025/05'), '2025-05-01');
      // Year-first with dots must NOT become a 1905-era Excel serial.
      expect(excelDateToIso('2025.05'), '2025-05-01');
      expect(excelDateToIso('2025'), '2025-01-01');
    });

    test('day + named month without year → current year (daily pickout)', () {
      final now = DateTime.now();
      expect(excelDateToIso('5-May'), '${now.year}-05-05');
      expect(excelDateToIso('01-May'), '${now.year}-05-01');
    });

    test('garbage returns null (never raw text)', () {
      expect(excelDateToIso('garbage'), isNull);
      expect(excelDateToIso(''), isNull);
      expect(excelDateToIso(null), isNull);
      expect(excelDateToIso('12345.678.9'), isNull);
    });
  });

  group('excelDateToCurrentYearIso', () {
    final now = DateTime(2026, 9, 29);

    test('rebases Excel date cells and ISO text but preserves month/day', () {
      expect(
        excelDateToCurrentYearIso(
          DateCellValue(year: 2012, month: 1, day: 1),
          now: now,
        ),
        '2026-01-01',
      );
      expect(excelDateToCurrentYearIso('2012-01-12', now: now), '2026-01-12');
      expect(excelDateToCurrentYearIso('Sept 30', now: now), '2026-09-30');
    });

    test('rejects month/day combinations invalid in the current year', () {
      expect(excelDateToCurrentYearIso('2024-02-29', now: now), isNull);
    });
  });

  group('display formatting', () {
    test('always month + day — a year is never rendered', () {
      expect(formatDateLikeExcel('2025-05-01'), 'May-01');
      expect(formatDateLikeExcel('1930-03-01'), 'Mar-01');
      expect(formatDateLikeExcelD(DateTime(2025, 5, 1)), 'May-01');
      // Dates from other years used to fall back to ISO ("2025-05-15").
      expect(formatDateLikeExcel('2025-05-15'), 'May-15');
      expect(formatDateLikeExcelD(DateTime(2025, 5, 15)), 'May-15');
    });

    test('null/invalid input formats to empty string', () {
      expect(formatDateLikeExcel(null), '');
      expect(formatDateLikeExcel(''), '');
      expect(formatDateLikeExcel('garbage'), '');
      expect(formatDateLikeExcelD(null), '');
    });

    test('monthYearLabel two-digit year', () {
      expect(monthYearLabel(DateTime(1930, 3, 1)), 'Mar-30');
      expect(monthYearLabel(DateTime(2025, 12, 1)), 'Dec-25');
    });
  });

  // Rows imported before the day/month rule was fixed hold a month-YEAR: the
  // 1st of the month in a meaningless year, with the intended day hiding in
  // the year's last two digits ("Aug-25" saved as 2025-08-01).
  group('repairStoredMonthDayIso — old month-year rows recover their day', () {
    final year = DateTime.now().year;

    test('the year\'s last two digits are re-read as the day', () {
      expect(repairStoredMonthDayIso('2025-08-01'), '$year-08-25');
      expect(repairStoredMonthDayIso('2018-09-01'), '$year-09-18');
      expect(repairStoredMonthDayIso('2028-01-01'), '$year-01-28');
      expect(repairStoredMonthDayIso('2004-12-01'), '$year-12-04');
      // The 1930/1931 values seen in wip_eta and delivered_on.
      expect(repairStoredMonthDayIso('1930-03-01'), '$year-03-30');
      expect(repairStoredMonthDayIso('1931-08-01'), '$year-08-31');
    });

    test('genuine day-level dates are left untouched', () {
      expect(repairStoredMonthDayIso('2026-08-25'), '2026-08-25');
      expect(repairStoredMonthDayIso('2025-09-14'), '2025-09-14');
    });

    test('an impossible day keeps the 1st instead of inventing one', () {
      expect(repairStoredMonthDayIso('1932-04-01'), '1932-04-01'); // 32
      expect(repairStoredMonthDayIso('1931-04-01'), '1931-04-01'); // 31 April
      expect(repairStoredMonthDayIso('1930-02-01'), '1930-02-01'); // 30 Feb
      expect(repairStoredMonthDayIso('2000-05-01'), '2000-05-01'); // 00
    });

    test('null / empty / garbage pass through unchanged', () {
      expect(repairStoredMonthDayIso(null), isNull);
      expect(repairStoredMonthDayIso(''), '');
      expect(repairStoredMonthDayIso('garbage'), 'garbage');
    });

    test('repairStoredRowDates only copies the row when it changed', () {
      final row = <String, dynamic>{'eta': '2025-08-01', 'shotCode': 'GRID1'};
      final repaired = repairStoredRowDates(row, const ['eta', 'wipEta']);
      expect(repaired['eta'], '$year-08-25');
      expect(repaired['shotCode'], 'GRID1');

      final clean = <String, dynamic>{'eta': '2026-08-25'};
      expect(
        identical(repairStoredRowDates(clean, const ['eta']), clean),
        isTrue,
      );
    });
  });
}
