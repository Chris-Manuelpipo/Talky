// lib/features/splash/presentation/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) async {
        if (user == null) {
          context.go(AppRoutes.onboarding);
        } else {
          final isComplete = await ref
              .read(authServiceProvider)
              .isProfileComplete(user.uid);
          if (mounted) {
            context.go(isComplete ? AppRoutes.home : AppRoutes.profileSetup);
          }
        }
      },
      loading: () => context.go(AppRoutes.onboarding),
      error:   (_, __) => context.go(AppRoutes.onboarding),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: Stack(
          children: [
            Positioned(top: -100, right: -100,
              child: _GlowCircle(size: 300, color: AppColors.primary.withOpacity(0.15))),
            Positioned(bottom: -80, left: -80,
              child: _GlowCircle(size: 250, color: AppColors.accent.withOpacity(0.08))),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TalkyLogo()
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0),
                        duration: 700.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 500.ms),
                  const SizedBox(height: 24),
                  Text(AppConstants.appName,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: 2))
                    .animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 8),
                  Text(AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary, letterSpacing: 0.5))
                    .animate(delay: 500.ms).fadeIn(),
                ],
              ),
            ),
            Positioned(bottom: 60, left: 0, right: 0,
              child: Center(
                child: SizedBox(width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withOpacity(0.6))))
                  .animate(delay: 800.ms).fadeIn())),
          ],
        ),
      ),
    );
  }
}

class _TalkyLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4),
            blurRadius: 30, spreadRadius: 5)],
      ),
      child: const Center(child: Text('T',
        style: TextStyle(fontSize: 52, fontWeight: FontWeight.w700,
            color: Colors.white, height: 1))),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 20)]));
  }
}