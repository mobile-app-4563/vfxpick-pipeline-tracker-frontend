import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Projects API calls — departments, clients, shows and shot CRUD.
class ProjectService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getDepartments() =>
      _api.get(ApiConstants.projectDepartments);

  Future<Map<String, dynamic>> getClients() =>
      _api.get(ApiConstants.projectClients);

  Future<Map<String, dynamic>> createClient(String clientName) =>
      _api.post(ApiConstants.projectClients, {'clientName': clientName});

  Future<Map<String, dynamic>> getShows(String clientId) =>
      _api.get(ApiConstants.projectShowsForClient(clientId));

  Future<Map<String, dynamic>> createShow(String clientId, String showName) =>
      _api.post(ApiConstants.projectShowsForClient(clientId), {
        'showName': showName,
      });

  Future<Map<String, dynamic>> getShots({
    String? department,
    String? clientId,
    String? showId,
    String? status,
  }) {
    final params = <String, String>{};
    if (department != null) params['department'] = department;
    if (clientId != null) params['clientId'] = clientId;
    if (showId != null) params['showId'] = showId;
    if (status != null) params['status'] = status;
    return _api.get(ApiConstants.projectShots, queryParams: params);
  }

  Future<Map<String, dynamic>> createShot(Map<String, dynamic> body) =>
      _api.post(ApiConstants.projectShots, body);

  Future<Map<String, dynamic>> bulkUpsertShots(
    List<Map<String, dynamic>> rows,
  ) => _api.post(ApiConstants.projectShotsBulkUpsert, {'rows': rows});

  Future<Map<String, dynamic>> updateShot(
    String shotId,
    Map<String, dynamic> body,
  ) => _api.put(ApiConstants.projectShot(shotId), body);

  Future<Map<String, dynamic>> updateStatus(String shotId, String status) =>
      _api.patch(
        ApiConstants.projectShotStatus(shotId),
        body: {'status': status},
      );

  Future<Map<String, dynamic>> deleteShot(String shotId) =>
      _api.delete(ApiConstants.projectShot(shotId));
}
