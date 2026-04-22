// lib/features/profile/presentation/profile_setup_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/talky_button.dart';
import '../../../core/widgets/talky_text_field.dart';
import '../../../core/widgets/country_picker.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../chat/data/media_service.dart';
import '../../../core/providers/settings_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedLanguage = 'fr';
  String? _localImagePath;
  bool _isLoading = false;
  bool _phoneReadOnly = false;

  // True si l'utilisateur vient de Google (pas de phone dans Firebase Auth).
  // Il doit alors saisir lui-même son numéro, qu'on valide côté backend
  // (unicité), sans passer par OTP.
  bool _needsPhoneInput = false;

  // Code pays
  String _selectedCountryCode = '+237';

  // Couleur et thème sélectionnés
  Color _selectedColor = const Color(0xFF7C5CFC);
  ThemeMode _selectedThemeMode = ThemeMode.system;

  final _languages = [
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final authService = ref.read(authServiceProvider);
    final phone = authService.currentUser?.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      // User arrivé par OTP téléphone → numéro figé (déjà validé par Firebase)
      _phoneController.text = phone;
      _phoneReadOnly = true;
    } else {
      // User Google → doit saisir son numéro manuellement.
      // Validation : vérifier qu'il n'est pas déjà pris côté backend.
      _needsPhoneInput = true;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _localImagePath = picked.path);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final uid = authService.currentUser!.uid;

      // Construction du numéro final :
      //  - User OTP → déjà dans authService.currentUser.phoneNumber
      //  - User Google → saisie manuelle + code pays, à envoyer au backend
      String phone;
      String? phoneForRegister;
      if (_needsPhoneInput) {
        final digits =
            _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
        phone = '$_selectedCountryCode$digits';
        phoneForRegister = phone;

        // Anti-doublon : vérifier côté backend avant toute tentative d'insert.
        try {
          final res = await ApiService.instance.phoneExists(phone);
          if (res['exists'] == true) {
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Ce numéro est déjà utilisé par un autre compte.'),
              ),
            );
            return;
          }
        } on ApiException catch (_) {
          // Backend injoignable → on laisse le register trancher (409).
        }
      } else {
        phone = authService.currentUser!.phoneNumber ?? '';
      }

      String? photoUrl;
      if (_localImagePath != null) {
        try {
          photoUrl = await MediaService().uploadProfilePhoto(
            filePath: _localImagePath!,
            userId: uid,
          );
        } catch (_) {
          // Photo non critique — continuer sans photo
        }
      }

      final name = _nameController.text.trim();

      // Convertir le préfixe pays en idPays
      final idPays =
          await ApiService.instance.getIdPaysByPrefix(_selectedCountryCode);

      // 1) Créer / mettre à jour le user en MySQL (backend)
      try {
        await ApiService.instance.registerUser(
          nom: name,
          pseudo: name,
          avatarUrl: photoUrl,
          phone: phoneForRegister, // null = on utilise le phone du token (OTP)
          idPays: idPays,
        );
      } on ApiException catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: e.statusCode == 409
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // 2) Sauver le profil dans Firestore (pour les features pas encore migrées)
      final user = UserModel(
        uid: uid,
        name: name,
        phone: phone,
        email: authService.currentUser?.email,
        photoUrl: photoUrl,
        status: _statusController.text.trim().isEmpty
            ? 'Disponible sur Talky'
            : _statusController.text.trim(),
        preferredLanguage: _selectedLanguage,
        isOnline: true,
      );
      await authService.saveUserProfile(user);
      await authService.saveFcmToken(uid);

      // Sauvegarder la couleur d'accentuation et le thème via SettingsNotifier
      final settingsNotifier = ref.read(settingsProvider.notifier);
      await settingsNotifier.setAccentColor(_selectedColor);
      await settingsNotifier.setThemeMode(_selectedThemeMode);

      // Mettre à jour nom + photo dans toutes les conversations existantes
      await _updateNameInConversations(uid, name, photoUrl);

      // Invalider le cache → router détecte profil complet
      ref.invalidate(profileCompleteProvider);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Text(
                  'Votre profil',
                  style: theme.textTheme.displaySmall,
                ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Complétez votre profil pour que vos connaissances puissent vous reconnaître.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ).animate(delay: 50.ms).fadeIn(),

                const SizedBox(height: 40),

                // ── Photo de profil ───────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest,
                            border: Border.all(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.4),
                                width: 2),
                            image: _localImagePath != null
                                ? DecorationImage(
                                    image: NetworkImage(_localImagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _localImagePath == null
                              ? Icon(AppIcons.person,
                                  size: 42, color: colorScheme.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(delay: 100.ms)
                    .scale(duration: 500.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 8),

                Center(
                  child: TextButton(
                    onPressed: _pickImage,
                    child: const Text('Choisir une photo'),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Nom ───────────────────────────────────────────
                TalkyTextField(
                  controller: _nameController,
                  label: 'Nom complet *',
                  hint: 'Chris ETCHOME',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nom requis';
                    if (v.trim().length < 2) return 'Nom trop court';
                    return null;
                  },
                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 16),

                // ── Statut ────────────────────────────────────────
                TalkyTextField(
                  controller: _statusController,
                  label: 'Statut (optionnel)',
                  hint: ' Disponible sur Talky',
                  prefixIcon: Icons.edit_outlined,
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

                const SizedBox(height: 24),

                // ── Téléphone ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de pays
                    CountryPicker(
                      selectedCountryCode: _selectedCountryCode,
                      onCountrySelected: (code) =>
                          setState(() => _selectedCountryCode = code),
                      isReadOnly: _phoneReadOnly,
                      readOnlyCountryCode:
                          _phoneReadOnly ? _selectedCountryCode : null,
                    ),
                    const SizedBox(width: 12),
                    // Champ téléphone
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        readOnly: _phoneReadOnly,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Numéro requis';
                          final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (digits.length < 8) return 'Numéro invalide';
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone *',
                          hintText: '6XX XXX XXX',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.2, end: 0),

                if (_needsPhoneInput) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Saisis ton numéro : il sera validé à l\'enregistrement.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Langue préférée ───────────────────────────────
                Text(
                  'Langue préférée',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate(delay: 250.ms).fadeIn(),

                const SizedBox(height: 4),

                Text(
                  'Les messages reçus seront traduits dans cette langue.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ).animate(delay: 260.ms).fadeIn(),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languages.map((lang) {
                    final isSelected = lang['code'] == _selectedLanguage;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLanguage = lang['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Text(
                          '${lang['flag']} ${lang['name']}',
                          style: TextStyle(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ).animate(delay: 280.ms).fadeIn(),

                const SizedBox(height: 32),

                // ── Couleur d'accentuation ───────────────────────────
                Text(
                  'Couleur d\'accentuation',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 4),

                Text(
                  'Choisissez la couleur principale de l\'application.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ).animate(delay: 310.ms).fadeIn(),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppConstants.predefinedAccentColors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
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
                ).animate(delay: 320.ms).fadeIn(),

                const SizedBox(height: 32),

                // ── Mode thème ────────────────────────────────────────
                Text(
                  'Mode d\'affichage',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate(delay: 340.ms).fadeIn(),

                const SizedBox(height: 4),

                Text(
                  'Choisissez entre le mode clair, sombre ou automatique.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ).animate(delay: 350.ms).fadeIn(),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _ThemeModeOption(
                      icon: Icons.brightness_5_rounded,
                      label: 'Clair',
                      isSelected: _selectedThemeMode == ThemeMode.light,
                      onTap: () =>
                          setState(() => _selectedThemeMode = ThemeMode.light),
                    ),
                    const SizedBox(width: 12),
                    _ThemeModeOption(
                      icon: Icons.brightness_2_rounded,
                      label: 'Sombre',
                      isSelected: _selectedThemeMode == ThemeMode.dark,
                      onTap: () =>
                          setState(() => _selectedThemeMode = ThemeMode.dark),
                    ),
                    const SizedBox(width: 12),
                    _ThemeModeOption(
                      icon: Icons.brightness_auto_rounded,
                      label: 'Auto',
                      isSelected: _selectedThemeMode == ThemeMode.system,
                      onTap: () =>
                          setState(() => _selectedThemeMode = ThemeMode.system),
                    ),
                  ],
                ).animate(delay: 360.ms).fadeIn(),

                const SizedBox(height: 40),

                // ── Bouton ────────────────────────────────────────
                TalkyButton(
                  label: 'Continuer vers Talky',
                  onPressed: _saveProfile,
                  isLoading: _isLoading,
                  icon: Icons.arrow_forward_rounded,
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Met à jour participantNames + participantPhotos dans toutes les conversations
  Future<void> _updateNameInConversations(
      String uid, String name, String? photoUrl) async {
    try {
      final db = FirebaseFirestore.instance;
      final convs = await db
          .collection('conversations')
          .where('participantIds', arrayContains: uid)
          .get();

      final batch = db.batch();
      for (final doc in convs.docs) {
        final update = <String, dynamic>{
          'participantNames.$uid': name,
        };
        if (photoUrl != null) {
          update['participantPhotos.$uid'] = photoUrl;
        }
        batch.update(doc.reference, update);
      }
      if (convs.docs.isNotEmpty) await batch.commit();
    } catch (_) {}
  }
}

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
