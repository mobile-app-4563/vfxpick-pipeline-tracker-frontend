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
      expect(excelDateToIso('May-25'), '2025-05-01');
      expect(excelDateToIso('May 2025'), '2025-05-01');
      expect(excelDateToIso('Mar-30'), '1930-03-01');
      expect(excelDateToIso('may-25'), '2025-05-01');
    });

    test('garbage returns null (never raw text)', () {
      expect(excelDateToIso('garbage'), isNull);
      expect(excelDateToIso(''), isNull);
      expect(excelDateToIso(null), isNull);
      expect(excelDateToIso('12345.678.9'), isNull);
    });
  });

  group('display formatting', () {
    test('day == 1 renders like Excel mmm-yy', () {
      expect(formatDateLikeExcel('2025-05-01'), 'May-25');
      expect(formatDateLikeExcel('1930-03-01'), 'Mar-30');
      expect(formatDateLikeExcelD(DateTime(2025, 5, 1)), 'May-25');
    });

    test('genuine day-level dates keep the full date', () {
      expect(formatDateLikeExcel('2025-05-15'), '2025-05-15');
      expect(formatDateLikeExcelD(DateTime(2025, 5, 15)), '2025-05-15');
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
}
