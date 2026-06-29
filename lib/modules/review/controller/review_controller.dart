import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/services/review_service.dart';
import '../../../core/utils/excel_export_utils.dart';

class ReviewController extends ChangeNotifier {
  final ReviewService _service = ReviewService();

  DepartmentReview? _departmentReview;
  IndividualReview? _individualReview;
  bool _isLoading = true;
  String? _error;

  int month = DateTime.now().month;
  int year = DateTime.now().year;

  DepartmentReview? get departmentReview => _departmentReview;
  IndividualReview? get individualReview => _individualReview;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setPeriod(int m, int y) {
    month = m;
    year = y;
    notifyListeners();
  }

  Future<void> loadDepartmentReview(
    String department, {
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    _departmentReview = null;
    notifyListeners();
    try {
      final resp = await _service.getDepartmentReview(
        department: department,
        month: month,
        year: year,
        startDate: startDate,
        endDate: endDate,
      );
      _departmentReview = DepartmentReview.fromJson(resp);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadIndividualReview({
    String? userId,
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    _individualReview = null;
    notifyListeners();
    try {
      final resp = await _service.getIndividualReview(
        userId: userId,
        month: month,
        year: year,
        startDate: startDate,
        endDate: endDate,
      );
      _individualReview = IndividualReview.fromJson(resp);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Export and download-ready bytes for department review.
  Future<(String fileName, Uint8List bytes)> exportDepartmentReview(
    String department, {
    String? startDate,
    String? endDate,
  }) async {
    final resp = await _service.getDepartmentReview(
      department: department,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    final review = DepartmentReview.fromJson(resp);
    _departmentReview = review;
    notifyListeners();

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = defaultSheet ?? 'Department Review';
    final sheet = excel[sheetName];
    final titleStyle = ExcelExportUtils.titleCellStyle();
    final labelStyle = ExcelExportUtils.metaLabelStyle();
    final valueStyle = ExcelExportUtils.metaValueStyle();
    final headerStyle = ExcelExportUtils.tableHeaderStyle();
    final dataStyle = ExcelExportUtils.dataCellStyle();

    ExcelExportUtils.setColumnWidths(sheet, [16, 24, 18, 16, 14, 18, 28]);

    final deptTitleRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('Department Review'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    ExcelExportUtils.mergeRowAcross(
      sheet,
      rowIndex: deptTitleRow,
      fromCol: 0,
      toCol: 6,
    );
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: deptTitleRow,
      fromCol: 0,
      toCol: 6,
      style: titleStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, deptTitleRow, 34);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final deptMetaLabelRow1 = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('DEPARTMENT'),
      TextCellValue('MONTH'),
      TextCellValue('YEAR'),
      TextCellValue('TOTAL SHOWS'),
      TextCellValue('TOTAL SHOTS'),
      TextCellValue('TOTAL MANDAYS'),
      TextCellValue(''),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: deptMetaLabelRow1,
      fromCol: 0,
      toCol: 6,
      style: labelStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, deptMetaLabelRow1, 26);

    final deptMetaValueRow1 = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(review.department),
      IntCellValue(review.month),
      IntCellValue(review.year),
      IntCellValue(review.totalShows),
      IntCellValue(review.totalShots),
      DoubleCellValue(review.totalMandays),
      TextCellValue(''),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: deptMetaValueRow1,
      fromCol: 0,
      toCol: 6,
      style: valueStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, deptMetaValueRow1, 26);

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final deptHeaderRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('CLIENT NO'),
      TextCellValue('SHOW'),
      TextCellValue('SHOT'),
      TextCellValue('DATE'),
      TextCellValue('MANDAYS'),
      TextCellValue('ARTIST'),
      TextCellValue('CLIENT FEEDBACK'),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: deptHeaderRow,
      fromCol: 0,
      toCol: 6,
      style: headerStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, deptHeaderRow, 26);

    for (final row in review.detailRows) {
      final dataRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(row.clientNo),
        TextCellValue(row.show),
        TextCellValue(row.shot),
        TextCellValue(ExcelExportUtils.formatDate(row.date)),
        DoubleCellValue(row.mandays),
        TextCellValue(row.artist),
        TextCellValue(row.clientFeedback),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: dataRowIndex,
        fromCol: 0,
        toCol: 6,
        style: dataStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, dataRowIndex, 26);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Unable to generate department review export');
    }

    final fileName = ExcelExportUtils.buildExportFileName(
      prefix: 'review_department',
      department: department,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    return (fileName, Uint8List.fromList(bytes));
  }

  /// Export and download-ready bytes for individual review.
  Future<(String fileName, Uint8List bytes)> exportIndividualReview({
    String? userId,
    String? startDate,
    String? endDate,
  }) async {
    final resp = await _service.getIndividualReview(
      userId: userId,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    final review = IndividualReview.fromJson(resp);
    _individualReview = review;
    notifyListeners();

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = defaultSheet ?? 'Individual Review';
    final sheet = excel[sheetName];
    final titleStyle = ExcelExportUtils.titleCellStyle();
    final labelStyle = ExcelExportUtils.metaLabelStyle();
    final valueStyle = ExcelExportUtils.metaValueStyle();
    final headerStyle = ExcelExportUtils.tableHeaderStyle();
    final dataStyle = ExcelExportUtils.dataCellStyle();

    ExcelExportUtils.setColumnWidths(sheet, [16, 24, 18, 16, 14, 18, 28]);

    final individualTitleRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('Individual Review'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    ExcelExportUtils.mergeRowAcross(
      sheet,
      rowIndex: individualTitleRow,
      fromCol: 0,
      toCol: 6,
    );
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: individualTitleRow,
      fromCol: 0,
      toCol: 6,
      style: titleStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, individualTitleRow, 34);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final individualMetaLabelRow1 = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('USER ID'),
      TextCellValue('NAME'),
      TextCellValue('DEPARTMENT'),
      TextCellValue('SHOTS WORKED'),
      TextCellValue('MANDAYS DELIVERED'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: individualMetaLabelRow1,
      fromCol: 0,
      toCol: 6,
      style: labelStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, individualMetaLabelRow1, 26);

    final individualMetaValueRow1 = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(review.userId),
      TextCellValue(review.name),
      TextCellValue(review.department),
      IntCellValue(review.shotsWorked),
      DoubleCellValue(review.mandaysDelivered),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: individualMetaValueRow1,
      fromCol: 0,
      toCol: 6,
      style: valueStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, individualMetaValueRow1, 26);

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final individualHeaderRow = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('CLIENT NO'),
      TextCellValue('SHOW'),
      TextCellValue('SHOT'),
      TextCellValue('DATE'),
      TextCellValue('MANDAYS'),
      TextCellValue('ARTIST STATUS'),
      TextCellValue('CLIENT FEEDBACK'),
    ]);
    ExcelExportUtils.styleRow(
      sheet,
      rowIndex: individualHeaderRow,
      fromCol: 0,
      toCol: 6,
      style: headerStyle,
    );
    ExcelExportUtils.setRowHeight(sheet, individualHeaderRow, 26);

    for (final row in review.detailRows) {
      final dataRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(row.clientNo),
        TextCellValue(row.show),
        TextCellValue(row.shot),
        TextCellValue(ExcelExportUtils.formatDate(row.date)),
        DoubleCellValue(row.mandays),
        TextCellValue(row.artistStatus),
        TextCellValue(row.clientFeedback),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: dataRowIndex,
        fromCol: 0,
        toCol: 6,
        style: dataStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, dataRowIndex, 26);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Unable to generate individual review export');
    }

    final fileName = ExcelExportUtils.buildExportFileName(
      prefix: 'review_individual',
      department: review.department,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    return (fileName, Uint8List.fromList(bytes));
  }
}
