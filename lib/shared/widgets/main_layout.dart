import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/controllers/theme_controller.dart';
import '../../modules/auth/controller/auth_controller.dart';
import '../../modules/notifications/controller/notification_controller.dart';
import 'custom_sidebar.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String pageTitle;

  const MainLayout({super.key, required this.child, required this.pageTitle});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().refreshUnreadCount();
    });
  }

  String _getPageTitle(String path) {
    if (path.contains('/home')) return 'Home';
    if (path.contains('/dashboard')) return 'Dashboard';
    if (path.contains('/projects')) return 'Projects';
    if (path.contains('/assets')) return 'Assets';
    if (path.contains('/tasks')) return 'Tasks';
    if (path.contains('/review')) return 'Review';
    if (path.contains('/reports')) return 'Reports';
    if (path.contains('/teams')) return 'Teams';
    if (path.contains('/notifications')) return 'Notifications';
    if (path.contains('/hrms')) return 'HRMS';
    if (path.contains('/access-provider')) return 'Access Provider';
    if (path.contains('/inventory')) return 'Inventory';
    if (path.contains('/user-register')) return 'Register';
    return 'VFXPICK Pipeline';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authController = Provider.of<AuthController>(context);
    final themeController = Provider.of<ThemeController>(context);
    final notificationController = Provider.of<NotificationController>(context);

    final user = authController.currentUser;
    final currentRoute = GoRouterState.of(context).uri.path;
    final pageTitle =
        widget.pageTitle.isNotEmpty && !widget.pageTitle.startsWith('/')
        ? widget.pageTitle
        : _getPageTitle(currentRoute);

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: PointerInterceptor(
          child: SafeArea(child: CustomSidebar(scaffoldKey: _scaffoldKey)),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),

        child: PointerInterceptor(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: AppBar(
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 60,
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(
                  Icons.menu,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              actions: isMobile
                  ? [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none,
                              size: 22,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            onPressed: () => context.go('/notifications'),
                          ),
                          if (notificationController.unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.priorityHigh,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${notificationController.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Quick actions',
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.brandGreen,
                          child: Text(
                            (user?.avatar.isNotEmpty ?? false)
                                ? user!.avatar
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'theme') {
                            themeController.toggleTheme(
                              !themeController.isDarkMode,
                            );
                          } else if (value == 'notifications') {
                            context.go('/notifications');
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.name ?? 'Guest User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${user?.role ?? ''} • ${user?.department ?? ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'theme',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.brightness_6_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  themeController.isDarkMode
                                      ? 'Switch to Light'
                                      : 'Switch to Dark',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'notifications',
                            child: Row(
                              children: [
                                Icon(Icons.notifications_none, size: 18),
                                SizedBox(width: 8),
                                Text('Notifications'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                    ]
                  : [
                      SizedBox(
                        height: 40,
                        child: VerticalDivider(
                          thickness: 1,
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.light_mode,
                            size: 16,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.brandGreen,
                          ),
                          Switch(
                            value: themeController.isDarkMode,
                            onChanged: themeController.toggleTheme,
                            activeColor: AppColors.brandGreen,
                          ),
                          Icon(
                            Icons.dark_mode,
                            size: 16,
                            color: isDark
                                ? AppColors.brandGreen
                                : AppColors.lightTextSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none,
                              size: 24,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            onPressed: () => context.go('/notifications'),
                          ),
                          if (notificationController.unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.priorityHigh,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${notificationController.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.brandGreen,
                              child: Text(
                                (user?.avatar.isNotEmpty ?? false)
                                    ? user!.avatar
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Guest User',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  '${user?.role ?? ''}  •  ${user?.department ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20),
        child: Transform.scale(scale: 1, child: widget.child),
      ),
    );
  }
}
