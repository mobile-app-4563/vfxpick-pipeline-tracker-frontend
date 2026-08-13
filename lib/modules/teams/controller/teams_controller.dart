import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/team_service.dart';

class TeamController extends ChangeNotifier {
  final TeamService _service = TeamService();

  List<DepartmentTeam> _teams = [];
  List<String> _roleOptions = List<String>.from(AppConstants.userRoles);
  List<String> _departmentOptions = List<String>.from(AppConstants.departments);
  bool _isLoading = false;
  String? _error;

  List<DepartmentTeam> get teams => _teams;
  List<String> get roleOptions => List<String>.unmodifiable(_roleOptions);
  List<String> get departmentOptions =>
      List<String>.unmodifiable(_departmentOptions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMemberOptions() async {
    try {
      final resp = await _service.getMemberOptions();
      AppConstants.applyDynamicOptions(resp);
      final roles = ((resp['roles'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      final departments = ((resp['departments'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (roles.isNotEmpty) {
        _roleOptions = roles;
      }
      if (departments.isNotEmpty) {
        _departmentOptions = departments;
      }
    } catch (_) {
      // Keep fallback constants when options endpoint is unavailable.
    }
  }

  Future<void> loadTeams({String? department}) async {
    _isLoading = true;
    _error = null;
    _teams = [];
    notifyListeners();
    try {
      await loadMemberOptions();
      final resp = await _service.getTeams(department: department);
      _teams = ((resp['departments'] as List<dynamic>?) ?? const [])
          .map((e) => DepartmentTeam.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new team member and refresh the list.
  Future<String?> addMember(Map<String, dynamic> body) async {
    try {
      await _service.addMember(body);
      await loadTeams();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Remove a team member and refresh the list.
  Future<String?> removeMember(String userId) async {
    try {
      await _service.deleteMember(userId);
      await loadTeams();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Update an existing team member and refresh the list.
  Future<String?> editMember(String userId, Map<String, dynamic> body) async {
    try {
      await _service.updateMember(userId, body);
      await loadTeams();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Import many members and refresh once at the end.
  Future<Map<String, dynamic>> importMembers(
    List<Map<String, dynamic>> rows,
  ) async {
    var created = 0;
    final errors = <String>[];

    for (final row in rows) {
      try {
        await _service.addMember(row);
        created++;
      } on ApiException catch (e) {
        final name = (row['name'] ?? row['email'] ?? 'row').toString();
        errors.add('$name: ${e.message}');
      } catch (e) {
        final name = (row['name'] ?? row['email'] ?? 'row').toString();
        errors.add('$name: $e');
      }
    }

    await loadTeams();
    return {'created': created, 'errors': errors};
  }
}
