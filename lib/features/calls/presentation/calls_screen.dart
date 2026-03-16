// lib/features/calls/presentation/calls_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart'; 
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

    // Écouter les erreurs d'appel
    ref.listen(callProvider, (prev, next) {
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
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text('Appels',
          style: TextStyle(
            color:      context.appThemeColors.textPrimary,
            fontSize:   22,
            fontWeight: FontWeight.w700,
          )),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded,
                color: context.appThemeColors.textSecondary),
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
          return Center(child: CircularProgressIndicator(
              color: AppColors.primary));
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return Center(
            child: Text('Aucun contact disponible',
              style: TextStyle(color: context.appThemeColors.textSecondary)),
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
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              title: Text(name,
                style: TextStyle(
                    color: context.appThemeColors.textPrimary,
                    fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.call_rounded,
                        color: AppColors.primary),
                    onPressed: () => onCallAudio(uid, name, photo),
                  ),
                  IconButton(
                    icon: Icon(Icons.videocam_rounded,
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
