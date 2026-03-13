// lib/features/groups/presentation/groups_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/domain/conversation_model.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final currentUid    = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Groupes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () => context.push(AppRoutes.createGroup),
          ),
        ],
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (list) {
          final groups = list.where((c) => c.isGroup).toList();
          if (groups.isEmpty) return _EmptyGroupsState();
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) => _GroupTile(
              group: groups[i], currentUserId: currentUid,
            ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.1),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createGroup),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.group_add_rounded, color: Colors.white),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ConversationModel group;
  final String currentUserId;
  const _GroupTile({required this.group, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final unread = group.getUnreadCount(currentUserId);

    return InkWell(
      onTap: () => context.push(
        AppRoutes.chat.replaceAll(':conversationId', group.id),
        extra: {'name': group.groupName ?? 'Groupe', 'photo': group.groupPhoto},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFF4FC3F7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: Text('👥', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.groupName ?? 'Groupe',
                          style: TextStyle(fontSize: 16,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (group.lastMessageAt != null)
                        Text(_formatTime(group.lastMessageAt!),
                          style: TextStyle(fontSize: 12,
                            color: unread > 0 ? AppColors.primary : AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_getMembersPreview(),
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.lastMessage ?? '${group.participantIds.length} membres',
                          style: TextStyle(fontSize: 13,
                            color: unread > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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

  String _getMembersPreview() {
    final names = group.participantNames.values.take(3).join(', ');
    final total = group.participantIds.length;
    return total > 3 ? '$names +${total - 3}' : names;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) return DateFormat('HH:mm').format(dt);
    if (dt.day == now.day - 1) return 'Hier';
    return DateFormat('dd/MM').format(dt);
  }
}

class _EmptyGroupsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👥', style: TextStyle(fontSize: 64))
              .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text('Aucun groupe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Créez un groupe pour discuter\navec plusieurs personnes',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.createGroup),
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Créer un groupe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}