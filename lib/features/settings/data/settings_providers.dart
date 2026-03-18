// lib/features/settings/data/settings_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

// ── Settings state ─────────────────────────────────────────────────────────
class SettingsState {
  final ThemeMode themeMode;
  final String language;
  final bool notificationsEnabled;
  final bool notificationSound;
  final bool callNotifications;
  final bool vibration;
  final bool readReceipts;
  final String onlineVisibility;
  final String profileVisibility;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.language = 'fr',
    this.notificationsEnabled = true,
    this.notificationSound = true,
    this.callNotifications = true,
    this.vibration = true,
    this.readReceipts = true,
    this.onlineVisibility = 'everyone',
    this.profileVisibility = 'everyone',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? language,
    bool? notificationsEnabled,
    bool? notificationSound,
    bool? callNotifications,
    bool? vibration,
    bool? readReceipts,
    String? onlineVisibility,
    String? profileVisibility,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      callNotifications: callNotifications ?? this.callNotifications,
      vibration: vibration ?? this.vibration,
      readReceipts: readReceipts ?? this.readReceipts,
      onlineVisibility: onlineVisibility ?? this.onlineVisibility,
      profileVisibility: profileVisibility ?? this.profileVisibility,
    );
  }
}

// ── Settings notifier ─────────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences? _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;

    final themeModeIndex = _prefs!.getInt(AppConstants.prefThemeMode) ?? 0; // 0 = ThemeMode.system
    final language = _prefs!.getString(AppConstants.prefUserLanguage) ?? 'fr';
    final notifications = _prefs!.getBool('notifications_enabled') ?? true;
    final sound = _prefs!.getBool('notification_sound') ?? true;
    final calls = _prefs!.getBool('call_notifications') ?? true;
    final vibration = _prefs!.getBool('vibration') ?? true;
    final receipts = _prefs!.getBool('read_receipts') ?? true;
    final online = _prefs!.getString('online_visibility') ?? 'everyone';
    final profile = _prefs!.getString('profile_visibility') ?? 'everyone';

    state = SettingsState(
      themeMode: ThemeMode.values[themeModeIndex],
      language: language,
      notificationsEnabled: notifications,
      notificationSound: sound,
      callNotifications: calls,
      vibration: vibration,
      readReceipts: receipts,
      onlineVisibility: online,
      profileVisibility: profile,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs?.setInt(AppConstants.prefThemeMode, mode.index);
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await _prefs?.setString(AppConstants.prefUserLanguage, language);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs?.setBool('notifications_enabled', enabled);
  }

  Future<void> setNotificationSound(bool enabled) async {
    state = state.copyWith(notificationSound: enabled);
    await _prefs?.setBool('notification_sound', enabled);
  }

  Future<void> setCallNotifications(bool enabled) async {
    state = state.copyWith(callNotifications: enabled);
    await _prefs?.setBool('call_notifications', enabled);
  }

  Future<void> setVibration(bool enabled) async {
    state = state.copyWith(vibration: enabled);
    await _prefs?.setBool('vibration', enabled);
  }

  Future<void> setReadReceipts(bool enabled) async {
    state = state.copyWith(readReceipts: enabled);
    await _prefs?.setBool('read_receipts', enabled);
  }

  Future<void> setOnlineVisibility(String visibility) async {
    state = state.copyWith(onlineVisibility: visibility);
    await _prefs?.setString('online_visibility', visibility);
  }

  Future<void> setProfileVisibility(String visibility) async {
    state = state.copyWith(profileVisibility: visibility);
    await _prefs?.setString('profile_visibility', visibility);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

// ── Language options ───────────────────────────────────────────────────────
const Map<String, String> availableLanguages = {
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
const Map<String, String> visibilityOptions = {
  'everyone': 'Tout le monde',
  'contacts': 'Mes contacts',
  'none': 'Personne',
};
