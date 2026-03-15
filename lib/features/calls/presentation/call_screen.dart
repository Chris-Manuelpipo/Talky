// lib/features/calls/presentation/call_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/constants/app_colors.dart';
import '../data/call_providers.dart';
import '../data/call_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Timer? _durationTimer;
  int _durationSeconds  = 0;
  bool _showControls    = true;
  Timer? _hideTimer;
  StreamSubscription<MediaStream?>? _localStreamSub;
  StreamSubscription<MediaStream?>? _remoteStreamSub;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _listenStreamUpdates();
    _scheduleHideControls();
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
      if (mounted) setState(() {
        _localRenderer.srcObject  = service.localStream;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final isVideo   = callState.isVideo;

    // Quand l'appel se termine → fermer l'écran
    ref.listen(callProvider, (prev, next) {
      if (next.status == CallStatus.calling && mounted) {
        _stopDurationTimer(reset: true);
      }
      if (next.status == CallStatus.connected && mounted) {
        _startDurationTimer();
      }
      if (next.status == CallStatus.idle && mounted) {
        _stopDurationTimer(reset: true);
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          children: [
            // ── Vidéo remote (plein écran) ────────────────────────
            if (isVideo)
              Positioned.fill(
                child: _remoteRenderer.srcObject == null
                    ? _VideoWaiting(callState: callState)
                    : RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              )
            else
              _AudioCallBackground(callState: callState),

            // ── Soft top overlay for readability ────────────────────
            if (isVideo)
              Positioned(
                top: 0, left: 0, right: 0, height: 180,
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
            if (isVideo && _showControls)
              Positioned(
                right: 16, top: 72,
                child: Container(
                  width: 110, height: 150,
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
                    child: callState.isCameraOff
                        ? Container(
                            color: Colors.black,
                            child: const Icon(Icons.videocam_off_rounded,
                                color: Colors.white, size: 32),
                          )
                        : RTCVideoView(_localRenderer, mirror: true),
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
                              Text(callState.remoteName ?? 'Appel',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 20,
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
              bottom: 0, left: 0, right: 0,
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
                              icon:      callState.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label:     callState.isMuted ? 'Micro off' : 'Micro',
                              color:     callState.isMuted
                                  ? Colors.red.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.18),
                              onPressed: () =>
                                  ref.read(callProvider.notifier).toggleMute(),
                            ),

                            // Terminer
                            _CallButton(
                              icon:      Icons.call_end_rounded,
                              label:     'Terminer',
                              color:     Colors.red,
                              size:      64,
                              onPressed: () =>
                                  ref.read(callProvider.notifier).endCall(),
                            ),

                            // Caméra (si vidéo) ou haut-parleur (si audio)
                            if (isVideo)
                              _CallButton(
                                icon:      callState.isCameraOff
                                    ? Icons.videocam_off_rounded
                                    : Icons.videocam_rounded,
                                label:     'Caméra',
                                color:     callState.isCameraOff
                                    ? Colors.red.withOpacity(0.85)
                                    : Colors.white.withOpacity(0.18),
                                onPressed: () =>
                                    ref.read(callProvider.notifier).toggleCamera(),
                              )
                            else
                              _CallButton(
                                icon:      Icons.volume_up_rounded,
                                label:     'HP',
                                color:     Colors.white.withOpacity(0.18),
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
                top: 72, left: 16,
                child: SafeArea(
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded,
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
}

// ── Fond appel audio ───────────────────────────────────────────────────
class _AudioCallBackground extends StatelessWidget {
  final CallState callState;
  const _AudioCallBackground({required this.callState});

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
              width: 120, height: 120,
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
                    blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: callState.remotePhoto != null
                  ? ClipOval(child: Image.network(
                      callState.remotePhoto!, fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        (callState.remoteName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 48,
                          fontWeight: FontWeight.w700),
                      )),
            ),
            const SizedBox(height: 24),
            Text(callState.remoteName ?? '',
              style: const TextStyle(
                color: Colors.white, fontSize: 32,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Appel audio',
              style: TextStyle(
                  color: Colors.white54, fontSize: 16)),
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
            const Icon(Icons.videocam_rounded,
                color: Colors.white54, size: 64),
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
            width: size, height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white,
                size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
