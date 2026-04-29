// lib/features/chat/data/chat_service.dart
//
// Service Chat — version REST/Socket (backend Node.js + MySQL).
// Remplace l'ancienne implémentation Firestore.
// L'API publique est conservée autant que possible pour limiter l'impact écrans.
//
// La couche REST (ApiService) reste la source de vérité.
// La couche temps réel (SocketService) est consommée par les providers
// (pas directement ici, sauf pour émettre des events lors des écritures).

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../domain/contact_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import 'contact_local_store.dart';

class ChatService {
  ApiService get _api => ApiService.instance;
  SocketService get _socket => SocketService.instance;
  ContactLocalStore get _contacts => ContactLocalStore.instance;

  // ════════════════════════════════════════════════════════════════
  //  CONVERSATIONS
  // ════════════════════════════════════════════════════════════════

  /// Récupère la liste des conversations (non-archivées).
  Future<List<ConversationModel>> getConversations(String currentUserId) async {
    final rows = await _api.getConversations();
    final list = <ConversationModel>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      map['currentUserID'] = currentUserId;
      await _ensureParticipants(map);
      list.add(ConversationModel.fromJson(map));
    }
    return list.where((c) => !c.isArchived).toList();
  }

  Future<List<ConversationModel>> getArchivedConversations(
      String currentUserId) async {
    final rows = await _api.getConversations();
    final list = <ConversationModel>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      map['currentUserID'] = currentUserId;
      await _ensureParticipants(map);
      list.add(ConversationModel.fromJson(map));
    }
    return list.where((c) => c.isArchived).toList();
  }

  /// Stream de conversations — pour compat avec l'ancien code Firestore.
  /// Émet une seule valeur (charge initiale). Les providers réactifs
  /// s'occupent des live updates via Socket.IO.
  Stream<List<ConversationModel>> conversationsStream(String userId) async* {
    yield await getConversations(userId);
  }

  Stream<List<ConversationModel>> archivedConversationsStream(
      String userId) async* {
    yield await getArchivedConversations(userId);
  }

  /// Enrichit une Map de conversation avec un champ `participants[]` si absent.
  /// Si le backend ne renvoie pas les participants, on les extrait depuis
  /// les champs disponibles (`otherName`, `otherAvatar`) ou on laisse vide —
  /// les écrans font aussi une résolution côté `backendUserProvider`.
  Future<void> _ensureParticipants(Map<String, dynamic> map) async {
    if (map['participants'] is List) return;
    // Fallback minimaliste — le provider enrichit via backendUserProvider.
    map['participants'] = <Map<String, dynamic>>[];
  }

  /// Crée ou retourne une conversation 1-à-1.
  /// L'API publique historique prenait des IDs String (Firebase UID).
  /// Maintenant, `otherUserId` doit contenir un `alanyaID` sérialisé en String.
  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhoto,
    required String otherUserId,
    required String otherUserName,
    String? otherUserPhoto,
  }) async {
    final participantID = int.tryParse(otherUserId);
    if (participantID == null) {
      throw ArgumentError('otherUserId doit être un alanyaID numérique');
    }
    final res = await _api.getOrCreateConversation(participantID);
    final conversID = (res['conversID'] ?? 0).toString();

    // Ajout automatique dans les contacts locaux si nécessaire
    final ownerID = int.tryParse(currentUserId);
    if (ownerID != null) {
      try {
        final existing = await _contacts.isContact(
          ownerID: ownerID,
          alanyaID: participantID,
        );
        if (!existing) {
          await _contacts.addOrUpdateContact(
            ownerID: ownerID,
            alanyaID: participantID,
            contactName: otherUserName,
            contactPhoto: otherUserPhoto,
          );
        }
      } catch (_) {
        // best effort
      }
    }

    return conversID;
  }

  Future<String> createGroup({
    required String creatorId,
    required String creatorName,
    String? creatorPhoto,
    required String groupName,
    String? groupPhoto,
    required List<Map<String, dynamic>> members,
  }) async {
    final participantIDs = <int>[];
    for (final m in members) {
      final rawId = m['id'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (id != null && id > 0) participantIDs.add(id);
    }
    if (participantIDs.isEmpty) {
      throw ArgumentError('Aucun membre valide');
    }
    final res = await _api.createGroup(
      participantIDs: participantIDs,
      groupName: groupName,
      groupPhoto: groupPhoto,
    );
    return (res['conversID'] ?? 0).toString();
  }

  Future<void> togglePinConversation({
    required String conversationId,
    required bool isPinned,
  }) async {
    final id = int.tryParse(conversationId);
    if (id == null) return;
    await _api.updateConversation(id, {'isPinned': isPinned ? 1 : 0});
  }

  Future<void> toggleArchiveConversation({
    required String conversationId,
    required bool isArchived,
  }) async {
    final id = int.tryParse(conversationId);
    if (id == null) return;
    await _api.updateConversation(id, {'isArchived': isArchived ? 1 : 0});
  }

  Future<void> deleteConversation({
    required String conversationId,
  }) async {
    final id = int.tryParse(conversationId);
    if (id == null) return;
    await _api.deleteConversation(id);
  }

  Future<void> leaveGroup({required String conversationId}) async {
    final id = int.tryParse(conversationId);
    if (id == null) return;
    await _api.leaveGroup(id);
  }

  // ════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ════════════════════════════════════════════════════════════════

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    int? before,
  }) async {
    final id = int.tryParse(conversationId);
    if (id == null) return const [];
    final rows = await _api.getMessages(id, limit: limit, before: before);
    return rows
        .whereType<Map>()
        .map((r) => MessageModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Stream pour compat — émet une seule valeur (charge initiale).
  /// Les providers ajoutent les nouveaux messages via Socket.IO.
  Stream<List<MessageModel>> messagesStream(String conversationId) async* {
    yield await getMessages(conversationId);
  }

  Future<MessageModel?> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? content,
    String? replyToId,
    String? replyToContent,
    bool isStatusReply = false,
  }) async {
    final convID = int.tryParse(conversationId);
    if (convID == null) return null;

    try {
      final res = await _api.sendMessage(
        convID,
        content: content,
        type: 0,
        replyToID: replyToId != null ? int.tryParse(replyToId) : null,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
      );
      final msg = MessageModel.fromJson(Map<String, dynamic>.from(res));

      // Broadcast via socket pour les autres clients (si le backend ne broadcast pas)
      _socket.broadcastSentMessage(Map<String, dynamic>.from(res));
      return msg;
    } catch (e) {
      debugPrint('[ChatService.sendMessage] $e');
      rethrow;
    }
  }

  Future<MessageModel?> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String mediaUrl,
    required MessageType type,
    String? mediaName,
    int? mediaDuration,
    String? replyToId,
    String? replyToContent,
  }) async {
    final convID = int.tryParse(conversationId);
    if (convID == null) return null;

    final typeInt = _typeToInt(type);

    try {
      final res = await _api.sendMessage(
        convID,
        type: typeInt,
        mediaUrl: mediaUrl,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        replyToID: replyToId != null ? int.tryParse(replyToId) : null,
        replyToContent: replyToContent,
      );
      final msg = MessageModel.fromJson(Map<String, dynamic>.from(res));
      _socket.broadcastSentMessage(Map<String, dynamic>.from(res));
      return msg;
    } catch (e) {
      debugPrint('[ChatService.sendMediaMessage] $e');
      rethrow;
    }
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    final msgID = int.tryParse(messageId);
    if (msgID == null) return;
    await _api.updateMessage(msgID, newContent);
  }

  Future<void> deleteMessageForAll({
    required String conversationId,
    required String messageId,
  }) async {
    final msgID = int.tryParse(messageId);
    if (msgID == null) return;
    await _api.deleteMessage(msgID, all: true);
  }

  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    final msgID = int.tryParse(messageId);
    if (msgID == null) return;
    await _api.deleteMessage(msgID, all: false);
  }

  // ── Read / Delivered / Unread ─────────────────────────────────────

  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final id = int.tryParse(conversationId);
    if (id == null) return;
    try {
      await _api.markConversationAsRead(id);
    } catch (_) {}
  }

  Future<void> markAsUnread({
    required String conversationId,
    required String userId,
  }) async {
    // Pas d'endpoint backend dédié — on laisse le backend gérer via le
    // prochain message reçu. Aucune action côté client.
  }

  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    // Pas d'endpoint REST — on passe uniquement par Socket pour signaler
    // la livraison (le backend doit persister).
    final convID = int.tryParse(conversationId);
    if (convID == null) return;
    _socket.sendMessageStatus(
      msgID: 0,
      status: 2, // delivered
      conversationID: convID,
    );
  }

  Future<void> markMessagesReadByIds({
    required String conversationId,
    required String userId,
    required List<String> messageIds,
  }) async {
    final convID = int.tryParse(conversationId);
    if (convID == null) return;
    // Marque toute la conversation comme lue (endpoint unique)
    try {
      await _api.markConversationAsRead(convID);
    } catch (_) {}
    // Notifie via socket pour que les autres clients mettent à jour
    for (final mid in messageIds) {
      final m = int.tryParse(mid);
      if (m == null) continue;
      _socket.sendMessageStatus(
        msgID: m,
        status: 3, // read
        conversationID: convID,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  USERS / RECHERCHE
  // ════════════════════════════════════════════════════════════════

  /// Recherche par nom/pseudo/numéro via le backend.
  /// Retourne une liste de maps `{id, name, phone, photoUrl}` pour compat.
  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    try {
      final rows = await _api.searchUsers(query);
      return rows
          .whereType<Map>()
          .map((r) => _userMapFromJson(Map<String, dynamic>.from(r)))
          .where((u) => u['id'] != currentUserId)
          .toList();
    } catch (e) {
      debugPrint('[ChatService.searchUsers] $e');
      return const [];
    }
  }

  /// Récupère les contacts préférés de l'utilisateur depuis le backend.
  Future<List<Map<String, dynamic>>> getPreferredContacts() async {
    try {
      final rows = await _api.getPreferredContacts();
      return rows
          .whereType<Map>()
          .map((r) => _userMapFromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService.getPreferredContacts] $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return null;
    try {
      final raw = await _api.getUserByPhone(normalized);
      return _userMapFromJson(raw);
    } catch (e) {
      return null;
    }
  }

  /// Recherche batch de users par numéros (séquentiel, résilient aux 404).
  Future<List<Map<String, dynamic>>> findUsersByPhones(
      List<String> phones) async {
    final results = <Map<String, dynamic>>[];
    for (final p in phones) {
      final u = await findUserByPhone(p);
      if (u != null && !results.any((e) => e['id'] == u['id'])) {
        results.add(u);
      }
    }
    return results;
  }

  /// Version progressive — émet la liste cumulée au fur et à mesure.
  Stream<List<Map<String, dynamic>>> findUsersByPhonesProgressive(
      List<String> phones) async* {
    final accumulated = <Map<String, dynamic>>[];
    const chunkSize = 8;

    final unique = <String>{};
    for (final p in phones) {
      final n = _normalizePhone(p);
      if (n.isNotEmpty) unique.add(n);
    }
    final list = unique.toList();

    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, list.length);
      final chunk = list.sublist(i, end);
      final results = await Future.wait(chunk.map((p) => findUserByPhone(p)));
      for (final u in results) {
        if (u != null && !accumulated.any((e) => e['id'] == u['id'])) {
          accumulated.add(u);
        }
      }
      yield List<Map<String, dynamic>>.from(accumulated);
    }
  }

  /// Stream des utilisateurs disponibles (anciennement toute la collection users).
  /// On retourne maintenant les contacts locaux Talky sous forme de Map.
  Stream<List<Map<String, dynamic>>> usersStream(String currentUserId) async* {
    final ownerID = int.tryParse(currentUserId);
    if (ownerID == null || ownerID <= 0) {
      yield const [];
      return;
    }
    await for (final contacts in _contacts.watchContacts(ownerID)) {
      yield contacts
          .map((c) => <String, dynamic>{
                'id': c.alanyaID.toString(),
                'name': c.contactName,
                'phone': c.phoneNumber ?? '',
                'photoUrl': c.contactPhoto,
              })
          .toList();
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  CONTACTS (locaux via Hive)
  // ════════════════════════════════════════════════════════════════

  Stream<List<ContactModel>> contactsStream(String userId) async* {
    final ownerID = int.tryParse(userId);
    if (ownerID == null || ownerID <= 0) {
      yield const [];
      return;
    }
    yield* _contacts.watchContacts(ownerID);
  }

  Future<void> addContact({
    required String userId,
    required String contactUserId,
    required String contactName,
    String? contactPhoto,
    String? phoneNumber,
  }) async {
    final ownerID = int.tryParse(userId);
    final alanyaID = int.tryParse(contactUserId);
    if (ownerID == null || alanyaID == null) return;
    await _contacts.addOrUpdateContact(
      ownerID: ownerID,
      alanyaID: alanyaID,
      contactName: contactName,
      contactPhoto: contactPhoto,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> removeContact({
    required String userId,
    required String contactUserId,
  }) async {
    final ownerID = int.tryParse(userId);
    final alanyaID = int.tryParse(contactUserId);
    if (ownerID == null || alanyaID == null) return;
    await _contacts.removeContact(ownerID: ownerID, alanyaID: alanyaID);
  }

  // ════════════════════════════════════════════════════════════════
  //  Helpers internes
  // ════════════════════════════════════════════════════════════════

  Map<String, dynamic> _userMapFromJson(Map<String, dynamic> raw) {
    return {
      'id': (raw['alanyaID'] ?? '').toString(),
      'alanyaID': raw['alanyaID'] as int? ?? 0,
      'name': raw['nom'] as String? ?? '',
      'pseudo': raw['pseudo'] as String? ?? '',
      'phone': raw['alanyaPhone'] as String? ?? '',
      'photoUrl': raw['avatar_url'] as String?,
    };
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  int _typeToInt(MessageType t) {
    switch (t) {
      case MessageType.text:
        return 0;
      case MessageType.image:
        return 1;
      case MessageType.video:
        return 2;
      case MessageType.audio:
        return 3;
      case MessageType.file:
        return 4;
      case MessageType.deleted:
        return 0;
    }
  }
}
