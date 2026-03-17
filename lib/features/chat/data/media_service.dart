// lib/features/chat/data/media_service.dart
// Utilise Cloudinary pour l'upload des médias

import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  // ── Config Cloudinary ─────────────────────────────────────────────
  static const _cloudName   = 'dvnxsn73m';
  static const _uploadPreset = 'talkyapp';

  final _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  final _picker     = ImagePicker();

  // ── Sélection fichiers ────────────────────────────────────────────

  Future<File?> pickImage({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickImage(
      source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth:     1280,
    );
    return picked != null ? File(picked.path) : null;
  }

  Future<File?> pickVideo() async {
    final XFile? picked = await _picker.pickVideo(
      source:      ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    return picked != null ? File(picked.path) : null;
  }

  // ── Upload vers Cloudinary ────────────────────────────────────────

  /// Upload une image → retourne l'URL publique
  Future<String> uploadImage({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder:       'talky/conversations/$conversationId/images',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Erreur upload image: $e');
    }
  }

  /// Upload une vidéo → retourne l'URL publique
  Future<String> uploadVideo({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder:       'talky/conversations/$conversationId/videos',
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Erreur upload vidéo: $e');
    }
  }

  /// Upload un audio → retourne l'URL publique
  Future<String> uploadAudio({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder:       'talky/conversations/$conversationId/audio',
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Erreur upload audio: $e');
    }
  }


  /// Upload une photo de profil → retourne l'URL publique
  Future<String> uploadProfilePhoto({
    required String filePath,
    required String userId,
  }) async {
    try {
      // Utiliser un timestamp pour forcer un nouvel upload à chaque fois
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          folder:       'talky/profiles/$userId',
          resourceType: CloudinaryResourceType.Image,
          publicId:     'profile_$timestamp',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Erreur upload photo profil: \$e');
    }
  }


  /// Upload un média de statut (image ou vidéo)
  Future<String> uploadStatusMedia({
    required File file,
    required String userId,
    required String type, // 'image' ou 'video'
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder:       'talky/statuses/$userId',
          resourceType: type == 'video'
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Erreur upload statut: \$e');
    }
  }

  // ── Utilitaires ───────────────────────────────────────────────────
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}