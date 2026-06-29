import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Feedback API calls for client feedback listing and updates.
class FeedbackService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getClientFeedbacks({
    String? department,
    String? clientId,
    String? showId,
    String? status,
  }) {
    final params = <String, String>{};
    if (department != null && department.isNotEmpty) {
      params['department'] = department;
    }
    if (clientId != null && clientId.isNotEmpty) params['clientId'] = clientId;
    if (showId != null && showId.isNotEmpty) params['showId'] = showId;
    if (status != null && status.isNotEmpty) params['status'] = status;

    return _api.get(ApiConstants.feedbackClientList, queryParams: params);
  }

  Future<Map<String, dynamic>> updateFeedback(
    String shotId, {
    String? status,
    String? clientFeedback,
  }) {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (clientFeedback != null) body['clientFeedback'] = clientFeedback;

    return _api.patch(ApiConstants.feedbackShot(shotId), body: body);
  }
}
