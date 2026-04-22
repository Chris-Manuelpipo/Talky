// lib/features/status/domain/status_model.dart
//
// Aligné sur MySQL : statut + statut_views
// Suppression de Firestore

enum StatusType { text, image, video }

class StatusModel {
  final int statutID;        // PK MySQL
  final String id;           // String pour compatibilité UI
  final String userId;       // alanyaID en String
  final String userName;
  final String? userPhoto;
  final StatusType type;
  final String? text;
  final String? mediaUrl;
  final String? backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewedByCount;   // compteur dénormalisé
  final int likedByCount;    // compteur dénormalisé
  // Vues détaillées — chargées séparément via GET /status/:id/views
  final List<StatusView> views;

  // ── Champs legacy (Firestore — feature pas encore migrée) ──────
  final List<String> viewedBy;
  final Map<String, DateTime> viewedAt;
  final List<String> likedBy;
  /// True si l'utilisateur connecté a liké (colonne SQL / GET /status).
  final bool likedByMe;

  const StatusModel({
    this.statutID = 0,
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
    this.viewedByCount = 0,
    this.likedByCount  = 0,
    this.views         = const [],
    this.viewedBy      = const [],
    this.viewedAt      = const {},
    this.likedBy       = const [],
    this.likedByMe     = false,
  });

  bool get isExpired  => DateTime.now().isAfter(expiresAt);
  int  get viewCount  => viewedByCount > 0 ? viewedByCount : viewedBy.length;
  int  get likeCount  => likedByCount  > 0 ? likedByCount  : likedBy.length;

  bool isViewedBy(String userId) => viewedBy.contains(userId);
  bool isLikedBy(String userId) => likedBy.contains(userId);

  // ── API REST → StatusModel ───────────────────────────────────────
  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      statutID:        json['ID']           as int? ?? 0,
      id:              (json['ID'] ?? '').toString(),
      userId:          (json['alanyaID'] ?? '').toString(),
      userName:        json['nom']          as String? ?? '',
      userPhoto:       json['avatar_url']   as String?,
      type:            _typeFromInt(json['type'] as int? ?? 0),
      text:            json['text']         as String?,
      mediaUrl:        json['mediaUrl']     as String?,
      backgroundColor: json['backgroundColor'] as String?,
      createdAt:       json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt:       json['expiredAt'] != null
          ? DateTime.tryParse(json['expiredAt'] as String) ??
              DateTime.now().add(const Duration(hours: 24))
          : DateTime.now().add(const Duration(hours: 24)),
      viewedByCount:   json['viewedBy'] as int? ?? 0,
      likedByCount:    json['likedBy']  as int? ?? 0,
      likedByMe:
          json['likedByMe'] == true || json['likedByMe'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    if (text            != null) 'text':            text,
    'type':                                          _typeToInt(type),
    if (mediaUrl        != null) 'mediaUrl':         mediaUrl,
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
  };

  // ── Firestore compat ────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'userId':           userId,
    'userName':         userName,
    'userPhoto':        userPhoto,
    'type':             type.name,
    'text':             text,
    'mediaUrl':         mediaUrl,
    'backgroundColor':  backgroundColor,
    'createdAt':        createdAt.toIso8601String(),
    'expiresAt':        expiresAt.toIso8601String(),
    'viewedBy':         viewedBy,
    'likedBy':          likedBy,
    'viewedAtMs':       viewedAt.map(
        (k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
  };

  factory StatusModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseTs(dynamic v, {DateTime? fallback}) {
      if (v is String) return DateTime.tryParse(v) ?? (fallback ?? DateTime.now());
      if (v is int)    return DateTime.fromMillisecondsSinceEpoch(v);
      try {
        final d = (v as dynamic).toDate();
        if (d is DateTime) return d;
      } catch (_) {}
      return fallback ?? DateTime.now();
    }

    StatusType parseType(String? s) {
      switch (s) {
        case 'image': return StatusType.image;
        case 'video': return StatusType.video;
        default:      return StatusType.text;
      }
    }

    final rawViewedAt = (data['viewedAtMs'] as Map?) ?? const {};
    final viewedAt = <String, DateTime>{};
    rawViewedAt.forEach((k, v) {
      if (v is int) {
        viewedAt[k.toString()] = DateTime.fromMillisecondsSinceEpoch(v);
      }
    });

    return StatusModel(
      id:               id,
      userId:           (data['userId']   ?? '').toString(),
      userName:         (data['userName'] ?? '').toString(),
      userPhoto:        data['userPhoto'] as String?,
      type:             parseType(data['type'] as String?),
      text:             data['text']             as String?,
      mediaUrl:         data['mediaUrl']         as String?,
      backgroundColor:  data['backgroundColor']  as String?,
      createdAt:        parseTs(data['createdAt']),
      expiresAt:        parseTs(
        data['expiresAt'],
        fallback: DateTime.now().add(const Duration(hours: 24)),
      ),
      viewedBy:
          (data['viewedBy'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      likedBy:
          (data['likedBy'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      viewedAt:         viewedAt,
      likedByMe:        data['likedByMe'] == true || data['likedByMe'] == 1,
    );
  }

  static StatusType _typeFromInt(int v) {
    const map = {0: StatusType.text, 1: StatusType.image, 2: StatusType.video};
    return map[v] ?? StatusType.text;
  }

  static int _typeToInt(StatusType t) {
    const map = {StatusType.text: 0, StatusType.image: 1, StatusType.video: 2};
    return map[t] ?? 0;
  }
}

// ── Vue d'un statut (statut_views) ──────────────────────────────────
class StatusView {
  final int id;
  final int statutID;
  final String viewerID;
  final String viewerName;
  final String? viewerPhoto;
  final DateTime seenAt;

  const StatusView({
    required this.id,
    required this.statutID,
    required this.viewerID,
    required this.viewerName,
    this.viewerPhoto,
    required this.seenAt,
  });

  factory StatusView.fromJson(Map<String, dynamic> json) {
    return StatusView(
      id:          json['id']       as int? ?? 0,
      statutID:    json['statutID'] as int? ?? 0,
      viewerID:    (json['alanyaID'] ?? '').toString(),
      viewerName:  json['nom']      as String? ?? '',
      viewerPhoto: json['avatar_url'] as String?,
      seenAt:      json['seenAt'] != null
          ? DateTime.tryParse(json['seenAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ── Groupe de statuts par utilisateur (inchangé) ─────────────────────
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

  StatusModel get latest  => statuses.last;
  bool hasUnviewed(String currentUserId) =>
      statuses.any((s) => !s.isExpired && s.viewedByCount == 0);
}