// / Central API constants for all VfxPick backend endpoints.
// / All endpoints are mounted under the `/api` prefix.
// /
// / Domain hierarchy: Department -> Client -> Show -> Shots.
class ApiConstants {
  // ───────────────────────────────────────────────────────────────────────────
  // BASE CONFIGURATION
  // ───────────────────────────────────────────────────────────────────────────
  // static const String baseUrlPersonalLaptop =
  // 'https://jdtf4ztk-3000.inc1.devtunnels.ms/api';
  static const String baseUrlServer = 'http://192.168.1.15:3000/api';
  static const String baseUrlLocalhost = 'http://localhost:3000/api';
  static const String baseUrl = baseUrlServer;
  // ───────────────────────────────────────────────────────────────────────────
  // AUTH (/api/auth) — unchanged
  // ───────────────────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String authMe = '/auth/me';
  static const String authOptions = '/auth/options';
  static const String authProfile = '/auth/profile';
  static const String authAddDepartment = '/auth/departments';

  // ───────────────────────────────────────────────────────────────────────────
  // DASHBOARD (/api/dashboard)
  // ───────────────────────────────────────────────────────────────────────────
  static const String dashboardSummary = '/dashboard/summary';
  static const String dashboardHomeSummary = '/dashboard/home-summary';
  static const String dashboardTodaysPickouts = '/dashboard/today-pickouts';
  static const String dashboardArtistPerformance =
      '/dashboard/artist-performance';
  static const String dashboardInventActiveShows =
      '/dashboard/invent-active-shows';
  static String dashboardShowShots(String showId) =>
      '/dashboard/show/$showId/shots';

  // ───────────────────────────────────────────────────────────────────────────
  // PROJECTS (/api/projects)
  // ───────────────────────────────────────────────────────────────────────────
  static const String projectDepartments = '/projects/departments';
  static const String projectClients = '/projects/clients';
  static String projectShowsForClient(String clientId) =>
      '/projects/clients/$clientId/shows';
  static const String projectShots = '/projects/shots';
  static const String projectShotsBulkUpsert = '/projects/shots/bulk-upsert';
  static const String projectShotsBulkDelete = '/projects/shots/bulk-delete';
  static String projectShot(String shotId) => '/projects/shots/$shotId';
  static String projectShotStatus(String shotId) =>
      '/projects/shots/$shotId/status';

  // ───────────────────────────────────────────────────────────────────────────
  // TASKS (/api/tasks)
  // ───────────────────────────────────────────────────────────────────────────
  static const String tasksDepartment = '/tasks/department';
  static const String tasksArtist = '/tasks/artist';
  static String tasksAssign(String shotId) => '/tasks/shots/$shotId/assign';
  static String tasksArtistStatus(String shotId) =>
      '/tasks/shots/$shotId/artist-status';
  static String tasksSupervisorStatus(String shotId) =>
      '/tasks/shots/$shotId/supervisor-status';

  // ───────────────────────────────────────────────────────────────────────────
  // BIDDING (/api/bidding)
  // ───────────────────────────────────────────────────────────────────────────
  static const String biddingPending = '/bidding/pending';
  static const String biddingGridPending = '/bidding/grid-pending';
  static String biddingShot(String shotId) => '/bidding/shot/$shotId';
  static String biddingApprove(String shotId) =>
      '/bidding/shot/$shotId/approve';
  static String biddingReject(String shotId) => '/bidding/shot/$shotId/reject';

  // ───────────────────────────────────────────────────────────────────────────
  // TEAMS (/api/teams)
  // ───────────────────────────────────────────────────────────────────────────
  static const String teams = '/teams';
  static String teamMember(String userId) => '/teams/$userId';

  // ───────────────────────────────────────────────────────────────────────────
  // REVIEW (/api/review)
  // ───────────────────────────────────────────────────────────────────────────
  static const String reviewDepartment = '/review/department';
  static const String reviewIndividual = '/review/individual';
  static const String reviewDepartmentExport = '/review/department/export';
  static const String reviewIndividualExport = '/review/individual/export';
  static String reviewDepartmentExportDownload(String fileName) =>
      '/review/department/export/download?fileName=$fileName';
  static String reviewIndividualExportDownload(String fileName) =>
      '/review/individual/export/download?fileName=$fileName';

  // ───────────────────────────────────────────────────────────────────────────
  // REPORTS (/api/reports)
  // ───────────────────────────────────────────────────────────────────────────
  static const String reports = '/reports';
  static const String reportsExport = '/reports/export';
  static String reportsExportDownload(String fileName) =>
      '/reports/export/download?fileName=$fileName';

  // ───────────────────────────────────────────────────────────────────────────
  // ASSETS (/api/assets)
  // ───────────────────────────────────────────────────────────────────────────
  static const String assets = '/assets';
  static String assetById(String attachmentId) => '/assets/$attachmentId';

  // ───────────────────────────────────────────────────────────────────────────
  // CHAT (/api/chat)
  // ───────────────────────────────────────────────────────────────────────────
  static const String chat = '/chat';

  // ───────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS (/api/notifications)
  // ───────────────────────────────────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String markNotificationAsRead(String notificationId) =>
      '/notifications/$notificationId/read';
  static const String markAllNotificationsAsRead =
      '/notifications/mark-all-read';
  static const String clearAllNotifications = '/notifications/clear-all';

  // ───────────────────────────────────────────────────────────────────────────
  // FEEDBACK (/api/feedback)
  // ───────────────────────────────────────────────────────────────────────────
  static const String feedbackClientList = '/feedback/client';
  static String feedbackShot(String shotId) => '/feedback/shots/$shotId';

  // ───────────────────────────────────────────────────────────────────────────
  // ACCESS (/api/access)
  // ───────────────────────────────────────────────────────────────────────────
  static const String accessPermissions = '/access/permissions';
  static const String accessPermissionsReset = '/access/permissions/reset';
  static const String accessPermissionsAudit = '/access/permissions/audit';
  static const String accessSettings = '/access/settings';
  // ───────────────────────────────────────────────────────────────────────────
  // INVENTORY (/api/inventory)
  // ───────────────────────────────────────────────────────────────────────────
  static const String inventory = '/inventory';
  static String inventoryItem(int id) => '/inventory/$id';

  // ───────────────────────────────────────────────────────────────────────────
  // PRODUCTION (/api/production)
  // ───────────────────────────────────────────────────────────────────────────
  static const String production = '/production';
  static const String productionGrid = '/production/grid';
  static const String productionGridSync = '/production/grid/sync';
  static const String productionGridBulkUpsert = '/production/grid/bulk-upsert';
  static const String productionGridBulkDelete = '/production/grid/bulk-delete';
  static String productionGridRow(String gridId) => '/production/grid/$gridId';
}
