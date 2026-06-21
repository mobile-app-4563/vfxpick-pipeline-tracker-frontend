import 'dart:typed_data';

import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Reports API calls — per-department monthly / dated report.
class ReportService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getReport({
    required String department,
    int? month,
    int? year,
    String? date,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{'department': department};
    if (startDate != null && endDate != null) {
      params['startDate'] = startDate;
      params['endDate'] = endDate;
    } else if (date != null) {
      params['date'] = date;
    } else {
      if (month != null) params['month'] = '$month';
      if (year != null) params['year'] = '$year';
    }
    return _api.get(ApiConstants.reports, queryParams: params);
  }

  Future<Map<String, dynamic>> exportReport({
    required String department,
    int? month,
    int? year,
    String? date,
    String? startDate,
    String? endDate,
  }) {
    final suffix = (startDate != null && endDate != null)
        ? '?startDate=$startDate&endDate=$endDate'
        : date != null
        ? '?date=$date'
        : '?month=${month ?? DateTime.now().month}&year=${year ?? DateTime.now().year}';
    return _api.post('${ApiConstants.reportsExport}$suffix', {
      'department': department,
    });
  }

  Future<Uint8List> downloadReportExport(String fileName) =>
      _api.getBytes(ApiConstants.reportsExportDownload(fileName));
}
