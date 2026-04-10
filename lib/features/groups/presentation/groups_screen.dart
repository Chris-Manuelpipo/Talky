// lib/features/groups/presentation/groups_screen.dart

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
import '../../chat/data/chat_providers.dart';
import '../../chat/domain/conversation_model.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
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
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: TextStyle(color: context.appThemeColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher un groupe...',
                  hintStyle: TextStyle(color: context.appThemeColors.textHint),
                  border: InputBorder.none,
                ),
              )
            : Text('Groupes',
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
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () => context.push(AppRoutes.createGroup),
          ),
        ],
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list) {
          final groups = list.where((c) => c.isGroup).toList();
          final filtered = _query.trim().isEmpty
              ? groups
              : groups
                  .where(
                      (g) => (g.groupName ?? '').toLowerCase().contains(_query))
                  .toList();

          if (filtered.isEmpty) {
            return _searching && _query.isNotEmpty
                ? Center(
                    child: Text('Aucun groupe trouvé',
                        style: TextStyle(
                            color: context.appThemeColors.textSecondary)),
                  )
                : _EmptyGroupsState();
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) => _GroupTile(
              group: filtered[i],
              currentUserId: currentUid,
            ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.1),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createGroup),
        backgroundColor: context.primaryColor,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primaryColor,
              ),
              child: Center(
                child: Icon(AppIcons.group, color: Colors.white, size: 24),
              ),
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
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: context.appThemeColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (group.lastMessageAt != null)
                        Text(_formatTime(group.lastMessageAt!),
                            style: TextStyle(
                                fontSize: 12,
                                color: unread > 0
                                    ? AppColors.primary
                                    : context.appThemeColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_getMembersPreview(),
                      style:
                          TextStyle(fontSize: 11, color: context.primaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            group.lastMessage ??
                                '${group.participantIds.length} membres',
                            style: TextStyle(
                                fontSize: 13,
                                color: unread > 0
                                    ? context.appThemeColors.textPrimary
                                    : context.appThemeColors.textSecondary,
                                fontWeight: unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
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
                                  fontWeight: FontWeight.w700)),
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
    final colors = context.appThemeColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.group, size: 64, color: colors.textHint)
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text('Aucun groupe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Créez un groupe pour discuter\navec plusieurs personnes',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.createGroup),
            icon: const Icon(Icons.group_add_rounded),
            label: Text('Créer un groupe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
