// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: AppConstants.animNormal, curve: Curves.easeInOutCubic);
    } else {
      context.go(AppRoutes.phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.phone),
                  child: Text('Passer',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 14)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: 3,
                itemBuilder: (context, index) =>
                    _buildPage(context, index, colors),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                              duration: AppConstants.animFast,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == i ? 24 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPage == i
                                    ? colors.primary
                                    : colors.border,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary),
                      child: Text(
                        _currentPage == 2 ? 'Commencer' : 'Suivant',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Déjà un compte ? ',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 14)),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.phone),
                        child: Text('Se connecter',
                            style: TextStyle(
                                color: colors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
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

  Widget _buildPage(BuildContext context, int index, AppThemeColors colors) {
    final pages = [
      (
        icon: Icons.chat_outlined,
        title: 'Messagerie\ninstantanée',
        subtitle:
            'Échangez en temps réel avec vos collègues. Messages, médias, vocaux — tout en un.'
      ),
      (
        icon: Icons.language_outlined,
        title: 'Traduction\ninstantanée',
        subtitle:
            'Parlez votre langue, soyez compris dans la leur. La barrière linguistique n\'existe plus.'
      ),
      (
        icon: Icons.lock_outline_rounded,
        title: 'Mode\nconfidentiel',
        subtitle:
            'Messages éphémères, verrouillage biométrique et chiffrement de bout en bout.'
      ),
    ];

    final page = pages[index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: colors.primary),
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 48),
          Text(page.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.2))
              .animate()
              .fadeIn(delay: 400.ms),
          const SizedBox(height: 16),
          Text(page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: colors.textSecondary, height: 1.5))
              .animate()
              .fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}
