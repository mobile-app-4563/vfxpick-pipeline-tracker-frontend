import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/services/report_service.dart';
import '../../../core/utils/excel_export_utils.dart';

class ReportController extends ChangeNotifier {
  final ReportService _service = ReportService();

  List<ReportItem> _items = [];
  bool _isLoading = false;
  String? _error;

  String? selectedDepartment;
  int month = DateTime.now().month;
  int year = DateTime.now().year;

  List<ReportItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setPeriod(int m, int y) {
    month = m;
    year = y;
    notifyListeners();
  }

  Future<void> loadReport(
    String department, {
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    selectedDepartment = department;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _service.getReport(
        department: department,
        month: month,
        year: year,
        date: date,
        startDate: startDate,
        endDate: endDate,
      );
      _items = ((resp['items'] as List<dynamic>?) ?? const [])
          .map((e) => ReportItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<(String fileName, Uint8List bytes)> exportReport(
    String department, {
    String? startDate,
    String? endDate,
  }) async {
    final resp = await _service.getReport(
      department: department,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );

    final rows = ((resp['items'] as List<dynamic>?) ?? const [])
        .map((e) => ReportItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _items = rows;
    notifyListeners();

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = defaultSheet ?? 'Report';
    final sheet = excel[sheetName];
    final titleStyle = ExcelExportUtils.titleCellStyle();
    final labelStyle = ExcelExportUtils.metaLabelStyle();
    final valueStyle = ExcelExportUtils.metaValueStyle();
    final headerStyle = ExcelExportUtils.tableHeaderStyle();
    final dataStyle = ExcelExportUtils.dataCellStyle();

    final uniqueShows = rows.map((r) => r.show).toSet().length;
    final totalMandays = rows.fold<double>(0, (sum, r) => sum + r.mandays);
    final hasDateRange = startDate != null && endDate != null;

    ExcelExportUtils.setColumnWidths(sheet, [16, 24, 18, 16, 14, 28]);

    final titleRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('Report Export'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    ExcelExportUtils.mergeRowAcross(
      sheet,
      rowIndex: titleRow,
      fromCol: 0,
      toCol: 5,
    );
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: titleRow,
      fromCol: 0,
      toCol: 5,
      style: titleStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, titleRow, 34);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final metaLabelRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('DEPARTMENT'),
      TextCellValue('MONTH'),
      TextCellValue('YEAR'),
      TextCellValue('ROWS'),
      TextCellValue('SHOWS'),
      TextCellValue('TOTAL MANDAYS'),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: metaLabelRow,
      fromCol: 0,
      toCol: 5,
      style: labelStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, metaLabelRow, 26);

    final metaValueRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(department),
      IntCellValue(month),
      IntCellValue(year),
      IntCellValue(rows.length),
      IntCellValue(uniqueShows),
      DoubleCellValue(totalMandays),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: metaValueRow,
      fromCol: 0,
      toCol: 5,
      style: valueStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, metaValueRow, 26);

    if (hasDateRange) {
      final dateLabelRow = sheet.maxRows;
      sheet.appendRow([
        TextCellValue('START DATE'),
        TextCellValue('END DATE'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: dateLabelRow,
        fromCol: 0,
        toCol: 5,
        style: labelStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, dateLabelRow, 26);

      final dateValueRow = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(startDate),
        TextCellValue(endDate),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: dateValueRow,
        fromCol: 0,
        toCol: 5,
        style: valueStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, dateValueRow, 26);
    }

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final tableHeaderRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('CLIENT NO'),
      TextCellValue('SHOW'),
      TextCellValue('SHOT'),
      TextCellValue('DATE'),
      TextCellValue('MANDAYS'),
      TextCellValue('CLIENT FEEDBACK'),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: tableHeaderRow,
      fromCol: 0,
      toCol: 5,
      style: headerStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, tableHeaderRow, 26);

    for (final row in rows) {
      final dataRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(row.clientNo),
        TextCellValue(row.show),
        TextCellValue(row.shotId),
        TextCellValue(ExcelExportUtils.formatDate(row.date)),
        DoubleCellValue(row.mandays),
        TextCellValue(row.clientFeedback ?? ''),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: dataRowIndex,
        fromCol: 0,
        toCol: 5,
        style: dataStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, dataRowIndex, 26);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Unable to generate report export');
    }

    final fileName = ExcelExportUtils.buildExportFileName(
      prefix: 'report',
      department: department,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    return (fileName, Uint8List.fromList(bytes));
  }
}
