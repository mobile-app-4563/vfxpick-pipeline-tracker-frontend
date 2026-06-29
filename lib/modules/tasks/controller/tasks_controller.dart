import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/project_service.dart';
import '../../../core/services/task_service.dart';

class TaskController extends ChangeNotifier {
  final TaskService _service = TaskService();
  final ProjectService _projectService = ProjectService();

  List<String> _departments = [];
  List<ClientModel> _clients = [];
  List<ShowModel> _shows = [];
  List<ShotModel> _departmentShots = [];
  List<ShotModel> _artistShots = [];
  String? selectedDepartment;
  String? selectedClientId;
  String? selectedShowId;
  bool _isLoading = true;
  String? _error;

  List<String> get departments => _departments;
  List<ClientModel> get clients => _clients;
  List<ShowModel> get shows => _shows;
  List<ShotModel> get departmentShots => _departmentShots;
  List<ShotModel> get artistShots => _artistShots;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> init({List<String>? departments}) async {
    _isLoading = true;
    _error = null;
    selectedClientId = null;
    selectedShowId = null;
    _shows = [];
    _departmentShots = [];
    _artistShots = [];
    notifyListeners();
    try {
      if (departments != null) {
        _departments = List<String>.from(departments);
      } else {
        final deptResp = await _projectService.getDepartments();
        _departments = ((deptResp['departments'] as List<dynamic>?) ?? const [])
            .cast<String>();
      }

      final clientResp = await _projectService.getClients();
      _clients = ((clientResp['clients'] as List<dynamic>?) ?? const [])
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (selectedDepartment != null &&
          !_departments.contains(selectedDepartment)) {
        selectedDepartment = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDepartment(String department) {
    selectedDepartment = department;
    selectedClientId = null;
    selectedShowId = null;
    _shows = [];
    notifyListeners();
  }

  Future<void> selectClient(String clientId) async {
    selectedClientId = clientId;
    selectedShowId = null;
    _shows = [];
    _departmentShots = [];
    notifyListeners();
    try {
      final resp = await _projectService.getShows(clientId);
      _shows = ((resp['shows'] as List<dynamic>?) ?? const [])
          .map((e) => ShowModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await loadShots();
    } catch (e) {
      debugPrint('TaskController.selectClient error: $e');
    }
  }

  Future<void> selectShow(String showId) async {
    selectedShowId = showId;
    notifyListeners();
    await loadShots();
  }

  Future<void> loadShots() async {
    _isLoading = true;
    _error = null;
    _departmentShots = [];
    notifyListeners();
    try {
      final resp = await _projectService.getShots(
        department: selectedDepartment,
        clientId: selectedClientId,
        showId: selectedShowId,
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

  Future<void> loadDepartmentShots({String? department}) async {
    if (department != null) {
      if (department != selectedDepartment) {
        selectedDepartment = department;
        selectedClientId = null;
        selectedShowId = null;
        _shows = [];
      }
    }
    await loadShots();
  }

  Future<void> loadDepartmentTasksFallback({String? department}) async {
    _isLoading = true;
    _error = null;
    selectedDepartment = department;
    _departmentShots = [];
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
    _artistShots = [];
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
