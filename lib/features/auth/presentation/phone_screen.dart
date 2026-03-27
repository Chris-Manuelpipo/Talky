// lib/features/auth/presentation/phone_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../shared/widgets/talky_button.dart';
import '../data/auth_providers.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

enum _AuthMethod { phone, google }

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+237'; // Cameroun par défaut
  final _formKey = GlobalKey<FormState>();
  bool _googleLoading = false;
  _AuthMethod _method = _AuthMethod.phone;

  final _countryCodes = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroun'},
    {'code': '+33',  'flag': '🇫🇷', 'name': 'France'},
    {'code': '+1',   'flag': '🇺🇸', 'name': 'États-Unis'},
    {'code': '+44',  'flag': '🇬🇧', 'name': 'Royaume-Uni'},
    {'code': '+49',  'flag': '🇩🇪', 'name': 'Allemagne'},
    {'code': '+34',  'flag': '🇪🇸', 'name': 'Espagne'},
    {'code': '+39',  'flag': '🇮🇹', 'name': 'Italie'},
    {'code': '+212', 'flag': '🇲🇦', 'name': 'Maroc'},
    {'code': '+221', 'flag': '🇸🇳', 'name': 'Sénégal'},
    {'code': '+225', 'flag': '🇨🇮', 'name': 'Côte d\'Ivoire'},
    {'code': '+243', 'flag': '🇨🇩', 'name': 'RD Congo'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final fullNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

    await ref.read(otpProvider.notifier).sendOtp(fullNumber);

    final state = ref.read(otpProvider);
    if (state.codeSent && mounted) {
      context.push(AppRoutes.otp, extra: {'phoneNumber': fullNumber});
    } else if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      String? phoneHint;
      final digits = _phoneController.text.trim();
      if (digits.isNotEmpty && digits.length >= 8) {
        phoneHint = '$_selectedCountryCode$digits';
      }

      final result = await ref.read(authServiceProvider).signInWithGoogle(
        phoneHint: phoneHint,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _googleLoading = false);
        return;
      }
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) {
        final isComplete =
            await ref.read(authServiceProvider).isProfileComplete(uid);
        if (!mounted) return;
        context.go(isComplete ? AppRoutes.home : AppRoutes.profileSetup);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Google: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);
    final colors = context.appThemeColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.onboarding),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                const SizedBox(height: 24),

                // // ── Icône ─────────────────────────────────────────
                // Container(
                //   width: 64,
                //   height: 64,
                //   decoration: BoxDecoration(
                //     color: colors.primary.withValues(alpha: 0.12),
                //     borderRadius: BorderRadius.circular(18),
                //     border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                //   ),
                //   child: Center(
                //     child: Icon(AppIcons.smartphone, color: colors.primary, size: 30),
                //   ),
                // ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

                // const SizedBox(height: 24),

                Text(
                  'Se connecter à Talky',
                  style: Theme.of(context).textTheme.displaySmall,
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Choisissez comment vous voulez vous connecter.\nVous pourrez lier l’autre méthode plus tard.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 24),

                // ── Choix méthode ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _MethodCard(
                        colors: colors,
                        isSelected: _method == _AuthMethod.google,
                        title: 'Google',
                        subtitle: 'Connexion rapide',
                        leading: Image.asset(
                          'assets/images/google.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.g_mobiledata_rounded,
                            size: 22,
                            color: colors.textSecondary,
                          ),
                        ),
                        onTap: () => setState(() => _method = _AuthMethod.google),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MethodCard(
                        colors: colors,
                        isSelected: _method == _AuthMethod.phone,
                        title: 'Téléphone',
                        subtitle: 'Recevoir un code par SMS',
                        icon: Icons.sms_rounded,
                        onTap: () => setState(() => _method = _AuthMethod.phone),
                      ),
                    ),
                  ],
                ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 24),

                // ── Sélecteur indicatif + champ téléphone ─────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _method == _AuthMethod.phone
                      ? Column(
                          key: const ValueKey('phone'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Indicatif pays
                                GestureDetector(
                                  onTap: _showCountryPicker,
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _countryCodes.firstWhere(
                                            (c) => c['code'] == _selectedCountryCode,
                                          )['flag']!,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedCountryCode,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            color: colors.textHint, size: 18),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Numéro
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '6XX XXX XXX',
                                      hintStyle: TextStyle(color: colors.textHint, letterSpacing: 1),
                                      filled: true,
                                      fillColor: colors.surfaceVariant,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: colors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: colors.border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: colors.primary, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                    validator: (v) {
                                      if (_method != _AuthMethod.phone) return null;
                                      if (v == null || v.isEmpty) return 'Numéro requis';
                                      if (v.length < 8) return 'Numéro trop court';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Nous enverrons un code SMS pour vérifier votre numéro.',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideY(begin: 0.1, end: 0)
                      : const SizedBox(
                          key: ValueKey('google'),
                          height: 0,
                        ),
                ),

                const SizedBox(height: 12),

                Text(
                  'En continuant, vous acceptez nos Conditions d\'utilisation\net notre Politique de confidentialité.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
                ).animate(delay: 250.ms).fadeIn(),

                const SizedBox(height: 24),

                // ── Bouton principal ──────────────────────────────
                if (_method == _AuthMethod.phone)
                  TalkyButton(
                    label: 'Recevoir le code',
                    onPressed: _sendOtp,
                    isLoading: otpState.isLoading,
                    icon: Icons.sms_rounded,
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0)
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: _googleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Image.asset(
                              'assets/images/google.png',
                              width: 18,
                              height: 18,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.g_mobiledata_rounded,
                                size: 22,
                                color: colors.textSecondary,
                              ),
                            ),
                      label: const Text('Continuer avec Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLight ? Colors.white : colors.surfaceHigh,
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),

                const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCountryPicker() {
    final colors = context.appThemeColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Indicatif pays', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _countryCodes.length,
              itemBuilder: (context, index) {
                final country = _countryCodes[index];
                final isSelected = country['code'] == _selectedCountryCode;
                return ListTile(
                  leading: Text(country['flag']!, style: const TextStyle(fontSize: 26)),
                  title: Text(country['name']!),
                  trailing: Text(
                    country['code']!,
                    style: TextStyle(
                      color: isSelected ? colors.primary : colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: colors.primary.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _selectedCountryCode = country['code']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final AppThemeColors colors;
  final bool isSelected;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback onTap;

  const _MethodCard({
    required this.colors,
    required this.isSelected,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.18)
                    : colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: leading ??
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
