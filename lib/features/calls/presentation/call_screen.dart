// lib/features/calls/presentation/call_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/ringback_service.dart';
import '../../auth/data/auth_providers.dart';
import '../data/call_providers.dart';
import '../../chat/data/chat_providers.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Timer? _durationTimer;
  int _durationSeconds = 0;
  bool _showControls = true;
  Timer? _hideTimer;
  StreamSubscription<MediaStream?>? _localStreamSub;
  StreamSubscription<MediaStream?>? _remoteStreamSub;
  bool _swapViews = false;
  bool _ringbackStarted = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _listenStreamUpdates();
    _scheduleHideControls();
    _checkInitialCallStatus();
  }

  void _checkInitialCallStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(callProvider).status;
      if (status == CallStatus.calling && !_ringbackStarted) {
        _ringbackStarted = true;
        RingbackService.instance.play();
      }
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final service = ref.read(callServiceProvider);
    if (service.localStream != null) {
      _localRenderer.srcObject = service.localStream;
    }
    if (service.remoteStream != null) {
      _remoteRenderer.srcObject = service.remoteStream;
    }

    // Attendre que les streams soient disponibles
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted)
        setState(() {
          _localRenderer.srcObject = service.localStream;
          _remoteRenderer.srcObject = service.remoteStream;
        });
    });
  }

  void _listenStreamUpdates() {
    final service = ref.read(callServiceProvider);
    _localStreamSub = service.localStreamUpdates.listen((stream) {
      if (mounted) {
        setState(() => _localRenderer.srcObject = stream);
      }
    });
    _remoteStreamSub = service.remoteStreamUpdates.listen((stream) {
      if (mounted) {
        setState(() => _remoteRenderer.srcObject = stream);
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _stopDurationTimer({bool reset = false}) {
    _durationTimer?.cancel();
    _durationTimer = null;
    if (reset && mounted) {
      setState(() => _durationSeconds = 0);
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _toggleSwap() {
    setState(() => _swapViews = !_swapViews);
  }

  String get _formattedDuration {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _durationTimer?.cancel();
    _hideTimer?.cancel();
    _localStreamSub?.cancel();
    _remoteStreamSub?.cancel();
    RingbackService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final isVideo = callState.isVideo;
    final mainIsLocal = _swapViews;
    final pipIsLocal = !_swapViews;
    final mainRenderer = _swapViews ? _localRenderer : _remoteRenderer;
    final pipRenderer = _swapViews ? _remoteRenderer : _localRenderer;
    final fallbackName = callState.remoteName ?? 'Appel';
    final contactsService = ref.read(phoneContactsServiceProvider);
    final user = (!callState.isGroup &&
            callState.remoteUserId != null &&
            callState.remoteUserId!.isNotEmpty)
        ? ref
            .watch(userProfileStreamProvider(callState.remoteUserId!))
            .asData
            ?.value
        : null;
    final resolvedName = user?.name.trim();
    final baseName = (resolvedName != null && resolvedName.isNotEmpty)
        ? resolvedName
        : fallbackName;
    final displayName = contactsService.resolveNameFromCache(
      fallbackName: baseName,
      phone: user?.phone,
    );

    // Quand l'appel se termine → fermer l'écran
    ref.listen(callProvider, (prev, next) {
      if (next.status == CallStatus.calling && mounted && !_ringbackStarted) {
        _stopDurationTimer(reset: true);
        _ringbackStarted = true;
        RingbackService.instance.play();
      }
      if (next.status == CallStatus.connected && mounted) {
        _startDurationTimer();
        RingbackService.instance.stop();
      }
      if (next.status == CallStatus.idle && mounted) {
        _stopDurationTimer(reset: true);
        RingbackService.instance.stop();
        Navigator.pop(context);
      }
    });

    if (callState.isGroup) {
      return _buildGroupCallScreen(context, callState);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          children: [
            // ── Vidéo remote (plein écran) ────────────────────────
            if (isVideo)
              Positioned.fill(
                child: mainRenderer.srcObject == null
                    ? _VideoWaiting(callState: callState)
                    : RTCVideoView(
                        mainRenderer,
                        mirror: mainIsLocal,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              )
            else
              _AudioCallBackground(
                callState: callState,
                displayName: displayName,
              ),

            // ── Soft top overlay for readability ────────────────────
            if (isVideo)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Vidéo locale (petit coin) ──────────────────────────
            if (isVideo)
              Positioned(
                right: 16,
                top: 72,
                child: GestureDetector(
                  onTap: _toggleSwap,
                  child: Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: pipIsLocal
                          ? (callState.isCameraOff
                              ? Container(
                                  color: Colors.black,
                                  child: Icon(Icons.videocam_off_rounded,
                                      color: Colors.white, size: 32),
                                )
                              : RTCVideoView(pipRenderer, mirror: true))
                          : (pipRenderer.srcObject == null
                              ? Container(
                                  color: Colors.black,
                                  child: Icon(Icons.person_rounded,
                                      color: Colors.white54, size: 28),
                                )
                              : RTCVideoView(pipRenderer, mirror: false)),
                    ),
                  ),
                ),
              ),

            // ── Header (nom + durée) ───────────────────────────────
            SafeArea(
              child: AnimatedOpacity(
                opacity: _showControls || !isVideo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  callState.status == CallStatus.calling
                                      ? 'Connexion...'
                                      : _formattedDuration,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Contrôles en bas ───────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls || !isVideo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Micro
                            _CallButton(
                              icon: callState.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: callState.isMuted ? 'Micro off' : 'Micro',
                              color: callState.isMuted
                                  ? Colors.red.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.18),
                              onPressed: () =>
                                  ref.read(callProvider.notifier).toggleMute(),
                            ),

                            // Terminer
                            _CallButton(
                              icon: Icons.call_end_rounded,
                              label: 'Terminer',
                              color: Colors.red,
                              size: 64,
                              onPressed: () =>
                                  ref.read(callProvider.notifier).endCall(),
                            ),

                            // Caméra (si vidéo) ou haut-parleur (si audio)
                            if (isVideo)
                              _CallButton(
                                icon: callState.isCameraOff
                                    ? Icons.videocam_off_rounded
                                    : Icons.videocam_rounded,
                                label: 'Caméra',
                                color: callState.isCameraOff
                                    ? Colors.red.withOpacity(0.85)
                                    : Colors.white.withOpacity(0.18),
                                onPressed: () => ref
                                    .read(callProvider.notifier)
                                    .toggleCamera(),
                              )
                            else
                              _CallButton(
                                icon: Icons.volume_up_rounded,
                                label: 'HP',
                                color: Colors.white.withOpacity(0.18),
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bouton retourner caméra ────────────────────────────
            if (isVideo && _showControls)
              Positioned(
                top: 72,
                left: 16,
                child: SafeArea(
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.flip_camera_ios_rounded,
                              color: Colors.white, size: 22),
                          onPressed: () =>
                              ref.read(callProvider.notifier).switchCamera(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCallScreen(BuildContext context, CallState callState) {
    final service = ref.read(callServiceProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<Map<String, MediaStream>>(
        stream: service.groupRemoteStreamsUpdates,
        initialData: service.groupRemoteStreams,
        builder: (context, snap) {
          final streams = snap.data ?? {};
          return Stack(
            children: [
              if (callState.isVideo)
                _GroupVideoGrid(
                  streams: streams,
                  localRenderer: _localRenderer,
                )
              else
                _GroupAudioList(
                  participants: callState.groupParticipants,
                  title: callState.remoteName ?? 'Appel de groupe',
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                callState.remoteName ?? 'Appel de groupe',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                callState.status == CallStatus.calling
                                    ? 'Connexion...'
                                    : _formattedDuration,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallButton(
                              icon: callState.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: callState.isMuted ? 'Micro off' : 'Micro',
                              color: callState.isMuted
                                  ? Colors.red.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.18),
                              onPressed: () =>
                                  ref.read(callProvider.notifier).toggleMute(),
                            ),
                            _CallButton(
                              icon: Icons.call_end_rounded,
                              label: 'Terminer',
                              color: Colors.red,
                              size: 64,
                              onPressed: () =>
                                  ref.read(callProvider.notifier).endCall(),
                            ),
                            if (callState.isVideo)
                              _CallButton(
                                icon: callState.isCameraOff
                                    ? Icons.videocam_off_rounded
                                    : Icons.videocam_rounded,
                                label: 'Caméra',
                                color: callState.isCameraOff
                                    ? Colors.red.withOpacity(0.85)
                                    : Colors.white.withOpacity(0.18),
                                onPressed: () => ref
                                    .read(callProvider.notifier)
                                    .toggleCamera(),
                              )
                            else
                              _CallButton(
                                icon: Icons.volume_up_rounded,
                                label: 'HP',
                                color: Colors.white.withOpacity(0.18),
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupVideoGrid extends StatefulWidget {
  final Map<String, MediaStream> streams;
  final RTCVideoRenderer localRenderer;

  const _GroupVideoGrid({
    required this.streams,
    required this.localRenderer,
  });

  @override
  State<_GroupVideoGrid> createState() => _GroupVideoGridState();
}

class _GroupVideoGridState extends State<_GroupVideoGrid> {
  final Map<String, RTCVideoRenderer> _renderers = {};

  @override
  void initState() {
    super.initState();
    _syncRenderers();
  }

  @override
  void didUpdateWidget(covariant _GroupVideoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRenderers();
  }

  void _syncRenderers() {
    final newIds = widget.streams.keys.toSet();
    final oldIds = _renderers.keys.toSet();

    for (final id in oldIds.difference(newIds)) {
      _renderers[id]?.dispose();
      _renderers.remove(id);
    }

    for (final id in newIds) {
      if (!_renderers.containsKey(id)) {
        final r = RTCVideoRenderer();
        r.initialize().then((_) {
          r.srcObject = widget.streams[id];
          if (mounted) setState(() {});
        });
        _renderers[id] = r;
      } else {
        _renderers[id]!.srcObject = widget.streams[id];
      }
    }
  }

  @override
  void dispose() {
    for (final r in _renderers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    // Local preview
    tiles.add(_VideoTile(renderer: widget.localRenderer, isLocal: true));

    // Remote videos
    for (final entry in _renderers.entries) {
      tiles.add(_VideoTile(renderer: entry.value));
    }

    final count = tiles.length;
    final crossAxisCount = count <= 2 ? 1 : (count <= 4 ? 2 : 3);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      children: tiles,
    );
  }
}

class _VideoTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool isLocal;

  const _VideoTile({
    required this.renderer,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: RTCVideoView(
          renderer,
          mirror: isLocal,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}

class _GroupAudioList extends StatelessWidget {
  final List<GroupParticipant> participants;
  final String title;

  const _GroupAudioList({
    required this.participants,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...participants.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary,
                      backgroundImage:
                          p.photo != null ? NetworkImage(p.photo!) : null,
                      child: p.photo == null
                          ? Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Fond appel audio ───────────────────────────────────────────────────
class _AudioCallBackground extends StatelessWidget {
  final CallState callState;
  final String displayName;
  const _AudioCallBackground({
    required this.callState,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A3B), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10),
                ],
              ),
              child: callState.remotePhoto != null
                  ? ClipOval(
                      child: Image.network(callState.remotePhoto!,
                          fit: BoxFit.cover))
                  : Center(
                      child: Text(
                      (displayName.isNotEmpty ? displayName : '?')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w700),
                    )),
            ),
            const SizedBox(height: 24),
            Text(displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Appel audio',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder vidéo en attente ──────────────────────────────────────
class _VideoWaiting extends StatelessWidget {
  final CallState callState;
  const _VideoWaiting({required this.callState});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF101018), Color(0xFF0B0F14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_rounded, color: Colors.white54, size: 64),
            const SizedBox(height: 12),
            Text(
              callState.status == CallStatus.calling
                  ? 'Connexion vidéo...'
                  : 'En attente de la caméra…',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton d'action appel ──────────────────────────────────────────────
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
