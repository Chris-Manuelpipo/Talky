// lib/features/settings/presentation/about_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'À propos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App logo and info
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConstants.appVersion}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appTagline,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Contact us
          _ContactCard(
            icon: Icons.mail_outline_rounded,
            title: 'Contactez-nous',
            subtitle: 'Une question ? Nous sommes là pour vous aider',
            onTap: () => _showContactOptions(context),
          ),

          const SizedBox(height: 16),

          // Terms of use
          _ContactCard(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            subtitle: 'Lire les conditions générales',
            onTap: () => _showTerms(context),
          ),

          const SizedBox(height: 16),

          // Privacy policy
          _ContactCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            subtitle: 'Comment nous protégeons vos données',
            onTap: () => _showPrivacyPolicy(context),
          ),

          const SizedBox(height: 32),

          // Features
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Fonctionnalités',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FeatureItem(
                  icon: Icons.chat_bubble_rounded,
                  text: 'Messagerie instantanée',
                ),
                _FeatureItem(
                  icon: Icons.group_rounded,
                  text: 'Groupes jusqu\'à 256 membres',
                ),
                _FeatureItem(
                  icon: Icons.call_rounded,
                  text: 'Appels audio et vidéo',
                ),
                _FeatureItem(
                  icon: Icons.circle_rounded,
                  text: 'Statuts éphémères 24h',
                ),
                _FeatureItem(
                  icon: Icons.security_rounded,
                  text: 'Chiffrement de bout en bout',
                ),
                _FeatureItem(
                  icon: Icons.translate_rounded,
                  text: 'Traduction automatique (bientôt)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Copyright
          const Center(
            child: Column(
              children: [
                Text(
                  '© 2026 Talky',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tous droits réservés',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Contactez-nous',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.primary),
              title: const Text(
                'Email',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'support@talky.app',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email: support@talky.app'),
                    backgroundColor: AppColors.surfaceHigh,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: AppColors.primary),
              title: const Text(
                'Site web',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'www.talky.app',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Site: www.talky.app'),
                    backgroundColor: AppColors.surfaceHigh,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
              title: const Text(
                'FAQ',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Questions fréquentes',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('FAQ bientôt disponible'),
                    backgroundColor: AppColors.surfaceHigh,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
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

  void _showPrivacyPolicy(BuildContext context) {
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
                'Politique de confidentialité',
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
                    title: '1. Collecte de données',
                    content:
                        'Nous collectons les informations nécessaires au fonctionnement du service, '
                        'notamment votre numéro de téléphone, votre profil et vos messages.',
                  ),
                  _TermsSection(
                    title: '2. Utilisation des données',
                    content:
                        'Vos données sont utilisées pour fournir, maintenir et améliorer nos services. '
                        'Elles ne sont jamais vendues à des tiers.',
                  ),
                  _TermsSection(
                    title: '3. Sécurité',
                    content:
                        'Nous utilisons le chiffrement de bout en bout pour protéger vos communications. '
                        'Vos messages ne peuvent être lus que par vous et vos destinataires.',
                  ),
                  _TermsSection(
                    title: '4. Vos droits',
                    content:
                        'Vous pouvez à tout moment accéder, modifier ou supprimer vos données personnelles '
                        'depuis les paramètres de l\'application.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
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
