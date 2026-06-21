import 'dart:typed_data';

import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Review API calls — department and individual monthly reviews.
class ReviewService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getDepartmentReview({
    required String department,
    required int month,
    required int year,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{'department': department};
    if (startDate != null && endDate != null) {
      params['startDate'] = startDate;
      params['endDate'] = endDate;
    } else {
      params['month'] = '$month';
      params['year'] = '$year';
    }
    return _api.get(ApiConstants.reviewDepartment, queryParams: params);
  }

  Future<Map<String, dynamic>> getIndividualReview({
    String? userId,
    required int month,
    required int year,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{};
    if (startDate != null && endDate != null) {
      params['startDate'] = startDate;
      params['endDate'] = endDate;
    } else {
      params['month'] = '$month';
      params['year'] = '$year';
    }
    if (userId != null) params['userId'] = userId;
    return _api.get(ApiConstants.reviewIndividual, queryParams: params);
  }

  Future<Map<String, dynamic>> exportDepartmentReview({
    required String department,
    required int month,
    required int year,
    String? startDate,
    String? endDate,
  }) {
    final suffix = (startDate != null && endDate != null)
        ? '?startDate=$startDate&endDate=$endDate'
        : '?month=$month&year=$year';
    return _api.post('${ApiConstants.reviewDepartmentExport}$suffix', {
      'department': department,
    });
  }

  Future<Map<String, dynamic>> exportIndividualReview({
    String? userId,
    required int month,
    required int year,
    String? startDate,
    String? endDate,
  }) {
    final body = <String, dynamic>{};
    if (userId != null) body['userId'] = userId;
    final suffix = (startDate != null && endDate != null)
        ? '?startDate=$startDate&endDate=$endDate'
        : '?month=$month&year=$year';
    return _api.post('${ApiConstants.reviewIndividualExport}$suffix', body);
  }

  Future<Uint8List> downloadDepartmentExport(String fileName) =>
      _api.getBytes(ApiConstants.reviewDepartmentExportDownload(fileName));

  Future<Uint8List> downloadIndividualExport(String fileName) =>
      _api.getBytes(ApiConstants.reviewIndividualExportDownload(fileName));
}
