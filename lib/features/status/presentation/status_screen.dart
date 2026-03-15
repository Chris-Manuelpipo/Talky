// lib/features/status/presentation/status_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../data/status_providers.dart';
import '../domain/status_model.dart';
import 'add_status_screen.dart';
import 'status_viewer_screen.dart';
import 'widgets/status_ring.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
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
    final groupsAsync   = ref.watch(statusGroupsProvider);
    final currentUserId = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                ),
              )
            : const Text('Statuts',
                style: TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   22,
                  fontWeight: FontWeight.w700,
                )),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.textSecondary),
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
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),

      body: groupsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: const TextStyle(color: AppColors.textSecondary))),
        data: (groups) {
          final myGroup = groups.where((g) => g.isMyStatus).firstOrNull;
          final others  = groups.where((g) => !g.isMyStatus).toList();

          final filtered = _query.trim().isEmpty
              ? others
              : others.where((g) =>
                  g.userName.toLowerCase().contains(_query)).toList();

          final unread  = filtered.where((g) => g.hasUnviewed(currentUserId)).toList();
          final read    = filtered.where((g) => !g.hasUnviewed(currentUserId)).toList();

          return CustomScrollView(
            slivers: [
              // ── Mon statut ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Mon statut',
                        style: TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        )),
                    ),
                    _MyStatusTile(
                      myGroup:        myGroup,
                      currentUserId:  currentUserId,
                    ),
                    if (unread.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text('Récents',
                          style: TextStyle(
                            color:      AppColors.textSecondary,
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          )),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Statuts des contacts ───────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _StatusTile(
                    group:         unread[i],
                    currentUserId: currentUserId,
                  ),
                  childCount: unread.length,
                ),
              ),

              if (read.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Déjà vus',
                      style: TextStyle(
                        color:      AppColors.textSecondary,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
                  ),
                ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _StatusTile(
                    group:         read[i],
                    currentUserId: currentUserId,
                  ),
                  childCount: read.length,
                ),
              ),

              if (others.isEmpty && myGroup == null)
                const SliverFillRemaining(
                  child: _EmptyState()),
            ],
          );
        },
      ),

      // ── FAB publier ────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AddStatusScreen())),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Mon statut tile ────────────────────────────────────────────────────
class _MyStatusTile extends ConsumerWidget {
  final UserStatusGroup? myGroup;
  final String currentUserId;

  const _MyStatusTile({this.myGroup, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myName = ref.watch(currentUserNameProvider).value ?? 'Moi';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          StatusRing(
            hasStatus:   myGroup != null,
            allViewed:   false,
            isMyStatus:  true,
            child: _Avatar(name: myName, photoUrl: null),
          ),
          if (myGroup == null)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
      title: const Text('Mon statut',
        style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(
        myGroup == null
            ? 'Appuyer pour ajouter un statut'
            : '${myGroup!.statuses.length} statut${myGroup!.statuses.length > 1 ? 's' : ''} · ${_timeAgo(myGroup!.latest.createdAt)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      onTap: () {
        if (myGroup != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => StatusViewerScreen(
              group:         myGroup!,
              currentUserId: currentUserId,
            )));
        } else {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddStatusScreen()));
        }
      },
    );
  }
}

// ── Tile statut d'un contact ───────────────────────────────────────────
class _StatusTile extends StatelessWidget {
  final UserStatusGroup group;
  final String currentUserId;

  const _StatusTile({required this.group, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final allViewed = !group.hasUnviewed(currentUserId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: StatusRing(
        hasStatus:  true,
        allViewed:  allViewed,
        isMyStatus: false,
        child: _Avatar(
            name: group.userName, photoUrl: group.userPhoto),
      ),
      title: Text(group.userName,
        style: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(
        _timeAgo(group.latest.createdAt),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          group:         group,
          currentUserId: currentUserId,
        ))),
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl == null ? const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ) : null,
        image: photoUrl != null ? DecorationImage(
            image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
      ),
      child: photoUrl == null ? Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      ) : null,
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.circle_outlined,
                color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Aucun statut pour le moment',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Publiez votre premier statut !',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
  return 'Il y a ${diff.inDays}j';
}
