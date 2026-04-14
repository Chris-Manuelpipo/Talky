// lib/features/groups/presentation/group_details_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/domain/conversation_model.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? groupName;
  final String? groupPhoto;

  const GroupDetailsScreen({
    super.key,
    required this.conversationId,
    this.groupName,
    this.groupPhoto,
  });

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  late TextEditingController _nameCtrl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.groupName ?? 'Groupe');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final conversationsAsync = ref.watch(conversationsProvider);
    final authState = ref.watch(authStateProvider);
    final currentUserId = authState.value?.uid ?? '';
    final isAdminAsync = ref.watch(isGroupAdminProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text('Détails du groupe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (conversations) {
          final group = conversations.firstWhere(
            (c) => c.id == widget.conversationId,
            orElse: () => ConversationModel(
              id: '',
              participantIds: [],
              participantNames: {},
              participantPhotos: {},
              unreadCount: {},
            ),
          );

          if (group.id.isEmpty) {
            return Center(
              child: Text('Groupe non trouvé',
                style: TextStyle(color: colors.textSecondary)),
            );
          }

          return isAdminAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (isAdmin) => _buildContent(
              context,
              colors,
              group,
              isAdmin,
              currentUserId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppThemeColors colors,
    ConversationModel group,
    bool isAdmin,
    String currentUserId,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Group photo
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: group.groupPhoto ?? '',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          AppIcons.group,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Group name (editable if admin)
                if (_editingName && isAdmin)
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      onSubmitted: (value) async {
                        await ref
                            .read(chatServiceProvider)
                            .updateGroupInfo(
                              conversationId: widget.conversationId,
                              adminId: ref.read(authStateProvider).value!.uid,
                              groupName: value.isNotEmpty ? value : null,
                            );
                        setState(() => _editingName = false);
                      },
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          group.groupName ?? 'Groupe',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          onPressed: () {
                            setState(() => _editingName = true);
                          },
                        ),
                    ],
                  ),

                const SizedBox(height: 8),
                Text(
                  '${group.participantIds.length} membres',
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),

          // Members section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Membres',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter'),
                        onPressed: () => _showAddMembersDialog(context),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Members list
                ...group.participantIds.map((memberId) {
                  final name = group.participantNames[memberId] ?? 'Membre';
                  final photo = group.participantPhotos[memberId];
                  final isCurrentUser = memberId == ref.read(authStateProvider).value?.uid;
                  final isMemberAdmin = group.adminIds.contains(memberId);

                  return _MemberTile(
                    memberId: memberId,
                    name: name,
                    photo: photo,
                    isCurrentUser: isCurrentUser,
                    isAdmin: isMemberAdmin,
                    isCurrentUserAdmin: isAdmin,
                    conversationId: widget.conversationId,
                    onRemove: () => _showRemoveMemberDialog(context, name, memberId),
                    onPromote: () => _showPromoteDialog(context, name, memberId),
                  );
                }).toList(),
              ],
            ),
          ),

          // Admin actions
          if (isAdmin) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteGroupDialog(context),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Supprimer le groupe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddMembersDialog(BuildContext context) {
    // TODO: Implement contact selection dialog (reuse from create_group_screen)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter des membres'),
        content: const Text('Fonctionnalité à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(BuildContext context, String memberName, String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text('Retirer "$memberName" du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).removeMemberFromGroup(
                  conversationId: widget.conversationId,
                  adminId: ref.read(authStateProvider).value!.uid,
                  memberId: memberId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$memberName a été retiré du groupe')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  void _showPromoteDialog(BuildContext context, String memberName, String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promouvoir en admin'),
        content: Text('Promouvoir "$memberName" en administrateur du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).promoteToAdmin(
                  conversationId: widget.conversationId,
                  adminId: ref.read(authStateProvider).value!.uid,
                  memberId: memberId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$memberName est maintenant admin')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Promouvoir'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text(
          'Cette action supprimera définitivement le groupe et tous ses messages. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).deleteGroup(
                  conversationId: widget.conversationId,
                  adminId: ref.read(authStateProvider).value!.uid,
                );
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Groupe supprimé')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ── Member Tile ────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final String memberId;
  final String name;
  final String? photo;
  final bool isCurrentUser;
  final bool isAdmin;
  final bool isCurrentUserAdmin;
  final String conversationId;
  final VoidCallback? onRemove;
  final VoidCallback? onPromote;

  const _MemberTile({
    required this.memberId,
    required this.name,
    this.photo,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.isCurrentUserAdmin,
    required this.conversationId,
    this.onRemove,
    this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Avatar
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: photo ?? '',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '(Vous)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons (admin-only, not for current user)
          if (isCurrentUserAdmin && !isCurrentUser)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'remove') {
                  onRemove?.call();
                } else if (value == 'promote' && !isAdmin) {
                  onPromote?.call();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Retirer'),
                ),
                if (!isAdmin)
                  const PopupMenuItem<String>(
                    value: 'promote',
                    child: Text('Promouvoir en admin'),
                  ),
              ],
              icon: const Icon(Icons.more_vert_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
