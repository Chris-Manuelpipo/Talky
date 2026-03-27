// lib/features/calls/presentation/incoming_call_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../data/call_providers.dart';
import '../data/call_service.dart';
import 'call_screen.dart';
import '../../chat/data/chat_providers.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String? callerId;
  final String? callerName;
  final bool? isVideo;
  final bool? isGroup;
  final String? roomId;
  final Map<String, dynamic>? offer;

  const IncomingCallScreen({
    super.key,
    this.callerId,
    this.callerName,
    this.isVideo,
    this.isGroup,
    this.roomId,
    this.offer,
  });

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
      if (!mounted) return;
      final isGroupCall =
          ref.read(callProvider).incomingCall?.isGroup ?? widget.isGroup ?? false;
      if (isGroupCall) {
        ref.read(callProvider.notifier).rejectGroupCall();
      } else {
        ref.read(callProvider.notifier).rejectCall();
      }
    });
    
    // Si des paramètres d'appel sont passés (via notification), mettre à jour le callProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.callerId != null) {
        // Créer des données d'appel entrantes avec l'offre SDP
        final incomingData = IncomingCallData(
          callerId: widget.callerId!,
          callerName: widget.callerName ?? 'Appel entrant',
          callerPhoto: null,
          isVideo: widget.isVideo ?? false,
          offer: widget.offer ?? const <String, dynamic>{},
          isGroup: widget.isGroup ?? false,
          roomId: widget.roomId,
        );
        // Mettre à jour le callProvider avec les données d'appel
        ref.read(callProvider.notifier).setIncomingCallData(incomingData);
      }
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
    final callerId = callState.incomingCall?.callerId ?? widget.callerId;
    final fallbackName =
        callState.remoteName ?? widget.callerName ?? 'Appel entrant';
    final nameFuture = _resolveCallerName(callerId, fallbackName);
    final isGroupCall =
        callState.incomingCall?.isGroup ?? widget.isGroup ?? false;

    // Si l'appel disparaît → fermer
    ref.listen(callProvider, (_, next) {
      if (next.status == CallStatus.idle && mounted) {
        Navigator.pop(context);
      }
    });

    return FutureBuilder<String>(
      future: nameFuture,
      builder: (context, nameSnap) {
        final displayName = nameSnap.data ?? fallbackName;
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
                  isGroupCall
                      ? (callState.isVideo
                          ? 'Appel vidéo de groupe'
                          : 'Appel audio de groupe')
                      : (callState.isVideo
                          ? 'Appel vidéo entrant'
                          : 'Appel audio entrant'),
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
                              (displayName.isNotEmpty ? displayName : '?')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.white, fontSize: 52,
                                fontWeight: FontWeight.w700),
                            )),
                  ),
                ),

                const SizedBox(height: 24),

                // Nom
                Text(displayName,
                  style: TextStyle(
                    color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w700)),

                const SizedBox(height: 8),
                Text(isGroupCall ? 'Groupe' : (callState.isVideo ? 'Vidéo' : 'Audio'),
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
                              if (isGroupCall) {
                                ref.read(callProvider.notifier).rejectGroupCall();
                              } else {
                                ref.read(callProvider.notifier).rejectCall();
                              }
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

                              if (isGroupCall) {
                                await ref.read(callProvider.notifier).answerGroupCall();
                              } else {
                                await ref.read(callProvider.notifier).answerCall();
                              }
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
      },
    );
  }

  Future<String> _resolveCallerName(String? userId, String fallbackName) async {
    if (userId == null || userId.isEmpty) return fallbackName;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data();
      final resolvedName = (data?['name'] as String?)?.trim();
      final baseName = (resolvedName != null && resolvedName.isNotEmpty)
          ? resolvedName
          : fallbackName;
      final phone = data?['phone'] as String?;
      return ref.read(phoneContactsServiceProvider).resolveName(
        fallbackName: baseName,
        phone: phone,
      );
    } catch (_) {
      return fallbackName;
    }
  }
}
