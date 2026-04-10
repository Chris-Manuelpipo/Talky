// lib/features/settings/presentation/appearance_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../data/settings_providers.dart';

const List<Color> predefinedColors = [
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

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  late Color _previewColor;

  @override
  void initState() {
    super.initState();
    _previewColor = ref.read(settingsProvider).accentColor;
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _previewColor,
            onColorChanged: (color) {
              setState(() => _previewColor = color);
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setAccentColor(_previewColor);
              Navigator.pop(context);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final accentColor = settings.accentColor;

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: const Text(
          'Apparence',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Couleur d'accentuation
          Text(
            'Couleur d\'accentuation',
            style: TextStyle(
              color: context.appThemeColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Palette de couleurs prédéfinies
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appThemeColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: context.appThemeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: predefinedColors.map((color) {
                    final isSelected =
                        color.toARGB32() == accentColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setAccentColor(color);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Bouton couleur personnalisée
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showColorPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: context.appThemeColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Couleur personnalisée',
                            style: TextStyle(
                              color: context.appThemeColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: context.appThemeColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Mode sombre / clair
          Text(
            'Mode',
            style: TextStyle(
              color: context.appThemeColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.appThemeColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: context.appThemeColors.border),
            ),
            child: Column(
              children: [
                _ThemeModeTile(
                  title: 'Sombre',
                  subtitle: 'Réduit la luminosité',
                  icon: Icons.dark_mode_rounded,
                  accentColor: accentColor,
                  isSelected: settings.themeMode == ThemeMode.dark,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                  },
                ),
                Divider(height: 1, color: context.appThemeColors.divider),
                _ThemeModeTile(
                  title: 'Clair',
                  subtitle: 'Lumière maximale',
                  icon: Icons.light_mode_rounded,
                  accentColor: accentColor,
                  isSelected: settings.themeMode == ThemeMode.light,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(ThemeMode.light);
                  },
                ),
                Divider(height: 1, color: context.appThemeColors.divider),
                _ThemeModeTile(
                  title: 'Système',
                  subtitle: 'Basé sur les paramètres',
                  icon: Icons.settings_brightness_rounded,
                  accentColor: accentColor,
                  isSelected: settings.themeMode == ThemeMode.system,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(ThemeMode.system);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Aperçu dynamique
          Text(
            'Aperçu',
            style: TextStyle(
              color: context.appThemeColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _PreviewWidget(accentColor: accentColor),

          const SizedBox(height: 16),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cette couleur sera utilisée pour les boutons, liens et éléments d\'accentuation.',
                    style: TextStyle(
                      color: context.appThemeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.2)
                      : context.appThemeColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? accentColor
                      : context.appThemeColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? accentColor
                            : context.appThemeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appThemeColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: accentColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewWidget extends StatelessWidget {
  final Color accentColor;

  const _PreviewWidget({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: context.appThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'John Doe',
                      style: TextStyle(
                        color: context.appThemeColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'En ligne',
                      style: TextStyle(
                        color:
                            isDark ? AppColors.success : AppColors.successLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Message bubble received
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Bonjour ! Comment allez-vous ?',
                style: TextStyle(
                  color: context.appThemeColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Sent message
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Salut ! Je vais très bien, merci !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Button preview
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'Bouton',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
