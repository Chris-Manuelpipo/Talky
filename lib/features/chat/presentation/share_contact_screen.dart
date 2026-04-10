// lib/features/chat/presentation/share_contact_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';

class ShareContactScreen extends ConsumerStatefulWidget {
  final String contactUserId;
  final String contactName;
  final String? contactPhoto;

  const ShareContactScreen({
    super.key,
    required this.contactUserId,
    required this.contactName,
    this.contactPhoto,
  });

  @override
  ConsumerState<ShareContactScreen> createState() => _ShareContactScreenState();
}

class _ShareContactScreenState extends ConsumerState<ShareContactScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Partager le contact',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref
                  .read(chatServiceProvider)
                  .usersStream(currentUser?.uid ?? ''),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? [];
                final filtered = _query.isEmpty
                    ? all
                    : all
                        .where((u) => (u['name'] as String? ?? '')
                            .toLowerCase()
                            .contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Aucun utilisateur trouvé',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final user = filtered[i];
                    return _UserTile(
                      user: user,
                      onTap: () => _shareToUser(user, currentUser),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToUser(
    Map<String, dynamic> otherUser,
    dynamic currentUser,
  ) async {
    if (currentUser == null) return;

    try {
      final myName = await ref.read(currentUserNameProvider.future);
      final myPhoto = await _getMyPhotoFromFirestore(currentUser.uid);

      final convId =
          await ref.read(chatServiceProvider).getOrCreateConversation(
                currentUserId: currentUser.uid,
                currentUserName: myName,
                currentUserPhoto: myPhoto,
                otherUserId: otherUser['id'] as String,
                otherUserName: otherUser['name'] as String? ?? 'Utilisateur',
                otherUserPhoto: otherUser['photoUrl'] as String?,
              );

      final contactProfile = await ref
          .read(authServiceProvider)
          .getUserProfile(widget.contactUserId);
      final contactPhone = contactProfile?.phone ?? '';

      final content = contactPhone.isNotEmpty
          ? 'Contact: ${widget.contactName}\nTéléphone: $contactPhone'
          : 'Contact: ${widget.contactName}';

      await ref.read(chatServiceProvider).sendMessage(
            conversationId: convId,
            senderId: currentUser.uid,
            senderName: myName,
            content: content,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Contact partagé à ${otherUser['name'] ?? 'Utilisateur'}'),
          backgroundColor: context.primaryColor,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur partage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _getMyPhotoFromFirestore(String uid) async {
    final profile = await ref.read(authServiceProvider).getUserProfile(uid);
    return profile?.photoUrl;
  }
}

class _UserTile extends ConsumerWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user['name'] as String? ?? 'Utilisateur';
    final phone = user['phone'] as String? ?? '';
    final photo = user['photoUrl'] as String?;
    final colors = context.appThemeColors;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photo == null
              ? LinearGradient(
                  colors: [context.primaryColor, context.accentColor])
              : null,
          image: photo != null
              ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
              : null,
        ),
        child: photo == null
            ? Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)))
            : null,
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: colors.textPrimary)),
      subtitle: Text(phone,
          style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textHint),
    );
  }
}
