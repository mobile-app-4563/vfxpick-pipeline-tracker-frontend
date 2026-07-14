import 'package:flutter/material.dart';

import '../../../core/services/notification_service.dart';
import '../model/notification_model.dart';

class NotificationController extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
    try {
      final resp = await _service.getAll();
      _notifications = ((resp['notifications'] as List<dynamic>?) ?? const [])
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final resp = await _service.getUnreadCount();
      _unreadCount = (resp['count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationController.refreshUnreadCount error: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationController.markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationController.markAllAsRead error: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _service.clearAll();
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationController.clearAll error: $e');
    }
  }
}
