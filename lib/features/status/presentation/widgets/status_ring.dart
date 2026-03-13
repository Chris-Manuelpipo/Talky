// lib/features/status/presentation/widgets/status_ring.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StatusRing extends StatelessWidget {
  final bool hasStatus;
  final bool allViewed;
  final bool isMyStatus;
  final Widget child;

  const StatusRing({
    super.key,
    required this.hasStatus,
    required this.allViewed,
    required this.isMyStatus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasStatus) {
      return Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.divider,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: child,
      );
    }

    return Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: allViewed
            ? LinearGradient(
                colors: [
                  AppColors.textSecondary.withOpacity(0.5),
                  AppColors.textSecondary.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF7C5CFC), // violet
                  Color(0xFF4FC3F7), // cyan
                  Color(0xFFFF6B9D), // rose
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
        ),
        padding: const EdgeInsets.all(2),
        child: child,
      ),
    );
  }
}