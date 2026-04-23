// lib/features/chat/presentation/widgets/video_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors_provider.dart';
import '../../domain/message_model.dart';
import 'package:intl/intl.dart';

class VideoMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;

  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isGroup,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
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
    final colors = context.appThemeColors;
    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: _openFullscreen,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(widget.isMine ? 18 : 4),
              bottomRight: Radius.circular(widget.isMine ? 4 : 18),
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
              bottomLeft: Radius.circular(widget.isMine ? 18 : 4),
              bottomRight: Radius.circular(widget.isMine ? 4 : 18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Nom de l'expéditeur pour les messages de groupe
                if (!widget.isMine &&
                    widget.isGroup &&
                    widget.message.senderName.isNotEmpty)
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
                        widget.message.senderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_hasError)
                  Container(
                    height: 200,
                    color: colors.surface,
                    child: Icon(Icons.broken_image_rounded,
                        color: colors.textHint, size: 48),
                  )
                else if (_controller == null)
                  Container(
                    height: 200,
                    color: colors.surface,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: colors.primary)),
                  )
                else
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),

                // Overlay play icon
                if (_controller != null)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),

                // Heure
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
                      DateFormat('HH:mm').format(widget.message.sentAt),
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

  void _openFullscreen() {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullscreenVideo(url: url),
        ));
  }
}

class _FullscreenVideo extends StatefulWidget {
  final String url;
  const _FullscreenVideo({required this.url});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
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
    final colors = context.appThemeColors;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _hasError
            ? Icon(Icons.broken_image_rounded, color: colors.textHint, size: 48)
            : _controller == null
                ? CircularProgressIndicator(color: colors.primary)
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
                              playedColor: colors.primary,
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
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
