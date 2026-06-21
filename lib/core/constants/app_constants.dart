class AppConstants {
  static const String appName = 'VFXPick Pipeline';

  // ──── Departments (fixed) ──────────────────────────────────────────────────
  static const String deptRoto = 'ROTO';
  static const String deptPaint = 'PAINT';
  static const String deptMM = 'MM';
  static const String deptComp = 'COMP';

  static const List<String> pipelineDepartments = [
    deptRoto,
    deptPaint,
    deptMM,
    deptComp,
  ];

  // Departments offered at registration (includes management groups).
  static const List<String> departments = [
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

  static const List<String> userRoles = [
    roleAdmin,
    roleProduction,
    roleManagement,
    roleSupervisor,
    roleTeamLead,
    roleArtist,
  ];

  static const List<String> broadAccessRoles = [
    roleAdmin,
    roleProduction,
    roleManagement,
  ];

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
  static const List<String> artistLevels = ['Senior', 'Mid', 'Junior'];

  // ──── Shot (client) statuses ─────────────────────────────────────────────────
  static const List<String> shotStatuses = [
    'Hold',
    'Approved',
    'Awaiting Approval',
    'Approved Internal',
    'Client Feedback',
  ];

  // ──── Supervisor review statuses ─────────────────────────────────────────────
  static const List<String> supervisorStatuses = [
    'Awaiting QC',
    'Feedback',
    'Approved',
    'Hold',
    'Client FB',
  ];

  // ──── Artist work statuses ───────────────────────────────────────────────────
  static const List<String> artistStatuses = [
    'YTS',
    'In Progress',
    'WIP Complete',
    'QC',
    'Additional',
  ];

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
