// lib/core/constants/app_constants.dart

import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ── Nom & version ──────────────────────────────────────────────────
  static const String appName = 'Talky';
  static const String appTagline = 'Parlez sans frontières';
  static const String appVersion = '1.0.0';

  // ── Couleurs prédéfinies ─────────────────────────────────────────────
  static const List<Color> predefinedAccentColors = [
    Color(0xFF7C5CFC), // Violet (défaut Talky)
    Color(0xFF2196F3), // Bleu
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4CAF50), // Vert
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Rouge
    Color(0xFFE91E63), // Rose
    Color(0xFF9C27B0), // Violet foncé
    Color(0xFF607D8B), // Bleu gris
    Color(0xFF795548), // Marron
  ]; 

  // ── Language options ───────────────────────────────────────────────────────
  static const Map<String, String> availableLanguages = {
    'fr': 'Français',
    'en': 'English',
    'es': 'Español',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'ar': 'العربية',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
  };

  // ── Visibility options ─────────────────────────────────────────────────────
  static const Map<String, String> visibilityOptions = {
    'everyone': 'Tout le monde',
    'contacts': 'Mes contacts',
    'none': 'Personne',
  };

  // ── Firestore collections ──────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String conversationsCollection = 'conversations';
  static const String messagesCollection = 'messages';

  // ── SharedPreferences keys ─────────────────────────────────────────
  static const String prefThemeMode = 'theme_mode';
  static const String prefUserLanguage = 'user_language';
  static const String prefAutoTranslate = 'auto_translate';
  static const String prefBiometric = 'biometric_enabled';
  static const String prefAccentColor = 'accent_color';

  // ── Durées de vie des messages confidentiels ───────────────────────
  static const Map<String, int> confidentialDurations = {
    '5 secondes': 5,
    '10 secondes': 10,
    '30 secondes': 30,
    '1 minute': 60,
    '5 minutes': 300,
    'Personnalisé': -1,
  };

  // ── Limites ────────────────────────────────────────────────────────
  static const int maxGroupMembers = 256;
  static const int maxMessageLength = 4096;
  static const double maxMediaSizeMB = 64.0;
  static const int messagePageSize = 30;

  // ── Animations ────────────────────────────────────────────────────
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);

  // ── Dimensions ────────────────────────────────────────────────────
  static const double avatarSizeSmall = 36.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge = 80.0;
  static const double borderRadius = 16.0;
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 24.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
}
