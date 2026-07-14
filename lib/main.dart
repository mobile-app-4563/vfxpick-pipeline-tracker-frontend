import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/providers/access_provider.dart';
import 'core/controllers/theme_controller.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/controller/auth_controller.dart';
import 'modules/bidding/controller/bidding_controller.dart';
import 'modules/dashboard/controller/dashboard_controller.dart';
import 'modules/feedback/controller/feedback_controller.dart';
import 'modules/home/controller/home_controller.dart';
import 'modules/notifications/controller/notification_controller.dart';
import 'modules/projects/controller/projects_controller.dart';
import 'modules/reports/controller/reports_controller.dart';
import 'modules/review/controller/review_controller.dart';
import 'modules/tasks/controller/tasks_controller.dart';
import 'modules/teams/controller/teams_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => AccessProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => BiddingController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => FeedbackController()),
        ChangeNotifierProvider(create: (_) => ProjectController()),
        ChangeNotifierProvider(create: (_) => TaskController()),
        ChangeNotifierProvider(create: (_) => TeamController()),
        ChangeNotifierProvider(create: (_) => ReviewController()),
        ChangeNotifierProvider(create: (_) => ReportController()),
        ChangeNotifierProvider(create: (_) => NotificationController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authController = context.read<AuthController>();
    final accessProvider = context.read<AccessProvider>();
    _router = AppRoutes.createRouter(authController, accessProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp.router(
      title: 'VFXPICK Pipeline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      routerConfig: _router,
    );
  }
}
