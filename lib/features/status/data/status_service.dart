// lib/features/status/data/status_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/status_model.dart';
import '../../chat/data/media_service.dart';

class StatusService {
  final _db     = FirebaseFirestore.instance;
  final _media  = MediaService();

  CollectionReference get _statuses => _db.collection('statuses');

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
    });
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
}