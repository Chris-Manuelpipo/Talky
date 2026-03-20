// lib/features/chat/data/chat_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_service.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/contact_model.dart';
import '../../auth/data/auth_providers.dart';
import '../../../core/services/phone_contacts_service.dart';

// ── Service ────────────────────────────────────────────────────────────
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ── Nom de l'utilisateur courant depuis Firestore ──────────────────────
// Évite le bug "Moi" quand displayName Firebase est null
final currentUserNameProvider = FutureProvider<String>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return 'Utilisateur';

  // D'abord essayer Firebase displayName
  if (user.displayName != null && user.displayName!.isNotEmpty) {
    return user.displayName!;
  }

  // Sinon lire depuis Firestore
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['name'] ?? 'Utilisateur';
  } catch (_) {
    return 'Utilisateur';
  }
});

// ── Stream conversations ───────────────────────────────────────────────
final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.read(chatServiceProvider).conversationsStream(user.uid);
    },
    loading: () => const Stream.empty(),
    error:   (_, __) => const Stream.empty(),
  );
});

// ── Stream conversations archivées ─────────────────────────────────────
final archivedConversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.read(chatServiceProvider).archivedConversationsStream(user.uid);
    },
    loading: () => const Stream.empty(),
    error:   (_, __) => const Stream.empty(),
  );
});

// ── Stream messages ────────────────────────────────────────────────────
final messagesProvider = StreamProvider.family<List<MessageModel>, String>(
  (ref, conversationId) {
    return ref.read(chatServiceProvider).messagesStream(conversationId);
  },
);

// ── Notifier envoi de message ──────────────────────────────────────────
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
      // Lire le vrai nom depuis Firestore
      final senderName = await _ref.read(currentUserNameProvider.future);

      await _chatService.sendMessage(
        conversationId: conversationId,
        senderId:       senderId,
        senderName:     senderName,
        content:        content,
        replyToId:      replyToId,
        replyToContent: replyToContent,
      );
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

// ── Stream contacts ─────────────────────────────────────────────────────
final contactsProvider = StreamProvider<List<ContactModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.read(chatServiceProvider).contactsStream(user.uid);
    },
    loading: () => const Stream.empty(),
    error:   (_, __) => const Stream.empty(),
  );
});

// ── Phone contacts ─────────────────────────────────────────────────────
final phoneContactsServiceProvider = Provider<PhoneContactsService>((ref) {
  return PhoneContactsService();
});

final phoneContactsProvider = FutureProvider<List<PhoneContact>>((ref) async {
  final service = ref.read(phoneContactsServiceProvider);
  
  // Demander la permission
  final hasPermission = await service.requestPermission();
  if (!hasPermission) {
    return [];
  }
  
  return service.getContacts();
});
