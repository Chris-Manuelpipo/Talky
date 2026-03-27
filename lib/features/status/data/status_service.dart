// lib/features/status/data/status_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/cache/local_cache.dart';
import '../domain/status_model.dart';
import '../../chat/data/media_service.dart';

class StatusService {
  final _db     = FirebaseFirestore.instance;
  final _media  = MediaService();

  CollectionReference get _statuses => _db.collection('statuses');
  static const _statusCacheKey = 'statuses_v1';
  static const _statusCacheTtl = Duration(hours: 6);

  // ── Publier un statut texte ────────────────────────────────────────
  Future<void> postTextStatus({
    required String userId,
    required String userName,
    String? userPhoto,
    required String text,
    required String backgroundColor,
  }) async {
    final now = DateTime.now();
    final model = StatusModel(
      id:              '',
      userId:          userId,
      userName:        userName,
      userPhoto:       userPhoto,
      type:            StatusType.text,
      text:            text,
      backgroundColor: backgroundColor,
      createdAt:       now,
      expiresAt:       now.add(const Duration(hours: 24)),
      viewedBy:        [],
      viewedAt:        const {},
      likedBy:         const [],
    );
    await _statuses.add(model.toMap());
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

    final now = DateTime.now();
    final model = StatusModel(
      id:        '',
      userId:    userId,
      userName:  userName,
      userPhoto: userPhoto,
      type:      StatusType.image,
      mediaUrl:  url,
      text:      caption,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      viewedBy:  [],
      viewedAt:  const {},
      likedBy:   const [],
    );
    await _statuses.add(model.toMap());
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

    final now = DateTime.now();
    final model = StatusModel(
      id:        '',
      userId:    userId,
      userName:  userName,
      userPhoto: userPhoto,
      type:      StatusType.video,
      mediaUrl:  url,
      text:      caption,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      viewedBy:  [],
      viewedAt:  const {},
      likedBy:   const [],
    );
    await _statuses.add(model.toMap());
  }

  // ── Stream statuts non expirés ─────────────────────────────────────
  Stream<List<StatusModel>> statusesStream() {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)));

    return _statuses
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StatusModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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

    // Mon statut en premier
    groups.sort((a, b) {
      if (a.isMyStatus) return -1;
      if (b.isMyStatus) return 1;
      // Non vus en premier
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
    await _statuses.doc(statusId).update({
      'viewedBy': FieldValue.arrayUnion([viewerId]),
      'viewedAt.$viewerId': FieldValue.serverTimestamp(),
    });
  }

  // ── Liker un statut ─────────────────────────────────────────────────
  Future<void> likeStatus(String statusId, String userId) async {
    await _statuses.doc(statusId).update({
      'likedBy': FieldValue.arrayUnion([userId]),
    });
  }

  // ── Retirer le like d'un statut ─────────────────────────────────────
  Future<void> unlikeStatus(String statusId, String userId) async {
    await _statuses.doc(statusId).update({
      'likedBy': FieldValue.arrayRemove([userId]),
    });
  }

  // ── Obtenir le statut par ID ───────────────────────────────────────
  Future<StatusModel?> getStatusById(String statusId) async {
    final doc = await _statuses.doc(statusId).get();
    if (!doc.exists) return null;
    return StatusModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }


  // ── Supprimer mon statut ───────────────────────────────────────────
  Future<void> deleteStatus(String statusId) async {
    await _statuses.doc(statusId).delete();
  }

  // ── Mes statuts ────────────────────────────────────────────────────
  Stream<List<StatusModel>> myStatusesStream(String userId) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)));

    return _statuses
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StatusModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  List<StatusModel> getCachedStatuses() {
    final entry = LocalCache.instance.getEntry(_statusCacheKey);
    if (entry == null) return [];
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

  List<Map<String, dynamic>> _serializeStatuses(List<StatusModel> statuses) {
    return statuses
        .map((s) => {
              'id': s.id,
              'userId': s.userId,
              'userName': s.userName,
              'userPhoto': s.userPhoto,
              'type': s.type.name,
              'text': s.text,
              'mediaUrl': s.mediaUrl,
              'backgroundColor': s.backgroundColor,
              'createdAtMs': s.createdAt.millisecondsSinceEpoch,
              'expiresAtMs': s.expiresAt.millisecondsSinceEpoch,
              'viewedBy': s.viewedBy,
              'viewedAtMs': s.viewedAt.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
              'likedBy': s.likedBy,
            })
        .toList();
  }

  List<StatusModel> _deserializeStatuses(dynamic data) {
    if (data is! List) return [];
    final result = <StatusModel>[];
    for (final item in data) {
      if (item is Map) {
        final viewedAtRaw = item['viewedAtMs'];
        final viewedAt = <String, DateTime>{};
        if (viewedAtRaw is Map) {
          viewedAtRaw.forEach((k, v) {
            if (v is int) {
              viewedAt[k.toString()] = DateTime.fromMillisecondsSinceEpoch(v);
            }
          });
        }
        result.add(StatusModel(
          id: item['id']?.toString() ?? '',
          userId: item['userId']?.toString() ?? '',
          userName: item['userName']?.toString() ?? '',
          userPhoto: item['userPhoto']?.toString(),
          type: StatusType.values.firstWhere(
            (e) => e.name == (item['type'] ?? 'text'),
            orElse: () => StatusType.text,
          ),
          text: item['text']?.toString(),
          mediaUrl: item['mediaUrl']?.toString(),
          backgroundColor: item['backgroundColor']?.toString(),
          createdAt: item['createdAtMs'] is int
              ? DateTime.fromMillisecondsSinceEpoch(item['createdAtMs'] as int)
              : DateTime.now(),
          expiresAt: item['expiresAtMs'] is int
              ? DateTime.fromMillisecondsSinceEpoch(item['expiresAtMs'] as int)
              : DateTime.now().add(const Duration(hours: 24)),
          viewedBy: (item['viewedBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          viewedAt: viewedAt,
          likedBy: (item['likedBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        ));
      }
    }
    return result;
  }
}
