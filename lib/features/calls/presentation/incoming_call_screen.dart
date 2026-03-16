// lib/features/calls/presentation/incoming_call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/constants/app_icons.dart';
import '../data/call_providers.dart';
import 'call_screen.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseCtrl;
  Timer? _autoRejectTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Auto-rejeter après 60s
    _autoRejectTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) ref.read(callProvider.notifier).rejectCall();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _autoRejectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Si l'appel disparaît → fermer
    ref.listen(callProvider, (_, next) {
      if (next.status == CallStatus.idle && mounted) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          // Fond animé
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0 + _pulseCtrl.value * 0.2,
                    colors: [
                      AppColors.primary.withOpacity(0.15 + _pulseCtrl.value * 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Texte appel entrant
                Text(
                  callState.isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
                  style: TextStyle(
                      color: context.appThemeColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Avatar animé
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 130 + _pulseCtrl.value * 10,
                    height: 130 + _pulseCtrl.value * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(
                              0.3 + _pulseCtrl.value * 0.2),
                          blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    child: callState.remotePhoto != null
                        ? ClipOval(child: Image.network(
                            callState.remotePhoto!, fit: BoxFit.cover))
                        : Center(
                            child: Text(
                              (callState.remoteName ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white, fontSize: 52,
                                fontWeight: FontWeight.w700),
                            )),
                  ),
                ),

                const SizedBox(height: 24),

                // Nom
                Text(callState.remoteName ?? 'Appel entrant',
                  style: TextStyle(
                    color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w700)),

                const SizedBox(height: 8),
                Text(callState.isVideo ? 'Vidéo' : 'Audio',
                  style: TextStyle(
                      color: context.appThemeColors.textSecondary, fontSize: 16)),

                const Spacer(),

                // Boutons répondre / rejeter
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Rejeter
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref.read(callProvider.notifier).rejectCall();
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 72, height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              child: Icon(Icons.call_end_rounded,
                                  color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Refuser',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        ],
                      ),

                      // Accepter
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final micStatus = await Permission.microphone.request();
                              if (!micStatus.isGranted) {
                                if (micStatus.isPermanentlyDenied) {
                                  await openAppSettings();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Permission microphone refusée'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              if (callState.isVideo) {
                                final camStatus = await Permission.camera.request();
                                if (!camStatus.isGranted) {
                                  if (camStatus.isPermanentlyDenied) {
                                    await openAppSettings();
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Permission caméra refusée'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }

                              await ref.read(callProvider.notifier).answerCall();
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CallScreen()),
                                );
                              }
                            },
                            child: Container(
                              width: 72, height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00C851),
                              ),
                              child: Icon(
                                callState.isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Répondre',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
