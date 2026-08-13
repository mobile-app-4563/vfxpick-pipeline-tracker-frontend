import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../controller/notification_controller.dart';
import '../model/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${controller.unreadCount} unread',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: controller.notifications.isEmpty
                  ? null
                  : controller.markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
            TextButton.icon(
              onPressed: controller.notifications.isEmpty
                  ? null
                  : controller.clearAll,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _body(controller)),
      ],
    );
  }

  Widget _body(NotificationController controller) {
    if (controller.isLoading && controller.notifications.isEmpty) {
      return const LoadingWidget();
    }
    if (controller.notifications.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none,
        title: 'No notifications',
        description: 'You are all caught up.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.loadNotifications,
      child: ListView.separated(
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(controller, controller.notifications[i]),
      ),
    );
  }

  Widget _tile(NotificationController controller, NotificationModel n) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: n.isRead
              ? Colors.grey.withValues(alpha: 0.2)
              : AppColors.brandGreen.withValues(alpha: 0.2),
          child: Icon(
            Icons.notifications,
            color: n.isRead ? Colors.grey : AppColors.brandGreen,
            size: 18,
          ),
        ),
        title: Text(
          n.message,
          style: TextStyle(
            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${n.type}  \u2022  ${_fmt(n.timestamp)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: n.isRead
            ? null
            : IconButton(
                icon: const Icon(Icons.check, size: 18),
                onPressed: () => controller.markAsRead(n.id),
              ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
