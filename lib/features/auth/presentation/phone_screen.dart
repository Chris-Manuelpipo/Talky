// lib/features/auth/presentation/phone_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/talky_button.dart';
import '../data/auth_providers.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+237'; // Cameroun par défaut
  final _formKey = GlobalKey<FormState>();

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

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.onboarding),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Icône ─────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Icon(AppIcons.smartphone, color: AppColors.primary, size: 30),
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 24),

                Text(
                  'Votre numéro',
                  style: Theme.of(context).textTheme.displaySmall,
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Entrez votre numéro de téléphone.\nNous vous enverrons un code de vérification.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 40),

                // ── Sélecteur indicatif + champ téléphone ─────────
                Row(
                  children: [
                    // Indicatif pays
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
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
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textHint, size: 18),
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: '6XX XXX XXX',
                          hintStyle: const TextStyle(color: AppColors.textHint, letterSpacing: 1),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Numéro requis';
                          if (v.length < 8) return 'Numéro trop court';
                          return null;
                        },
                      ),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 12),

                Text(
                  'En continuant, vous acceptez nos Conditions d\'utilisation\net notre Politique de confidentialité.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
                ).animate(delay: 250.ms).fadeIn(),

                const Spacer(),

                // ── Bouton ────────────────────────────────────────
                TalkyButton(
                  label: 'Envoyer le code',
                  onPressed: _sendOtp,
                  isLoading: otpState.isLoading,
                  icon: Icons.send_rounded,
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
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
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
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
