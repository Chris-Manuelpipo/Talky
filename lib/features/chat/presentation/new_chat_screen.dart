// lib/features/chat/presentation/new_chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
import '../data/chat_service.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
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
        title: const Text('Nouvelle discussion',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Bouton créer un groupe
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => context.push(AppRoutes.createGroup),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 22,
                      child: Icon(Icons.group_add_rounded,
                          color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 14),
                    Text('Créer un groupe',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                  ],
                ),
              ),
            ),
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged:  (v) => setState(() => _query = v.toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:   'Rechercher un contact...',
                hintStyle:  const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint),
                filled:     true,
                fillColor:  AppColors.surface,
                border:     OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('CONTACTS',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                )),
            ),
          ),

          // Liste utilisateurs
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref.read(chatServiceProvider)
                  .usersStream(currentUser?.uid ?? ''),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final all      = snap.data ?? [];
                final filtered = _query.isEmpty ? all
                    : all.where((u) =>
                        (u['name'] as String? ?? '')
                            .toLowerCase().contains(_query)).toList();

                if (filtered.isEmpty)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_query.isEmpty
                            ? 'Aucun utilisateur trouvé'
                            : 'Aucun résultat pour "$_query"',
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                      ],
                    ),
                  );

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final user = filtered[i];
                    return _UserTile(
                      user:    user,
                      onTap:   () => _startChat(context, user, currentUser),
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


  Future<String?> _getMyPhotoFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      return doc.data()?['photoUrl'] as String?;
    } catch (_) { return null; }
  }
  Future<void> _startChat(
    BuildContext context,
    Map<String, dynamic> otherUser,
    dynamic currentUser,
  ) async {
    if (currentUser == null) return;
    try {
      // Lire nom + photo depuis Firestore (pas Firebase Auth qui peut être null)
      final myName  = await ref.read(currentUserNameProvider.future);
      final myPhoto = await _getMyPhotoFromFirestore(currentUser.uid);

      final convId = await ref.read(chatServiceProvider)
          .getOrCreateConversation(
        currentUserId:    currentUser.uid,
        currentUserName:  myName,
        currentUserPhoto: myPhoto,
        otherUserId:      otherUser['id'] as String,
        otherUserName:    otherUser['name'] as String? ?? 'Utilisateur',
        otherUserPhoto:   otherUser['photoUrl'] as String?,
      );
      if (context.mounted) {
        context.push(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {
            'name':  otherUser['name'] ?? 'Utilisateur',
            'photo': otherUser['photoUrl'],
          },
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')));
    }
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name  = user['name'] as String? ?? 'Utilisateur';
    final phone = user['phone'] as String? ?? '';
    final photo = user['photoUrl'] as String?;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photo == null
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent]) : null,
          image: photo != null ? DecorationImage(
              image: NetworkImage(photo), fit: BoxFit.cover) : null,
        ),
        child: photo == null ? Center(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700))) : null,
      ),
      title: Text(name, style: const TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(phone, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint),
    );
  }
}
