// lib/features/calls/presentation/call_screen.dart

import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startDurationTimer();
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

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = true);
    _scheduleHideControls();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final isVideo   = callState.isVideo;

    // Quand l'appel se termine → fermer l'écran
    ref.listen(callProvider, (prev, next) {
      if (next.status == CallStatus.idle && mounted) {
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
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              _AudioCallBackground(callState: callState),

            // ── Vidéo locale (petit coin) ──────────────────────────
            if (isVideo)
              Positioned(
                right: 16, top: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100, height: 140,
                    child: callState.isCameraOff
                        ? Container(color: Colors.black,
                            child: const Icon(Icons.videocam_off_rounded,
                                color: Colors.white, size: 32))
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(callState.remoteName ?? 'Appel',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        callState.status == CallStatus.calling
                            ? 'Appel en cours...'
                            : _formattedDuration,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16)),
                    ],
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
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
                            ? Colors.red.withOpacity(0.8)
                            : Colors.white.withOpacity(0.2),
                        onPressed: () => ref.read(callProvider.notifier).toggleMute(),
                      ),

                      // Terminer
                      _CallButton(
                        icon:      Icons.call_end_rounded,
                        label:     'Terminer',
                        color:     Colors.red,
                        size:      64,
                        onPressed: () => ref.read(callProvider.notifier).endCall(),
                      ),

                      // Caméra (si vidéo) ou haut-parleur (si audio)
                      if (isVideo)
                        _CallButton(
                          icon:      callState.isCameraOff
                              ? Icons.videocam_off_rounded
                              : Icons.videocam_rounded,
                          label:     'Caméra',
                          color:     callState.isCameraOff
                              ? Colors.red.withOpacity(0.8)
                              : Colors.white.withOpacity(0.2),
                          onPressed: () => ref.read(callProvider.notifier).toggleCamera(),
                        )
                      else
                        _CallButton(
                          icon:      Icons.volume_up_rounded,
                          label:     'HP',
                          color:     Colors.white.withOpacity(0.2),
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bouton retourner caméra ────────────────────────────
            if (isVideo)
              Positioned(
                top: 60, left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => ref.read(callProvider.notifier).switchCamera(),
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