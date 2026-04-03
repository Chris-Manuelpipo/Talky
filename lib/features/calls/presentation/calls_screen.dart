// lib/features/calls/presentation/calls_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../../core/services/ringback_service.dart';
import '../../chat/data/chat_providers.dart';
import '../data/call_providers.dart';
import '../domain/call_history_model.dart';
import 'call_screen.dart';
import 'new_call_screen.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();

  /// Static method to start a call from the new call screen
  static Future<void> startCallFromContact(
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
        targetName: name,
        targetPhoto: photo,
        isVideo: isVideo,
      );

      RingbackService.instance.play();

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

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: TextStyle(color: context.appThemeColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: context.appThemeColors.textHint),
                  border: InputBorder.none,
                ),
              )
            : Text('Appels',
                style: TextStyle(
                  color: context.appThemeColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                )),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
                color: context.appThemeColors.textSecondary),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
      ),
      body: _CallsContent(query: _query),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewCallScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }

}

// ── Contenu de l'écran d'appels ───────────────────────────────────────
class _CallsContent extends ConsumerWidget {
  final String query;

  const _CallsContent({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    if (currentUser == null) return const SizedBox();

    final callHistoryAsync = ref.watch(callHistoryProvider(currentUser.uid));
    final weeklyDurationAsync = ref.watch(weeklyCallDurationProvider(currentUser.uid));

    // Prefetch profils pour l'historique d'appels
    ref.listen(callHistoryProvider(currentUser.uid), (_, next) {
      next.whenData((calls) {
        final ids = <String>{};
        for (final call in calls) {
          if (call.isGroup) {
            ids.addAll(call.participantIds);
          } else {
            ids.add(call.callerId);
            ids.add(call.receiverId);
          }
        }
        ids.remove(currentUser.uid);
        if (ids.isNotEmpty) {
          ref.read(authServiceProvider).prefetchUserProfiles(ids.toList());
        }
      });
    });

    return Column(
      children: [
        // Carte des statistiques hebdomadaires
        _WeeklyStatsCard(
          weeklyDurationAsync: weeklyDurationAsync,
        ),

        // Liste des appels
        Expanded(
          child: callHistoryAsync.when(
            data: (calls) => _CallsList(
              calls: calls,
              currentUserId: currentUser.uid,
              query: query,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erreur: $e',
                  style: TextStyle(color: context.appThemeColors.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte des statistiques hebdomadaires ───────────────────────────────
class _WeeklyStatsCard extends StatelessWidget {
  final AsyncValue<int> weeklyDurationAsync;

  const _WeeklyStatsCard({required this.weeklyDurationAsync});

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0 min';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temps d\'appel cette semaine',
                  style: TextStyle(
                    color: context.appThemeColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                weeklyDurationAsync.when(
                  data: (seconds) => Text(
                    _formatDuration(seconds),
                    style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => Text(
                    '...',
                    style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  error: (_, __) => Text(
                    '0 min',
                    style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Détails - à implémenter
            },
            child: const Text(
              'Détails',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste des appels ─────────────────────────────────────────────────
class _CallsList extends StatelessWidget {
  final List<CallHistoryModel> calls;
  final String currentUserId;
  final String query;

  const _CallsList({
    required this.calls,
    required this.currentUserId,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filteredCalls = normalizedQuery.isEmpty
        ? calls
        : calls.where((call) => _matchesQuery(call, normalizedQuery)).toList();

    if (filteredCalls.isEmpty) {
      if (calls.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_outlined,
                size: 64,
                color: context.appThemeColors.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun appel',
                style: TextStyle(
                  color: context.appThemeColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos appels apparaîtront ici',
                style: TextStyle(
                  color: context.appThemeColors.textHint,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: context.appThemeColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: TextStyle(
                color: context.appThemeColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun appel ne correspond à votre recherche',
              style: TextStyle(
                color: context.appThemeColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Grouper les appels par date
    final groupedCalls = _groupCallsByDate(filteredCalls);

    return ListView.builder(
      itemCount: groupedCalls.length,
      itemBuilder: (context, index) {
        final item = groupedCalls[index];
        if (item is DateTime) {
          // En-tête de date
          return _DateHeader(date: item);
        } else {
          // Élément d'appel
          final call = item as CallHistoryModel;
          return _CallTile(call: call, currentUserId: currentUserId);
        }
      },
    );
  }

  List<dynamic> _groupCallsByDate(List<CallHistoryModel> calls) {
    final List<dynamic> result = [];
    DateTime? currentDate;

    for (final call in calls) {
      final callDate = DateTime(
        call.timestamp.year,
        call.timestamp.month,
        call.timestamp.day,
      );

      if (currentDate == null || callDate != currentDate) {
        currentDate = callDate;
        result.add(callDate);
      }
      result.add(call);
    }

    return result;
  }

  bool _matchesQuery(CallHistoryModel call, String query) {
    if (query.isEmpty) return true;

    final parts = <String>[
      call.getDisplayName(currentUserId),
      call.callerName,
      call.receiverName,
      if (call.groupName != null) call.groupName!,
      ...call.participantNames.values,
    ];

    final haystack = parts.join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

// ── En-tête de date ─────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(date.year, date.month, date.day);

    if (callDate == today) {
      return 'Aujourd\'hui';
    } else if (callDate == yesterday) {
      return 'Hier';
    } else if (date.year == now.year) {
      final months = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
      ];
      return '${months[date.month - 1]} ${date.day}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        _formatDate(date),
        style: TextStyle(
          color: context.appThemeColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Tuile d'appel ───────────────────────────────────────────────────
class _CallTile extends ConsumerWidget {
  final CallHistoryModel call;
  final String currentUserId;

  const _CallTile({required this.call, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = call.getDisplayName(currentUserId);
    final displayPhoto = call.getDisplayPhoto(currentUserId);
    final isOutgoing = call.isOutgoing(currentUserId);
    final otherId = call.callerId == currentUserId
        ? call.receiverId
        : call.callerId;
    final contactsService = ref.read(phoneContactsServiceProvider);

    if (call.isGroup) {
      return _buildTile(
        context,
        displayName,
        displayPhoto,
        isOutgoing,
        ref,
        isGroup: true,
        otherId: otherId,
      );
    }

    final user = ref.watch(userProfileStreamProvider(otherId)).asData?.value;
    final resolvedName = user?.name.trim();
    final baseName = (resolvedName != null && resolvedName.isNotEmpty)
        ? resolvedName
        : displayName;
    final resolvedDisplayName = contactsService.resolveNameFromCache(
      fallbackName: baseName,
      phone: user?.phone,
    );
    final photo = user?.photoUrl ?? displayPhoto;
    return _buildTile(
      context,
      resolvedDisplayName,
      photo,
      isOutgoing,
      ref,
      otherId: otherId,
    );
  }

  Widget _buildTile(
    BuildContext context,
    String displayName,
    String? displayPhoto,
    bool isOutgoing,
    WidgetRef ref, {
    bool isGroup = false,
    required String otherId,
  }
  ) {

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary,
        backgroundImage: displayPhoto != null ? NetworkImage(displayPhoto) : null,
        child: displayPhoto == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700))
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: context.appThemeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          _CallTypeIndicator(callType: call.type, isOutgoing: isOutgoing),
          const SizedBox(width: 4),
          Text(
            _formatTime(call.timestamp),
            style: TextStyle(
              color: context.appThemeColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (call.durationSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(
              call.formattedDuration,
              style: TextStyle(
                color: context.appThemeColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: AppColors.primary,
            ),
            onPressed: () {
              if (isGroup) {
                final currentId = ref.read(authStateProvider).value?.uid ?? '';
                final targetUserIds = call.participantIds
                    .where((id) => id != currentId)
                    .toList();
                final participants = call.participantIds.map((id) {
                  return GroupParticipant(
                    id: id,
                    name: call.participantNames[id] ?? 'Utilisateur',
                    photo: call.participantPhotos[id],
                  );
                }).toList();
                ref.read(callProvider.notifier).startGroupCall(
                      targetUserIds: targetUserIds,
                      isVideo: call.isVideo,
                      initialParticipants: participants,
                      groupName: call.groupName ?? 'Appel de groupe',
                    );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CallScreen()),
                );
              } else {
                CallsScreen.startCallFromContact(
                  context,
                  ref,
                  otherId,
                  displayName,
                  displayPhoto,
                  call.isVideo,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ── Indicateur de type d'appel ───────────────────────────────────────
class _CallTypeIndicator extends StatelessWidget {
  final CallType callType;
  final bool isOutgoing;

  const _CallTypeIndicator({
    required this.callType,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (callType) {
      case CallType.outgoing:
        icon = Icons.arrow_upward_rounded;
        color = Colors.green;
        break;
      case CallType.incoming:
        icon = Icons.arrow_downward_rounded;
        color = Colors.green;
        break;
      case CallType.missed:
        icon = Icons.arrow_downward_rounded;
        color = Colors.red;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }
}
