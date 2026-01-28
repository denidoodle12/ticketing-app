import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/change_password_screen.dart';
import '../features/auth/screens/change_password_success_screen.dart';
import '../features/main/screens/main_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/tickets/screens/create_ticket_screen.dart';
import '../features/tickets/screens/ticket_detail_screen.dart';
import '../features/tickets/models/ticket_model.dart';
import '../features/search/screens/search_screen.dart';

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String changePassword = '/change-password';
  static const String changePasswordSuccess = '/change-password-success';
  static const String home = '/home';
  static const String search = '/search';
  static const String createTicket = '/tickets/create';
  static const String ticketDetail = '/tickets/detail';

  // Navigator key for global access
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // GoRouter configuration
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: changePassword,
        name: 'changePassword',
        builder: (context, state) {
          final isFirstLogin = state.extra as bool? ?? false;
          return ChangePasswordScreen(isFirstLogin: isFirstLogin);
        },
      ),
      GoRoute(
        path: changePasswordSuccess,
        name: 'changePasswordSuccess',
        builder: (context, state) => const ChangePasswordSuccessScreen(),
      ),
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) {
          // Check if we need to show welcome toast (from change password success)
          final extra = state.extra;
          bool showWelcomeToast = false;
          if (extra is Map<String, dynamic>) {
            showWelcomeToast = extra['showWelcomeToast'] as bool? ?? false;
          }
          return MainScreen(showWelcomeToast: showWelcomeToast);
        },
      ),
      GoRoute(
        path: search,
        name: 'search',
        builder: (context, state) {
          final initialQuery = state.extra as String?;
          return SearchScreen(initialQuery: initialQuery);
        },
      ),
      GoRoute(
        path: createTicket,
        name: 'createTicket',
        builder: (context, state) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: ticketDetail,
        name: 'ticketDetail',
        builder: (context, state) {
          final ticket = state.extra as Ticket;
          return TicketDetailScreen(ticket: ticket);
        },
      ),
    ],
  );
}
