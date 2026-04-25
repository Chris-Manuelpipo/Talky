// lib/features/chat/presentation/widgets/media_picker_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors_provider.dart';
import '../../data/chat_service.dart';
import '../../data/media_service.dart';
import '../../domain/conversation_model.dart';

class MediaPickerSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final String senderId;
  final String senderName;

  const MediaPickerSheet({
    super.key,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
  });

  @override
  ConsumerState<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends ConsumerState<MediaPickerSheet> {
  final _mediaService = MediaService();
  bool _uploading = false;
  double _progress = 0;
  String _statusText = '';

  Future<void> _sendImage({bool fromCamera = false}) async {
    final file = await _mediaService.pickImage(fromCamera: fromCamera);
    if (file == null || !mounted) return;
    await _upload(file, MessageType.image);
  }

  Future<void> _sendVideo() async {
    final file = await _mediaService.pickVideo();
    if (file == null || !mounted) return;
    await _upload(file, MessageType.video);
  }

  Future<void> _sendFile() async {
    final file = await _mediaService.pickFile();
    if (file == null || !mounted) return;
    await _upload(file, MessageType.file);
  }

  Future<void> _upload(File file, MessageType type) async {
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _statusText = 'Préparation...';
    });

    try {
      setState(() => _statusText = 'Upload en cours...');

      String url;
      if (type == MessageType.image) {
        url = await _mediaService.uploadImage(
          file: file,
          conversationId: widget.conversationId,
          onProgress: (p) {
            if (mounted)
              setState(() {
                _progress = p;
                _statusText = 'Upload ${(p * 100).toInt()}%';
              });
          },
        );
      } else if (type == MessageType.video) {
        url = await _mediaService.uploadVideo(
          file: file,
          conversationId: widget.conversationId,
          onProgress: (p) {
            if (mounted)
              setState(() {
                _progress = p;
                _statusText = 'Upload ${(p * 100).toInt()}%';
              });
          },
        );
      } else {
        url = await _mediaService.uploadFile(
          file: file,
          conversationId: widget.conversationId,
          onProgress: (p) {
            if (mounted)
              setState(() {
                _progress = p;
                _statusText = 'Upload ${(p * 100).toInt()}%';
              });
          },
        );
      }

      if (!mounted) return;
      setState(() => _statusText = 'Envoi du message...');

      await ChatService().sendMediaMessage(
        conversationId: widget.conversationId,
        senderId: widget.senderId,
        senderName: widget.senderName,
        mediaUrl: url,
        type: type,
        mediaName: file.path.split('/').last,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _statusText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final primaryColor = colors.primary;

    return PopScope(
      canPop: !_uploading,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: _uploading
              ? _buildProgress(primaryColor, colors)
              : _buildOptions(colors),
        ),
      ),
    );
  }

  Widget _buildProgress(Color primaryColor, AppThemeColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.cloud_upload_rounded, color: primaryColor, size: 56),
        const SizedBox(height: 16),
        Text(_statusText,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            backgroundColor: colors.divider,
            valueColor: AlwaysStoppedAnimation(primaryColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _progress > 0
              ? '${(_progress * 100).toInt()}%'
              : 'Connexion à Cloudinary...',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOptions(AppThemeColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(height: 20),
        Text('Envoyer un média',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            )),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MediaOption(
              icon: Icons.camera_alt_rounded,
              label: 'Caméra',
              color: const Color(0xFF4FC3F7),
              onTap: () => _sendImage(fromCamera: true),
            ),
            _MediaOption(
              icon: Icons.photo_library_rounded,
              label: 'Galerie',
              color: colors.primary,
              onTap: () => _sendImage(),
            ),
            _MediaOption(
              icon: Icons.videocam_rounded,
              label: 'Vidéo',
              color: const Color(0xFFFF6B6B),
              onTap: _sendVideo,
            ),
            _MediaOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'Fichier',
              color: const Color(0xFF51CF66),
              onTap: _sendFile,
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                color: context.appThemeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
