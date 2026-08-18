import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/models/todays_pickout_model.dart';
import '../../../core/services/dashboard_service.dart';
import '../../../core/services/production_service.dart';
import '../../../core/services/report_service.dart';
import '../../../core/services/review_service.dart';

/// Home page controller for Today's Pickouts and dashboard data.
/// Supports department-based filtering:
/// - Production department: shows concern data from production_data table
/// - Other departments: shows actual data (reports/performance)
/// - Admin: shows both data types
class HomeController extends ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final ReviewService _reviewService = ReviewService();
  final ProductionService _productionService = ProductionService();

  List<TodaysPickoutModel> _todaysPickouts = [];
  Map<String, double> _reportMandaysByDepartment = {};
  Map<String, double> _reviewMandaysByDepartment = {};
  List<Map<String, dynamic>> _artistPerformance = [];
  Map<String, List<InventActiveShow>> _inventActiveShowsByStatus = {
    'Approved': const [],
    'Approved Internal': const [],
  };

  // ── Production-specific data (for Production department users) ──
  List<Map<String, dynamic>> _productionConcerns = [];
  Map<String, int> _concernStatusCount = {};

  bool _isLoading = false;
  bool _isInsightsLoading = false;
  bool _isInventActiveLoading = false;
  bool _isProductionLoading = false;
  String? _errorMessage;
  String? _inventActiveError;
  String? _productionError;

  List<TodaysPickoutModel> get todaysPickouts => _todaysPickouts;
  Map<String, double> get reportMandaysByDepartment =>
      _reportMandaysByDepartment;
  Map<String, double> get reviewMandaysByDepartment =>
      _reviewMandaysByDepartment;
  List<Map<String, dynamic>> get artistPerformance => _artistPerformance;
  Map<String, List<InventActiveShow>> get inventActiveShowsByStatus =>
      _inventActiveShowsByStatus;
  List<Map<String, dynamic>> get productionConcerns => _productionConcerns;
  Map<String, int> get concernStatusCount => _concernStatusCount;

  bool get isLoading => _isLoading;
  bool get isInsightsLoading => _isInsightsLoading;
  bool get isInventActiveLoading => _isInventActiveLoading;
  bool get isProductionLoading => _isProductionLoading;
  String? get errorMessage => _errorMessage;
  String? get inventActiveError => _inventActiveError;
  String? get productionError => _productionError;

  /// Fetch today's pickouts from the API
  Future<void> fetchTodaysPickouts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await _dashboardService.fetchTodaysPickouts(date: today);
      final pickoutsData = (response['pickouts'] as List<dynamic>?) ?? [];

      _todaysPickouts = pickoutsData.map((item) {
        return TodaysPickoutModel.calculatePriority(
          item as Map<String, dynamic>,
        );
      }).toList();

      _todaysPickouts.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
      _errorMessage = null;

      // ── Fire insights + invent-active + production concerns in PARALLEL ───
      await Future.wait([
        fetchInsights(),
        fetchInventActiveShows(),
        fetchProductionConcerns(),
      ]);
    } catch (e) {
      _errorMessage = 'Failed to load today\'s pickouts: $e';
      _todaysPickouts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch production concerns from production_data table
  /// Only called if user's department is 'Production' or user is Admin
  Future<void> fetchProductionConcerns() async {
    _isProductionLoading = true;
    _productionError = null;
    notifyListeners();

    try {
      // Get only open/in-progress concerns (not resolved/on hold)
      final response = await _productionService.getProductionConcerns(
        status: '', // Get all statuses, or filter if needed
      );

      if (response['success'] == true) {
        final concerns =
            (response['concerns'] as List<dynamic>?) ?? const <dynamic>[];
        _productionConcerns = concerns.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );

        // Count concerns by status
        _concernStatusCount = {};
        for (final concern in _productionConcerns) {
          final status = (concern['status'] ?? 'Unknown').toString();
          _concernStatusCount[status] = (_concernStatusCount[status] ?? 0) + 1;
        }
      } else {
        _productionError =
            response['error'] ?? 'Failed to load production concerns';
        _productionConcerns = [];
        _concernStatusCount = {};
      }
    } catch (e) {
      _productionError = 'Failed to load production concerns: $e';
      _productionConcerns = [];
      _concernStatusCount = {};
    } finally {
      _isProductionLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInventActiveShows() async {
    _isInventActiveLoading = true;
    _inventActiveError = null;
    notifyListeners();

    try {
      final response = await _dashboardService.fetchInventActiveShows();
      final statuses =
          (response['statuses'] as List<dynamic>?) ?? const <dynamic>[];

      final byStatus = <String, List<InventActiveShow>>{
        'Approved': const <InventActiveShow>[],
        'Approved Internal': const <InventActiveShow>[],
      };

      for (final statusRow in statuses) {
        if (statusRow is! Map<String, dynamic>) continue;
        final status = (statusRow['status'] ?? '').toString();
        final showsRaw = (statusRow['shows'] as List<dynamic>?) ?? const [];
        byStatus[status] = showsRaw
            .whereType<Map<String, dynamic>>()
            .map(InventActiveShow.fromJson)
            .toList(growable: false);
      }

      _inventActiveShowsByStatus = byStatus;
    } catch (e) {
      _inventActiveError = 'Failed to load InventActive shows: $e';
      _inventActiveShowsByStatus = {
        'Approved': const [],
        'Approved Internal': const [],
      };
    } finally {
      _isInventActiveLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInsights() async {
    _isInsightsLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final reports = <String, double>{};
    final reviews = <String, double>{};

    try {
      // ── Fire ALL department API calls in parallel ─────────────────
      final depts = AppConstants.pipelineDepartments;
      final futures = <Future<void>>[];

      for (final dept in depts) {
        futures.add(
          _reportService
              .getReport(department: dept, month: now.month, year: now.year)
              .then((resp) {
                final items = (resp['items'] as List<dynamic>?) ?? const [];
                reports[dept] = items.fold<double>(
                  0,
                  (sum, item) =>
                      sum +
                      ((item as Map<String, dynamic>)['mandays'] as num? ?? 0)
                          .toDouble(),
                );
              })
              .catchError((_) {
                reports[dept] = 0;
              }),
        );

        futures.add(
          _reviewService
              .getDepartmentReview(
                department: dept,
                month: now.month,
                year: now.year,
              )
              .then((resp) {
                reviews[dept] = (resp['totalMandays'] as num? ?? 0).toDouble();
              })
              .catchError((_) {
                reviews[dept] = 0;
              }),
        );
      }

      // Wait for ALL department calls + artist performance concurrently
      futures.add(
        _dashboardService.fetchArtistPerformance().then((resp) {
          _artistPerformance =
              ((resp['performers'] as List<dynamic>?) ?? const [])
                  .map((e) => e as Map<String, dynamic>)
                  .toList(growable: false);
        }),
      );

      await Future.wait(futures);

      _reportMandaysByDepartment = reports;
      _reviewMandaysByDepartment = reviews;
    } catch (e) {
      _errorMessage ??= 'Failed to load insights: $e';
      _reportMandaysByDepartment = reports;
      _reviewMandaysByDepartment = reviews;
      _artistPerformance = const [];
    } finally {
      _isInsightsLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cached data
  void clear() {
    _todaysPickouts = [];
    _reportMandaysByDepartment = {};
    _reviewMandaysByDepartment = {};
    _artistPerformance = [];
    _inventActiveShowsByStatus = {
      'Approved': const [],
      'Approved Internal': const [],
    };
    _productionConcerns = [];
    _concernStatusCount = {};
    _inventActiveError = null;
    _productionError = null;
    _errorMessage = null;
    _isLoading = false;
    _isInsightsLoading = false;
    _isInventActiveLoading = false;
    _isProductionLoading = false;
    notifyListeners();
  }
}
