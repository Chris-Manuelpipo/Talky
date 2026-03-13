// lib/features/chat/presentation/conversations_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
import '../domain/conversation_model.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final authState    = ref.watch(authStateProvider);
    final currentUid   = authState.value?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Discussions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.newChat),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push(AppRoutes.newChat),
          ),
        ],
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list) {
          if (list.isEmpty) return _EmptyState();
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              return _ConversationTile(
                conversation: list[index],
                currentUserId: currentUid,
              ).animate(delay: (index * 40).ms).fadeIn().slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.newChat),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }
}

// ── Tuile conversation ─────────────────────────────────────────────────
class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread      = conversation.getUnreadCount(currentUserId);
    final displayName = conversation.getDisplayName(currentUserId);
    final photo       = conversation.getDisplayPhoto(currentUserId);
    final isMe        = conversation.lastMessageSenderId == currentUserId;
    final otherId     = conversation.participantIds
        .firstWhere((id) => id != currentUserId, orElse: () => '');
    final needsResolve = !conversation.isGroup &&
        (displayName.trim().isEmpty || displayName.toLowerCase() == 'moi');

    if (needsResolve && otherId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(otherId).get(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final resolvedName  = (data?['name'] as String?)?.trim();
          final resolvedPhoto = data?['photoUrl'] as String?;
          final name = (resolvedName != null && resolvedName.isNotEmpty)
              ? resolvedName
              : displayName;
          final photoUrl = resolvedPhoto ?? photo;
          return _buildTile(context, name, photoUrl, unread, isMe);
        },
      );
    }

    return _buildTile(context, displayName, photo, unread, isMe);
  }

  Widget _buildTile(
    BuildContext context,
    String displayName,
    String? photo,
    int unread,
    bool isMe,
  ) {
    return InkWell(
      onTap: () => context.push(
        AppRoutes.chat.replaceAll(':conversationId', conversation.id),
        extra: {'name': displayName, 'photo': photo},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            _Avatar(name: displayName, photoUrl: photo, isGroup: conversation.isGroup),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unread > 0
                                ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0
                                ? AppColors.primary : AppColors.textHint,
                            fontWeight: unread > 0
                                ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Indicateur "moi :"
                      if (isMe && conversation.lastMessage != null)
                        const Text('Vous : ',
                          style: TextStyle(
                            fontSize: 13, color: AppColors.textHint)),

                      // Dernier message
                      Expanded(
                        child: Text(
                          _getLastMessagePreview(conversation),
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Badge non-lus
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            )),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) return DateFormat('HH:mm').format(dt);
    if (dt.day == now.day - 1) return 'Hier';
    return DateFormat('dd/MM').format(dt);
  }

  String _getLastMessagePreview(ConversationModel conv) {
    if (conv.lastMessage == null) return 'Démarrez la conversation';
    switch (conv.lastMessageType) {
      case MessageType.image:   return '📷 Photo';
      case MessageType.video:   return '🎥 Vidéo';
      case MessageType.audio:   return '🎤 Vocal';
      case MessageType.file:    return '📎 Fichier';
      case MessageType.deleted: return '🚫 Message supprimé';
      default:                  return conv.lastMessage!;
    }
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isGroup;

  const _Avatar({required this.name, this.photoUrl, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl == null ? const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        image: photoUrl != null ? DecorationImage(
          image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
      ),
      child: photoUrl == null ? Center(
        child: Text(
          isGroup ? '👥' : name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: isGroup ? 22 : 20,
          ),
        ),
      ) : null,
    );
  }
}

// ── État vide ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 64))
              .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text('Aucune discussion',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Appuyez sur le bouton + pour démarrer\nune nouvelle conversation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
