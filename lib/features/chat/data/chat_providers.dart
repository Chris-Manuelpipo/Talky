// lib/features/chat/data/chat_providers.dart
//
// Providers reactifs pour la messagerie — REST (chargement initial) +
// Socket.IO (live updates).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/phone_contacts_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
import '../domain/contact_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import 'chat_service.dart';

// ════════════════════════════════════════════════════════════════
//  Service
// ════════════════════════════════════════════════════════════════

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ════════════════════════════════════════════════════════════════
//  Nom de l'utilisateur courant (via backend /api/auth/me)
// ════════════════════════════════════════════════════════════════

final currentUserNameProvider = FutureProvider<String>((ref) async {
  final authState = ref.watch(authStateProvider);
  final firebaseUser = authState.value;
  if (firebaseUser == null) return 'Utilisateur';

  // D'abord Firebase displayName
  if (firebaseUser.displayName != null &&
      firebaseUser.displayName!.isNotEmpty) {
    return firebaseUser.displayName!;
  }
  // Sinon profil backend
  final me = ref.watch(currentBackendUserProvider).value;
  if (me != null && me.name.isNotEmpty) return me.name;
  if (me != null && me.pseudo.isNotEmpty) return me.pseudo;
  return 'Utilisateur';
});

// ════════════════════════════════════════════════════════════════
//  Conversations — StateNotifier
// ════════════════════════════════════════════════════════════════

