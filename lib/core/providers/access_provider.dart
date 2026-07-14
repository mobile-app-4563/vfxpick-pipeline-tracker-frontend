import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../services/api_controller.dart';

class AccessProvider extends ChangeNotifier {
  final ApiController _api = ApiController.instance;

  static const List<String> orderedMenuRoutes = [
    '/home',
    '/dashboard',
    '/bidding',
    '/projects',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/access-provider',
    '/hrms',
    '/inventory',
  ];

  static const Set<String> protectedRoutes = {
    '/home',
    '/dashboard',
    '/bidding',
    '/projects',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/access-provider',
    '/hrms',
    '/inventory',
  };

  static const Set<String> _artistDefaults = {
    '/home',
    '/dashboard',
    '/tasks',
    '/notifications',
  };

  static const Set<String> _fullAccessDefaults = {
    '/home',
    '/dashboard',
    '/bidding',
    '/projects',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/hrms',
    '/inventory',
  };

  final Map<String, Set<String>> _roleRoutes = {};
  List<String> _roles = List<String>.from(AppConstants.userRoles);
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAuditLoading = false;
  bool _loadedFromApi = false;
  bool _auditLoaded = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isAuditLoading => _isAuditLoading;
  bool get loadedFromApi => _loadedFromApi;
  bool get auditLoaded => _auditLoaded;
  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  List<String> get roles {
    final merged = <String>{...AppConstants.userRoles, ..._roles};
    final ordered = <String>[];
    for (final role in AppConstants.userRoles) {
      if (merged.contains(role)) {
        ordered.add(role);
      }
    }
    for (final role in merged) {
      if (!ordered.contains(role)) {
        ordered.add(role);
      }
    }
    return List<String>.unmodifiable(ordered);
  }

  String? get errorMessage => _errorMessage;

  AccessProvider() {
    _resetDefaults();
  }

  String _normalizeRole(String role) => role.trim().toLowerCase();

  Future<void> ensureLoaded() async {
    if (_loadedFromApi || _isLoading) return;
    await loadPermissions();
  }

  Future<void> ensureAuditLoaded() async {
    if (_auditLoaded || _isAuditLoading) return;
    await loadAuditLogs();
  }

  bool isAdminRole(String role) =>
      _normalizeRole(role) == AppConstants.roleAdmin.toLowerCase();

  bool isArtistRole(String role) =>
      _normalizeRole(role) == AppConstants.roleArtist.toLowerCase();

  bool isFullAccessRole(String role) {
    final normalized = _normalizeRole(role);
    return normalized == AppConstants.roleSupervisor.toLowerCase() ||
        normalized == AppConstants.roleTeamLead.toLowerCase() ||
        normalized == AppConstants.roleAdmin.toLowerCase() ||
        normalized == AppConstants.roleProduction.toLowerCase() ||
        normalized == AppConstants.roleManagement.toLowerCase();
  }

  Set<String> _effectiveAllowedRoutes(String role) {
    final allowed = {...(_roleRoutes[role] ?? _artistDefaults)};
    if (isFullAccessRole(role)) {
      allowed.add('/hrms');
    }
    if (isAdminRole(role)) {
      allowed.add('/access-provider');
    }
    return allowed;
  }

  String labelForRoute(String route, {required String role}) {
    if (route == '/tasks' && isArtistRole(role)) {
      return 'My Tasks';
    }
    switch (route) {
      case '/home':
        return 'Home';
      case '/dashboard':
        return 'Dashboard';
      case '/bidding':
        return 'Bidding';
      case '/projects':
        return 'Projects';
      case '/assets':
        return 'Assets';
      case '/tasks':
        return 'Tasks';
      case '/review':
        return 'Review';
      case '/feedback':
        return 'Feedback';
      case '/reports':
        return 'Reports';
      case '/teams':
        return 'Teams';
      case '/notifications':
        return 'Notifications';
      case '/user-register':
        return 'Add Users';
      case '/access-provider':
        return 'Access Provider';
      case '/hrms':
        return 'HRMS';
      case '/inventory':
        return 'Inventory';
      default:
        return route;
    }
  }

  List<String> allowedMenuRoutes(String role) {
    final allowed = _effectiveAllowedRoutes(role);
    return orderedMenuRoutes
        .where((route) => allowed.contains(route))
        .toList(growable: false);
  }

