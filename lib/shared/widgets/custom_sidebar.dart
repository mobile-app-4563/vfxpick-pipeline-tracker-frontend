import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/access_provider.dart';
import '../../core/utils/size_config.dart';
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
      case '/bidding':
        return Icons.sync_alt_outlined;
      case '/projects':
        return Icons.movie_outlined;
      case '/production-management':
        return Icons.precision_manufacturing_outlined;
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
      case '/register':
        return Icons.person_add_alt_1_outlined;
      case '/notifications':
        return Icons.notifications_none_outlined;
      case '/user-register':
        return Icons.person_add_alt_1_outlined;
      case '/access-provider':
        return Icons.admin_panel_settings_outlined;
      case '/inventory':
        return Icons.inventory_2_outlined;
      case '/profile':
        return Icons.person_outline;
      case '/audit-logs':
        return Icons.history_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  List<SidebarItem> _getItemsForRole(String role, AccessProvider access) {
    // Role menus are intersected with the user's department menus, so an
    // admin toggling a menu OFF for a department hides it from every user of
    // that department (role defaults still apply for new departments).
    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    final department = user?.department;
    final routes = access.allowedMenuRoutes(role, department: department);
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
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.scaleHeight(context, 16),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.scaleWidth(context, 12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(
                        SizeConfig.scaleWidth(context, 10),
                      ),
                    ),
                    child: Icon(
                      Icons.movie_filter,
                      color: Colors.white,
                      size: SizeConfig.iconSize(context, 24),
                    ),
                  ),
                  SizeConfig.sizedBoxW(context, 12),
                  Expanded(
                    child: Text(
                      'VFXPICK',
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 20),
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
            SizedBox(height: SizeConfig.scaleHeight(context, 30)),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = currentRoute == item.route;
                  return Padding(
                    padding: SizeConfig.paddingSymmetric(
                      context,
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: InkWell(
                      onTap: () {
                        widget.scaffoldKey.currentState?.closeDrawer();
                        context.go(item.route);
                      },
                      borderRadius: BorderRadius.circular(
                        SizeConfig.scaleWidth(context, 8),
                      ),
                      child: Container(
                        padding: SizeConfig.paddingSymmetric(
                          context,
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            SizeConfig.scaleWidth(context, 8),
                          ),
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
                              size: SizeConfig.iconSize(context, 22),
                            ),
                            SizeConfig.sizedBoxW(context, 16),
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
                                  fontSize: SizeConfig.fontSize(context, 14),
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
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.scaleWidth(context, 12),
              ),
              child: Column(
                children: [
                  Divider(
                    height: SizeConfig.scaleHeight(context, 24),
                    color: AppColors.darkCardBorder,
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: SizeConfig.scaleWidth(context, 18),
                        backgroundColor: AppColors.brandGreen.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          (user?.avatar.isNotEmpty ?? false)
                              ? user!.avatar
                              : 'U',
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 13),
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizeConfig.sizedBoxW(context, 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Guest User',
                              style: TextStyle(
                                fontSize: SizeConfig.fontSize(context, 13),
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${user?.role ?? 'Artist'}  â€¢  ${user?.department ?? ''}',
                              style: TextStyle(
                                fontSize: SizeConfig.fontSize(context, 11),
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
                        icon: Icon(
                          Icons.logout,
                          color: AppColors.priorityHigh,
                          size: SizeConfig.iconSize(context, 20),
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