class ConversationsNotifier
    extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  ConversationsNotifier(this._ref, this._currentUserId)
      : super(const AsyncValue.loading()) {
    _load();
    _wireSocket();
  }

  final Ref _ref;
  final String _currentUserId;
  StreamSubscription<SocketMessageEvent>? _msgSub;
  StreamSubscription<SocketPresenceEvent>? _presSub;
  StreamSubscription<bool>? _connSub;

  Future<void> _load() async {
    try {
      final list =
          await _ref.read(chatServiceProvider).getConversations(_currentUserId);
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  void _wireSocket() {
    final socket = _ref.read(socketInstanceProvider);

    _msgSub = socket.onMessage.listen(_onMessageReceived);
    _presSub = socket.onPresence.listen(_onPresenceUpdated);
    _connSub = socket.onConnectedChange.listen((connected) {
      if (connected) _load();
    });
  }

  void _onMessageReceived(SocketMessageEvent event) {
    final current = state.value;
    if (current == null) return;

    final convIdStr = event.conversationID.toString();
    final idx = current.indexWhere((c) => c.id == convIdStr);

    if (idx < 0) {
      // Nouvelle conversation : rechargement
      _load();
      return;
    }

    final existing = current[idx];
    final payload = event.payload;
    final senderId = payload['senderID']?.toString();
    final content = payload['content']?.toString();
    final typeInt = payload['type'] as int? ?? 0;
    final isMe = senderId == _currentUserId;
    final newUnread = Map<String, int>.from(existing.unreadCount);
    if (!isMe) {
      newUnread[_currentUserId] = (newUnread[_currentUserId] ?? 0) + 1;
    }

    final updated = ConversationModel(
      conversID: existing.conversID,
      id: existing.id,
      participantIds: existing.participantIds,
      participantNames: existing.participantNames,
      participantPhotos: existing.participantPhotos,
      lastMessage: content ?? existing.lastMessage,
      lastMessageSenderId: senderId ?? existing.lastMessageSenderId,
      lastMessageType: _typeFromInt(typeInt),
      lastMessageStatus: MessageStatus.sent,
      lastMessageAt: DateTime.now(),
      unreadCount: newUnread,
      isGroup: existing.isGroup,
      groupName: existing.groupName,
      groupPhoto: existing.groupPhoto,
      isPinned: existing.isPinned,
      isArchived: existing.isArchived,
    );

    final newList = List<ConversationModel>.from(current);
    newList.removeAt(idx);
    newList.insert(0, updated);
    state = AsyncValue.data(newList);
  }

  void _onPresenceUpdated(SocketPresenceEvent event) {
    // Les providers backendUserStreamProvider gèrent la présence par user.
    // Rien à faire ici.
  }

  static MessageType _typeFromInt(int v) {
    const map = {
      0: MessageType.text,
      1: MessageType.image,
      2: MessageType.video,
      3: MessageType.audio,
      4: MessageType.file,
    };
    return map[v] ?? MessageType.text;
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _presSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}

/// Provider singleton pour le SocketService (évite les ref circulaires).
final socketInstanceProvider =
    Provider<SocketService>((ref) => SocketService.instance);

final conversationsProvider = StateNotifierProvider<ConversationsNotifier,
    AsyncValue<List<ConversationModel>>>((ref) {
  final currentId = ref.watch(currentAlanyaIDStringProvider);
  return ConversationsNotifier(ref, currentId);
});

// ════════════════════════════════════════════════════════════════
//  Conversations archivées
// ════════════════════════════════════════════════════════════════

class ArchivedConversationsNotifier
    extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  ArchivedConversationsNotifier(this._ref, this._currentUserId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;
  final String _currentUserId;

  Future<void> _load() async {
    try {
      final list = await _ref
          .read(chatServiceProvider)
          .getArchivedConversations(_currentUserId);
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();
}

final archivedConversationsProvider = StateNotifierProvider<
    ArchivedConversationsNotifier, AsyncValue<List<ConversationModel>>>((ref) {
  final currentId = ref.watch(currentAlanyaIDStringProvider);
  // Rafraîchit si une conversation est archivée
  ref.listen(conversationsProvider, (_, __) {});
  return ArchivedConversationsNotifier(ref, currentId);
});

// ════════════════════════════════════════════════════════════════
//  Messages d'une conversation — StateNotifier
// ════════════════════════════════════════════════════════════════

class MessagesNotifier
    extends StateNotifier<AsyncValue<List<MessageModel>>> {
  MessagesNotifier(this._ref, this._conversationId)
      : super(const AsyncValue.loading()) {
    _load();
    _wireSocket();
    _joinRoom();
  }

  final Ref _ref;
  final String _conversationId;
  StreamSubscription<SocketMessageEvent>? _msgSub;
  StreamSubscription<SocketMessageStatusEvent>? _statusSub;

  int? get _convIDInt => int.tryParse(_conversationId);

  Future<void> _load() async {
    try {
      final list = await _ref
          .read(chatServiceProvider)
          .getMessages(_conversationId);
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void _wireSocket() {
    final socket = _ref.read(socketInstanceProvider);
    _msgSub = socket.onMessage.listen(_onMessageReceived);
    _statusSub = socket.onMessageStatus.listen(_onStatusUpdate);
  }

  void _joinRoom() {
    final id = _convIDInt;
    if (id == null) return;
    _ref.read(socketInstanceProvider).joinConversation(id);
  }

  void _leaveRoom() {
    final id = _convIDInt;
    if (id == null) return;
    _ref.read(socketInstanceProvider).leaveConversation(id);
  }

  void _onMessageReceived(SocketMessageEvent event) {
    if (event.conversationID.toString() != _conversationId) return;
    final current = state.value ?? const <MessageModel>[];
    try {
      final msg = MessageModel.fromJson(event.payload);
      // Évite les doublons (si le message a déjà été envoyé par soi-même
      // et reçu en retour par le broadcast)
      if (current.any((m) => m.msgID == msg.msgID)) return;
      state = AsyncValue.data([...current, msg]);
    } catch (e) {
      debugPrint('[MessagesNotifier] parse error: $e');
    }
  }

  void _onStatusUpdate(SocketMessageStatusEvent event) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.msgID == event.msgID);
    if (idx < 0) return;
    final updated = current[idx]
        .copyWith(status: _statusFromInt(event.status));
    final newList = List<MessageModel>.from(current);
    newList[idx] = updated;
    state = AsyncValue.data(newList);
  }

  /// Ajoute un message optimiste ou confirmé localement (appelé après send).
  void appendLocal(MessageModel msg) {
    final current = state.value ?? const <MessageModel>[];
    if (current.any((m) => m.msgID == msg.msgID)) return;
    state = AsyncValue.data([...current, msg]);
  }

  static MessageStatus _statusFromInt(int v) {
    const map = {
      0: MessageStatus.sending,
      1: MessageStatus.sent,
      2: MessageStatus.delivered,
      3: MessageStatus.read,
    };
    return map[v] ?? MessageStatus.sent;
  }

  @override
  void dispose() {
    _leaveRoom();
    _msgSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier,
    AsyncValue<List<MessageModel>>, String>((ref, conversationId) {
  return MessagesNotifier(ref, conversationId);
});

// ════════════════════════════════════════════════════════════════
//  Envoi de message
// ════════════════════════════════════════════════════════════════

class SendMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatService _chatService;
  final Ref _ref;

  SendMessageNotifier(this._chatService, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> send({
    required String conversationId,
    required String senderId,
    required String content,
    String? replyToId,
    String? replyToContent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final senderName = await _ref.read(currentUserNameProvider.future);
      final msg = await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        replyToId: replyToId,
        replyToContent: replyToContent,
      );
      // Append immédiat dans la liste locale (pas d'attente socket)
      if (msg != null) {
        _ref
            .read(messagesProvider(conversationId).notifier)
            .appendLocal(msg);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, AsyncValue<void>>(
  (ref) => SendMessageNotifier(ref.read(chatServiceProvider), ref),
);

// ════════════════════════════════════════════════════════════════
//  Typing — StreamProvider
// ════════════════════════════════════════════════════════════════

final typingProvider = StreamProvider.family<Set<int>, String>(
  (ref, conversationId) async* {
    final socket = ref.watch(socketInstanceProvider);
    final convID = int.tryParse(conversationId);
    if (convID == null) {
      yield const <int>{};
      return;
    }
    final active = <int>{};
    yield active;
    await for (final event in socket.onTyping) {
      if (event.conversationID != convID) continue;
      if (event.isTyping) {
        active.add(event.userID);
      } else {
        active.remove(event.userID);
      }
      yield {...active};
    }
  },
);

// ════════════════════════════════════════════════════════════════
//  Contacts (Hive)
// ════════════════════════════════════════════════════════════════

final contactsProvider = StreamProvider<List<ContactModel>>((ref) {
  final currentId = ref.watch(currentAlanyaIDStringProvider);
  if (currentId.isEmpty) return const Stream.empty();
  return ref.read(chatServiceProvider).contactsStream(currentId);
});

// ════════════════════════════════════════════════════════════════
//  Phone contacts (système)
// ════════════════════════════════════════════════════════════════

final phoneContactsServiceProvider = Provider<PhoneContactsService>((ref) {
  return PhoneContactsService();
});

final phoneContactsProvider = FutureProvider<List<PhoneContact>>((ref) async {
  final service = ref.read(phoneContactsServiceProvider);
  final hasPermission = await service.requestPermission();
  if (!hasPermission) return [];
  return service.getContacts();
});
