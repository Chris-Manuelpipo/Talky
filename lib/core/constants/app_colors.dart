// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════
  // ── PRIMARY COLORS (Violet Talky) - Common to both themes ─────────────
  // ═══════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF7C5CFC); // Violet signature
  static const Color primaryLight = Color(0xFF9D84FD);
  static const Color primaryDark = Color(0xFF5A3DD8);

  // Accent
  static const Color accent = Color(0xFF4FC3F7);
  static const Color accentDark = Color(0xFF0288D1);

  // ═══════════════════════════════════════════════════════════════════════
  // ── COLOR GENERATION METHODS (HSL) ────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  static Color primaryFromAccent(Color accent) => accent;

  static Color primaryLightFromAccent(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
  }

  static Color primaryDarkFromAccent(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  static Color accentFromPrimary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final newHue = (hsl.hue + 40) % 360;
    return hsl.withHue(newHue).toColor();
  }

  static Color accentDarkFromAccent(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }

  // Bubble colors - adapts to theme
  static Color bubbleSentFromAccent(Color accent) => accent;

  static Color bubbleSentTextFromAccent(Color accent, bool isDark) {
    return isDark ? Colors.white : Colors.white;
  }

  static Color overlayFromAccent(Color accent) => accent.withValues(alpha: 0.5);
  static Color shadowFromAccent(Color accent) => accent.withValues(alpha: 0.6);

  // ═══════════════════════════════════════════════════════════════════════
  // ── DARK THEME COLORS (Default) ──────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  // Backgrounds
  static const Color background = Color(0xFF0A0A0F); // Noir profond
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceVariant = Color(0xFF1C1C28);
  static const Color surfaceHigh = Color(0xFF252535);
  static const Color inputFill = surfaceVariant;

  // Text
  static const Color textPrimary = Color(0xFFF0EEFF);
  static const Color textSecondary = Color(0xFF9B96B8);
  static const Color textHint = Color(0xFF5A5570);

  // Messages
  static const Color bubbleSent = Color(0xFF7C5CFC);
  static const Color bubbleReceived = Color(0xFF1C1C28);
  static const Color bubbleSentText = Color(0xFFFFFFFF);
  static const Color bubbleReceivedText = Color(0xFFF0EEFF);

  // Dividers & Borders
  static const Color divider = Color(0xFF1C1C28);
  static const Color border = Color(0xFF2A2A3C);

  // Status colors
  static const Color success = Color(0xFF4CAF82);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF5C7A);
  static const Color online = Color(0xFF4CAF82);
  static const Color offline = Color(0xFF5A5570);

  // Overlay
  static const Color overlay = Color(0x807C5CFC);
  static const Color shadow = Color(0x997C5CFC);

  // ═══════════════════════════════════════════════════════════════════════
  // ── LIGHT THEME COLORS - Amélioré pour une meilleure harmonie ─────────
  // ═══════════════════════════════════════════════════════════════════════

  // Backgrounds - Version améliorée avec subtils reflets bleutés
  static const Color backgroundLight =
      Color(0xFFF8F9FC); // Gris très clair bleuté
  static const Color surfaceLight = Color(0xFFFFFFFF); // Blanc pur
  static const Color surfaceVariantLight = Color(0xFFF0F2F5); // Gris clair
  static const Color surfaceHighLight = Color(0xFFE8EAED); // Gris moyen
  static const Color inputFillLight = Color(0xFFF0F2F5);

  // Text - Meilleure lisibilité avec noir bleuté
  static const Color textPrimaryLight = Color(0xFF1A1A2E); // Noir bleuté
  static const Color textSecondaryLight = Color(0xFF5A5A7A); // Gris foncé
  static const Color textHintLight = Color(0xFF9E9EA8); // Gris moyen

  // Messages - Couleurs harmonieuses
  static const Color bubbleSentLight = Color(0xFF7C5CFC); // Violet primaire
  static const Color bubbleReceivedLight = Color(0xFFF0F2F5); // Gris clair
  static const Color bubbleSentTextLight = Color(0xFFFFFFFF);
  static const Color bubbleReceivedTextLight = Color(0xFF1A1A2E);

  // Status colors - Version plus visible sur fond clair
  static const Color successLight = Color(0xFF2E7D32); // Vert foncé
  static const Color warningLight = Color(0xFFF57C00); // Orange foncé
  static const Color errorLight = Color(0xFFD32F2F); // Rouge foncé
  static const Color onlineLight = Color(0xFF2E7D32); // Vert foncé
  static const Color offlineLight = Color(0xFF9E9EA8); // Gris moyen

  // Dividers & Borders
  static const Color dividerLight = Color(0xFFE0E2E5);
  static const Color borderLight = Color(0xFFD0D2D5);

  // ═══════════════════════════════════════════════════════════════════════
  // ── GRADIENTS ─────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════

  static LinearGradient primaryGradient(Color accent) => LinearGradient(
        colors: [accent, accentFromPrimary(accent)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF0D0D1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient splashGradient(Color accent) => LinearGradient(
        colors: [Color(0xFF0A0A0F), Color(0xFF1A0F2E), Color(0xFF0A0A0F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient splashGradientLight(Color accent) => LinearGradient(
        colors: [Color(0xFFF8F9FC), Color(0xFFE8E4F8), Color(0xFFF8F9FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
