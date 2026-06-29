import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/access_provider.dart';
import '../../modules/auth/controller/auth_controller.dart';
import 'glass_container.dart';

class SidebarItem {
  final String title;
  final IconData icon;
  final String route;

  SidebarItem({required this.title, required this.icon, required this.route});
}

class CustomSidebar extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const CustomSidebar({super.key, required this.scaffoldKey});

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadScheduled) return;
      _loadScheduled = true;
      context.read<AccessProvider>().ensureLoaded();
    });
  }

  IconData _iconForRoute(String route) {
    switch (route) {
      case '/home':
        return Icons.home_outlined;
      case '/dashboard':
        return Icons.dashboard_outlined;
      case '/bidding':
        return Icons.sync_alt_outlined;
      case '/projects':
        return Icons.movie_outlined;
      case '/assets':
        return Icons.folder_outlined;
      case '/tasks':
        return Icons.task_outlined;
      case '/review':
        return Icons.fact_check_outlined;
      case '/feedback':
        return Icons.feedback_outlined;
      case '/reports':
        return Icons.analytics_outlined;
      case '/teams':
        return Icons.groups_outlined;
      case '/notifications':
        return Icons.notifications_none_outlined;
      case '/hrms':
        return Icons.badge_outlined;
      case '/access-provider':
        return Icons.admin_panel_settings_outlined;
      case '/inventory':
        return Icons.inventory_2_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  List<SidebarItem> _getItemsForRole(String role, AccessProvider access) {
    final routes = access.allowedMenuRoutes(role);
    return routes
        .map(
          (route) => SidebarItem(
            title: access.labelForRoute(route, role: role),
            icon: _iconForRoute(route),
            route: route,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessProvider = Provider.of<AccessProvider>(context);
    final authController = Provider.of<AuthController>(context);
    final user = authController.currentUser;
    final role = user?.role ?? '';
    final items = _getItemsForRole(role, accessProvider);
    final String currentRoute = GoRouterState.of(context).uri.path;

    return GlassContainer(
      borderRadius: 0,
      blur: 15.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.movie_filter,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'VFXPICK',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.brandGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = currentRoute == item.route;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: InkWell(
                      onTap: () {
                        widget.scaffoldKey.currentState?.closeDrawer();
                        context.go(item.route);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: isActive ? AppColors.brandGradient : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isActive
                                  ? Colors.white
                                  : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary),
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                children: [
                  const Divider(height: 24, color: AppColors.darkCardBorder),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.brandGreen.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          (user?.avatar.isNotEmpty ?? false)
                              ? user!.avatar
                              : 'U',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Guest User',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${user?.role ?? 'Artist'}  •  ${user?.department ?? ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          authController.logout();
                          context.go('/login');
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: AppColors.priorityHigh,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
