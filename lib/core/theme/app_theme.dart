// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  // ── Primary color (Violet) ─────────────────────────────────────────────
  static const Color _primary = AppColors.primary;
  static const Color _accent = AppColors.accent;

  // ═══════════════════════════════════════════════════════════════════════
  // ── DARK THEME ────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  
  static TextTheme get _darkTextTheme => TextTheme(
    displayLarge:  GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
    displayMedium: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
    displaySmall:  GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    headlineLarge: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    headlineMedium:GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    headlineSmall: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
    titleLarge:    GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    titleMedium:   GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
    titleSmall:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
    bodyLarge:     GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    bodyMedium:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    bodySmall:     GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
    labelLarge:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    labelMedium:   GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
    labelSmall:    GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: _darkTextTheme,

    // Couleurs
    colorScheme: const ColorScheme.dark(
      primary:        _primary,
      onPrimary:      Colors.white,
      secondary:      _accent,
      onSecondary:    Colors.white,
      surface:        AppColors.surface,
      onSurface:      AppColors.textPrimary,
      error:          AppColors.error,
      onError:        Colors.white,
    ),

    scaffoldBackgroundColor: AppColors.background,
    primaryColor: _primary,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: _primary,
      unselectedItemColor: AppColors.textHint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // NavigationBar (Material 3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: _primary.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textHint, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: _primary);
        }
        return GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint);
      }),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surfaceVariant,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),

    // Boutons primaires
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        elevation: 0,
        textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Boutons outline
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: _primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Boutons texte
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        textStyle: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      hintStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textHint),
      labelStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    // IconButton
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
      ),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: _primary.withValues(alpha: 0.2),
      labelStyle: GoogleFonts.sora(fontSize: 12, color: AppColors.textPrimary),
      side: const BorderSide(color: AppColors.border, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primary;
        }
        return AppColors.textHint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primary.withValues(alpha: 0.4);
        }
        return AppColors.surfaceVariant;
      }),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // ── LIGHT THEME ────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  
  static TextTheme get _lightTextTheme => TextTheme(
    displayLarge:  GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
    displayMedium: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
    displaySmall:  GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
    headlineLarge: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
    headlineMedium:GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
    headlineSmall: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight),
    titleLarge:    GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
    titleMedium:   GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight),
    titleSmall:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight),
    bodyLarge:     GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimaryLight),
    bodyMedium:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimaryLight),
    bodySmall:     GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondaryLight),
    labelLarge:    GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
    labelMedium:   GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight),
    labelSmall:    GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHintLight),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: _lightTextTheme,

    // Couleurs - Using violet for primary elements on white background
    colorScheme: const ColorScheme.light(
      primary:        _primary,
      onPrimary:      Colors.white,
      secondary:      _accent,
      onSecondary:    Colors.white,
      surface:        AppColors.surfaceLight,
      onSurface:      AppColors.textPrimaryLight,
      error:          AppColors.error,
      onError:        Colors.white,
    ),

    scaffoldBackgroundColor: AppColors.backgroundLight,
    primaryColor: _primary,

    // AppBar - White background with dark text
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundLight,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundLight,
      selectedItemColor: _primary,
      unselectedItemColor: AppColors.textHintLight,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),

    // NavigationBar (Material 3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.backgroundLight,
      elevation: 3,
      indicatorColor: _primary.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textHintLight, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: _primary);
        }
        return GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHintLight);
      }),
    ),

    // Cards - White background with subtle border
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.borderLight, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),

    // Boutons primaires - Violet
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        elevation: 2,
        textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Boutons outline - Violet border
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: _primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Boutons texte - Violet
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        textStyle: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // Inputs - Light gray background
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariantLight,
      hintStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textHintLight),
      labelStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondaryLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 0.5,
      space: 0,
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    // IconButton
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimaryLight,
      ),
    ),

    // FloatingActionButton - Violet
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    // Snackbar - White with dark text
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimaryLight,
      contentTextStyle: GoogleFonts.sora(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariantLight,
      selectedColor: _primary.withValues(alpha: 0.2),
      labelStyle: GoogleFonts.sora(fontSize: 12, color: AppColors.textPrimaryLight),
      side: const BorderSide(color: AppColors.borderLight, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primary;
        }
        return AppColors.textHintLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primary.withValues(alpha: 0.4);
        }
        return AppColors.surfaceVariantLight;
      }),
    ),
  );
}
