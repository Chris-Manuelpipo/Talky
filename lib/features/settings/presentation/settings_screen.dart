// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../features/auth/data/auth_providers.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../core/providers/settings_providers.dart';
import 'profile_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'language_settings_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text(
          'Paramètres',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Profil ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Profil'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profil',
            subtitle: 'Photo, nom, statut',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Notifications ─────────────────────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          _SettingsTileSwitch(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Activer/désactiver les notifications',
            value: settings.notificationsEnabled,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setNotificationsEnabled(value);
            },
          ),
          _SettingsTileSwitch(
            icon: Icons.music_note_outlined,
            title: 'Son des notifications',
            subtitle: 'Jouer un son pour les notifications',
            value: settings.notificationSound,
            onChanged: settings.notificationsEnabled
                ? (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setNotificationSound(value);
                  }
                : null,
          ),
          _SettingsTileSwitch(
            icon: Icons.call_outlined,
            title: 'Notifications d\'appels',
            subtitle: 'Recevoir des notifications pour les appels',
            value: settings.callNotifications,
            onChanged: settings.notificationsEnabled
                ? (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setCallNotifications(value);
                  }
                : null,
          ),
          _SettingsTileSwitch(
            icon: Icons.vibration_outlined,
            title: 'Vibreur',
            subtitle: 'Vibration pour les notifications',
            value: settings.vibration,
            onChanged: settings.notificationsEnabled
                ? (value) {
                    ref.read(settingsProvider.notifier).setVibration(value);
                  }
                : null,
          ),

          const SizedBox(height: 24),

          // ── Apparence ─────────────────────────────────────────────────────
          _SectionHeader(title: 'Apparence'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Thème et couleurs',
            subtitle: 'Mode sombre, couleur d\'accent',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AppearanceSettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Langue ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Langue'),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Langue préférée',
            subtitle: availableLanguages[settings.language] ?? 'Français',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Confidentialité ──────────────────────────────────────────────
          _SectionHeader(title: 'Confidentialité'),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Qui peut voir mon statut en ligne',
            subtitle:
                visibilityOptions[settings.onlineVisibility] ?? 'Tout le monde',
            onTap: () => _showVisibilityPicker(context, ref, true),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),
          _SettingsTile(
            icon: Icons.photo_library_outlined,
            title: 'Qui peut voir ma photo de profil',
            subtitle: visibilityOptions[settings.profileVisibility] ??
                'Tout le monde',
            onTap: () => _showVisibilityPicker(context, ref, false),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),
          _SettingsTileSwitch(
            icon: Icons.done_all_outlined,
            title: 'Confirmation de lecture',
            subtitle: 'Envoyer ✓✓ (lecture)',
            value: settings.readReceipts,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setReadReceipts(value);
            },
          ),

          const SizedBox(height: 24),

          // ── Appels ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Appels'),
          _SettingsTile(
            icon: Icons.videocam_outlined,
            title: 'Qualité vidéo',
            subtitle: 'Automatique',
            onTap: () => _showComingSoon(context),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),
          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Sécurité',
            subtitle: 'Chiffrement de bout en bout',
            onTap: () => _showComingSoon(context),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // ── Partager ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Partager'),
          _SettingsTile(
            icon: Icons.share_outlined,
            title: 'Partager Talky avec un ami',
            subtitle: 'Invitez vos amis à rejoindre Talky',
            onTap: () => _showComingSoon(context),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // ── À propos ─────────────────────────────────────────────────────
          _SectionHeader(title: 'À propos'),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contactez-nous',
            subtitle: 'Une question ? Nous sommes là pour vous aider',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Version de l\'app',
            subtitle: AppConstants.appVersion,
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            subtitle: 'Lire les conditions',
            onTap: () => _showTerms(context),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // ── Déconnexion ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LogoutButton(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Conditions d\'utilisation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _TermsSection(
                    title: '1. Acceptation des conditions',
                    content:
                        'En utilisant Talky, vous acceptez les présentes conditions d\'utilisation. '
                        'Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser l\'application.',
                  ),
                  _TermsSection(
                    title: '2. Utilisation du service',
                    content:
                        'Talky est une application de messagerie destinée à un usage personnel et professionnel. '
                        'Vous vous engagez à utiliser le service conformément aux lois applicables.',
                  ),
                  _TermsSection(
                    title: '3. Confidentialité',
                    content:
                        'Vos données personnelles sont traitées conformément à notre politique de confidentialité. '
                        'Nous utilisons le chiffrement de bout en bout pour protéger vos messages.',
                  ),
                  _TermsSection(
                    title: '4. Contenu',
                    content:
                        'Vous êtes responsable du contenu que vous partagez via Talky. '
                        'Tout contenu illicite ou inapproprié est strictement interdit.',
                  ),
                  _TermsSection(
                    title: '5. Résiliation',
                    content:
                        'Nous nous réservons le droit de suspendre ou résilier votre compte en cas de violation des présentes conditions.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityPicker(
      BuildContext context, WidgetRef ref, bool isOnline) {
    final colors = context.appThemeColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VisibilityPicker(
        isOnline: isOnline,
        currentValue: isOnline
            ? ref.read(settingsProvider).onlineVisibility
            : ref.read(settingsProvider).profileVisibility,
        onSelect: (value) {
          if (isOnline) {
            ref.read(settingsProvider.notifier).setOnlineVisibility(value);
          } else {
            ref.read(settingsProvider.notifier).setProfileVisibility(value);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    final colors = context.appThemeColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bientôt disponible !'),
        backgroundColor: colors.surfaceHigh,
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
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
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.primary, size: 22),
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
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings tile with switch ─────────────────────────────────────────────
class _SettingsTileSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsTileSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final isDisabled = onChanged == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primary, size: 22),
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
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: colors.primary,
              activeTrackColor: colors.primary.withOpacity(0.4),
              inactiveThumbColor: colors.textSecondary,
              inactiveTrackColor: colors.surfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visibility picker ─────────────────────────────────────────────────────
class _VisibilityPicker extends StatelessWidget {
  final bool isOnline;
  final String currentValue;
  final ValueChanged<String> onSelect;

  const _VisibilityPicker({
    required this.isOnline,
    required this.currentValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isOnline
                  ? 'Qui peut voir mon statut en ligne'
                  : 'Qui peut voir ma photo de profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...visibilityOptions.entries.map((entry) {
            final isSelected = currentValue == entry.key;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              title: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              onTap: () => onSelect(entry.key),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────
class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appThemeColors;
    return ElevatedButton(
      onPressed: () => _showLogoutDialog(context, ref, colors),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.error.withOpacity(0.1),
        foregroundColor: colors.error,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: colors.error.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded),
          const SizedBox(width: 8),
          Text(
            'Déconnexion',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.error,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context, WidgetRef ref, AppThemeColors colors) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Déconnexion',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                // Navigation will be handled by router
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
