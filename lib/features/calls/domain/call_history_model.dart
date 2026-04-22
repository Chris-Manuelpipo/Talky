// lib/features/calls/domain/call_history_model.dart
//
// Aligné sur la table MySQL `callHistory`

enum CallType { incoming, outgoing, missed }

class CallHistoryModel {
  final int IDcall;           // PK MySQL bigint
  final String id;            // String pour compatibilité UI
  final String callerId;      // alanyaID appelant
  final String callerName;
  final String? callerPhoto;
  final String receiverId;    // alanyaID receveur
  final String receiverName;
  final String? receiverPhoto;
  final int typeInt;          // 0=audio, 1=video (DB)
  final int statusInt;        // 0=missed, 1=answered, 2=rejected (DB)
  final bool isVideo;
  final DateTime timestamp;
  final int durationSeconds;

  // ── Champs legacy (Firestore — historique des appels groupés) ─────
  // Conservés tant que la feature Calls n'est pas migrée vers le backend.
  final CallType type;
  final bool isGroup;
  final String? groupName;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;

  CallHistoryModel({
    this.IDcall = 0,
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    this.typeInt = 0,
    this.statusInt = 1,
    required this.isVideo,
    required this.timestamp,
    this.durationSeconds = 0,
    this.type = CallType.outgoing,
    this.isGroup = false,
    this.groupName,
    this.participantIds = const [],
    this.participantNames = const {},
    this.participantPhotos = const {},
  });

  CallType get callType {
    if (statusInt == 0) return CallType.missed;
    return CallType.outgoing; // sera ajusté selon currentUserId
  }

  // ── API REST → CallHistoryModel ──────────────────────────────────
  factory CallHistoryModel.fromJson(Map<String, dynamic> json) {
    final typeInt   = json['type']   as int? ?? 0;
    final statusInt = json['status'] as int? ?? 0;
    return CallHistoryModel(
      IDcall:        json['IDcall']          as int? ?? 0,
      id:            (json['IDcall'] ?? '').toString(),
      callerId:      (json['idCaller'] ?? '').toString(),
      callerName:    json['caller_nom']      as String? ?? '',
      callerPhoto:   json['caller_avatar']   as String?,
      receiverId:    (json['idReceiver'] ?? '').toString(),
      receiverName:  json['receiver_nom']    as String? ?? '',
      receiverPhoto: json['receiver_avatar'] as String?,
      typeInt:       typeInt,
      statusInt:     statusInt,
      isVideo:       typeInt == 1,
      timestamp:     json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: json['duree'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'idReceiver': int.tryParse(receiverId),
    'type':       typeInt,
  };

  // ── Firestore compat ────────────────────────────────────────────
  factory CallHistoryModel.fromMap(String id, Map<String, dynamic> data) {
    CallType parseType(String? s) {
      switch (s) {
        case 'missed':   return CallType.missed;
        case 'incoming': return CallType.incoming;
        case 'outgoing': return CallType.outgoing;
        default:         return CallType.outgoing;
      }
    }

    DateTime parseTs(dynamic v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      if (v is int)    return DateTime.fromMillisecondsSinceEpoch(v);
      try {
        final d = (v as dynamic).toDate();
        if (d is DateTime) return d;
      } catch (_) {}
      return DateTime.now();
    }

    final t = parseType(data['type'] as String?);
    return CallHistoryModel(
      id:            id,
      callerId:      (data['callerId']   ?? '').toString(),
      callerName:    (data['callerName'] ?? '').toString(),
      callerPhoto:   data['callerPhoto']   as String?,
      receiverId:    (data['receiverId']   ?? '').toString(),
      receiverName:  (data['receiverName'] ?? '').toString(),
      receiverPhoto: data['receiverPhoto'] as String?,
      isVideo:       data['isVideo'] == true,
      timestamp:     parseTs(data['timestamp']),
      durationSeconds: (data['durationSeconds'] as int?) ?? 0,
      type:          t,
      statusInt:     t == CallType.missed ? 0 : 1,
      typeInt:       data['isVideo'] == true ? 1 : 0,
      isGroup:       data['isGroup'] == true,
      groupName:     data['groupName'] as String?,
      participantIds:
          (data['participantIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      participantNames:
          ((data['participantNames'] as Map?) ?? const {})
              .map((k, v) => MapEntry(k.toString(), v.toString())),
      participantPhotos:
          ((data['participantPhotos'] as Map?) ?? const {})
              .map((k, v) => MapEntry(k.toString(), v?.toString())),
    );
  }

  // ── UI helpers (inchangés) ───────────────────────────────────────
  String getDisplayName(String currentUserId) {
    if (callerId == currentUserId) return receiverName;
    return callerName;
  }

  String? getDisplayPhoto(String currentUserId) {
    if (callerId == currentUserId) return receiverPhoto;
    return callerPhoto;
  }

  bool isOutgoing(String currentUserId) => callerId == currentUserId;

  CallType getCallType(String currentUserId) {
    if (statusInt == 0) return CallType.missed;
    if (callerId  == currentUserId) return CallType.outgoing;
    return CallType.incoming;
  }

  String get formattedDuration {
    if (durationSeconds == 0) return '';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}