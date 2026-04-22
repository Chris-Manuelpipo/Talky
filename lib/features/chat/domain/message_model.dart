// lib/features/chat/domain/message_model.dart
//
// Aligné sur la table MySQL `message`
// Suppression de Firestore (Timestamp, FieldValue)

import 'conversation_model.dart';

class MessageModel {
  final int msgID;              // PK MySQL (bigint)
  final String id;              // String pour compatibilité UI
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? content;
  final MessageType type;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaDuration;
  final String? replyToId;
  final String? replyToContent;
  final bool isStatusReply;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  // deletedFor : simplifié — on ne reçoit jamais les messages supprimés
  // car le backend les filtre. Ce champ est conservé pour la logique locale.
  final String? deletedForId;

  /// Compat : ancienne API exposait une List<String> des userIds ayant
  /// supprimé le message pour eux-mêmes. Le backend n'en stocke qu'un seul.
  List<String> get deletedFor =>
      deletedForId == null ? const [] : [deletedForId!];

  const MessageModel({
    required this.msgID,
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.content,
    required this.type,
    required this.status,
    required this.sentAt,
    this.readAt,
    this.mediaUrl,
    this.mediaName,
    this.mediaDuration,
    this.replyToId,
    this.replyToContent,
    this.isStatusReply = false,
    this.isDeleted     = false,
    this.isEdited      = false,
    this.editedAt,
    this.deletedForId,
  });

  // ── API REST → MessageModel ──────────────────────────────────────
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = (json['msgID'] ?? 0).toString();
    return MessageModel(
      msgID:          json['msgID']          as int? ?? 0,
      id:             id,
      conversationId: (json['conversationID'] ?? '').toString(),
      senderId:       (json['senderID']       ?? '').toString(),
      senderName:     json['sender_nom']      as String? ?? '',
      senderAvatar:   json['sender_avatar']   as String?,
      content:        json['content']         as String?,
      type:           _typeFromInt(json['type']   as int? ?? 0),
      status:         _statusFromInt(json['status'] as int? ?? 1),
      sentAt:         json['sendAt'] != null
          ? DateTime.tryParse(json['sendAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      readAt:         json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      mediaUrl:       json['mediaUrl']       as String?,
      mediaName:      json['mediaName']      as String?,
      mediaDuration:  json['mediaDuration']  as int?,
      replyToId:      json['replyToID']?.toString(),
      replyToContent: json['replyToContent'] as String?,
      isStatusReply:  (json['isStatusReply']  as int? ?? 0) == 1,
      isDeleted:      (json['isDeleted']       as int? ?? 0) == 1,
      isEdited:       (json['isEdited']        as int? ?? 0) == 1,
      editedAt:       json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'] as String)
          : null,
      deletedForId:   json['deletedForID']?.toString(),
    );
  }

  // ── MessageModel → API REST (envoi) ─────────────────────────────
  Map<String, dynamic> toJson() => {
    if (content   != null) 'content':        content,
    'type':                                   _typeToInt(type),
    if (mediaUrl  != null) 'mediaUrl':        mediaUrl,
    if (mediaName != null) 'mediaName':       mediaName,
    if (mediaDuration != null) 'mediaDuration': mediaDuration,
    if (replyToId != null) 'replyToID':       int.tryParse(replyToId!),
    if (replyToContent != null) 'replyToContent': replyToContent,
    'isStatusReply':                          isStatusReply ? 1 : 0,
  };

  // ── Helpers enums ────────────────────────────────────────────────
  static MessageType _typeFromInt(int v) {
    const map = {0: MessageType.text, 1: MessageType.image,
                 2: MessageType.video, 3: MessageType.audio,
                 4: MessageType.file};
    return map[v] ?? MessageType.text;
  }

  static int _typeToInt(MessageType t) {
    const map = {MessageType.text: 0, MessageType.image: 1,
                 MessageType.video: 2, MessageType.audio: 3,
                 MessageType.file: 4};
    return map[t] ?? 0;
  }

  static MessageStatus _statusFromInt(int v) {
    const map = {0: MessageStatus.sending, 1: MessageStatus.sent,
                 2: MessageStatus.delivered, 3: MessageStatus.read};
    return map[v] ?? MessageStatus.sent;
  }

  MessageModel copyWith({
    MessageStatus? status,
    bool? isDeleted,
    bool? isEdited,
    DateTime? editedAt,
    String? content,
  }) {
    return MessageModel(
      msgID:          msgID,
      id:             id,
      conversationId: conversationId,
      senderId:       senderId,
      senderName:     senderName,
      senderAvatar:   senderAvatar,
      content:        content        ?? this.content,
      type:           type,
      status:         status         ?? this.status,
      sentAt:         sentAt,
      readAt:         readAt,
      mediaUrl:       mediaUrl,
      mediaName:      mediaName,
      mediaDuration:  mediaDuration,
      replyToId:      replyToId,
      replyToContent: replyToContent,
      isStatusReply:  isStatusReply,
      isDeleted:      isDeleted      ?? this.isDeleted,
      isEdited:       isEdited       ?? this.isEdited,
      editedAt:       editedAt       ?? this.editedAt,
      deletedForId:   deletedForId,
    );
  }
}