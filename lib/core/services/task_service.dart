import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Tasks API calls — department/supervisor view and artist portal.
class TaskService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getDepartmentShots({String? department}) =>
      _api.get(
        ApiConstants.tasksDepartment,
        queryParams: department != null ? {'department': department} : null,
      );

  Future<Map<String, dynamic>> getArtistShots() =>
      _api.get(ApiConstants.tasksArtist);

  Future<Map<String, dynamic>> assignShot(
    String shotId,
    Map<String, dynamic> body,
  ) => _api.patch(ApiConstants.tasksAssign(shotId), body: body);

  Future<Map<String, dynamic>> updateArtistStatus(
    String shotId,
    String artistStatus, {
    double? mandays,
  }) {
    final body = <String, dynamic>{'artistStatus': artistStatus};
    if (mandays != null) body['mandays'] = mandays;
    return _api.patch(ApiConstants.tasksArtistStatus(shotId), body: body);
  }

  Future<Map<String, dynamic>> updateSupervisorStatus(
    String shotId,
    String supervisorStatus, {
    String? clientFeedback,
  }) {
    final body = <String, dynamic>{'supervisorStatus': supervisorStatus};
    if (clientFeedback != null) body['clientFeedback'] = clientFeedback;
    return _api.patch(ApiConstants.tasksSupervisorStatus(shotId), body: body);
  }
}
