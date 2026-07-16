import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Dashboard API calls — department summaries and expandable shot lists.
class DashboardService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getSummary() =>
      _api.get(ApiConstants.dashboardSummary);

  Future<Map<String, dynamic>> getShowShots(
    String showId, {
    String? department,
  }) => _api.get(
    ApiConstants.dashboardShowShots(showId),
    queryParams: department != null ? {'department': department} : null,
  );

  Future<Map<String, dynamic>> fetchTodaysPickouts({String? date}) => _api.get(
    ApiConstants.dashboardTodaysPickouts,
    queryParams: date != null ? {'date': date} : null,
  );

  Future<Map<String, dynamic>> fetchArtistPerformance() =>
      _api.get(ApiConstants.dashboardArtistPerformance);

  Future<Map<String, dynamic>> fetchInventActiveShows() =>
      _api.get(ApiConstants.dashboardInventActiveShows);
}
