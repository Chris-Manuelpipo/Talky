// lib/core/theme/app_colors_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../../features/settings/data/settings_providers.dart';

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color bubbleSent;
  final Color bubbleReceived;
  final Color bubbleSentText;
  final Color bubbleReceivedText;
  final Color divider;
  final Color border;
  final Color inputFill;
  final Color primary;
  final Color accent;
  final Color error;
  final Color success;
  final Color online;
  final Color offline;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.bubbleSent,
    required this.bubbleReceived,
    required this.bubbleSentText,
    required this.bubbleReceivedText,
    required this.divider,
    required this.border,
    required this.inputFill,
    required this.primary,
    required this.accent,
    required this.error,
    required this.success,
    required this.online,
    required this.offline,
  });

  static AppThemeColors dark(Color accentColor) {
    final primary = AppColors.primaryFromAccent(accentColor);
    final accent = AppColors.accentFromPrimary(primary);

    return AppThemeColors(
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceVariant: AppColors.surfaceVariant,
      surfaceHigh: AppColors.surfaceHigh,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textHint: AppColors.textHint,
      bubbleSent: AppColors.bubbleSentFromAccent(accentColor),
      bubbleReceived: AppColors.bubbleReceived,
      bubbleSentText: AppColors.bubbleSentTextFromAccent(accentColor, true),
      bubbleReceivedText: AppColors.bubbleReceivedText,
      divider: AppColors.divider,
      border: AppColors.border,
      inputFill: AppColors.inputFill,
      primary: primary,
      accent: accent,
      error: AppColors.error,
      success: AppColors.success,
      online: AppColors.online,
      offline: AppColors.offline,
    );
  }

  static AppThemeColors light(Color accentColor) {
    final primary = AppColors.primaryFromAccent(accentColor);
    final accent = AppColors.accentFromPrimary(primary);

    return AppThemeColors(
      background: AppColors.backgroundLight,
      surface: AppColors.surfaceLight,
      surfaceVariant: AppColors.surfaceVariantLight,
      surfaceHigh: AppColors.surfaceHighLight,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      textHint: AppColors.textHintLight,
      bubbleSent: AppColors.bubbleSentFromAccent(accentColor),
      bubbleReceived: AppColors.bubbleReceivedLight,
      bubbleSentText: AppColors.bubbleSentTextFromAccent(accentColor, false),
      bubbleReceivedText: AppColors.bubbleReceivedTextLight,
      divider: AppColors.dividerLight,
      border: AppColors.borderLight,
      inputFill: AppColors.inputFillLight,
      primary: primary,
      accent: accent,
      error: AppColors.errorLight,
      success: AppColors.successLight,
      online: AppColors.onlineLight,
      offline: AppColors.offlineLight,
    );
  }
}

final themeColorsProvider = Provider<AppThemeColors>((ref) {
  final settings = ref.watch(settingsProvider);
  final accentColor = settings.accentColor;
  final brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  return brightness == Brightness.light
      ? AppThemeColors.light(accentColor)
      : AppThemeColors.dark(accentColor);
});

extension AppColorsExtension on BuildContext {
  AppThemeColors get appThemeColors {
    final brightness = Theme.of(this).brightness;
    final container = ProviderScope.containerOf(this);
    final settings = container.read(settingsProvider);
    final accentColor = settings.accentColor;

    return brightness == Brightness.light
        ? AppThemeColors.light(accentColor)
        : AppThemeColors.dark(accentColor);
  }

  Color get backgroundColor => appThemeColors.background;
  Color get surfaceColor => appThemeColors.surface;
  Color get surfaceVariantColor => appThemeColors.surfaceVariant;
  Color get surfaceHighColor => appThemeColors.surfaceHigh;
  Color get textPrimaryColor => appThemeColors.textPrimary;
  Color get textSecondaryColor => appThemeColors.textSecondary;
  Color get textHintColor => appThemeColors.textHint;
  Color get bubbleSentColor => appThemeColors.bubbleSent;
  Color get bubbleReceivedColor => appThemeColors.bubbleReceived;
  Color get bubbleSentTextColor => appThemeColors.bubbleSentText;
  Color get bubbleReceivedTextColor => appThemeColors.bubbleReceivedText;
  Color get dividerColor => appThemeColors.divider;
  Color get borderColor => appThemeColors.border;
  Color get inputFillColor => appThemeColors.inputFill;
  Color get primaryColor => appThemeColors.primary;
  Color get accentColor => appThemeColors.accent;
  Color get errorColor => appThemeColors.error;
  Color get successColor => appThemeColors.success;
  Color get onlineColor => appThemeColors.online;
  Color get offlineColor => appThemeColors.offline;
}
