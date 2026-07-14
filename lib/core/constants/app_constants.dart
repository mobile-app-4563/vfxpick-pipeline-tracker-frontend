class AppConstants {
  static const String appName = 'VFXPick Pipeline';

  // ──── Departments (fixed) ──────────────────────────────────────────────────
  static const String deptRoto = 'ROTO';
  static const String deptPaint = 'PAINT';
  static const String deptMM = 'MM';
  static const String deptComp = 'COMP';

  static const List<String> _defaultPipelineDepartments = [
    deptRoto,
    deptPaint,
    deptMM,
    deptComp,
  ];

  // Departments offered at registration (includes management groups).
  static const List<String> _defaultDepartments = [
    deptRoto,
    deptPaint,
    deptMM,
    deptComp,
    'Production',
    'Management',
  ];

  // ──── Roles ────────────────────────────────────────────────────────────────
  static const String roleAdmin = 'Admin';
  static const String roleProduction = 'Production';
  static const String roleManagement = 'Management';
  static const String roleSupervisor = 'Supervisor';
  static const String roleTeamLead = 'Team Lead';
  static const String roleArtist = 'Artist';

  // Kept for backward compatibility with the auth register screen default.
  static const String roleEmployee = roleArtist;

  static const List<String> _defaultUserRoles = [
    roleAdmin,
    roleProduction,
    roleManagement,
    roleSupervisor,
    roleTeamLead,
    roleArtist,
  ];

  static const List<String> _defaultBroadAccessRoles = [
    roleAdmin,
    roleProduction,
    roleManagement,
  ];

  static List<String> _pipelineDepartments = List<String>.from(
    _defaultPipelineDepartments,
  );
  static List<String> _departments = List<String>.from(_defaultDepartments);
  static List<String> _userRoles = List<String>.from(_defaultUserRoles);
  static List<String> _broadAccessRoles = List<String>.from(
    _defaultBroadAccessRoles,
  );

  static List<String> get pipelineDepartments =>
      List<String>.unmodifiable(_pipelineDepartments);
  static List<String> get departments =>
      List<String>.unmodifiable(_departments);
  static List<String> get userRoles => List<String>.unmodifiable(_userRoles);
  static List<String> get broadAccessRoles =>
      List<String>.unmodifiable(_broadAccessRoles);

  static List<String> _normalizeStringList(dynamic raw) {
    return ((raw as List<dynamic>?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static void applyDynamicOptions(Map<String, dynamic> payload) {
    final roles = _normalizeStringList(payload['roles']);
    final departments = _normalizeStringList(payload['departments']);
    final pipelineDepartments = _normalizeStringList(
      payload['pipelineDepartments'],
    );
    final broadAccessRoles = _normalizeStringList(payload['broadAccessRoles']);
    final artistLevels = _normalizeStringList(payload['artistLevels']);
    final shotStatuses = _normalizeStringList(payload['shotStatuses']);
    final supervisorStatuses = _normalizeStringList(
      payload['supervisorStatuses'],
    );
    final artistStatuses = _normalizeStringList(payload['artistStatuses']);

    if (roles.isNotEmpty) _userRoles = roles;
    if (departments.isNotEmpty) _departments = departments;
    if (pipelineDepartments.isNotEmpty) {
      _pipelineDepartments = pipelineDepartments;
    }
    if (broadAccessRoles.isNotEmpty) {
      _broadAccessRoles = broadAccessRoles;
    }
    if (artistLevels.isNotEmpty) {
      _artistLevels = artistLevels;
    }
    if (shotStatuses.isNotEmpty) {
      _shotStatuses = shotStatuses;
    }
    if (supervisorStatuses.isNotEmpty) {
      _supervisorStatuses = supervisorStatuses;
    }
    if (artistStatuses.isNotEmpty) {
      _artistStatuses = artistStatuses;
    }
  }

  static List<String> accessiblePipelineDepartments({
    required String? role,
    required String? department,
  }) {
    if (broadAccessRoles.contains(role)) {
      return pipelineDepartments;
    }
    if (pipelineDepartments.contains(department)) {
      return [department!];
    }
    return const [];
  }

  // ──── Artist levels ──────────────────────────────────────────────────────────
  static const List<String> _defaultArtistLevels = ['Senior', 'Mid', 'Junior'];
  static List<String> _artistLevels = List<String>.from(_defaultArtistLevels);
  static List<String> get artistLevels =>
      List<String>.unmodifiable(_artistLevels);

  // ──── Shot (client) statuses ─────────────────────────────────────────────────
  static const List<String> _defaultShotStatuses = [
    'Hold',
    'Approved',
    'Awaiting Approval',
    'Approved Internal',
    'Client Feedback',
  ];
  static List<String> _shotStatuses = List<String>.from(_defaultShotStatuses);
  static List<String> get shotStatuses =>
      List<String>.unmodifiable(_shotStatuses);

  // ──── Supervisor review statuses ─────────────────────────────────────────────
  static const List<String> _defaultSupervisorStatuses = [
    'Awaiting QC',
    'Feedback',
    'Approved',
    'Hold',
  ];
  static List<String> _supervisorStatuses = List<String>.from(
    _defaultSupervisorStatuses,
  );
  static List<String> get supervisorStatuses =>
      List<String>.unmodifiable(_supervisorStatuses);

  // ──── Artist work statuses ───────────────────────────────────────────────────
  static const List<String> _defaultArtistStatuses = [
    'YTS',
    'In Progress',
    'Awaiting QC',
    'WIP Completed',
    'Render & Upload Completed',
    'QC',
    'Additional',
  ];
  static List<String> _artistStatuses = List<String>.from(
    _defaultArtistStatuses,
  );
  static List<String> get artistStatuses =>
      List<String>.unmodifiable(_artistStatuses);

  static const List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}
