import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../services/api_controller.dart';

class AccessProvider extends ChangeNotifier {
  final ApiController _api = ApiController.instance;

  static const List<String> orderedMenuRoutes = [
    '/home',
    '/bidding',
    '/projects',
    '/production-management',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/access-provider',
    '/inventory',
    '/profile',
    '/audit-logs',
  ];

  static const Set<String> protectedRoutes = {
    '/home',
    '/bidding',
    '/projects',
    '/production-management',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/access-provider',
    '/inventory',
    '/profile',
    '/audit-logs',
  };

  static const Set<String> _artistDefaults = {
    '/home',
    '/tasks',
    '/notifications',
    '/profile',
  };

  static const Set<String> _fullAccessDefaults = {
    '/home',
    '/bidding',
    '/projects',
    '/production-management',
    '/assets',
    '/tasks',
    '/review',
    '/feedback',
    '/reports',
    '/teams',
    '/notifications',
    '/user-register',
    '/inventory',
    '/profile',
  };

  final Map<String, Set<String>> _roleRoutes = {};
  Set<String>? _serverRoutes;
  List<String> _roles = List<String>.from(AppConstants.userRoles);
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAuditLoading = false;
  bool _loadedFromApi = false;
  bool _auditLoaded = false;
  bool _deleteEnabled = true;
  bool _isSavingSettings = false;
  // Per-department delete switches from the Access Provider page. Keys are
  // normalized to upper case so lookups are case-insensitive.
  final Map<String, bool> _departmentDelete = {};
  // Per-department menu switches from the Access Provider matrix. Keys are
  // normalized to upper case. A department with no entry yet defaults to
  // EVERY menu, so brand-new departments keep their users on role defaults.
  final Map<String, Set<String>> _departmentMenus = {};
  String? _errorMessage;
  String? _auditErrorMessage;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isAuditLoading => _isAuditLoading;
  bool get loadedFromApi => _loadedFromApi;
  bool get auditLoaded => _auditLoaded;
  bool get deleteEnabled => _deleteEnabled;
  bool get isSavingSettings => _isSavingSettings;
  Map<String, bool> get departmentDelete => Map.unmodifiable(_departmentDelete);
  Map<String, Set<String>> get departmentMenus => Map.unmodifiable({
    for (final entry in _departmentMenus.entries)
      entry.key: Set<String>.unmodifiable(entry.value),
  });
  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  String? get auditErrorMessage => _auditErrorMessage;
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

  Set<String> get _safeServerRoutes =>
      _serverRoutes ??= Set<String>.from(orderedMenuRoutes);

  String _normalizeClientRoute(String route) {
    if (route == '/register') return '/user-register';
    return route;
  }

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

  /// Per-department delete permission: an explicit department switch wins,
  /// otherwise falls back to the global kill-switch.
  bool deleteEnabledForDepartment(String? department) {
    final key = (department ?? '').trim().toUpperCase();
    if (key.isNotEmpty) {
      final direct = _departmentDelete[key];
      if (direct != null) return direct;
      final normalized = _departmentDelete.entries
          .where((e) => e.key.toUpperCase() == key)
          .toList(growable: false);
      if (normalized.isNotEmpty) return normalized.first.value;
    }
    return _deleteEnabled;
  }

  Set<String> _effectiveAllowedRoutes(String role, {String? department}) {
    // Unconfigured roles (e.g. a user registered with a brand-new role, often
    // alongside a new department) default to EVERY menu so they are never
    // locked out, regardless of department; the admin can fine-tune in the
    // Access Provider screen.
    final allowed = {
      ...(_roleRoutes[role] ?? Set<String>.from(orderedMenuRoutes)),
    };
    if (isAdminRole(role)) {
      allowed.addAll(orderedMenuRoutes);
      return allowed;
    }
    if (department != null && department.trim().isNotEmpty) {
      allowed.retainAll(departmentMenuRoutes(department));
    }
    return allowed;
  }

  /// Routes allowed for [department] at the department level. Departments with
  /// no explicit rows default to EVERY menu, so brand-new departments keep
  /// their users on role defaults until the admin toggles menus off.
  Set<String> departmentMenuRoutes(String? department) {
    final key = (department ?? '').trim().toUpperCase();
    if (key.isEmpty) {
      return Set<String>.from(orderedMenuRoutes);
    }
    final direct = _departmentMenus[key];
    if (direct != null) {
      return Set<String>.from(direct);
    }
    final normalized = _departmentMenus.entries
        .where((e) => e.key.toUpperCase() == key)
        .toList(growable: false);
    if (normalized.isNotEmpty) {
      return Set<String>.from(normalized.first.value);
    }
    return Set<String>.from(orderedMenuRoutes);
  }

