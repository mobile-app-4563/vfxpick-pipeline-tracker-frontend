import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/models/todays_pickout_model.dart';
import '../../../core/services/dashboard_service.dart';
import '../../../core/services/report_service.dart';
import '../../../core/services/review_service.dart';

/// Home page controller for Today's Pickouts and dashboard data.
class HomeController extends ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final ReviewService _reviewService = ReviewService();

  List<TodaysPickoutModel> _todaysPickouts = [];
  Map<String, double> _reportMandaysByDepartment = {};
  Map<String, double> _reviewMandaysByDepartment = {};
  List<Map<String, dynamic>> _artistPerformance = [];
  final Map<String, List<InventActiveShow>> _inventActiveShowsByStatus = {
    'Approved': const [],
    'Approved Internal': const [],
  };
  bool _isLoading = true;
  bool _isInsightsLoading = true;
  bool _isInventActiveLoading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  List<TodaysPickoutModel> get todaysPickouts => _todaysPickouts;
  Map<String, double> get reportMandaysByDepartment =>
      _reportMandaysByDepartment;
  Map<String, double> get reviewMandaysByDepartment =>
      _reviewMandaysByDepartment;
  List<Map<String, dynamic>> get artistPerformance => _artistPerformance;
  Map<String, List<InventActiveShow>> get inventActiveShowsByStatus =>
      _inventActiveShowsByStatus;
  Map<String, List<InventActiveShow>> get inventSummary =>
      _inventActiveShowsByStatus;
  bool get isLoading => _isLoading;
  bool get isInsightsLoading => _isInsightsLoading;
  bool get isInventActiveLoading => _isInventActiveLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch today's pickouts from the API
  Future<void> fetchTodaysPickouts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dashboardService.fetchTodaysPickouts();
      final pickoutsData = (response['pickouts'] as List<dynamic>?) ?? [];

      _todaysPickouts = pickoutsData.map((item) {
        return TodaysPickoutModel.calculatePriority(
          item as Map<String, dynamic>,
        );
      }).toList();

      // Sort by priority rank (1 = highest first)
      _todaysPickouts.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));

      _errorMessage = null;
      await fetchInsights();
    } catch (e) {
      _errorMessage = 'Failed to load today\'s pickouts: $e';
      _todaysPickouts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInsights() async {
    _isInsightsLoading = true;
    _isInventActiveLoading = true;
    if (!_hasLoadedOnce) {
      _reportMandaysByDepartment = {};
      _reviewMandaysByDepartment = {};
      _artistPerformance = const [];
      _inventActiveShowsByStatus.clear();
    }
    notifyListeners();

    final now = DateTime.now();
    final reports = <String, double>{};
    final reviews = <String, double>{};

    try {
      for (final dept in AppConstants.pipelineDepartments) {
        try {
          final reportResp = await _reportService.getReport(
            department: dept,
            month: now.month,
            year: now.year,
          );
          final items = (reportResp['items'] as List<dynamic>?) ?? const [];
          final mandays = items.fold<double>(
            0,
            (sum, item) =>
                sum +
                ((item as Map<String, dynamic>)['mandays'] as num? ?? 0)
                    .toDouble(),
          );
          reports[dept] = mandays;
        } catch (_) {
          reports[dept] = 0;
        }

        try {
          final reviewResp = await _reviewService.getDepartmentReview(
            department: dept,
            month: now.month,
            year: now.year,
          );
          reviews[dept] = (reviewResp['totalMandays'] as num? ?? 0).toDouble();
        } catch (_) {
          reviews[dept] = 0;
        }
      }

      final performanceResp = await _dashboardService.fetchArtistPerformance();
      _artistPerformance =
          ((performanceResp['performers'] as List<dynamic>?) ?? const [])
              .map((e) => e as Map<String, dynamic>)
              .toList(growable: false);

      _reportMandaysByDepartment = reports;
      _reviewMandaysByDepartment = reviews;

      // Fetch InventActive Shows
      try {
        final inventResp = await _dashboardService.fetchInventActiveShows();
        final statusesList = (inventResp['statuses'] as List<dynamic>?) ?? [];
        for (final s in statusesList) {
          final map = s as Map<String, dynamic>;
          final status = map['status'] as String;
          final showsList = (map['shows'] as List<dynamic>?) ?? [];
          _inventActiveShowsByStatus[status] = showsList
              .map((e) => InventActiveShow.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Failed to load InventActive shows: $e');
      }

      _hasLoadedOnce = true;
    } catch (e) {
      _errorMessage ??= 'Failed to load insights: $e';
      _reportMandaysByDepartment = reports;
      _reviewMandaysByDepartment = reviews;
      _artistPerformance = const [];
    } finally {
      _isInsightsLoading = false;
      _isInventActiveLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cached data
  void clear() {
    _todaysPickouts = [];
    _reportMandaysByDepartment = {};
    _reviewMandaysByDepartment = {};
    _artistPerformance = [];
    _inventActiveShowsByStatus.clear();
    _errorMessage = null;
    _isLoading = false;
    _isInsightsLoading = false;
    _isInventActiveLoading = false;
    _hasLoadedOnce = false;
    notifyListeners();
  }
}
