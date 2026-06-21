import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Teams API calls — artists grouped by department.
class TeamService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getTeams({String? department}) => _api.get(
    ApiConstants.teams,
    queryParams: department != null ? {'department': department} : null,
  );

  Future<Map<String, dynamic>> addMember(Map<String, dynamic> body) =>
      _api.post(ApiConstants.teams, body);

  Future<Map<String, dynamic>> deleteMember(String userId) =>
      _api.delete(ApiConstants.teamMember(userId));

  Future<Map<String, dynamic>> updateMember(
    String userId,
    Map<String, dynamic> body,
  ) => _api.put(ApiConstants.teamMember(userId), body);
}
