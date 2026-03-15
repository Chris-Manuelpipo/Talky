// lib/features/home/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../status/presentation/status_screen.dart';
import '../../calls/presentation/calls_screen.dart';
import '../../settings/presentation/settings_screen.dart';

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
    GroupsScreen(),
    StatusScreen(),
    CallsScreen(),
    SettingsScreen(),
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
    final colors = context.appThemeColors;
    
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
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: colors.textHint),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: colors.primary),
            label: 'Discussions',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: colors.textHint),
            selectedIcon: Icon(Icons.group_rounded, color: colors.primary),
            label: 'Groupes',
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined, color: colors.textHint),
            selectedIcon: Icon(Icons.circle_rounded, color: colors.primary),
            label: 'Statuts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined, color: colors.textHint),
            selectedIcon: Icon(Icons.call_rounded, color: colors.primary),
            label: 'Appels',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: colors.textHint),
            selectedIcon: Icon(Icons.settings_rounded, color: colors.primary),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