  /// Department-level menu access. Falls back to true (every menu) when the
  /// department is unknown or not configured.
  bool hasDepartmentMenuAccess(String? department, String route) {
    if (department == null || department.trim().isEmpty) return true;
    return departmentMenuRoutes(department).contains(route);
  }

  String labelForRoute(String route, {required String role}) {
    if (route == '/tasks' && isArtistRole(role)) {
      return 'My Tasks';
    }
    switch (route) {
      case '/home':
        return 'Home';
      case '/bidding':
        return 'Bidding';
      case '/projects':
        return 'Projects';
      case '/production-management':
        return 'Production Management';
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
      case '/inventory':
        return 'Inventory';
      case '/profile':
        return 'My Profile';
      case '/audit-logs':
        return 'Audit Logs';
      default:
        return route;
    }
  }

  List<String> allowedMenuRoutes(String role, {String? department}) {
    final allowed = _effectiveAllowedRoutes(role, department: department);
    return orderedMenuRoutes
        .where((route) => allowed.contains(route))
        .toList(growable: false);
  }

  bool canAccessPath(String role, String path, {String? department}) {
    if (!protectedRoutes.contains(path)) {
      return true;
    }
    final allowed = _effectiveAllowedRoutes(role, department: department);
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
        final rawRoutes =
            (response['routes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{};
        if (rawRoutes.isNotEmpty) {
          _serverRoutes = rawRoutes;
        } else {
          _safeServerRoutes;
        }
        _applyPermissionsMap(
          permissions,
          rolesFromApi: (response['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false),
        );
        _applyAuditLogsPayload(response['logs']);
        final rawDelete = response['deleteEnabled'];
        if (rawDelete is bool) {
          _deleteEnabled = rawDelete;
        }
        _applyDepartmentDelete(response['departments']);
        _applyDepartmentMenus(response['departmentMenus']);
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
    _auditErrorMessage = null;
    notifyListeners();
    try {
      final response = await _api.get(
        ApiConstants.accessPermissionsAudit,
        queryParams: {'limit': '$limit'},
      );
      _applyAuditLogsPayload(response['logs']);
      return true;
    } on ApiException catch (e) {
      _auditLoaded = false;
      _auditErrorMessage = e.message;
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _auditLoaded = false;
      _auditErrorMessage = e.toString();
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
    if (isAdminRole(role)) {
      _errorMessage = 'Admin access is always enabled for every menu.';
      notifyListeners();
      return false;
    }

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
    }
    return saved;
  }

  Future<bool> savePermissions() async {
    if (_isSaving) {
      _errorMessage = 'Please wait, permission update is in progress.';
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.put(
        ApiConstants.accessPermissions,
        _buildPermissionsPayload(),
      );
      _applyPermissionsResponse(response);
      _loadedFromApi = true;
      return true;
    } on ApiException catch (e) {
      final message = e.message.toLowerCase();
      final invalidRoute = message.contains('invalid route');
      final mentionsUserRegister = message.contains('/user-register');
      final mentionsRegister =
          message.contains('/register') && !mentionsUserRegister;

      if (invalidRoute && (mentionsUserRegister || mentionsRegister)) {
        try {
          final response = await _api.put(
            ApiConstants.accessPermissions,
            _buildPermissionsPayload(
              forceLegacyRegisterAlias: mentionsUserRegister,
            ),
          );
          _applyPermissionsResponse(response);
          _loadedFromApi = true;
          _errorMessage = null;
          return true;
        } on ApiException catch (retryError) {
          _errorMessage = retryError.message;
          return false;
        } catch (retryError) {
          _errorMessage = retryError.toString();
          return false;
        }
      }

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

  Map<String, dynamic> _buildPermissionsPayload({
    bool forceLegacyRegisterAlias = false,
  }) {
    return {
      'permissions': {
        for (final role in _roles)
          role: allowedMenuRoutes(role)
              .map((route) {
                final normalizedRoute = _normalizeClientRoute(route);
                if (normalizedRoute == '/user-register') {
                  if (forceLegacyRegisterAlias) return '/register';
                  return '/user-register';
                }
                return normalizedRoute;
              })
              .where(
                (route) =>
                    _safeServerRoutes.contains(route) ||
                    route == '/user-register',
              )
              .toSet()
              .toList(growable: false),
      },
      'departmentMenus': {
        for (final department in AppConstants.departments)
          department: departmentMenuRoutes(department).toList(growable: false),
      },
    };
  }

  Future<bool> resetDefaults() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.post(ApiConstants.accessPermissionsReset, {});
      _applyPermissionsResponse(response, fallbackToDefaults: true);
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

  Future<bool> loadDeleteSetting() async {
    try {
      final response = await _api.get(ApiConstants.accessSettings);
      final raw = response['deleteEnabled'];
      if (raw is bool) {
        _deleteEnabled = raw;
      }
      _applyDepartmentDelete(response['departments']);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// Delete switch. Without [department] it acts as the global kill-switch;
  /// with [department] it toggles delete for that department only.
  /// Persisted server-side (admin-only endpoint).
  Future<bool> setDeleteEnabled(bool enabled, {String? department}) async {
    final normalizedDept = (department ?? '').trim().toUpperCase();
    final perDepartment = normalizedDept.isNotEmpty;
    final previousGlobal = _deleteEnabled;
    final previousDept = perDepartment
        ? _departmentDelete[normalizedDept]
        : null;
    if (perDepartment) {
      _departmentDelete[normalizedDept] = enabled;
    } else {
      _deleteEnabled = enabled;
    }
    _isSavingSettings = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.put(ApiConstants.accessSettings, {
        if (perDepartment) 'department': department,
        'deleteEnabled': enabled,
      });
      _applyDepartmentDelete(response['departments']);
      final raw = response['deleteEnabled'];
      if (raw is bool) {
        _deleteEnabled = raw;
      }
      _errorMessage = null;
      return true;
    } on ApiException catch (e) {
      _rollbackDelete(
        perDepartment,
        normalizedDept,
        previousDept,
        previousGlobal,
      );
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _rollbackDelete(
        perDepartment,
        normalizedDept,
        previousDept,
        previousGlobal,
      );
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSavingSettings = false;
      notifyListeners();
    }
  }

  void _rollbackDelete(
    bool perDepartment,
    String dept,
    bool? previousDept,
    bool previousGlobal,
  ) {
    if (perDepartment) {
      if (previousDept == null) {
        _departmentDelete.remove(dept);
      } else {
        _departmentDelete[dept] = previousDept;
      }
    } else {
      _deleteEnabled = previousGlobal;
    }
  }

  void _applyDepartmentDelete(dynamic raw) {
    if (raw is! Map) return;
    _departmentDelete.clear();
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toUpperCase();
      if (key.isEmpty) continue;
      _departmentDelete[key] = entry.value == true;
    }
  }

  void _applyDepartmentMenus(dynamic raw) {
    if (raw is! Map) return;
    _departmentMenus.clear();
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toUpperCase();
      if (key.isEmpty) continue;
      final rawRoutes = entry.value;
      if (rawRoutes is List) {
        final routes = rawRoutes
            .map((r) => r.toString())
            .map(_normalizeClientRoute)
            .where(
              (r) => orderedMenuRoutes.contains(r) || r == '/user-register',
            )
            .toSet();
        if (routes.isNotEmpty) {
          _departmentMenus[key] = routes;
        }
      }
    }
  }

  /// Department-level menu switch for the Access Provider matrix. Mirrors
  /// [setMenuAccess] with snapshot + rollback on failure.
  Future<bool> setDepartmentMenuAccess({
    required String department,
    required String route,
    required bool allowed,
  }) async {
    if (department.trim().isEmpty) return false;
    if (!protectedRoutes.contains(route)) return false;

    final normalizedDept = department.trim().toUpperCase();
    final snapshot = {
      for (final entry in _departmentMenus.entries) entry.key: {...entry.value},
    };

    final target = _departmentMenus.putIfAbsent(
      normalizedDept,
      () => Set<String>.from(orderedMenuRoutes),
    );
    if (allowed) {
      target.add(route);
    } else {
      target.remove(route);
    }
    notifyListeners();

    final saved = await savePermissions();
    if (!saved) {
      _departmentMenus
        ..clear()
        ..addAll(snapshot);
      notifyListeners();
    }
    return saved;
  }

  void resetDefaultsLocal() {
    _resetDefaults();
    notifyListeners();
  }

  void _applyPermissionsResponse(
    Map<String, dynamic> response, {
    bool fallbackToDefaults = false,
  }) {
    final permissions = response['permissions'];
    if (permissions is Map<String, dynamic>) {
      _applyPermissionsMap(
        permissions,
        rolesFromApi: (response['roles'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(growable: false),
      );
    } else if (fallbackToDefaults) {
      _resetDefaults();
    }
    final rawDelete = response['deleteEnabled'];
    if (rawDelete is bool) {
      _deleteEnabled = rawDelete;
    }
    _applyDepartmentDelete(response['departments']);
    _applyDepartmentMenus(response['departmentMenus']);
    _applyAuditLogsPayload(response['logs']);
  }

  void _applyAuditLogsPayload(dynamic rawLogs) {
    if (rawLogs is! List) return;
    _auditLogs = rawLogs
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    _auditLoaded = true;
    _auditErrorMessage = null;
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
            .map(_normalizeClientRoute)
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
    _departmentMenus.clear();
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
