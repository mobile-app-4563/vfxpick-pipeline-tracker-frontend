import 'package:excel/excel.dart';

class ExcelExportUtils {
  static CellStyle titleCellStyle() {
    return CellStyle(
      bold: true,
      fontSize: 20,
      backgroundColorHex: ExcelColor.fromHexString('#000000'),
      fontColorHex: ExcelColor.fromHexString('#39FF14'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle metaLabelStyle() {
    return CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#000000'),
      fontColorHex: ExcelColor.fromHexString('#39FF14'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle metaValueStyle() {
    return CellStyle(
      bold: false,
      backgroundColorHex: ExcelColor.fromHexString('#E6E6E6'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
    );
  }

  static CellStyle tableHeaderStyle() {
    return CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#000000'),
      fontColorHex: ExcelColor.fromHexString('#39FF14'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle dataCellStyle() {
    return CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E6E6E6'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      ),
    );
  }

  static void setColumnWidths(Sheet sheet, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  static void setRowHeight(Sheet sheet, int rowIndex, double height) {
    sheet.setRowHeight(rowIndex, height);
  }

  static void mergeRowAcross(
    Sheet sheet, {
    required int rowIndex,
    required int fromCol,
    required int toCol,
  }) {
    final start = CellIndex.indexByColumnRow(
      rowIndex: rowIndex,
      columnIndex: fromCol,
    );
    final end = CellIndex.indexByColumnRow(
      rowIndex: rowIndex,
      columnIndex: toCol,
    );
    sheet.merge(start, end);
  }

  static void styleRow(
    Sheet sheet, {
    required int rowIndex,
    required int fromCol,
    required int toCol,
    required CellStyle style,
  }) {
    for (var col = fromCol; col <= toCol; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: col),
      );
      cell.cellStyle = style;
    }
  }

  static void styleColumn(
    Sheet sheet, {
    required int rowIndex,
    required int columnIndex,
    required CellStyle style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: columnIndex),
    );
    cell.cellStyle = style;
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$yyyy-$mm-$dd';
  }

  static String buildExportFileName({
    required String prefix,
    required String? department,
    required int month,
    required int year,
    String? startDate,
    String? endDate,
  }) {
    final safeDepartment = (department ?? 'all')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final now = DateTime.now().toIso8601String().replaceAll(':', '-');
    if (startDate != null && endDate != null) {
      return '${prefix}_${safeDepartment}_${startDate}_to_${endDate}_$now.xlsx';
    }
    return '${prefix}_${safeDepartment}_${month}_${year}_$now.xlsx';
  }
}
