import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/dashboard_service.dart';

class DashboardController extends ChangeNotifier {
  final DashboardService _service = DashboardService();

  List<DashboardDepartment> _departments = [];
  bool _isLoading = true;
  String? _error;

  // Cache of expanded show -> shots.
  final Map<String, List<ShotModel>> _showShots = {};

  List<DashboardDepartment> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
