// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Couleurs primaires ──────────────────────────────────────────────
  static const Color primary        = Color(0xFF7C5CFC); // Violet signature Talky
  static const Color primaryLight   = Color(0xFF9D84FD);
  static const Color primaryDark    = Color(0xFF5A3DD8);

  // ── Accent ─────────────────────────────────────────────────────────
  static const Color accent         = Color(0xFF4FC3F7); // Cyan bleu électrique
  static const Color accentDark     = Color(0xFF0288D1);

  // ── Fonds (Dark theme) ─────────────────────────────────────────────
  static const Color background     = Color(0xFF0A0A0F); // Noir profond
  static const Color surface        = Color(0xFF12121A); // Surface légèrement plus claire
  static const Color surfaceVariant = Color(0xFF1C1C28); // Cards, containers
  static const Color surfaceHigh    = Color(0xFF252535); // Éléments surélevés
  static const Color inputFill      = surfaceVariant;

  // ── Textes ─────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF0EEFF); // Blanc cassé violet
  static const Color textSecondary  = Color(0xFF9B96B8); // Gris violet
  static const Color textHint       = Color(0xFF5A5570);  // Placeholder

  // ── Messages ───────────────────────────────────────────────────────
  static const Color bubbleSent     = Color(0xFF7C5CFC); // Violet (messages envoyés)
  static const Color bubbleReceived = Color(0xFF1C1C28); // Surface sombre (messages reçus)
  static const Color bubbleSentText     = Color(0xFFFFFFFF);
  static const Color bubbleReceivedText = Color(0xFFF0EEFF);

  // ── États & feedbacks ──────────────────────────────────────────────
  static const Color success  = Color(0xFF4CAF82);
  static const Color warning  = Color(0xFFFFB547);
  static const Color error    = Color(0xFFFF5C7A);
  static const Color online   = Color(0xFF4CAF82);
  static const Color offline  = Color(0xFF5A5570);

  // ── Séparateurs & bordures ─────────────────────────────────────────
  static const Color divider  = Color(0xFF1C1C28);
  static const Color border   = Color(0xFF2A2A3C);

  // ── Overlay & ombres ───────────────────────────────────────────────
  static const Color overlay  = Color(0x807C5CFC); // Violet transparent
  static const Color shadow   = Color(0x997C5CFC); // Ombre violette

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF0D0D1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF1A0F2E), Color(0xFF0A0A0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
