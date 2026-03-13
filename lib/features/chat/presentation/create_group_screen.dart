// lib/features/chat/presentation/create_group_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
import '../data/chat_service.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl   = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  final List<Map<String, dynamic>> _selected = [];
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isSelected(String id) => _selected.any((m) => m['id'] == id);

  void _toggle(Map<String, dynamic> user) {
    setState(() {
      if (_isSelected(user['id'])) {
        _selected.removeWhere((m) => m['id'] == user['id']);
      } else {
        if (_selected.length >= 99) return; // limite groupe
        _selected.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un nom au groupe')));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un membre')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).value!;
      final myName = await ref.read(currentUserNameProvider.future);
      final convId = await ref.read(chatServiceProvider).createGroup(
        creatorId:    user.uid,
        creatorName:  myName,
        creatorPhoto: user.photoURL,
        groupName:    _nameCtrl.text.trim(),
        members:      _selected,
      );

      if (mounted) {
        context.go(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {'name': _nameCtrl.text.trim(), 'photo': null},
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Nouveau groupe',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _loading ? null : _createGroup,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer',
                      style: TextStyle(color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Nom du groupe
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:   'Nom du groupe',
                hintStyle:  const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.group_rounded,
                    color: AppColors.primary),
                filled:     true,
                fillColor:  AppColors.surface,
                border:     OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          // Membres sélectionnés (chips)
          if (_selected.isNotEmpty)
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selected.length,
                itemBuilder: (_, i) {
                  final m = _selected[i];
                  return _MemberChip(
                    member:    m,
                    onRemove:  () => setState(() => _selected.removeAt(i)),
                  ).animate(delay: (i * 30).ms).fadeIn().scale();
                },
              ),
            ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged:  (v) => setState(() => _query = v.toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:   'Rechercher des membres...',
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Contacts',
                style: TextStyle(color: AppColors.textHint,
                    fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),

          // Liste utilisateurs
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref.read(chatServiceProvider)
                  .usersStream(currentUser?.uid ?? ''),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(
                    child: CircularProgressIndicator());

                final all = snap.data!;
                final filtered = _query.isEmpty ? all
                    : all.where((u) =>
                        (u['name'] as String? ?? '')
                            .toLowerCase().contains(_query)).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final user     = filtered[i];
                    final selected = _isSelected(user['id']);
                    return ListTile(
                      onTap: () => _toggle(user),
                      leading: Stack(
                        children: [
                          _UserAvatar(user: user),
                          if (selected)
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                width: 18, height: 18,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Text(user['name'] ?? 'Utilisateur',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w700 : FontWeight.w500,
                          )),
                      subtitle: Text(user['phone'] ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary)
                          : const Icon(Icons.circle_outlined,
                              color: AppColors.textHint),
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
}

// ── Chip membre sélectionné ────────────────────────────────────────────
class _MemberChip extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onRemove;

  const _MemberChip({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name  = member['name'] as String? ?? '?';
    final photo = member['photoUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photo == null
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent])
                      : null,
                  image: photo != null
                      ? DecorationImage(
                          image: NetworkImage(photo), fit: BoxFit.cover)
                      : null,
                ),
                child: photo == null ? Center(
                  child: Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))) : null,
              ),
              Positioned(
                right: -2, top: -2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.red),
                    child: const Icon(Icons.close_rounded,
                        size: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 44,
            child: Text(name.split(' ')[0],
              style: const TextStyle(fontSize: 10,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Avatar utilisateur ─────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final name  = user['name'] as String? ?? '?';
    final photo = user['photoUrl'] as String?;
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photo == null
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.accent])
            : null,
        image: photo != null ? DecorationImage(
            image: NetworkImage(photo), fit: BoxFit.cover) : null,
      ),
      child: photo == null ? Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700))) : null,
    );
  }
}
