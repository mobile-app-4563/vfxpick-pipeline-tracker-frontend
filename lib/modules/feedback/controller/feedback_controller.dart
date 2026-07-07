import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/services/project_service.dart';

class FeedbackController extends ChangeNotifier {
  final FeedbackService _feedbackService = FeedbackService();
  final ProjectService _projectService = ProjectService();

  List<String> _departments = [];
  List<ClientModel> _clients = [];
  List<ShowModel> _shows = [];
  List<ShotModel> _feedbackShots = [];

  String? selectedDepartment;
  String? selectedClientId;
  String? selectedShowId;
  String? selectedStatus;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<String> get departments => _departments;
  List<ClientModel> get clients => _clients;
  List<ShowModel> get shows => _shows;
  List<ShotModel> get feedbackShots => _feedbackShots;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final deptResp = await _projectService.getDepartments();
      _departments = ((deptResp['departments'] as List<dynamic>?) ?? const [])
          .cast<String>();

      final clientResp = await _projectService.getClients();
      _clients = ((clientResp['clients'] as List<dynamic>?) ?? const [])
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await loadFeedbacks();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDepartment(String? department) {
    selectedDepartment = department;
    selectedClientId = null;
    selectedShowId = null;
    _shows = [];
    notifyListeners();
  }

  Future<void> selectClient(String? clientId) async {
    selectedClientId = clientId;
    selectedShowId = null;
    _shows = [];
    notifyListeners();

    if (clientId == null || clientId.isEmpty) return;
    try {
      final resp = await _projectService.getShows(clientId);
      _shows = ((resp['shows'] as List<dynamic>?) ?? const [])
          .map((e) => ShowModel.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('FeedbackController.selectClient error: $e');
    }
  }

  void selectShow(String? showId) {
    selectedShowId = showId;
    notifyListeners();
  }

  void selectStatus(String? status) {
    selectedStatus = status;
    notifyListeners();
  }

  Future<void> updateShotFeedback(String shotId, String feedback) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _feedbackService.updateFeedback(shotId, clientFeedback: feedback);
      await loadFeedbacks();
    } catch (e) {
      _error = e.toString();
      debugPrint('FeedbackController.updateShotFeedback error: $e');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadFeedbacks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _feedbackService.getClientFeedbacks(
        department: selectedDepartment,
        clientId: selectedClientId,
        showId: selectedShowId,
        status: selectedStatus,
      );
      _feedbackShots = ((resp['feedbacks'] as List<dynamic>?) ?? const [])
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateFeedbackEntry(
    String shotId, {
    String? status,
    String? clientFeedback,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _feedbackService.updateFeedback(
        shotId,
        status: status,
        clientFeedback: clientFeedback,
      );
      await loadFeedbacks();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<ShowModel>> getShowsForClient(String clientId) async {
    try {
      final resp = await _projectService.getShows(clientId);
      return ((resp['shows'] as List<dynamic>?) ?? const [])
          .map((e) => ShowModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('FeedbackController.getShowsForClient error: $e');
      return [];
    }
  }

  Future<String?> createFeedbackShot({
    required String showId,
    required String department,
    required String shotCode,
    required String status,
    required String clientFeedback,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _projectService.createShot({
        'showId': showId,
        'department': department,
        'shotCode': shotCode,
        'status': status,
        'clientFeedback': clientFeedback,
      });
      await loadFeedbacks();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
