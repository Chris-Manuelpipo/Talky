// lib/features/chat/presentation/widgets/message_image_bubble.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_colors_provider.dart';
import '../../domain/message_model.dart';
import 'package:intl/intl.dart';

class MessageImageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;

  const MessageImageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openFullscreen(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            child: Stack(
              children: [
                // Nom de l'expéditeur pour les messages de groupe
                if (!isMine && isGroup && message.senderName.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Image
                CachedNetworkImage(
                  imageUrl: message.mediaUrl ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: colors.surface,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: colors.primary)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: colors.surface,
                    child: Icon(Icons.broken_image_rounded,
                        color: colors.textHint, size: 48),
                  ),
                ),

                // Heure en overlay
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      DateFormat('HH:mm').format(message.sentAt),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullscreenImage(url: message.mediaUrl ?? ''),
        ));
  }
}

// ── Visionneuse plein écran ────────────────────────────────────────────
class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {}, // à implémenter
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                CircularProgressIndicator(color: colors.primary),
          ),
        ),
      ),
    );
  }
}
