// lib/features/settings/presentation/language_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/providers/settings_providers.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(settingsProvider).language;
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text(
          'Langue',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La traduction automatique arrive bientôt !',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Current language
          Text(
            'Langue préférée',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez la langue dans laquelle vous souhaitez utiliser l\'application',
            style: TextStyle(
              color: colors.textHint,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Language list
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: availableLanguages.entries.map((entry) {
                final isSelected = currentLanguage == entry.key;
                return Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .setLanguage(entry.key);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              // Language flag (emoji)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withOpacity(0.2)
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _getLanguageFlag(entry.key),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.primary,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (entry.key != availableLanguages.keys.last)
                      Divider(height: 1, color: colors.divider),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Info about auto-translate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.accent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Traduction automatique',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Bientôt, vous pourrez recevoir vos messages dans votre langue préférée. '
                  'Stay tuned !',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageFlag(String code) {
    switch (code) {
      case 'fr':
        return '🇫🇷';
      case 'en':
        return '🇬🇧';
      case 'es':
        return '🇪🇸';
      case 'de':
        return '🇩🇪';
      case 'it':
        return '🇮🇹';
      case 'pt':
        return '🇧🇷';
      case 'ar':
        return '🇸🇦';
      case 'zh':
        return '🇨🇳';
      case 'ja':
        return '🇯🇵';
      case 'ko':
        return '🇰🇷';
      default:
        return '🌐';
    }
  }
}
