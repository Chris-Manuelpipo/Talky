// lib/features/calls/presentation/calls_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_service.dart';
import '../data/call_providers.dart';
import 'call_screen.dart';

class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // S'assurer que le service est connecté
    ref.watch(callServiceProvider);

    // Écouter les appels entrants
    ref.listen(callProvider, (prev, next) {
      if (next.status == CallStatus.ringing && prev?.status != CallStatus.ringing) {
        _showIncomingCall(context, ref);
      }
      if (next.status == CallStatus.idle &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Appels',
          style: TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   22,
            fontWeight: FontWeight.w700,
          )),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: _ContactsForCall(
        onCallAudio: (userId, name, photo) => _startCall(
            context, ref, userId, name, photo, false),
        onCallVideo: (userId, name, photo) => _startCall(
            context, ref, userId, name, photo, true),
      ),
    );
  }

  void _showIncomingCall(BuildContext context, WidgetRef ref) {
    // Afficher l'écran d'appel entrant par-dessus tout
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: _IncomingCallOverlay(),
        ),
        opaque: false,
        barrierColor: Colors.transparent,
      ),
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
    String? photo,
    bool isVideo,
  ) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (micStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission microphone refusée'),
            backgroundColor: Colors.red));
      return;
    }

    if (isVideo) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (camStatus.isPermanentlyDenied) {
          await openAppSettings();
        }
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission caméra refusée'),
              backgroundColor: Colors.red));
        return;
      }
    }

    final service = ref.read(callServiceProvider);
    if (!service.isConnected) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion au serveur en cours... Réessaie dans 5s'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      await ref.read(callProvider.notifier).startCall(
        targetUserId: userId,
        targetName:   name,
        targetPhoto:  photo,
        isVideo:      isVideo,
      );

      if (context.mounted) {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CallScreen()));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur appel: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// ── Overlay appel entrant ──────────────────────────────────────────────
class _IncomingCallOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    ref.listen(callProvider, (_, next) {
      if (next.status == CallStatus.idle && context.mounted) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A3B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 40, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent]),
                ),
                child: callState.remotePhoto != null
                    ? ClipOval(child: Image.network(
                        callState.remotePhoto!, fit: BoxFit.cover))
                    : Center(child: Text(
                        (callState.remoteName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 36,
                            fontWeight: FontWeight.w700))),
              ),
              const SizedBox(height: 20),
              Text(callState.remoteName ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                callState.isVideo
                    ? '📹 Appel vidéo entrant'
                    : '🎙️ Appel audio entrant',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Refuser
                  _OverlayButton(
                    icon:  Icons.call_end_rounded,
                    label: 'Refuser',
                    color: Colors.red,
                    onTap: () {
                      ref.read(callProvider.notifier).rejectCall();
                      Navigator.pop(context);
                    },
                  ),
                  // Accepter
                  _OverlayButton(
                    icon: callState.isVideo
                        ? Icons.videocam_rounded : Icons.call_rounded,
                    label: 'Répondre',
                    color: const Color(0xFF00C851),
                    onTap: () async {
                      final micStatus = await Permission.microphone.request();
                      if (!micStatus.isGranted) {
                        if (micStatus.isPermanentlyDenied) {
                          await openAppSettings();
                        }
                        if (context.mounted) {
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
                          if (context.mounted) {
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
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const CallScreen()));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

// ── Liste des contacts pour appeler ───────────────────────────────────
class _ContactsForCall extends ConsumerWidget {
  final void Function(String, String, String?) onCallAudio;
  final void Function(String, String, String?) onCallVideo;

  const _ContactsForCall({
    required this.onCallAudio,
    required this.onCallVideo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService().usersStream(currentUser.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: AppColors.primary));
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return const Center(
            child: Text('Aucun contact disponible',
              style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final user = users[i];
            final name  = user['name'] as String? ?? 'Utilisateur';
            final photo = user['photoUrl'] as String?;
            final uid   = user['id'] as String;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              title: Text(name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call_rounded,
                        color: AppColors.primary),
                    onPressed: () => onCallAudio(uid, name, photo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_rounded,
                        color: AppColors.accent),
                    onPressed: () => onCallVideo(uid, name, photo),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
