// lib/features/home/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../status/presentation/status_screen.dart';
import '../../calls/presentation/calls_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    ConversationsScreen(),
    GroupsScreen(),                                                    // ← ✅ réel
    StatusScreen(),
    CallsScreen(),
    _PlaceholderScreen(icon: '⚙️', label: 'Paramètres', phase: 'Phase 7'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label:        'Discussions',
          ),
          NavigationDestination(
            icon:         Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label:        'Groupes',
          ),
          NavigationDestination(
            icon:         Icon(Icons.circle_outlined),
            selectedIcon: Icon(Icons.circle_rounded),
            label:        'Statuts',
          ),
          NavigationDestination(
            icon:         Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call_rounded),
            label:        'Appels',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label:        'Paramètres',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder pour les onglets pas encore développés ─────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String icon;
  final String label;
  final String phase;

  const _PlaceholderScreen({
    required this.icon,
    required this.label,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(label,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(phase,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
