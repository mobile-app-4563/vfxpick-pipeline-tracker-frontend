import 'package:flutter/material.dart';

import '../../../core/models/shot_model.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/task_service.dart';

class TaskController extends ChangeNotifier {
  final TaskService _service = TaskService();

  List<ShotModel> _departmentShots = [];
  List<ShotModel> _artistShots = [];
  String? selectedDepartment;
  bool _isLoading = false;
  String? _error;

  List<ShotModel> get departmentShots => _departmentShots;
  List<ShotModel> get artistShots => _artistShots;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDepartmentShots({String? department}) async {
    _isLoading = true;
    _error = null;
    selectedDepartment = department;
    notifyListeners();
    try {
      final resp = await _service.getDepartmentShots(
        department: selectedDepartment,
      );
      _departmentShots = ((resp['shots'] as List<dynamic>?) ?? const [])
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArtistShots() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _service.getArtistShots();
      _artistShots = ((resp['shots'] as List<dynamic>?) ?? const [])
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> assignShot(String shotId, Map<String, dynamic> body) async {
    try {
      await _service.assignShot(shotId, body);
      await loadDepartmentShots(department: selectedDepartment);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateArtistStatus(
    String shotId,
    String status, {
    double? mandays,
  }) async {
    try {
      await _service.updateArtistStatus(shotId, status, mandays: mandays);
      await loadArtistShots();
    } catch (e) {
      debugPrint('TaskController.updateArtistStatus error: $e');
    }
  }

  Future<void> updateSupervisorStatus(
    String shotId,
    String status, {
    String? clientFeedback,
  }) async {
    try {
      await _service.updateSupervisorStatus(
        shotId,
        status,
        clientFeedback: clientFeedback,
      );
      await loadDepartmentShots(department: selectedDepartment);
    } catch (e) {
      debugPrint('TaskController.updateSupervisorStatus error: $e');
    }
  }
}
