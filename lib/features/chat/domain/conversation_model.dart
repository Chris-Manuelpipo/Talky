// lib/features/chat/domain/conversation_model.dart
//
// Aligné sur MySQL : conversation + conv_participants
// Les participantIds/Names/Photos sont reconstruits depuis l'API

class ConversationModel {
  final int conversID;                        // PK MySQL
  final String id;                            // String pour compatibilité UI existante
  final List<String> participantIds;          // alanyaIDs en String
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageType lastMessageType;
  final MessageStatus lastMessageStatus;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;         // { "alanyaID": count }
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final bool isPinned;
  final bool isArchived;

  const ConversationModel({
    this.conversID = 0,
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageType  = MessageType.text,
    this.lastMessageStatus = MessageStatus.sent,
    this.lastMessageAt,
    required this.unreadCount,
    this.isGroup   = false,
    this.groupName,
    this.groupPhoto,
    this.isPinned  = false,
    this.isArchived = false,
  });

  // ── API REST → ConversationModel ─────────────────────────────────
  // Le backend retourne conv + conv_participants joinés.
  // Les participants détaillés (noms, photos) arrivent via un champ `participants[]`
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Participants enrichis (nom, avatar) si fournis par l'API
    final rawParticipants =
        (json['participants'] as List<dynamic>?) ?? [];

    final participantIds    = <String>[];
    final participantNames  = <String, String>{};
    final participantPhotos = <String, String?>{};

    for (final p in rawParticipants) {
      final pid = p['alanyaID']?.toString() ?? '';
      if (pid.isEmpty) continue;
      participantIds.add(pid);
      participantNames[pid]  = p['nom']        as String? ?? '';
      participantPhotos[pid] = p['avatar_url'] as String?;
    }

    // unreadCount : on reçoit la valeur pour l'utilisateur courant
    final unreadCount = <String, int>{};
    final currentUserID = json['currentUserID']?.toString();
    if (currentUserID != null) {
      unreadCount[currentUserID] = json['unreadCount'] as int? ?? 0;
    }

    return ConversationModel(
      conversID:            json['conversID'] as int? ?? 0,
      id:                   (json['conversID'] ?? '').toString(),
      participantIds:       participantIds,
      participantNames:     participantNames,
      participantPhotos:    participantPhotos,
      lastMessage:          json['lastMessage']          as String?,
      lastMessageSenderId:  json['lastMessageSenderID']?.toString(),
      lastMessageType:      _typeFromInt(json['lastMessageType'] as int? ?? 0),
      lastMessageStatus:    _statusFromInt(json['lastMessageStatus'] as int? ?? 0),
      lastMessageAt:        json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      unreadCount:          unreadCount,
      isGroup:              (json['isGroup'] as int? ?? 0) == 1,
      groupName:            json['GroupName']  as String?,
      groupPhoto:           json['groupPhoto'] as String?,
      isPinned:             (json['isPinned']  as int? ?? 0) == 1,
      isArchived:           (json['isArchived'] as int? ?? 0) == 1,
    );
  }

  // ── Helpers enums ────────────────────────────────────────────────
  static MessageType _typeFromInt(int v) {
    const map = {0: MessageType.text, 1: MessageType.image,
                 2: MessageType.video, 3: MessageType.audio,
                 4: MessageType.file};
    return map[v] ?? MessageType.text;
  }

  static MessageStatus _statusFromInt(int v) {
    const map = {0: MessageStatus.sending, 1: MessageStatus.sent,
                 2: MessageStatus.delivered, 3: MessageStatus.read};
    return map[v] ?? MessageStatus.sent;
  }

  // ── UI helpers (inchangés) ───────────────────────────────────────
  String getDisplayName(String currentUserId) {
    if (isGroup) return groupName ?? 'Groupe';
    final otherId = participantIds.firstWhere(
        (id) => id != currentUserId, orElse: () => '');
    return participantNames[otherId] ?? 'Utilisateur';
  }

  String? getDisplayPhoto(String currentUserId) {
    if (isGroup) return groupPhoto;
    final otherId = participantIds.firstWhere(
        (id) => id != currentUserId, orElse: () => '');
    return participantPhotos[otherId];
  }

  int getUnreadCount(String userId) => unreadCount[userId] ?? 0;
}

enum MessageType   { text, image, video, audio, file, deleted }
enum MessageStatus { sending, sent, delivered, read }