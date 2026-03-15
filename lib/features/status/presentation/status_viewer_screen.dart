// lib/features/status/presentation/status_viewer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../data/status_providers.dart';
import '../domain/status_model.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  final UserStatusGroup group;
  final String currentUserId;

  const StatusViewerScreen({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen>
    with SingleTickerProviderStateMixin {

  int _currentIndex = 0;
  late AnimationController _progressCtrl;
  Timer? _autoTimer;

  static const _duration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      })
      ..forward();

    _markViewed();
  }

  void _markViewed() {
    final status = widget.group.statuses[_currentIndex];
    if (!status.isViewedBy(widget.currentUserId)) {
      ref.read(statusServiceProvider)
          .markAsViewed(status.id, widget.currentUserId);
    }
  }


  void _next() {
    if (_currentIndex < widget.group.statuses.length - 1) {
      setState(() => _currentIndex++);
      _progressCtrl.forward(from: 0);
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressCtrl.forward(from: 0);
    }
  }

  Future<void> _showViewers(BuildContext context, StatusModel status) async {
    final viewers = status.viewedBy;
    if (viewers.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text('Vu par ${viewers.length}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: viewers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final uid = viewers[i];
                    return _ViewerTile(
                      userId: uid,
                      viewedAt: status.viewedAt[uid],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status    = widget.group.statuses[_currentIndex];
    final isMyStatus = widget.group.isMyStatus;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Contenu du statut ────────────────────────────────────
          GestureDetector(
            onTapDown: (d) => _progressCtrl.stop(),
            onTapUp: (d) {
              final x = d.globalPosition.dx;
              final w = MediaQuery.of(context).size.width;
              if (x < w / 3) _prev();
              else if (x > w * 2 / 3) _next();
              else _progressCtrl.forward();
            },
            child: _StatusContent(status: status),
          ),

          // ── Barres de progression ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: List.generate(
                  widget.group.statuses.length,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: i < _currentIndex
                          ? _ProgressBar(progress: 1.0)
                          : i == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressCtrl,
                                  builder: (_, __) => _ProgressBar(
                                      progress: _progressCtrl.value),
                                )
                              : _ProgressBar(progress: 0.0),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Header (avatar + nom + heure) ────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      backgroundImage: widget.group.userPhoto != null
                          ? NetworkImage(widget.group.userPhoto!) : null,
                      child: widget.group.userPhoto == null
                          ? Text(widget.group.userName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.group.isMyStatus
                              ? 'Mon statut' : widget.group.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                          Text(_timeAgo(status.createdAt),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (isMyStatus)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white),
                        onPressed: () async {
                          await ref.read(statusServiceProvider)
                              .deleteStatus(status.id);
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Compteur de vues (mon statut) ─────────────────────────
          if (isMyStatus)
            Positioned(
              bottom: 32, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _showViewers(context, status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('${status.viewCount} vue${status.viewCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Contenu selon le type de statut ───────────────────────────────────
class _StatusContent extends StatelessWidget {
  final StatusModel status;
  const _StatusContent({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status.type) {
      case StatusType.text:
        final color = status.backgroundColor != null
            ? Color(int.parse(status.backgroundColor!.replaceFirst('#', '0xFF')))
            : AppColors.primary;
        return Container(
          width:  double.infinity,
          height: double.infinity,
          color:  color,
          child:  Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(status.text ?? '',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   28,
                  fontWeight: FontWeight.w700,
                  height:     1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case StatusType.image:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (status.mediaUrl != null)
              Image.network(status.mediaUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, prog) => prog == null
                      ? child
                      : const Center(child: CircularProgressIndicator(
                          color: Colors.white))),
            if (status.text != null && status.text!.isNotEmpty)
              Positioned(
                bottom: 80, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.text!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center),
                ),
              ),
          ],
        );

      case StatusType.video:
        return const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white, size: 80));
    }
  }
}

class _ViewerTile extends ConsumerWidget {
  final String userId;
  final DateTime? viewedAt;
  const _ViewerTile({required this.userId, this.viewedAt});

  String _formatViewedAt(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(dt)}';
    }
    if (date == yesterday) {
      return 'Hier à ${DateFormat('HH:mm').format(dt)}';
    }
    return 'Vu le ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] as String?) ?? 'Utilisateur';
        final photo = data?['photoUrl'] as String?;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          title: Text(name,
            style: const TextStyle(color: AppColors.textPrimary)),
          subtitle: viewedAt != null
              ? Text(
                  _formatViewedAt(viewedAt!),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                )
              : null,
        );
      },
    );
  }
}

// ── Barre de progression ───────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value:           progress,
        backgroundColor: Colors.white.withOpacity(0.3),
        valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight:       2.5,
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
  return 'Il y a ${diff.inDays}j';
}
