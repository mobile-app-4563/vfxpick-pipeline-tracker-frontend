import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Notifications API calls.
class NotificationService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getAll() => _api.get(ApiConstants.notifications);

  Future<Map<String, dynamic>> getUnreadCount() =>
      _api.get(ApiConstants.notificationsUnreadCount);

  Future<Map<String, dynamic>> markAsRead(String id) =>
      _api.patch(ApiConstants.markNotificationAsRead(id));

  Future<Map<String, dynamic>> markAllAsRead() =>
      _api.post(ApiConstants.markAllNotificationsAsRead, {});

  Future<Map<String, dynamic>> clearAll() =>
      _api.delete(ApiConstants.clearAllNotifications);
}
