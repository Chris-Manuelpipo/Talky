// lib/features/chat/domain/message_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'conversation_model.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? content;
  final MessageType type;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaDuration; // secondes pour audio/video
  final String? replyToId;   // message auquel on répond
  final String? replyToContent;
  final bool isDeleted;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
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
    this.isDeleted = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id:               id,
      conversationId:   map['conversationId'] ?? '',
      senderId:         map['senderId'] ?? '',
      senderName:       map['senderName'] ?? '',
      content:          map['content'],
      type:             MessageType.values.firstWhere(
                          (e) => e.name == (map['type'] ?? 'text'),
                          orElse: () => MessageType.text),
      status:           MessageStatus.values.firstWhere(
                          (e) => e.name == (map['status'] ?? 'sent'),
                          orElse: () => MessageStatus.sent),
      sentAt:           (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt:           (map['readAt'] as Timestamp?)?.toDate(),
      mediaUrl:         map['mediaUrl'],
      mediaName:        map['mediaName'],
      mediaDuration:    map['mediaDuration'],
      replyToId:        map['replyToId'],
      replyToContent:   map['replyToContent'],
      isDeleted:        map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'conversationId':  conversationId,
    'senderId':        senderId,
    'senderName':      senderName,
    'content':         content,
    'type':            type.name,
    'status':          status.name,
    'sentAt':          FieldValue.serverTimestamp(),
    'readAt':          readAt != null ? Timestamp.fromDate(readAt!) : null,
    'mediaUrl':        mediaUrl,
    'mediaName':       mediaName,
    'mediaDuration':   mediaDuration,
    'replyToId':       replyToId,
    'replyToContent':  replyToContent,
    'isDeleted':       isDeleted,
  };

  bool get isMine => false; // sera calculé avec currentUserId

  MessageModel copyWith({MessageStatus? status, bool? isDeleted}) {
    return MessageModel(
      id:              id,
      conversationId:  conversationId,
      senderId:        senderId,
      senderName:      senderName,
      content:         content,
      type:            type,
      status:          status ?? this.status,
      sentAt:          sentAt,
      readAt:          readAt,
      mediaUrl:        mediaUrl,
      mediaName:       mediaName,
      mediaDuration:   mediaDuration,
      replyToId:       replyToId,
      replyToContent:  replyToContent,
      isDeleted:       isDeleted ?? this.isDeleted,
    );
  }
}

enum MessageStatus { sending, sent, delivered, read }