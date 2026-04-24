// lib/features/meetings/presentation/meeting_room_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/backend_user_providers.dart';
import '../data/meeting_providers.dart';
import '../data/meeting_service.dart';
import '../domain/meeting_model.dart';

class MeetingRoomScreen extends ConsumerStatefulWidget {
  final MeetingModel meeting;
  const MeetingRoomScreen({super.key, required this.meeting});

  @override
  ConsumerState<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends ConsumerState<MeetingRoomScreen> {
  // Renderers WebRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  StreamSubscription<MediaStream?>? _localSub;
  StreamSubscription<Map<String, MediaStream>>? _remoteSub;
  StreamSubscription<MeetingEvent>? _eventSub;

  bool _showChat = false;
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();

  // Timer durée
  late Timer _timer;
  int _elapsed = 0;
  String? _initError;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      _listenStreams();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e, st) {
      debugPrintStack(stackTrace: st);
      debugPrint('[MeetingRoom] Erreur initialisation renderer: $e');
      if (mounted) {
        setState(() {
          _initError = 'Erreur: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  void _listenStreams() {
    try {
      final service = ref.read(meetingServiceProvider);

      _localSub = service.localStream.listen((stream) async {
        if (stream != null) {
          _localRenderer.srcObject = stream;
          if (mounted) setState(() {});
        }
      });

      _remoteSub = service.remoteStreams.listen((streams) async {
        // Créer les renderers manquants
        for (final uid in streams.keys) {
          if (!_remoteRenderers.containsKey(uid)) {
            final r = RTCVideoRenderer();
            await r.initialize();
            _remoteRenderers[uid] = r;
          }
          _remoteRenderers[uid]!.srcObject = streams[uid];
        }
        // Supprimer les renderers pour les pairs partis
        final toRemove = _remoteRenderers.keys
            .where((k) => !streams.containsKey(k))
            .toList();
        for (final uid in toRemove) {
          _remoteRenderers[uid]?.dispose();
          _remoteRenderers.remove(uid);
        }
        if (mounted) setState(() {});
      });

      _eventSub = service.events.listen((event) {
        if (event == MeetingEvent.ended && mounted) {
          if (mounted) Navigator.of(context).pop();
        }
      });

      // Alimenter le renderer local immédiatement si stream déjà dispo
      final current = service.currentLocalStream;
      if (current != null) _localRenderer.srcObject = current;

      // Alimenter les remotes déjà présents
      service.currentRemoteStreams.forEach((uid, stream) async {
        if (!_remoteRenderers.containsKey(uid)) {
          final r = RTCVideoRenderer();
          await r.initialize();
          _remoteRenderers[uid] = r;
          r.srcObject = stream;
        }
      });
    } catch (e, st) {
      debugPrintStack(stackTrace: st);
      debugPrint('[MeetingRoom] Erreur dans _listenStreams: $e');
      if (mounted) {
        setState(() {
          _initError = 'Erreur socket: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _localSub?.cancel();
    _remoteSub?.cancel();
    _eventSub?.cancel();
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) r.dispose();
    _remoteRenderers.clear();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  String get _elapsedStr {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final roomState = ref.watch(meetingRoomProvider);
    final alanyaID = ref.watch(currentAlanyaIDProvider);
    final isOrganiser = alanyaID == widget.meeting.idOrganiser;
    final isVideo = widget.meeting.isVideo;

    // Afficher l'erreur d'initialisation si elle existe
    if (_initError != null && !_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: const Text('Erreur'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Impossible d\'initialiser la réunion',
                style: TextStyle(color: colors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _initError!,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                ),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Grille vidéo ────────────────────────────────────────
            _buildVideoGrid(isVideo),

            // ── Top bar ─────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.meeting.objet,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _elapsedStr,
                            style: TextStyle(
                                color: Colors.white.withOpacity(.7),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Bouton démarrer (organisateur seulement)
                    if (isOrganiser && !roomState.isStarted)
                      TextButton(
                        onPressed: () => ref
                            .read(meetingRoomProvider.notifier)
                            .startMeeting(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(.8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Démarrer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    if (!roomState.isStarted && !isOrganiser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('En attente',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),

            // ── Chat panel ───────────────────────────────────────────
            if (_showChat)
              Positioned(
                right: 0,
                top: 0,
                bottom: 80,
                width: MediaQuery.of(context).size.width * .75,
                child: _ChatPanel(
                  messages: roomState.chatMessages,
                  scrollCtrl: _chatScroll,
                  chatCtrl: _chatCtrl,
                  onSend: () {
                    if (_chatCtrl.text.trim().isNotEmpty) {
                      ref
                          .read(meetingRoomProvider.notifier)
                          .sendChat(_chatCtrl.text.trim());
                      _chatCtrl.clear();
                    }
                  },
                ),
              ),

            // ── Barre de contrôles ────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Micro
                    _ControlBtn(
                      icon: roomState.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      active: !roomState.isMuted,
                      label: roomState.isMuted ? 'Muet' : 'Micro',
                      onTap: () =>
                          ref.read(meetingRoomProvider.notifier).toggleMute(),
                    ),
                    // Caméra
                    if (isVideo)
                      _ControlBtn(
                        icon: roomState.isCameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        active: !roomState.isCameraOff,
                        label: 'Caméra',
                        onTap: () => ref
                            .read(meetingRoomProvider.notifier)
                            .toggleCamera(),
                      ),
                    // Chat
                    _ControlBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      active: _showChat,
                      label: 'Chat',
                      onTap: () => setState(() => _showChat = !_showChat),
                    ),
                    // Quitter / Terminer
                    _ControlBtn(
                      icon: isOrganiser
                          ? Icons.call_end_rounded
                          : Icons.logout_rounded,
                      active: true,
                      activeColor: Colors.red,
                      label: isOrganiser ? 'Terminer' : 'Quitter',
                      onTap: () async {
                        if (isOrganiser) {
                          await ref
                              .read(meetingRoomProvider.notifier)
                              .endMeeting(widget.meeting.idMeeting);
                        } else {
                          ref.read(meetingRoomProvider.notifier).leaveMeeting();
                        }
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid(bool isVideo) {
    final renderers = <_VideoTile>[];

    // Local
    renderers.add(_VideoTile(
      renderer: _localRenderer,
      label: 'Moi',
      isLocal: true,
      isVideo: isVideo,
    ));

    // Distants
    for (final entry in _remoteRenderers.entries) {
      renderers.add(_VideoTile(
        renderer: entry.value,
        label: 'Participant',
        isLocal: false,
        isVideo: isVideo,
      ));
    }

    if (renderers.length == 1) {
      return SizedBox.expand(child: renderers.first);
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: renderers.length <= 2 ? 1 : 2,
        childAspectRatio: renderers.length <= 2 ? 16 / 9 : 1,
      ),
      itemCount: renderers.length,
      itemBuilder: (_, i) => renderers[i],
    );
  }
}

// ── Tuile vidéo ──────────────────────────────────────────────────────

class _VideoTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String label;
  final bool isLocal;
  final bool isVideo;

  const _VideoTile({
    required this.renderer,
    required this.label,
    required this.isLocal,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF1A1A2E)),
        if (isVideo)
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: isLocal,
          )
        else
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey[800],
              child: const Icon(Icons.person, size: 36, color: Colors.white54),
            ),
          ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

// ── Bouton de contrôle ───────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final String label;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (activeColor ?? Colors.white.withOpacity(.2))
        : Colors.grey.withOpacity(.4);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: bg,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Chat panel ───────────────────────────────────────────────────────

class _ChatPanel extends StatelessWidget {
  final List<MeetingChatMessage> messages;
  final ScrollController scrollCtrl;
  final TextEditingController chatCtrl;
  final VoidCallback onSend;

  const _ChatPanel({
    required this.messages,
    required this.scrollCtrl,
    required this.chatCtrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Chat',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ${msg.userID}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                      Text(msg.message,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: onSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
