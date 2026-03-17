// lib/features/splash/presentation/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';
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
          if (isComplete) {
            await ref.read(authServiceProvider).saveFcmToken(user.uid);
          }
        }
      },
      loading: () => context.go(AppRoutes.onboarding),
      error:   (_, __) => context.go(AppRoutes.onboarding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appThemeColors;
    
    // Dynamic colors based on theme
    final backgroundColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final gradient = isDark ? AppColors.splashGradient : AppColors.splashGradientLight;
    final primaryColor = colors.primary;
    final accentColor = colors.accent;
    final textSecondaryColor = colors.textSecondary;
    final textPrimaryColor = colors.textPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            // Ambient glow effects - adapted to theme
            Positioned(
              top: -150,
              right: -100,
              child: _GlowCircle(
                size: 350,
                color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
              ),
            ).animate().fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 800.ms,
              curve: Curves.easeOut,
            ),
            Positioned(
              bottom: -120,
              left: -120,
              child: _GlowCircle(
                size: 300,
                color: accentColor.withValues(alpha: isDark ? 0.06 : 0.05),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 800.ms,
              curve: Curves.easeOut,
            ),
            // Additional accent glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: -50,
              child: _GlowCircle(
                size: 150,
                color: primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
              ),
            ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
            
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TalkyLogo(isDark: isDark)
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms)
                    .shimmer(
                      delay: 800.ms,
                      duration: 1200.ms,
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  const SizedBox(height: 32),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: textPrimaryColor,
                    ),
                  ).animate(delay: 400.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondaryColor,
                      letterSpacing: 0.5,
                    ),
                  ).animate(delay: 600.ms)
                    .fadeIn(duration: 500.ms),
                ],
              ),
            ),
            
            // Loading indicator
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: _LoadingIndicator(
                  primaryColor: primaryColor,
                  isDark: isDark,
                ).animate(delay: 1000.ms)
                  .fadeIn(duration: 400.ms)),
            ),
            
            // Version text
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v${AppConstants.appVersion}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textSecondaryColor.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ).animate(delay: 1200.ms).fadeIn(duration: 400.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalkyLogo extends StatelessWidget {
  final bool isDark;
  
  const _TalkyLogo({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3),
            blurRadius: 40,
            spreadRadius: isDark ? 8 : 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 60,
            spreadRadius: isDark ? 15 : 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final Color primaryColor;
  final bool isDark;
  
  const _LoadingIndicator({
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          primaryColor.withValues(alpha: 0.7),
        ),
        backgroundColor: isDark 
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
