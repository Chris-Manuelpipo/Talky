// lib/features/status/domain/status_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusType { text, image, video }

class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final StatusType type;
  final String? text;
  final String? mediaUrl;
  final String? backgroundColor; // pour les statuts texte
  final DateTime createdAt;
  final DateTime expiresAt;      // createdAt + 24h
  final List<String> viewedBy;   // uids qui ont vu

  const StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.type,
    this.text,
    this.mediaUrl,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool isViewedBy(String uid) => viewedBy.contains(uid);
  int get viewCount => viewedBy.length;

  factory StatusModel.fromMap(Map<String, dynamic> map, String id) {
    return StatusModel(
      id:              id,
      userId:          map['userId'] ?? '',
      userName:        map['userName'] ?? '',
      userPhoto:       map['userPhoto'],
      type:            StatusType.values.firstWhere(
                         (e) => e.name == (map['type'] ?? 'text'),
                         orElse: () => StatusType.text),
      text:            map['text'],
      mediaUrl:        map['mediaUrl'],
      backgroundColor: map['backgroundColor'],
      createdAt:       (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:       (map['expiresAt'] as Timestamp?)?.toDate() ??
                         DateTime.now().add(const Duration(hours: 24)),
      viewedBy:        List<String>.from(map['viewedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':          userId,
    'userName':        userName,
    'userPhoto':       userPhoto,
    'type':            type.name,
    'text':            text,
    'mediaUrl':        mediaUrl,
    'backgroundColor': backgroundColor,
    'createdAt':       Timestamp.fromDate(createdAt),
    'expiresAt':       Timestamp.fromDate(expiresAt),
    'viewedBy':        viewedBy,
  };
}

// Groupe de statuts par utilisateur (comme WhatsApp)
class UserStatusGroup {
  final String userId;
  final String userName;
  final String? userPhoto;
  final List<StatusModel> statuses;
  final bool isMyStatus;

  const UserStatusGroup({
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.statuses,
    required this.isMyStatus,
  });

  StatusModel get latest => statuses.last;
  bool hasUnviewed(String currentUserId) =>
      statuses.any((s) => !s.isViewedBy(currentUserId));
}