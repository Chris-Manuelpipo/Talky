// lib/features/home/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/floating_glass_nav_bar.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../status/presentation/status_screen.dart';
import '../../calls/presentation/calls_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../chat/data/chat_providers.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phoneContactsServiceProvider).warmUpIfPermitted();
    });
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
      bottomNavigationBar: FloatingGlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }
}
