// lib/features/chat/data/chat_service.dart
// Version mise à jour Phase 3b — avec envoi médias

import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _conversations => _db.collection('conversations');
  CollectionReference _messages(String convId) =>
      _db.collection('conversations').doc(convId).collection('messages');

  // ── CONVERSATIONS ──────────────────────────────────────────────────

  Stream<List<ConversationModel>> conversationsStream(String userId) {
    return _conversations
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ConversationModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    required String? currentUserPhoto,
    required String otherUserId,
    required String otherUserName,
    required String? otherUserPhoto,
  }) async {
    String _cleanName(String? name) {
      final n = (name ?? '').trim();
      if (n.isEmpty) return 'Utilisateur';
      if (n.toLowerCase() == 'moi') return 'Utilisateur';
      return n;
    }

    final safeCurrentName = _cleanName(currentUserName);
    final safeOtherName   = _cleanName(otherUserName);

    final existing = await _conversations
        .where('participantIds', arrayContains: currentUserId)
        .where('isGroup', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ids = List<String>.from(data['participantIds'] ?? []);
      if (ids.contains(otherUserId) && ids.length == 2) {
        // Mettre à jour noms + photos à chaque fois (corrige le bug "Moi")
        await doc.reference.update({
          'participantNames.$currentUserId': safeCurrentName,
          'participantNames.$otherUserId':   safeOtherName,
          if (currentUserPhoto != null) 'participantPhotos.$currentUserId': currentUserPhoto,
          if (otherUserPhoto != null)   'participantPhotos.$otherUserId':   otherUserPhoto,
        });
        return doc.id;
      }
    }

    final conv = ConversationModel(
      id: '',
      participantIds: [currentUserId, otherUserId],
      participantNames: {
        currentUserId: safeCurrentName,
        otherUserId:   safeOtherName,
      },
      participantPhotos: {
        currentUserId: currentUserPhoto,
        otherUserId:   otherUserPhoto,
      },
      unreadCount: {currentUserId: 0, otherUserId: 0},
    );

    final ref = await _conversations.add(conv.toMap());
    return ref.id;
  }

  // ── MESSAGES ───────────────────────────────────────────────────────

  Stream<List<MessageModel>> messagesStream(String conversationId) {
    return _messages(conversationId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Envoyer un message texte
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? replyToId,
    String? replyToContent,
  }) async {
    await _sendMessageInternal(
      conversationId:  conversationId,
      senderId:        senderId,
      senderName:      senderName,
      content:         content,
      type:            MessageType.text,
      replyToId:       replyToId,
      replyToContent:  replyToContent,
      lastMessagePreview: content,
    );
  }

  /// Envoyer un message média (image, vidéo, audio, fichier)
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String mediaUrl,
    required MessageType type,
    String? mediaName,
    int? mediaDuration,
  }) async {
    final previews = {
      MessageType.image: '📷 Photo',
      MessageType.video: '🎥 Vidéo',
      MessageType.audio: '🎤 Vocal',
      MessageType.file:  '📎 Fichier',
    };

    await _sendMessageInternal(
      conversationId:     conversationId,
      senderId:           senderId,
      senderName:         senderName,
      content:            previews[type] ?? 'Média',
      type:               type,
      mediaUrl:           mediaUrl,
      mediaName:          mediaName,
      mediaDuration:      mediaDuration,
      lastMessagePreview: previews[type] ?? 'Média',
    );
  }

  Future<void> _sendMessageInternal({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    required MessageType type,
    required String lastMessagePreview,
    String? replyToId,
    String? replyToContent,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
  }) async {
    final batch = _db.batch();

    final msgRef = _messages(conversationId).doc();
    final message = MessageModel(
      id:             msgRef.id,
      conversationId: conversationId,
      senderId:       senderId,
      senderName:     senderName,
      content:        content,
      type:           type,
      status:         MessageStatus.sent,
      sentAt:         DateTime.now(),
      replyToId:      replyToId,
      replyToContent: replyToContent,
      mediaUrl:       mediaUrl,
      mediaName:      mediaName,
      mediaDuration:  mediaDuration,
    );
    batch.set(msgRef, message.toMap());

    // Mise à jour conversation
    final convRef  = _conversations.doc(conversationId);
    final convSnap = await convRef.get();
    final convData = convSnap.data() as Map<String, dynamic>?;
    final participantIds = List<String>.from(convData?['participantIds'] ?? []);

    final unreadUpdate = <String, dynamic>{};
    for (final uid in participantIds) {
      if (uid != senderId) {
        unreadUpdate['unreadCount.$uid'] = FieldValue.increment(1);
      }
    }

    batch.update(convRef, {
      'lastMessage':          lastMessagePreview,
      'lastMessageSenderId':  senderId,
      'lastMessageType':      type.name,
      'lastMessageStatus':    MessageStatus.sent.name,
      'lastMessageAt':        FieldValue.serverTimestamp(),
      ...unreadUpdate,
    });

    await batch.commit();
  }

  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _conversations.doc(conversationId).update({
      'unreadCount.$userId': 0,
    });

    final unread = await _messages(conversationId)
        .where('status', whereIn: ['sent', 'delivered'])
        .where('senderId', isNotEqualTo: userId)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'status': MessageStatus.read.name,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    if (unread.docs.isNotEmpty) await batch.commit();

    // Si le dernier message n'est pas de moi, il vient d'être lu
    final convSnap = await _conversations.doc(conversationId).get();
    final convData = convSnap.data() as Map<String, dynamic>?;
    final lastSender = convData?['lastMessageSenderId'] as String?;
    if (lastSender != null && lastSender != userId) {
      await _conversations.doc(conversationId).update({
        'lastMessageStatus': MessageStatus.read.name,
      });
    }
  }

  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    final unread = await _messages(conversationId)
        .where('status', isEqualTo: MessageStatus.sent.name)
        .where('senderId', isNotEqualTo: userId)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'status': MessageStatus.delivered.name,
      });
    }
    await batch.commit();

    // Si le dernier message n'est pas de moi, il vient d'être délivré
    final convSnap = await _conversations.doc(conversationId).get();
    final convData = convSnap.data() as Map<String, dynamic>?;
    final lastSender = convData?['lastMessageSenderId'] as String?;
    if (lastSender != null && lastSender != userId) {
      await _conversations.doc(conversationId).update({
        'lastMessageStatus': MessageStatus.delivered.name,
      });
    }
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _messages(conversationId).doc(messageId).update({
      'isDeleted': true,
      'content':   null,
    });
  }

  // ── GROUPES ────────────────────────────────────────────────────────

  Future<String> createGroup({
    required String creatorId,
    required String creatorName,
    required String? creatorPhoto,
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) async {
    final allIds = [creatorId, ...members.map((m) => m['id'] as String)];
    final names  = <String, String>{creatorId: creatorName};
    final photos = <String, String?>{creatorId: creatorPhoto};

    for (final m in members) {
      names[m['id']]  = m['name'] ?? 'Membre';
      photos[m['id']] = m['photoUrl'];
    }

    final conv = ConversationModel(
      id:               '',
      participantIds:   allIds,
      participantNames: names,
      participantPhotos: photos,
      unreadCount:      {for (final id in allIds) id: 0},
      isGroup:          true,
      groupName:        groupName,
    );

    final ref = await _conversations.add(conv.toMap());
    return ref.id;
  }

  // ── UTILISATEURS ──────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> usersStream(String currentUserId) {
    return _db
        .collection('users')
        .where('name', isNotEqualTo: '')
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    final snap = await _db
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snap.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
}
