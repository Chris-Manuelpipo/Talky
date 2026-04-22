// lib/features/status/data/status_service.dart
//
// Service Statuts — migré de Firestore vers l'API REST MySQL.
// Cloudinary conservé pour l'upload des médias.
// Firebase complètement supprimé.

import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/services/api_service.dart';
import '../domain/status_model.dart';
import '../../chat/data/media_service.dart';

class StatusService {
  final _media = MediaService();
  final _api   = ApiService.instance;

  static const _statusCacheKey = 'statuses_v2';
  static const _statusCacheTtl = Duration(hours: 1);

  // ── Publier un statut texte ────────────────────────────────────────
  Future<void> postTextStatus({
    required String userId,
    required String userName,
    String? userPhoto,
    required String text,
    required String backgroundColor,
  }) async {
    await _api.createStatus(
      text:            text,
      type:            0,
      backgroundColor: backgroundColor,
    );
  }

  // ── Publier un statut image ────────────────────────────────────────
  Future<void> postImageStatus({
    required String userId,
    required String userName,
    String? userPhoto,
    required File imageFile,
    String? caption,
  }) async {
    final url = await _media.uploadStatusMedia(
      file:   imageFile,
      userId: userId,
      type:   'image',
    );
    await _api.createStatus(
      text:     caption ?? '',
      type:     1,
      mediaUrl: url,
    );
  }

  // ── Publier un statut vidéo ────────────────────────────────────────
  Future<void> postVideoStatus({
    required String userId,
    required String userName,
    String? userPhoto,
    required File videoFile,
    String? caption,
  }) async {
    final url = await _media.uploadStatusMedia(
      file:   videoFile,
      userId: userId,
      type:   'video',
    );
    await _api.createStatus(
      text:     caption ?? '',
      type:     2,
      mediaUrl: url,
    );
  }

  // ── Stream statuts actifs des contacts ─────────────────────────────
  // Charge depuis l'API, met en cache, et émet.
  // Les providers réactifs rappellent cette méthode à l'intervalle voulu.
  Stream<List<StatusModel>> statusesStream() async* {
    // Cache immédiat si disponible
    final cached = getCachedStatuses();
    if (cached.isNotEmpty) yield cached;

    // Charge depuis l'API
    try {
      final rows = await _api.getStatuses();
      final statuses = rows
          .whereType<Map>()
          .map((r) => StatusModel.fromJson(Map<String, dynamic>.from(r)))
          .where((s) => !s.isExpired)
          .toList();
      await cacheStatuses(statuses);
      yield statuses;
    } catch (e) {
      debugPrint('[StatusService.statusesStream] $e');
      if (cached.isEmpty) yield const [];
    }
  }

  // ── Mes statuts ────────────────────────────────────────────────────
  Stream<List<StatusModel>> myStatusesStream(String userId) async* {
    try {
      final rows = await _api.getMyStatuses();
      yield rows
          .whereType<Map>()
          .map((r) => StatusModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[StatusService.myStatusesStream] $e');
      yield const [];
    }
  }

  // ── Grouper les statuts par utilisateur ───────────────────────────
  List<UserStatusGroup> groupByUser(
      List<StatusModel> statuses, String currentUserId) {
    final map = <String, List<StatusModel>>{};
    for (final s in statuses) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }

    final groups = map.entries.map((e) {
      final list = e.value;
      return UserStatusGroup(
        userId:    e.key,
        userName:  list.first.userName,
        userPhoto: list.first.userPhoto,
        statuses:  list,
        isMyStatus: e.key == currentUserId,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.isMyStatus) return -1;
      if (b.isMyStatus) return 1;
      final aUnread = a.hasUnviewed(currentUserId);
      final bUnread = b.hasUnviewed(currentUserId);
      if (aUnread && !bUnread) return -1;
      if (!aUnread && bUnread) return 1;
      return b.latest.createdAt.compareTo(a.latest.createdAt);
    });

    return groups;
  }

  // ── Marquer un statut comme vu ─────────────────────────────────────
  Future<void> markAsViewed(String statusId, String viewerId) async {
    final id = int.tryParse(statusId);
    if (id == null) return;
    try {
      await _api.viewStatus(id);
    } catch (e) {
      debugPrint('[StatusService.markAsViewed] $e');
    }
  }

  // ── Obtenir les vues d'un statut ──────────────────────────────────
  Future<List<StatusView>> getStatusViews(String statusId) async {
    final id = int.tryParse(statusId);
    if (id == null) return const [];
    try {
      final rows = await _api.getStatusViews(id);
      return rows
          .whereType<Map>()
          .map((r) => StatusView.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[StatusService.getStatusViews] $e');
      return const [];
    }
  }

  // ── Supprimer mon statut ───────────────────────────────────────────
  Future<void> deleteStatus(String statusId) async {
    final id = int.tryParse(statusId);
    if (id == null) return;
    await _api.deleteStatus(id);
  }

  // ── Obtenir le statut par ID (depuis le cache) ─────────────────────
  Future<StatusModel?> getStatusById(String statusId) async {
    final cached = getCachedStatuses();
    try {
      return cached.firstWhere((s) => s.id == statusId);
    } catch (_) {
      return null;
    }
  }

  // ── Cache local ───────────────────────────────────────────────────
  List<StatusModel> getCachedStatuses() {
    final entry = LocalCache.instance.getEntry(_statusCacheKey);
    if (entry == null) return const [];
    final list = _deserializeStatuses(entry.data);
    return list.where((s) => !s.isExpired).toList();
  }

  Future<void> cacheStatuses(List<StatusModel> statuses) async {
    await LocalCache.instance.set(
      _statusCacheKey,
      _serializeStatuses(statuses),
      ttl: _statusCacheTtl,
    );
  }

  // ── Sérialisation cache ───────────────────────────────────────────
  List<Map<String, dynamic>> _serializeStatuses(List<StatusModel> statuses) {
    return statuses.map((s) => {
      'ID':            s.statutID,
      'alanyaID':      s.userId,
      'nom':           s.userName,
      'avatar_url':    s.userPhoto,
      'type':          _typeToInt(s.type),
      'text':          s.text,
      'mediaUrl':      s.mediaUrl,
      'backgroundColor': s.backgroundColor,
      'createdAt':     s.createdAt.toIso8601String(),
      'expiredAt':     s.expiresAt.toIso8601String(),
      'viewedBy':      s.viewedByCount,
      'likedBy':       s.likedByCount,
      'likedByMe':     s.likedByMe ? 1 : 0,
    }).toList();
  }

  List<StatusModel> _deserializeStatuses(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => StatusModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static int _typeToInt(StatusType t) {
    switch (t) {
      case StatusType.text:  return 0;
      case StatusType.image: return 1;
      case StatusType.video: return 2;
    }
  }
}