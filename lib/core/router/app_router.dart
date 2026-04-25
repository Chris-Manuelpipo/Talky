// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/create_group_screen.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/chat/presentation/archived_conversations_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/calls/presentation/incoming_call_screen.dart';
import '../../features/meetings/presentation/meetings_screen.dart';
import '../../features/meetings/presentation/meeting_invitations_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const newChat = '/new-chat';
  static const createGroup = '/create-group';
  static const chat = '/chat/:conversationId';
  static const archivedChats = '/archived-chats';
  static const incomingCall = '/incoming-call';
  static const addStatus = '/add-status';
  static const meetings = '/meetings';
  static const meetingInvitations = '/meeting-invitations';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

// ── Provider profil complet (custom auth) ───────────────────────────────
final profileCompleteProvider = FutureProvider<bool>((ref) async {
  final authCustom = ref.watch(authCustomProvider);
  return authCustom.isLoggedIn;
});

// ── Router ─────────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final authCustom = ref.watch(authCustomProvider);
  final profileComplete = ref.watch(profileCompleteProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    navigatorKey: rootNavigatorKey,
    refreshListenable: _RouterNotifier(ref),
    redirect: (context, state) {
      final isLoading = profileComplete.isLoading;
      final isLoggedIn = authCustom.isLoggedIn;
      final loc = state.matchedLocation;

      // Routes publiques (pas de redirection)
      final isPublicRoute = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ].contains(loc);

      if (isLoading) return null;

      // Non connecté → login
      if (!isLoggedIn && !isPublicRoute) {
        return AppRoutes.login;
      }

      // Connecté sur page publique → home
      if (isLoggedIn && isPublicRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: AppRoutes.newChat, builder: (_, __) => const NewChatScreen()),
      GoRoute(
          path: AppRoutes.createGroup,
          builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
          path: AppRoutes.archivedChats,
          builder: (_, __) => const ArchivedConversationsScreen()),
      GoRoute(
        path: AppRoutes.chat,
        builder: (_, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            conversationId: conversationId,
            contactName: extra['name'] ?? 'Discussion',
            contactPhoto: extra['photo'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.incomingCall,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return IncomingCallScreen(
            callerId: extra['callerId'] ?? '',
            callerName: extra['callerName'] ?? 'Appel entrant',
            isVideo: extra['isVideo'] ?? false,
            isGroup: extra['isGroup'] ?? false,
            roomId: extra['roomId'],
          );
        },
      ),
      GoRoute(
          path: AppRoutes.meetings, builder: (_, __) => const MeetingsScreen()),
      GoRoute(
          path: AppRoutes.meetingInvitations,
          builder: (_, __) => const MeetingInvitationsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route introuvable: ${state.error}')),
    ),
  );
});

// ── Notifier pour rafraîchir le router quand auth change ───────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authCustomProvider, (_, __) => notifyListeners());
    ref.listen(profileCompleteProvider, (_, __) => notifyListeners());
  }
}
