// lib/core/widgets/floating_glass_nav_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors_provider.dart';

class FloatingGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Discussions',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                  colors: colors,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.group_outlined,
                  selectedIcon: Icons.group_rounded,
                  label: 'Groupes',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                  colors: colors,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.circle_outlined,
                  selectedIcon: Icons.circle_rounded,
                  label: 'Statuts',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                  colors: colors,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.call_outlined,
                  selectedIcon: Icons.call_rounded,
                  label: 'Appels',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                  colors: colors,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: 'Paramètres',
                  isSelected: currentIndex == 4,
                  onTap: () => onTap(4),
                  colors: colors,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic colors;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? colors.primary
                    : isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.5),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: isSelected ? 10.5 : 0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colors.primary : Colors.transparent,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
