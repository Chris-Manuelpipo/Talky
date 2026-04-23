// lib/features/settings/presentation/profile_settings_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../chat/data/media_service.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  bool _isLoading = false;
  bool _isLinkingGoogle = false;
  String? _photoUrl;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProfile = await ref.read(currentUserProfileProvider.future);
    if (userProfile != null) {
      _nameController.text = userProfile.name;
      _statusController.text = userProfile.status;
      setState(() {
        _photoUrl = userProfile.photoUrl;
        _phone = userProfile.phone;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (result != null) {
      setState(() => _isLoading = true);

      try {
        // Upload to Cloudinary using MediaService with correct credentials
        final mediaService = MediaService();
        final authState = ref.read(authStateProvider).value;
        
        final photoUrl = await mediaService.uploadProfilePhoto(
          filePath: result.path,
          userId: authState?.uid ?? 'unknown',
        );

        setState(() {
          _photoUrl = photoUrl;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'upload: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom ne peut pas être vide'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider).value;
      if (authState == null) return;

      final user = UserModel(
        uid: authState.uid,
        name: _nameController.text.trim(),
        phone: _phone ?? authState.phoneNumber ?? '',
        email: authState.email,
        photoUrl: _photoUrl,
        status: _statusController.text.trim().isEmpty
            ? 'Disponible sur Talky'
            : _statusController.text.trim(),
      );

      await ref.read(authServiceProvider).saveUserProfile(user);

      // Invalider le cache du profil pour forcer un refresh
      ref.invalidate(currentUserProfileProvider);

      // Mettre à jour la photo dans toutes les conversations existantes
      if (_photoUrl != null) {
        await _updatePhotoInConversations(authState.uid, _photoUrl!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil mis à jour'),
            backgroundColor: context.appThemeColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkGoogle() async {
    if (_isLinkingGoogle) return;
    setState(() => _isLinkingGoogle = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle(
        linkIfPossible: true,
      );
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Compte Google lié avec succès'),
            backgroundColor: context.appThemeColors.success,
          ),
        );
        // Refresh UI
        ref.invalidate(currentUserProfileProvider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  // Met à jour participantPhotos dans toutes les conversations
  Future<void> _updatePhotoInConversations(String uid, String photoUrl) async {
    try {
      final db = FirebaseFirestore.instance;
      final convs = await db
          .collection('conversations')
          .where('participantIds', arrayContains: uid)
          .get();

      final batch = db.batch();
      for (final doc in convs.docs) {
        batch.update(doc.reference, {'participantPhotos.$uid': photoUrl});
      }
      if (convs.docs.isNotEmpty) await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final authUser = ref.watch(authStateProvider).value;
    final hasGoogle =
        authUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final email = authUser?.email ?? '';
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Enregistrer',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo de profil
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceVariant,
                        border: Border.all(
                          color: colors.primary,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: _photoUrl != null && _photoUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: colors.surfaceVariant,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person_rounded,
                                  size: 60,
                                  color: colors.textSecondary,
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 60,
                                color: colors.textSecondary,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickImage,
                child: Text(
                  'Modifier la photo',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Nom d'affichage
            const Text(
              'Nom d\'affichage',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Votre nom',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Statut / Bio
            const Text(
              'Statut / Bio',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _statusController,
              maxLength: 150,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Dites quelque chose sur vous...',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Email / Lier Google
            const Text(
              'Compte Google',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (hasGoogle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        email.isNotEmpty ? email : 'Email non disponible',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLinkingGoogle ? null : _linkGoogle,
                  icon: _isLinkingGoogle
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    _isLinkingGoogle ? 'Liaison...' : 'Lier Google',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceVariant,
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Numéro de téléphone
            const Text(
              'Numéro de téléphone',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_android_rounded,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _phone ?? 'Non défini',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le numéro de téléphone et l\'adresse email ne peuvent pas être modifiés',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
