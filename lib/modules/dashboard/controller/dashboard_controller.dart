import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/dashboard_service.dart';

class DashboardController extends ChangeNotifier {
  final DashboardService _service = DashboardService();

  List<DashboardDepartment> _departments = [];
  bool _isLoading = true;
  String? _error;

  // Home summary (today/tomorrow pickouts + active shows).
  int _todayPickouts = 0;
  int _tomorrowPickouts = 0;
  bool _homeSummaryLoading = true;
  String? _homeSummaryError;
  // client / show / eta per active show (earliest grid ETA).
  final List<Map<String, dynamic>> _activeShows = [];

  // Cache of expanded show -> shots.
  final Map<String, List<ShotModel>> _showShots = {};

  List<DashboardDepartment> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get todayPickouts => _todayPickouts;
  int get tomorrowPickouts => _tomorrowPickouts;
  bool get homeSummaryLoading => _homeSummaryLoading;
  String? get homeSummaryError => _homeSummaryError;
  List<Map<String, dynamic>> get activeShows => _activeShows;

  List<ShotModel>? shotsForShow(String showId) => _showShots[showId];

  Future<void> loadSummary() async {
    _isLoading = true;
    _error = null;
    _departments = [];
    _showShots.clear();
    notifyListeners();
    try {
      final response = await _service.getSummary();
      final list = (response['departments'] as List<dynamic>?) ?? const [];
      _departments = list
          .map((e) => DashboardDepartment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the Home summary: today/tomorrow pickout counts and the active
  /// shows list (client, show, ETA). Non-blocking — the summary grid loads
  /// independently of these cards.
  Future<void> loadHomeSummary() async {
    _homeSummaryLoading = true;
    _homeSummaryError = null;
    notifyListeners();
    try {
      final response = await _service.fetchHomeSummary();
      _todayPickouts = response['todayPickouts'] as int? ?? 0;
      _tomorrowPickouts = response['tomorrowPickouts'] as int? ?? 0;
      _activeShows
        ..clear()
        ..addAll(
          ((response['activeShows'] as List<dynamic>?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
    } catch (e) {
      _homeSummaryError = e.toString();
    } finally {
      _homeSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadShowShots(String showId, {String? department}) async {
    try {
      final response = await _service.getShowShots(
        showId,
        department: department,
      );
      final list = (response['shots'] as List<dynamic>?) ?? const [];
      _showShots[showId] = list
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('DashboardController.loadShowShots error: $e');
    }
  }
}
