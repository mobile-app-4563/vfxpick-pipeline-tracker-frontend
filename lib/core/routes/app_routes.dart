import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vfxpick_pipeline/modules/hrms/view/hrms.dart';

import '../providers/access_provider.dart';
import '../../modules/access_provider/view/access_provider_screen.dart';
import '../../modules/auth/controller/auth_controller.dart';
import '../../modules/auth/view/login_screen.dart';
import '../../modules/auth/view/register_screen.dart';
import '../../modules/assets/view/assets_screen.dart';
import '../../modules/bidding/view/bidding_screen.dart';
import '../../modules/dashboard/view/dashboard_screen.dart';
import '../../modules/feedback/view/feedback_screen.dart';
import '../../modules/home/view/home_screen.dart';
import '../../modules/notifications/view/notifications_screen.dart';
import '../../modules/projects/view/projects_screen.dart';
import '../../modules/reports/view/reports_screen.dart';
import '../../modules/review/view/review_screen.dart';
import '../../modules/tasks/view/tasks_screen.dart';
import '../../modules/teams/view/teams_screen.dart';
import '../../modules/inventory/view/inventory_screen.dart';
import '../../shared/widgets/main_layout.dart';

class AppRoutes {
  static GoRouter createRouter(
    AuthController authController,
    AccessProvider accessProvider,
  ) {
    return GoRouter(
      refreshListenable: Listenable.merge([authController, accessProvider]),
      initialLocation: '/home',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authController.isAuthenticated;
        final role = authController.currentUser?.role ?? '';
        final path = state.uri.path;
        final isGoingToAuth = path == '/login';

        if (!isLoggedIn && !isGoingToAuth) return '/login';
        if (!isLoggedIn && path == '/register') return '/login';
        if (isLoggedIn && isGoingToAuth) return '/home';
        if (isLoggedIn && !accessProvider.canAccessPath(role, path)) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              MainLayout(pageTitle: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),

            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/bidding',
              builder: (context, state) => const BiddingScreen(),
            ),
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsScreen(),
            ),
            GoRoute(
              path: '/assets',
              builder: (context, state) => const AssetsScreen(),
            ),
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
            GoRoute(
              path: '/review',
              builder: (context, state) => const ReviewScreen(),
            ),
            GoRoute(
              path: '/feedback',
              builder: (context, state) => const FeedbackScreen(),
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
            GoRoute(
              path: '/teams',
              builder: (context, state) => const TeamsScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/hrms',
              builder: (context, state) => const HrmsView(),
            ),
            GoRoute(
              path: '/access-provider',
              builder: (context, state) => const AccessProviderScreen(),
            ),
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
