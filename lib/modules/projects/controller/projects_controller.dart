import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/project_service.dart';

class ProjectController extends ChangeNotifier {
  final ProjectService _service = ProjectService();

  List<String> _departments = [];
  List<ClientModel> _clients = [];
  List<ShowModel> _shows = [];
  List<ShotModel> _shots = [];

  String? selectedDepartment;
  String? selectedClientId;
  String? selectedShowId;

  bool _isLoading = true;
  String? _error;

  List<String> get departments => _departments;
  List<ClientModel> get clients => _clients;
  List<ShowModel> get shows => _shows;
  List<ShotModel> get shots => _shots;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    selectedDepartment = allOption;
    selectedClientId = allOption;
    selectedShowId = allOption;
    _shows = [];
    _shots = [];
    notifyListeners();
    try {
      final deptResp = await _service.getDepartments();
      _departments = ((deptResp['departments'] as List<dynamic>?) ?? const [])
          .cast<String>();
      final clientResp = await _service.getClients();
      _clients = ((clientResp['clients'] as List<dynamic>?) ?? const [])
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      // Load all shows initially so "All" shows dropdown has content
      final allShows = <ShowModel>[];
      for (final client in _clients) {
        try {
          final resp = await _service.getShows(client.clientId);
          final shows = ((resp['shows'] as List<dynamic>?) ?? const []).map(
            (e) => ShowModel.fromJson(e as Map<String, dynamic>),
          );
          allShows.addAll(shows);
        } catch (_) {
          // skip clients that fail
        }
      }
      _shows = allShows;
      // Load all shots
      await loadShots();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// "All" sentinel value for dropdowns.
  static const String allOption = 'All';

  void selectDepartment(String? department) {
    selectedDepartment = department;
    notifyListeners();
  }

  Future<void> selectClient(String? clientId) async {
    selectedClientId = clientId;
    selectedShowId = allOption;
    _shows = [];
    _shots = [];
    notifyListeners();
    if (clientId != null && clientId != allOption) {
      try {
        final resp = await _service.getShows(clientId);
        _shows = ((resp['shows'] as List<dynamic>?) ?? const [])
            .map((e) => ShowModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint('ProjectController.selectClient error: $e');
      }
    } else {
      // "All" selected — reload all shows
      final allShows = <ShowModel>[];
      for (final client in _clients) {
        try {
          final resp = await _service.getShows(client.clientId);
          final shows = ((resp['shows'] as List<dynamic>?) ?? const []).map(
            (e) => ShowModel.fromJson(e as Map<String, dynamic>),
          );
          allShows.addAll(shows);
        } catch (_) {}
      }
      _shows = allShows;
      notifyListeners();
    }
    await loadShots();
  }

  Future<void> selectShow(String? showId) async {
    selectedShowId = showId;
    notifyListeners();
    await loadShots();
  }

  Future<void> loadShots() async {
    _isLoading = true;
    _error = null;
    _shots = [];
    notifyListeners();
    try {
      final resp = await _service.getShots(
        department: selectedDepartment == allOption ? null : selectedDepartment,
        clientId: selectedClientId == allOption ? null : selectedClientId,
        showId: selectedShowId == allOption ? null : selectedShowId,
      );
      _shots = ((resp['shots'] as List<dynamic>?) ?? const [])
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createShot(Map<String, dynamic> body) async {
    try {
      await _service.createShot(body);
      await loadShots();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Create a new client, refresh the client list and select it.
  Future<String?> createClient(String clientName) async {
    try {
      final resp = await _service.createClient(clientName);
      final clientResp = await _service.getClients();
      _clients = ((clientResp['clients'] as List<dynamic>?) ?? const [])
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final created = resp['client'] as Map<String, dynamic>?;
      if (created != null) {
        await selectClient(created['clientId'] as String);
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Create a new show under the given client and refresh shows.
  Future<String?> createShow(String clientId, String showName) async {
    try {
      final resp = await _service.createShow(clientId, showName);
      await selectClient(clientId);
      final created = resp['show'] as Map<String, dynamic>?;
      if (created != null) {
        await selectShow(created['showId'] as String);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateShot(String shotId, Map<String, dynamic> body) async {
    try {
      await _service.updateShot(shotId, body);
      await loadShots();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Bulk-upserts [rows] to the API.
  ///
  /// [reload] defaults to `true` and refetches the whole shot list afterwards.
  /// Pass `reload: false` when saving many chunks in a loop — each call would
  /// otherwise trigger a full network refetch + grid rebuild (major UI jank).
  /// The caller should then call [loadShots] ONCE after the loop finishes.
  Future<Map<String, dynamic>?> bulkUpsertShots(
    List<Map<String, dynamic>> rows, {
    bool reload = true,
  }) async {
    try {
      final resp = await _service.bulkUpsertShots(rows);
      if (reload) {
        await loadShots();
      }
      return resp;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updateStatus(String shotId, String status) async {
    try {
      await _service.updateStatus(shotId, status);
      await loadShots();
    } catch (e) {
      debugPrint('ProjectController.updateStatus error: $e');
    }
  }

  Future<String?> deleteShot(String shotId) async {
    try {
      await _service.deleteShot(shotId);
      await loadShots();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> bulkDeleteShots(List<String> shotIds) async {
    try {
      await _service.bulkDeleteShots(shotIds);
      await loadShots();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
