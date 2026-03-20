// lib/features/chat/domain/conversation_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageType lastMessageType;
  final MessageStatus lastMessageStatus;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final bool isPinned;
  final bool isArchived;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageType = MessageType.text,
    this.lastMessageStatus = MessageStatus.sent,
    this.lastMessageAt,
    required this.unreadCount,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    this.isPinned = false,
    this.isArchived = false,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id:                   id,
      participantIds:       List<String>.from(map['participantIds'] ?? []),
      participantNames:     Map<String, String>.from(map['participantNames'] ?? {}),
      participantPhotos:    Map<String, String?>.from(map['participantPhotos'] ?? {}),
      lastMessage:          map['lastMessage'],
      lastMessageSenderId:  map['lastMessageSenderId'],
      lastMessageType:      MessageType.values.firstWhere(
                              (e) => e.name == (map['lastMessageType'] ?? 'text'),
                              orElse: () => MessageType.text),
      lastMessageStatus:    MessageStatus.values.firstWhere(
                              (e) => e.name == (map['lastMessageStatus'] ?? 'sent'),
                              orElse: () => MessageStatus.sent),
      lastMessageAt:        (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount:          Map<String, int>.from(map['unreadCount'] ?? {}),
      isGroup:              map['isGroup'] ?? false,
      groupName:            map['groupName'],
      groupPhoto:           map['groupPhoto'],
      isPinned:             map['isPinned'] ?? false,
      isArchived:           map['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'participantIds':      participantIds,
    'participantNames':    participantNames,
    'participantPhotos':   participantPhotos,
    'lastMessage':         lastMessage,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageType':     lastMessageType.name,
    'lastMessageStatus':   lastMessageStatus.name,
    'lastMessageAt':       lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
    'unreadCount':         unreadCount,
    'isGroup':             isGroup,
    'groupName':           groupName,
    'groupPhoto':          groupPhoto,
    'isPinned':            isPinned,
    'isArchived':          isArchived,
  };

  // Obtenir le nom affiché pour un utilisateur donné (l'autre participant)
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

enum MessageType { text, image, video, audio, file, deleted }
