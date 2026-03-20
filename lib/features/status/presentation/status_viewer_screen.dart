// lib/features/status/presentation/status_viewer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_service.dart';
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
  final _replyCtrl = TextEditingController();
  final _chatService = ChatService();

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

  Future<void> _toggleLike(StatusModel status) async {
    final service = ref.read(statusServiceProvider);
    if (status.isLikedBy(widget.currentUserId)) {
      await service.unlikeStatus(status.id, widget.currentUserId);
    } else {
      await service.likeStatus(status.id, widget.currentUserId);
    }
  }

  Future<void> _sendReply(StatusModel status) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    // Get current user info
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    // Get or create conversation with the status author
    final conversationId = await _chatService.getOrCreateConversation(
      currentUserId: widget.currentUserId,
      currentUserName: currentUser.displayName ?? 'Utilisateur',
      currentUserPhoto: currentUser.photoURL,
      otherUserId: status.userId,
      otherUserName: status.userName,
      otherUserPhoto: status.userPhoto,
    );

    // Create the reply content based on status type
    String replyContent;
    switch (status.type) {
      case StatusType.text:
        replyContent = status.text ?? 'Statut texte';
        break;
      case StatusType.image:
        replyContent = 'Photo';
        break;
      case StatusType.video:
        replyContent = 'Vidéo';
        break;
    }

    // Send the reply as a message with replyToContent
    await _chatService.sendMessage(
      conversationId: conversationId,
      senderId: widget.currentUserId,
      senderName: currentUser.displayName ?? 'Utilisateur',
      content: text,
      replyToContent: replyContent,
      isStatusReply: true,
    );

    // Clear the input
    _replyCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réponse envoyée à ${status.userName}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showViewers(BuildContext context, StatusModel status) async {
    final viewers = status.viewedBy;
    if (viewers.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: context.appThemeColors.surface,
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
                  color: context.appThemeColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vu par ${viewers.length}',
                style: TextStyle(
                  color: context.appThemeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: viewers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final uid = viewers[i];
                    final isLiked = status.likedBy.contains(uid);
                    return _ViewerTile(
                      userId: uid,
                      viewedAt: status.viewedAt[uid],
                      hasLiked: isLiked,
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
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.group.statuses[_currentIndex];
    final isMyStatus = widget.group.isMyStatus;
    final isLiked = status.isLikedBy(widget.currentUserId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Contenu du statut ────────────────────────────────────
          // Ignore touches on the reply bar area to prevent status navigation
          GestureDetector(
            onTapDown: (d) {
              // Only stop progress if not tapping on reply bar area
              final bottomPadding = MediaQuery.of(context).padding.bottom + 80;
              final screenHeight = MediaQuery.of(context).size.height;
              if (d.globalPosition.dy > screenHeight - bottomPadding) {
                return; // Don't handle tap in reply bar area
              }
              _progressCtrl.stop();
            },
            onTapUp: (d) {
              // Only navigate if not tapping on reply bar area
              final bottomPadding = MediaQuery.of(context).padding.bottom + 80;
              final screenHeight = MediaQuery.of(context).size.height;
              if (d.globalPosition.dy > screenHeight - bottomPadding) {
                return; // Don't navigate when tapping reply bar
              }
              
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
                              style: TextStyle(
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
                            style: TextStyle(
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
                    // Like button (only for others' statuses)
                    if (!isMyStatus)
                      GestureDetector(
                        onTap: () => _toggleLike(status),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? AppColors.primary : Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (isMyStatus)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
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
              bottom: 100, left: 0, right: 0,
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
                        Icon(Icons.visibility_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('${status.viewCount} vue${status.viewCount > 1 ? 's' : ''}',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                        if (status.likeCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.favorite,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 2),
                          Text('${status.likeCount}',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Floating reply bar (for others' statuses) ─────────────
          if (!isMyStatus)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ReplyBar(
                controller: _replyCtrl,
                onSend: () => _sendReply(status),
                onMicPressed: () {
                  // TODO: Implement voice message reply
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité vocale à venir'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reply Bar Widget ───────────────────────────────────────────────────
class _ReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicPressed;

  const _ReplyBar({
    required this.controller,
    required this.onSend,
    required this.onMicPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Répondre...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.mic,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    onPressed: onMicPressed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: onSend,
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
                style: TextStyle(
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
                    style: TextStyle(
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
  final bool hasLiked;
  const _ViewerTile({required this.userId, this.viewedAt, this.hasLiked = false});

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
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(name[0].toUpperCase(),
                        style: TextStyle(color: Colors.white))
                    : null,
              ),
              // Subtle heart indicator for those who liked
              if (hasLiked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.appThemeColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.primary,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(name,
            style: TextStyle(color: context.appThemeColors.textPrimary)),
          subtitle: viewedAt != null
              ? Text(
                  _formatViewedAt(viewedAt!),
                  style: TextStyle(color: context.appThemeColors.textSecondary, fontSize: 12),
                )
              : null,
          trailing: hasLiked
              ? Icon(Icons.favorite, color: AppColors.primary, size: 18)
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
