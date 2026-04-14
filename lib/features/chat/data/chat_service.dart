// lib/features/chat/data/chat_service.dart
// Version mise à jour Phase 3b — avec envoi médias

import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/contact_model.dart';
import '../../../core/services/fcm_sender.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _conversations => _db.collection('conversations');
  CollectionReference _messages(String convId) =>
      _db.collection('conversations').doc(convId).collection('messages');

  // ── CONVERSATIONS ──────────────────────────────────────────────────

  Stream<List<ConversationModel>> conversationsStream(String userId) {
    return _conversations
        .where('participantIds', arrayContains: userId)
        .where('isArchived', isEqualTo: false)
        .orderBy('isPinned', descending: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ConversationModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Stream des conversations archivées
  Stream<List<ConversationModel>> archivedConversationsStream(String userId) {
    return _conversations
        .where('participantIds', arrayContains: userId)
        .where('isArchived', isEqualTo: true)
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
    bool isStatusReply = false,
  }) async {
    await _sendMessageInternal(
      conversationId:  conversationId,
      senderId:        senderId,
      senderName:      senderName,
      content:         content,
      type:            MessageType.text,
      replyToId:       replyToId,
      replyToContent:  replyToContent,
      isStatusReply:   isStatusReply,
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
      MessageType.image: 'Photo',
      MessageType.video: 'Vidéo',
      MessageType.audio: 'Vocal',
      MessageType.file:  'Fichier',
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
    bool isStatusReply = false,
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
      isStatusReply:  isStatusReply,
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

    // Notify other participants (best-effort).
    for (final uid in participantIds) {
      if (uid == senderId) continue;
      await FcmSender.sendMessageNotification(
        toUserId: uid,
        senderName: senderName,
        message: lastMessagePreview,
        conversationId: conversationId,
      );
    }
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

  Future<void> markMessagesReadByIds({
    required String conversationId,
    required String userId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;

    try {
      final batch = _db.batch();
      for (final id in messageIds) {
        final ref = _messages(conversationId).doc(id);
        batch.update(ref, {
          'status': MessageStatus.read.name,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      await _conversations.doc(conversationId).update({
        'unreadCount.$userId': 0,
      });

      final convSnap = await _conversations.doc(conversationId).get();
      final convData = convSnap.data() as Map<String, dynamic>?;
      final lastSender = convData?['lastMessageSenderId'] as String?;
      if (lastSender != null && lastSender != userId) {
        await _conversations.doc(conversationId).update({
          'lastMessageStatus': MessageStatus.read.name,
        });
      }
    } catch (e) {
      // Debug pour voir si Firestore bloque l'update
      // ignore: avoid_print
      print('[ChatService] markMessagesReadByIds error: $e');
    }
  }

  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    final unread = await _messages(conversationId)
        .where('status', isEqualTo: MessageStatus.sent.name)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String?;
      if (senderId == userId) continue;
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

  /// Supprimer un message pour tous les utilisateurs
  /// Le contenu est effacé et le type devient 'deleted'
  Future<void> deleteMessageForAll({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'isDeleted': true,
        'content':   null,
        'type':      MessageType.deleted.name,
        'mediaUrl':  null,
        'mediaName': null,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[ChatService] deleteMessageForAll error: $e');
      rethrow;
    }
  }

  /// Supprimer un message uniquement pour l'utilisateur courant
  /// Le message reste visible pour les autres participants
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[ChatService] deleteMessageForMe error: $e');
      rethrow;
    }
  }

  /// Modifier le contenu d'un message
  /// Met à jour le contenu, définit isEdited=true et editedAt=now
  /// Le type est changé en 'text' si c'était un média
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'content':   newContent,
        'isEdited':  true,
        'editedAt':  FieldValue.serverTimestamp(),
        'type':      MessageType.text.name,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[ChatService] editMessage error: $e');
      rethrow;
    }
  }

  /// Vérifie si un message peut être modifié par l'utilisateur
  /// Un message ne peut être modifié que s'il:
  /// - N'est pas déjà supprimé
  /// - A été envoyé par l'utilisateur courant
  /// - Est de type texte
  Future<bool> canEditMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final doc = await _messages(conversationId).doc(messageId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final isDeleted = data['isDeleted'] as bool? ?? false;
      final senderId = data['senderId'] as String? ?? '';
      final type = data['type'] as String? ?? 'text';

      return !isDeleted && senderId == userId && type != MessageType.deleted.name;
    } catch (e) {
      // ignore: avoid_print
      print('[ChatService] canEditMessage error: $e');
      return false;
    }
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
      adminIds:         [creatorId],  // Creator is admin
      createdAt:        DateTime.now(),
      createdBy:        creatorId,
    );

    final ref = await _conversations.add(conv.toMap());
    return ref.id;
  }

  /// Add members to an existing group (admin-only operation)
  /// Note: Firestore security rules should verify adminId is actually an admin
  Future<void> addMembersToGroup({
    required String conversationId,
    required String adminId,
    required List<Map<String, dynamic>> newMembers,
  }) async {
    final convSnap = await _conversations.doc(conversationId).get();
    if (!convSnap.exists) throw Exception('Conversation not found');

    final convData = convSnap.data() as Map<String, dynamic>;
    final currentParticipantIds = List<String>.from(convData['participantIds'] ?? []);
    final currentNames = Map<String, String>.from(convData['participantNames'] ?? {});
    final currentPhotos = Map<String, String?>.from(convData['participantPhotos'] ?? {});
    final currentUnread = Map<String, int>.from(convData['unreadCount'] ?? {});

    // Add new members (skip if already in group)
    for (final m in newMembers) {
      final memberId = m['id'] as String;
      if (!currentParticipantIds.contains(memberId)) {
        currentParticipantIds.add(memberId);
        currentNames[memberId] = m['name'] ?? 'Membre';
        currentPhotos[memberId] = m['photoUrl'];
        currentUnread[memberId] = 0;
      }
    }

    await _conversations.doc(conversationId).update({
      'participantIds': currentParticipantIds,
      'participantNames': currentNames,
      'participantPhotos': currentPhotos,
      'unreadCount': currentUnread,
    });
  }

  /// Remove a member from a group (admin-only operation)
  Future<void> removeMemberFromGroup({
    required String conversationId,
    required String adminId,
    required String memberId,
  }) async {
    final convSnap = await _conversations.doc(conversationId).get();
    if (!convSnap.exists) throw Exception('Conversation not found');

    final convData = convSnap.data() as Map<String, dynamic>;
    final participantIds = List<String>.from(convData['participantIds'] ?? []);
    final names = Map<String, String>.from(convData['participantNames'] ?? {});
    final photos = Map<String, String?>.from(convData['participantPhotos'] ?? {});
    final unread = Map<String, int>.from(convData['unreadCount'] ?? {});

    // Remove the member
    participantIds.remove(memberId);
    names.remove(memberId);
    photos.remove(memberId);
    unread.remove(memberId);

    await _conversations.doc(conversationId).update({
      'participantIds': participantIds,
      'participantNames': names,
      'participantPhotos': photos,
      'unreadCount': unread,
    });
  }

  /// Member leaves the group (member removes themselves)
  Future<void> leaveGroup({
    required String conversationId,
    required String userId,
  }) async {
    await removeMemberFromGroup(
      conversationId: conversationId,
      adminId: userId,
      memberId: userId,
    );
  }

  /// Promote a member to admin (admin-only operation)
  Future<void> promoteToAdmin({
    required String conversationId,
    required String adminId,
    required String memberId,
  }) async {
    final convSnap = await _conversations.doc(conversationId).get();
    if (!convSnap.exists) throw Exception('Conversation not found');

    final convData = convSnap.data() as Map<String, dynamic>;
    final adminIds = List<String>.from(convData['adminIds'] ?? []);

    // Add to admins if not already there
    if (!adminIds.contains(memberId)) {
      adminIds.add(memberId);
      await _conversations.doc(conversationId).update({
        'adminIds': adminIds,
      });
    }
  }

  /// Update group information (admin-only operation)
  Future<void> updateGroupInfo({
    required String conversationId,
    required String adminId,
    String? groupName,
    String? groupPhoto,
  }) async {
    final updates = <String, dynamic>{};
    if (groupName != null) updates['groupName'] = groupName;
    if (groupPhoto != null) updates['groupPhoto'] = groupPhoto;

    if (updates.isNotEmpty) {
      await _conversations.doc(conversationId).update(updates);
    }
  }

  /// Delete a group entirely (admin-only operation)
  /// Deletes all messages and the conversation document
  Future<void> deleteGroup({
    required String conversationId,
    required String adminId,
  }) async {
    // Delete all messages
    final messages = await _messages(conversationId).get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Delete the conversation
    await _conversations.doc(conversationId).delete();
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

  /// Rechercher un utilisateur par numéro de téléphone
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    // Normaliser le numéro de téléphone
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Rechercher dans Firestore par téléphone
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return null;
    }

    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  /// Rechercher des utilisateurs par phones (pour matching avec contacts)
  /// Optimisé: utilise des requêtes par lot avec les deux formats (avec et sans +)
  Future<List<Map<String, dynamic>>> findUsersByPhones(List<String> phones) async {
    // Dédoublonner les numéros et créer les deux formats
    final uniquePhones = <String>{};
    final normalizedToOriginal = <String, String>{}; // normalized -> original
    for (final phone in phones) {
      final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (normalized.length >= 8) {
        uniquePhones.add(normalized);
        normalizedToOriginal[normalized] = phone;
        
        // Ajouter aussi le format avec +237 si ça ressemble à un numéro camerounais
        if (normalized.startsWith('237')) {
          normalizedToOriginal[normalized] = '+$normalized';
        }
      }
    }
    
    if (uniquePhones.isEmpty) return [];
    
    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    
    // Firestore whereIn limité à 10 valeurs, donc on fait des lots
    final phoneList = uniquePhones.toList();
    const batchSize = 10;
    
    // Préparer tous les batches
    final batches = <List<String>>[];
    for (var i = 0; i < phoneList.length; i += batchSize) {
      final end = (i + batchSize > phoneList.length) ? phoneList.length : i + batchSize;
      final batch = phoneList.sublist(i, end);
      final batchWithPlus = batch.map((p) => '+$p').toList();
      batches.add([...batch, ...batchWithPlus]);
    }

    // Lancer toutes les requêtes en parallèle
    final futures = batches.map((batch) async {
      try {
        return await _db
            .collection('users')
            .where('phone', whereIn: batch)
            .get();
      } catch (e) {
        // Fallback sur des queries individuelles pour ce batch
        final results = <QueryDocumentSnapshot>[];
        for (final phone in batch) {
          try {
            final singleSnap = await _db
                .collection('users')
                .where('phone', isEqualTo: phone)
                .limit(1)
                .get();
            results.addAll(singleSnap.docs);
          } catch (_) {
            // Ignore
          }
        }
        return results;
      }
    });

    // Attendre toutes les requêtes en parallèle
    final snapshots = await Future.wait(futures);

    // Combiner les résultats
    for (final snap in snapshots) {
      if (snap is QuerySnapshot) {
        for (final doc in snap.docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            results.add({'id': doc.id, ...doc.data() as Map<String, dynamic>});
          }
        }
      } else if (snap is List<QueryDocumentSnapshot>) {
        for (final doc in snap) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            results.add({'id': doc.id, ...doc.data() as Map<String, dynamic>});
          }
        }
      }
    }

    return results;
  }

  /// Variante progressive: renvoie les résultats au fur et à mesure des batches
  Stream<List<Map<String, dynamic>>> findUsersByPhonesProgressive(
      List<String> phones) async* {
    // Dédoublonner les numéros et créer les deux formats
    final uniquePhones = <String>{};
    for (final phone in phones) {
      final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (normalized.length >= 8) {
        uniquePhones.add(normalized);
      }
    }

    if (uniquePhones.isEmpty) {
      yield [];
      return;
    }

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    final phoneList = uniquePhones.toList();
    const batchSize = 10;

    for (var i = 0; i < phoneList.length; i += batchSize) {
      final end = (i + batchSize > phoneList.length) ? phoneList.length : i + batchSize;
      final batch = phoneList.sublist(i, end);
      final batchWithPlus = batch.map((p) => '+$p').toList();
      final batchQuery = [...batch, ...batchWithPlus];

      try {
        final snap = await _db
            .collection('users')
            .where('phone', whereIn: batchQuery)
            .get();
        for (final doc in snap.docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            results.add({'id': doc.id, ...doc.data()});
          }
        }
      } catch (e) {
        // Fallback: requêtes individuelles pour ce batch
        for (final phone in batchQuery) {
          try {
            final singleSnap = await _db
                .collection('users')
                .where('phone', isEqualTo: phone)
                .limit(1)
                .get();
            for (final doc in singleSnap.docs) {
              if (!seenIds.contains(doc.id)) {
                seenIds.add(doc.id);
                results.add({'id': doc.id, ...doc.data()});
              }
            }
          } catch (_) {
            // Ignore
          }
        }
      }

      yield List<Map<String, dynamic>>.from(results);
    }
  }

  // ── CONTACTS ─────────────────────────────────────────────────────────

  /// Stream des contacts de l'utilisateur
  Stream<List<ContactModel>> contactsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Ajouter ou mettre à jour un contact
  Future<void> addOrUpdateContact({
    required String currentUserId,
    required String contactUserId,
    required String contactName,
    String? contactPhoto,
    String? phoneNumber,
  }) async {
    // Sauvegarder le contact
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactUserId)
        .set({
      'contactName': contactName,
      'contactPhoto': contactPhoto,
      'phoneNumber': phoneNumber,
      'addedAt': DateTime.now(),
    }, SetOptions(merge: true));

    // Mettre à jour le nom dans les conversations existantes
    final convs = await _conversations
        .where('participantIds', arrayContains: currentUserId)
        .where('isGroup', isEqualTo: false)
        .get();

    for (final doc in convs.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ids = List<String>.from(data['participantIds'] ?? []);
      if (ids.contains(contactUserId) && ids.length == 2) {
        // Mettre à jour le nom du contact dans la conversation
        await doc.reference.update({
          'participantNames.$contactUserId': contactName,
          if (contactPhoto != null)
            'participantPhotos.$contactUserId': contactPhoto,
        });
      }
    }
  }

  /// Supprimer un contact
  Future<void> removeContact({
    required String currentUserId,
    required String contactUserId,
  }) async {
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactUserId)
        .delete();
  }

  /// Vérifier si un utilisateur est déjà un contact
  Future<bool> isContact({
    required String currentUserId,
    required String contactUserId,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactUserId)
        .get();
    return doc.exists;
  }

  /// Obtenir un contact spécifique
  Future<ContactModel?> getContact({
    required String currentUserId,
    required String contactUserId,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactUserId)
        .get();
    if (doc.exists) {
      return ContactModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // ── OPÉRATIONS SUR LES CONVERSATIONS ─────────────────────────────────

  /// Supprimer une conversation
  Future<void> deleteConversation({
    required String conversationId,
  }) async {
    // Supprimer tous les messages
    final messages = await _messages(conversationId).get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Supprimer la conversation
    await _conversations.doc(conversationId).delete();
  }

  /// Épingler/Désépingler une conversation
  Future<void> togglePinConversation({
    required String conversationId,
    required bool isPinned,
  }) async {
    await _conversations.doc(conversationId).update({
      'isPinned': isPinned,
    });
  }

  /// Archiver/Désarchiver une conversation
  Future<void> toggleArchiveConversation({
    required String conversationId,
    required bool isArchived,
  }) async {
    await _conversations.doc(conversationId).update({
      'isArchived': isArchived,
    });
  }

  /// Marquer une conversation comme non lue
  Future<void> markAsUnread({
    required String conversationId,
    required String userId,
  }) async {
    await _conversations.doc(conversationId).update({
      'unreadCount.$userId': FieldValue.increment(1),
    });
  }
}
