// lib/features/chat/presentation/chat_details_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import 'share_contact_screen.dart';

class ChatDetailsScreen extends ConsumerWidget {
  final String conversationId;
  final String contactName;
  final String? contactPhoto;
  final String? contactUserId;
  final bool isGroup;
  final ConversationModel? conversation;

  const ChatDetailsScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.contactPhoto,
    this.contactUserId,
    required this.isGroup,
    this.conversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider(conversationId));
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';
    final contactsService = ref.read(phoneContactsServiceProvider);
    final user = (!isGroup && contactUserId != null && contactUserId!.isNotEmpty)
        ? ref.watch(userProfileStreamProvider(contactUserId!)).asData?.value
        : null;
    final resolvedName = user?.name.trim();
    final baseName = (resolvedName != null && resolvedName.isNotEmpty)
        ? resolvedName
        : contactName;
    final displayName = isGroup
        ? contactName
        : contactsService.resolveNameFromCache(
            fallbackName: baseName,
            phone: user?.phone,
          );
    final displayPhoto = isGroup ? contactPhoto : (user?.photoUrl ?? contactPhoto);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text('Détails',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(
            name: displayName,
            photoUrl: displayPhoto,
            isGroup: isGroup,
            presenceUserId: isGroup ? null : contactUserId,
          ),
          const SizedBox(height: 14),
          if (isGroup && conversation != null)
            _GroupMembersCard(
              conversation: conversation!,
              currentUserId: currentUid,
            )
          else
            _ContactInfoCard(userId: contactUserId),
          const SizedBox(height: 14),
          _MediaSection(messages: messages),
          const SizedBox(height: 16),
          if (!isGroup && contactUserId != null && contactUserId!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.share_rounded),
                label: Text('Partager le contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareContactScreen(
                        contactUserId: contactUserId!,
                        contactName: displayName,
                        contactPhoto: displayPhoto,
                      ),
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

class _HeaderCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isGroup;
  final String? presenceUserId;

  const _HeaderCard({
    required this.name,
    required this.photoUrl,
    required this.isGroup,
    required this.presenceUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Avatar(name: name, photoUrl: photoUrl, isGroup: isGroup),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (isGroup)
                  Text('Groupe',
                      style: TextStyle(
                          fontSize: 12, color: context.appThemeColors.textSecondary))
                else if (presenceUserId != null && presenceUserId!.isNotEmpty)
                  _PresenceLine(userId: presenceUserId!)
                else
                  Text('Hors ligne',
                      style: TextStyle(
                          fontSize: 12, color: context.appThemeColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoCard extends ConsumerWidget {
  final String? userId;
  const _ContactInfoCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null || userId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appThemeColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('Informations indisponibles',
            style: TextStyle(color: context.appThemeColors.textSecondary)),
      );
    }

    final user = ref.watch(userProfileStreamProvider(userId!)).asData?.value;
    final phone = user?.phone ?? '';
    final about = user?.status ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Infos',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          if (phone.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Téléphone',
              value: phone,
            ),
          if (about.isNotEmpty)
            _InfoRow(
              icon: Icons.info_outline_rounded,
              label: 'À propos',
              value: about,
            ),
          if (phone.isEmpty && about.isEmpty)
            Text('Aucune information',
                style: TextStyle(color: context.appThemeColors.textSecondary)),
        ],
      ),
    );
  }
}

