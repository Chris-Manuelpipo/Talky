// lib/features/onboarding/presentation/onboarding_screen.dart
// Même fichier que Phase 1 — seule modification : bouton "Commencer" → AppRoutes.phone

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle, required this.accentColor});
}

const _pages = [
  _OnboardingPage(icon: Icons.chat_outlined, title: 'Messagerie\ninstantanée',
      subtitle: 'Échangez en temps réel avec vos collègues. Messages, médias, vocaux — tout en un.',
      accentColor: AppColors.primary),
  _OnboardingPage(icon: Icons.language_outlined, title: 'Traduction\ninstantanée',
      subtitle: 'Parlez votre langue, soyez compris dans la leur. La barrière linguistique n\'existe plus.',
      accentColor: AppColors.accent),
  _OnboardingPage(icon: Icons.lock_outline_rounded, title: 'Mode\nconfidentiel',
      subtitle: 'Messages éphémères, verrouillage biométrique et chiffrement de bout en bout.',
      accentColor: Color(0xFFAD7BFF)),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: AppConstants.animNormal, curve: Curves.easeInOutCubic);
    } else {
      context.go(AppRoutes.phone); // ← Vers PhoneScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.phone),
                  child: const Text('Passer',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _OnboardingPageWidget(page: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: AppConstants.animFast,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? _pages[_currentPage].accentColor : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(backgroundColor: _pages[_currentPage].accentColor),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Commencer' : 'Suivant',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Déjà un compte ? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.phone),
                        child: const Text('Se connecter',
                          style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
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
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accentColor.withValues(alpha: 0.08),
              border: Border.all(color: page.accentColor.withValues(alpha: 0.2), width: 1),
            ),
            child: Center(child: Icon(page.icon, size: 72, color: page.accentColor)),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
          const SizedBox(height: 48),
          Text(page.title, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(page.subtitle, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.6),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}
