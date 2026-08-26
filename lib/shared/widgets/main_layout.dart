import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/controllers/theme_controller.dart';
import '../../core/utils/size_config.dart';
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
    if (path.contains('/projects')) return 'Projects';
    if (path.contains('/production-management')) return 'Production Management';
    if (path.contains('/assets')) return 'Assets';
    if (path.contains('/tasks')) return 'Tasks';
    if (path.contains('/review')) return 'Review';
    if (path.contains('/feedback')) return 'Feedback';
    if (path.contains('/reports')) return 'Reports';
    if (path.contains('/teams')) return 'Teams';
    if (path.contains('/notifications')) return 'Notifications';
    if (path.contains('/access-provider')) return 'Access Provider';
    if (path.contains('/inventory')) return 'Inventory';
    if (path.contains('/user-register')) return 'Register';
    if (path.contains('/profile')) return 'My Profile';
    if (path.contains('/audit-logs')) return 'Audit Logs';
    return 'VFXPICK Pipeline';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = SizeConfig.isMobile(context);
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
        preferredSize: Size.fromHeight(SizeConfig.scaleHeight(context, 90)),
        child: PointerInterceptor(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: SizeConfig.scaleHeight(context, 4),
            ),
            child: AppBar(
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: SizeConfig.scaleHeight(context, 60),
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
                  fontSize: SizeConfig.deviceValue(
                    context,
                    mobile: 16.0,
                    desktop: 18.0,
                  ),
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
                              size: SizeConfig.iconSize(context, 22),
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            onPressed: () => context.go('/notifications'),
                          ),
                          if (notificationController.unreadCount > 0)
                            Positioned(
                              right: SizeConfig.scaleWidth(context, 6),
                              top: SizeConfig.scaleHeight(context, 6),
                              child: Container(
                                padding: EdgeInsets.all(
                                  SizeConfig.scaleWidth(context, 4),
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.priorityHigh,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: SizeConfig.scaleWidth(context, 16),
                                  minHeight: SizeConfig.scaleWidth(context, 16),
                                ),
                                child: Text(
                                  '${notificationController.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: SizeConfig.fontSize(context, 9),
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
                          radius: SizeConfig.scaleWidth(context, 14),
                          backgroundColor: AppColors.brandGreen,
                          child: Text(
                            (user?.avatar.isNotEmpty ?? false)
                                ? user!.avatar
                                : 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: SizeConfig.fontSize(context, 11),
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
                          } else if (value == 'profile') {
                            context.go('/profile');
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
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 2),
                                ),
                                Text(
                                  '${user?.role ?? ''} • ${user?.department ?? ''}',
                                  style: TextStyle(
                                    fontSize: SizeConfig.fontSize(context, 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'theme',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.brightness_6_outlined,
                                  size: SizeConfig.iconSize(context, 18),
                                ),
                                SizeConfig.sizedBoxW(context, 8),
                                Text(
                                  themeController.isDarkMode
                                      ? 'Switch to Light'
                                      : 'Switch to Dark',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: SizeConfig.iconSize(context, 18),
                                ),
                                SizeConfig.sizedBoxW(context, 8),
                                Text('My Profile'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'notifications',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: SizeConfig.iconSize(context, 18),
                                ),
                                SizeConfig.sizedBoxW(context, 8),
                                Text('Notifications'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizeConfig.sizedBoxW(context, 6),
                    ]
                  : [
                      SizedBox(
                        height: SizeConfig.scaleHeight(context, 40),
                        child: VerticalDivider(
                          thickness: 1,
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      SizeConfig.sizedBoxW(context, 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.light_mode,
                            size: SizeConfig.iconSize(context, 16),
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
                            size: SizeConfig.iconSize(context, 16),
                            color: isDark
                                ? AppColors.brandGreen
                                : AppColors.lightTextSecondary,
                          ),
                        ],
                      ),
                      SizeConfig.sizedBoxW(context, 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none,
                              size: SizeConfig.iconSize(context, 24),
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            onPressed: () => context.go('/notifications'),
                          ),
                          if (notificationController.unreadCount > 0)
                            Positioned(
                              right: SizeConfig.scaleWidth(context, 6),
                              top: SizeConfig.scaleHeight(context, 6),
                              child: Container(
                                padding: EdgeInsets.all(
                                  SizeConfig.scaleWidth(context, 4),
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.priorityHigh,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: SizeConfig.scaleWidth(context, 16),
                                  minHeight: SizeConfig.scaleWidth(context, 16),
                                ),
                                child: Text(
                                  '${notificationController.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: SizeConfig.fontSize(context, 9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizeConfig.sizedBoxW(context, 8),
                      Padding(
                        padding: SizeConfig.paddingSymmetric(
                          context,
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: SizeConfig.scaleWidth(context, 16),
                              backgroundColor: AppColors.brandGreen,
                              child: Text(
                                (user?.avatar.isNotEmpty ?? false)
                                    ? user!.avatar
                                    : 'U',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: SizeConfig.fontSize(context, 12),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizeConfig.sizedBoxW(context, 8),
                            // FittedBox keeps the two-line name/role block
                            // inside the AppBar's constrained action height;
                            // otherwise it overflows by ~8px and throws a
                            // RenderFlex overflow error on every frame.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name ?? 'Guest User',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: SizeConfig.fontSize(
                                          context,
                                          13,
                                        ),
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
                                        fontSize: SizeConfig.fontSize(
                                          context,
                                          10,
                                        ),
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizeConfig.sizedBoxW(context, 12),
                    ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.scaleWidth(context, isMobile ? 10 : 20),
        ),
        child: widget.child,
      ),
    );
  }
}