class _GroupMembersCard extends ConsumerWidget {
  final ConversationModel conversation;
  final String currentUserId;
  const _GroupMembersCard({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = conversation.participantIds
        .where((id) => id != currentUserId)
        .toList();
    final contactsService = ref.read(phoneContactsServiceProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Membres (${members.length})',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Text('Aucun membre',
                style: TextStyle(color: context.appThemeColors.textSecondary))
          else
            ...members.map((id) {
              final baseName = conversation.participantNames[id] ?? 'Utilisateur';
              final user = ref.watch(userProfileStreamProvider(id)).asData?.value;
              final resolvedName = user?.name.trim();
              final name = (resolvedName != null && resolvedName.isNotEmpty)
                  ? resolvedName
                  : baseName;
              final displayName = contactsService.resolveNameFromCache(
                fallbackName: name,
                phone: user?.phone,
              );
              final photo = user?.photoUrl ?? conversation.participantPhotos[id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _Avatar(name: displayName, photoUrl: photo, isGroup: false),
                    const SizedBox(width: 10),
                    Text(displayName,
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final AsyncValue<List<MessageModel>> messages;
  const _MediaSection({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Médias partagés',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          messages.when(
            loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Text('Erreur: $e'),
            data: (list) {
              final media = list.where((m) {
                final isMedia = m.type == MessageType.image ||
                    m.type == MessageType.video;
                return !m.isDeleted && isMedia && (m.mediaUrl ?? '').isNotEmpty;
              }).toList();

              if (media.isEmpty) {
                return Text('Aucun média pour l’instant',
                    style: TextStyle(color: context.appThemeColors.textSecondary));
              }

              final items = media.reversed.take(12).toList();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, i) => _MediaTile(message: items[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MessageModel message;
  const _MediaTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == MessageType.video;
    final url = message.mediaUrl ?? '';

    return GestureDetector(
      onTap: () {
        if (url.isEmpty) return;
        if (isVideo) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FullscreenVideo(url: url),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FullscreenImage(url: url),
          ));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              Container(
                color: Colors.black,
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white70, size: 30),
              )
            else
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: context.appThemeColors.background,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: context.appThemeColors.background,
                  child: Icon(Icons.broken_image_rounded,
                      color: context.appThemeColors.textHint),
                ),
              ),
            if (isVideo)
              Container(
                color: Colors.black.withOpacity(0.15),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appThemeColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: context.appThemeColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isGroup;

  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl == null
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.accent])
            : null,
        image: photoUrl != null
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: photoUrl == null
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : (isGroup ? 'G' : '?'),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22),
              ),
            )
          : null,
    );
  }
}

class _PresenceLine extends ConsumerWidget {
  final String userId;
  const _PresenceLine({required this.userId});

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);

    if (date == today) {
      return 'Aujourd\'hui à ${_two(lastSeen.hour)}:${_two(lastSeen.minute)}';
    }
    if (date == yesterday) {
      return 'Hier à ${_two(lastSeen.hour)}:${_two(lastSeen.minute)}';
    }
    return 'Vu le ${_two(lastSeen.day)}/${_two(lastSeen.month)}/${lastSeen.year} '
        '${_two(lastSeen.hour)}:${_two(lastSeen.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileStreamProvider(userId)).asData?.value;
    final isOnline = user?.isOnline == true;
    final lastSeen = user?.lastSeen;

    if (isOnline) {
      return Text('En ligne',
          style: TextStyle(fontSize: 12, color: AppColors.accent));
    }
    if (lastSeen != null) {
      return Text(_formatLastSeen(lastSeen),
          style: TextStyle(
              fontSize: 12, color: context.appThemeColors.textSecondary));
    }
    return Text('Hors ligne',
        style: TextStyle(fontSize: 12, color: context.appThemeColors.textSecondary));
  }
}

class FullscreenImage extends StatelessWidget {
  final String url;
  const FullscreenImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class FullscreenVideo extends StatefulWidget {
  final String url;
  const FullscreenVideo({super.key, required this.url});

  @override
  State<FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<FullscreenVideo> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctrl.initialize();
      ctrl.setLooping(false);
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _hasError
            ? Icon(Icons.broken_image_rounded,
                color: context.appThemeColors.textHint, size: 48)
            : _controller == null
                ? CircularProgressIndicator(color: AppColors.primary)
                : AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller!),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: AppColors.primary,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                            setState(() {});
                          },
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white, size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