  bool canAccessPath(String role, String path) {
    if (!protectedRoutes.contains(path)) {
      return true;
    }
    final allowed = _effectiveAllowedRoutes(role);
    return allowed.contains(path);
  }

  bool hasMenuAccess(String role, String route) {
    final allowed = _effectiveAllowedRoutes(role);
    return allowed.contains(route);
  }

  Future<bool> loadPermissions() async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.get(ApiConstants.accessPermissions);
      final permissions = response['permissions'];
      if (permissions is Map<String, dynamic>) {
        _applyPermissionsMap(
          permissions,
          rolesFromApi: (response['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false),
        );
        _loadedFromApi = true;
        _errorMessage = null;
        return true;
      }
      _errorMessage = 'Invalid permissions response';
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loadAuditLogs({int limit = 200}) async {
    if (_isAuditLoading) return false;
    _isAuditLoading = true;
    notifyListeners();
    try {
      final response = await _api.get(
        ApiConstants.accessPermissionsAudit,
        queryParams: {'limit': '$limit'},
      );
      final rows = (response['logs'] as List<dynamic>?) ?? const [];
      _auditLogs = rows.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      _auditLoaded = true;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isAuditLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setMenuAccess({
    required String role,
    required String route,
    required bool allowed,
  }) async {
    if (!protectedRoutes.contains(route)) return false;

    final snapshot = {
      for (final entry in _roleRoutes.entries) entry.key: {...entry.value},
    };

    final target = _roleRoutes.putIfAbsent(role, () => <String>{});
    if (allowed) {
      target.add(route);
    } else {
      target.remove(route);
    }
    notifyListeners();

    final saved = await savePermissions();
    if (!saved) {
      _roleRoutes
        ..clear()
        ..addAll(snapshot);
      notifyListeners();
    } else {
      await loadAuditLogs();
    }
    return saved;
  }

  Future<bool> savePermissions() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final payload = {
        'permissions': {
          for (final role in _roles) role: allowedMenuRoutes(role),
        },
      };
      await _api.put(ApiConstants.accessPermissions, payload);
      _loadedFromApi = true;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> resetDefaults() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.post(ApiConstants.accessPermissionsReset, {});
      final permissions = response['permissions'];
      if (permissions is Map<String, dynamic>) {
        _applyPermissionsMap(
          permissions,
          rolesFromApi: (response['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false),
        );
      } else {
        _resetDefaults();
      }
      _loadedFromApi = true;
      await loadAuditLogs();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void resetDefaultsLocal() {
    _resetDefaults();
    notifyListeners();
  }

  void _applyPermissionsMap(
    Map<String, dynamic> permissions, {
    List<String>? rolesFromApi,
  }) {
    _roleRoutes.clear();
    final validRoutes = Set<String>.from(orderedMenuRoutes);
    final roleSet = <String>{...AppConstants.userRoles};
    for (final role in permissions.keys) {
      roleSet.add(role.toString());
    }
    if (rolesFromApi != null) {
      roleSet.addAll(rolesFromApi.where((r) => r.trim().isNotEmpty));
    }
    _roles = roleSet.toList(growable: false)
      ..sort((a, b) {
        final ai = AppConstants.userRoles.indexOf(a);
        final bi = AppConstants.userRoles.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    for (final role in _roles) {
      final raw = permissions[role];
      if (raw is List) {
        _roleRoutes[role] = raw
            .map((e) => e.toString())
            .where(validRoutes.contains)
            .toSet();
      } else {
        _roleRoutes[role] = <String>{};
      }
    }

    _roleRoutes[AppConstants.roleAdmin] = {
      ...(_roleRoutes[AppConstants.roleAdmin] ?? <String>{}),
      '/access-provider',
    };
  }

  void _resetDefaults() {
    _roleRoutes.clear();
    _roles = List<String>.from(AppConstants.userRoles);

    _roleRoutes[AppConstants.roleArtist] = {..._artistDefaults};
    _roleRoutes[AppConstants.roleSupervisor] = {..._fullAccessDefaults};
    _roleRoutes[AppConstants.roleTeamLead] = {..._fullAccessDefaults};
    _roleRoutes[AppConstants.roleProduction] = {..._fullAccessDefaults};
    _roleRoutes[AppConstants.roleManagement] = {..._fullAccessDefaults};
    _roleRoutes[AppConstants.roleAdmin] = {
      ..._fullAccessDefaults,
      '/access-provider',
    };
  }
}
