// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/create_group_screen.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

abstract class AppRoutes {
  static const splash       = '/';
  static const onboarding   = '/onboarding';
  static const phone        = '/phone';
  static const otp          = '/otp';
  static const profileSetup = '/profile-setup';
  static const home         = '/home';
  static const newChat      = '/new-chat';
  static const createGroup  = '/create-group';
  static const chat         = '/chat/:conversationId';
}

// ── Provider profil complet ────────────────────────────────────────────
// Vérifie dans Firestore si le profil de l'utilisateur est complet
final profileCompleteProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return false;
  return ref.read(authServiceProvider).isProfileComplete(user.uid);
});

// ── Router ─────────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final authState       = ref.watch(authStateProvider);
  final profileComplete = ref.watch(profileCompleteProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterNotifier(ref),
    redirect: (context, state) {
      final isLoading  = authState.isLoading || profileComplete.isLoading;
      final isLoggedIn = authState.value != null;
      final hasProfile = profileComplete.value ?? false;
      final loc        = state.matchedLocation;

      // Routes publiques (pas de redirection)
      final isAuthRoute = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.phone,
        AppRoutes.otp,
      ].contains(loc);

      if (isLoading) return null;

      // Non connecté → auth
      if (!isLoggedIn && !isAuthRoute && loc != AppRoutes.profileSetup) {
        return AppRoutes.phone;
      }

      // Connecté mais profil incomplet → profile setup
      if (isLoggedIn && !hasProfile && loc != AppRoutes.profileSetup) {
        return AppRoutes.profileSetup;
      }

      // Connecté + profil complet sur une page auth → home
      if (isLoggedIn && hasProfile && (isAuthRoute || loc == AppRoutes.profileSetup)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.phone,
          builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(phoneNumber: extra['phoneNumber'] ?? '');
        },
      ),
      GoRoute(path: AppRoutes.profileSetup,
          builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: AppRoutes.home,
          builder: (_, __) => const HomeScreen()),
      GoRoute(path: AppRoutes.newChat,
          builder: (_, __) => const NewChatScreen()),
      GoRoute(path: AppRoutes.createGroup,
          builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
        path: AppRoutes.chat,
        builder: (_, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            conversationId: conversationId,
            contactName:    extra['name'] ?? 'Discussion',
            contactPhoto:   extra['photo'],
          );
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route introuvable: ${state.error}')),
    ),
  );
});

// ── Notifier pour rafraîchir le router quand auth change ───────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(profileCompleteProvider, (_, __) => notifyListeners());
  }
}