// lib/features/chat/presentation/conversations_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
import '../data/chat_providers.dart';
import '../domain/conversation_model.dart';
import '../domain/contact_model.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final currentUid = ref.watch(currentAlanyaIDStringProvider);

    // Marquer comme délivré quand l'utilisateur reçoit des messages
    ref.listen(conversationsProvider, (_, next) {
      final uid = ref.read(currentAlanyaIDStringProvider);
      if (uid.isEmpty) return;
      next.whenData((list) {
        for (final c in list) {
          if (c.lastMessageSenderId != null &&
              c.lastMessageSenderId != uid &&
              c.lastMessageStatus == MessageStatus.sent) {
            ref.read(chatServiceProvider).markAsDelivered(
                  conversationId: c.id,
                  userId: uid,
                );
          }
        }
      });
    });

    // Prefetch profils des autres utilisateurs (cache backend)
    ref.listen(conversationsProvider, (_, next) {
      final uid = ref.read(currentAlanyaIDStringProvider);
      if (uid.isEmpty) return;
      next.whenData((list) {
        final ids = <int>{};
        for (final c in list) {
          for (final pid in c.participantIds) {
            final i = int.tryParse(pid);
            if (i != null && i > 0) ids.add(i);
          }
        }
        ids.remove(int.tryParse(uid) ?? 0);
        if (ids.isNotEmpty) {
          ref.read(prefetchBackendUsersProvider(ids.toList()));
        }
      });
    });

    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                ),
              )
            : const Text('Discussions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
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
          if (_searching) {
            return _SearchResults(
              conversations: list,
              currentUserId: currentUid,
              query: _query,
              onOpenChat: (userId, name, photo) =>
                  _startChat(context, userId, name, photo),
            );
          }
          if (list.isEmpty) return _EmptyState();
          return ListView.builder(
            itemCount: list.length + 1,
            itemBuilder: (context, index) {
              if (index == list.length) {
                // Footer with archived conversations link
                return _ArchivedLink();
              }
              return _ConversationTile(
                conversation: list[index],
                currentUserId: currentUid,
              )
                  .animate(delay: (index * 40).ms)
                  .fadeIn()
                  .slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.newChat),
        backgroundColor: colors.primary,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _startChat(
    BuildContext context,
    String otherUserId,
    String otherUserName,
    String? otherUserPhoto,
  ) async {
    final currentUid = ref.read(currentAlanyaIDStringProvider);
    if (currentUid.isEmpty) return;

    try {
      final myName = await ref.read(currentUserNameProvider.future);
      final myProfile =
          await ref.read(currentBackendUserProvider.future);
      final myPhoto = myProfile?.photoUrl;

      final convId =
          await ref.read(chatServiceProvider).getOrCreateConversation(
                currentUserId: currentUid,
                currentUserName: myName,
                currentUserPhoto: myPhoto,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserPhoto: otherUserPhoto,
              );

      if (context.mounted) {
        context.push(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {'name': otherUserName, 'photo': otherUserPhoto},
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

class _SearchResults extends ConsumerWidget {
  final List<ConversationModel> conversations;
  final String currentUserId;
  final String query;
  final void Function(String, String, String?) onOpenChat;

  const _SearchResults({
    required this.conversations,
    required this.currentUserId,
    required this.query,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim();
    final convMatches = q.isEmpty
        ? conversations
        : conversations.where((c) {
            final name = c.getDisplayName(currentUserId).toLowerCase();
            final groupName = (c.groupName ?? '').toLowerCase();
            final last = (c.lastMessage ?? '').toLowerCase();
            return name.contains(q) ||
                groupName.contains(q) ||
                last.contains(q);
          }).toList();

    // Utiliser les contacts au lieu de tous les utilisateurs
    return StreamBuilder<List<ContactModel>>(
      stream: ref.read(chatServiceProvider).contactsStream(currentUserId),
      builder: (context, snap) {
        final contacts = snap.data ?? [];
        final contactMatches = q.isEmpty
            ? <ContactModel>[]
            : contacts.where((c) {
                final name = c.contactName.toLowerCase();
                final phone = (c.phoneNumber ?? '').toLowerCase();
                return name.contains(q) || phone.contains(q);
              }).toList();

        if (convMatches.isEmpty && contactMatches.isEmpty) {
          return const Center(
            child: Text('Aucun résultat',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        final items = <Widget>[];
        if (convMatches.isNotEmpty) {
          final groupConvs = convMatches.where((c) => c.isGroup).toList();
          final directConvs = convMatches.where((c) => !c.isGroup).toList();

          if (directConvs.isNotEmpty) {
            items.add(const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Discussions',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
            ));
            items.addAll(directConvs.map((c) => _ConversationTile(
                  conversation: c,
                  currentUserId: currentUserId,
                )));
          }

          if (groupConvs.isNotEmpty) {
            items.add(const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Groupes',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
            ));
            items.addAll(groupConvs.map((c) => _ConversationTile(
                  conversation: c,
                  currentUserId: currentUserId,
                )));
          }
        }

        if (contactMatches.isNotEmpty) {
          items.add(const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Contacts',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                )),
          ));
          items.addAll(contactMatches.map((c) {
            final name = c.contactName;
            final photo = c.contactPhoto;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: context.primaryColor,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person_rounded,
                        color: Colors.white, size: 24)
                    : null,
              ),
              title: Text(name,
                  style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text(c.phoneNumber ?? '',
                  style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () => onOpenChat(
                c.id,
                name,
                photo,
              ),
            );
          }));
        }

        return ListView(
          children: items,
        );
      },
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
    final unread = conversation.getUnreadCount(currentUserId);
    final displayName = conversation.getDisplayName(currentUserId);
    final photo = conversation.getDisplayPhoto(currentUserId);
    final isMe = conversation.lastMessageSenderId == currentUserId;
    final otherId = conversation.participantIds
        .firstWhere((id) => id != currentUserId, orElse: () => '');
    final contactsService = ref.read(phoneContactsServiceProvider);
    // Always resolve for non-group chats to get fresh profile photos from Firestore
    if (!conversation.isGroup && otherId.isNotEmpty) {
      final userAsync = ref.watch(userProfileStreamProvider(otherId));
      final user = userAsync.asData?.value;
      final resolvedName = user?.name.trim();
      final baseName = (resolvedName != null && resolvedName.isNotEmpty)
          ? resolvedName
          : displayName;
      final photoUrl = user?.photoUrl ?? photo;
      final resolvedDisplayName = contactsService.resolveNameFromCache(
        fallbackName: baseName,
        phone: user?.phone,
      );
      return _buildTile(
        context,
        ref,
        resolvedDisplayName,
        photoUrl,
        unread,
        isMe,
      );
    }

    return _buildTile(context, ref, displayName, photo, unread, isMe);
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
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
      onLongPress: () => _showConversationOptions(context, ref, displayName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                _Avatar(
                    name: displayName,
                    photoUrl: photo,
                    isGroup: conversation.isGroup),
                if (conversation.isPinned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.appThemeColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            color: context.appThemeColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(conversation.lastMessageAt!),
                              style: TextStyle(
                                fontSize: 12,
                                color: unread > 0
                                    ? context.primaryColor
                                    : AppColors.textHint,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (isMe && conversation.lastMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _LastStatusIcon(
                                  status: conversation.lastMessageStatus,
                                ),
                              ),
                          ],
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
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight:
                                unread > 0 ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Badge non-lus
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.primaryColor,
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

  void _showConversationOptions(
    BuildContext context,
    WidgetRef ref,
    String displayName,
  ) {
    final chatService = ref.read(chatServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appThemeColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            // Marquer comme non lu
            _OptionTile(
              icon: Icons.mark_email_unread_rounded,
              label: conversation.getUnreadCount(currentUserId) > 0
                  ? 'Marquer comme lu'
                  : 'Marquer comme non lu',
              onTap: () async {
                Navigator.pop(context);
                final unread = conversation.getUnreadCount(currentUserId);
                if (unread > 0) {
                  await chatService.markAsRead(
                    conversationId: conversation.id,
                    userId: currentUserId,
                  );
                } else {
                  await chatService.markAsUnread(
                    conversationId: conversation.id,
                    userId: currentUserId,
                  );
                }
              },
            ),
            // Épingler/Désépingler
            _OptionTile(
              icon: conversation.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              label: conversation.isPinned ? 'Désépingler' : 'Épingler',
              onTap: () async {
                Navigator.pop(context);
                await chatService.togglePinConversation(
                  conversationId: conversation.id,
                  isPinned: !conversation.isPinned,
                );
              },
            ),
            // Archiver/Désarchiver
            _OptionTile(
              icon: conversation.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: conversation.isArchived ? 'Désarchiver' : 'Archiver',
              onTap: () async {
                Navigator.pop(context);
                await chatService.toggleArchiveConversation(
                  conversationId: conversation.id,
                  isArchived: !conversation.isArchived,
                );
              },
            ),
            // Supprimer
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Supprimer la conversation'),
                    content: const Text(
                      'Cette action supprimera définitivement cette conversation et tous ses messages.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await chatService.deleteConversation(
                    conversationId: conversation.id,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
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
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Vidéo';
      case MessageType.audio:
        return 'Vocal';
      case MessageType.file:
        return 'Fichier';
      case MessageType.deleted:
        return 'Message supprimé';
      default:
        return conv.lastMessage!;
    }
  }
}

// ── Option Tile ─────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : colors.textPrimary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.red : colors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────
class _Avatar extends ConsumerWidget {
  final String name;
  final String? photoUrl;
  final bool isGroup;

  const _Avatar({required this.name, this.photoUrl, required this.isGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primaryColor,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primaryColor,
            ),
            child: Center(
              child: isGroup
                  ? const Icon(AppIcons.group, color: Colors.white, size: 24)
                  : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.primaryColor,
      ),
      child: Center(
        child: isGroup
            ? const Icon(AppIcons.group, color: Colors.white, size: 24)
            : const Icon(Icons.person_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

// ── Statut du dernier message ──────────────────────────────────────────
class _LastStatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _LastStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 12, color: AppColors.textHint);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 12, color: AppColors.textHint);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 12, color: AppColors.textHint);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded,
            size: 12, color: context.accentColor);
    }
  }
}

// ── État vide ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.chat, size: 64, color: colors.textHint)
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text('Aucune discussion',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
              'Appuyez sur le bouton + pour démarrer\nune nouvelle conversation',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Lien vers conversations archivées ─────────────────────────────────
class _ArchivedLink extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedConvos = ref.watch(archivedConversationsProvider);
    final colors = context.appThemeColors;

    return InkWell(
      onTap: () => context.push(AppRoutes.archivedChats),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              color: colors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Conversations archivées',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
            archivedConvos.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${list.length}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
