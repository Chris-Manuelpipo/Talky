// lib/features/calls/presentation/calls_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
import '../../../core/services/ringback_service.dart';
import '../../chat/data/chat_providers.dart';
import '../../meetings/data/meeting_providers.dart';
import '../data/call_providers.dart';
import '../domain/call_history_model.dart';
import 'call_screen.dart';
import 'new_call_screen.dart';
import '../../meetings/presentation/meetings_screen.dart';
import '../../meetings/presentation/meeting_room_screen.dart';

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
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission microphone refusée'),
            backgroundColor: Colors.red));
      return;
    }

    if (isVideo) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (camStatus.isPermanentlyDenied) {
          await openAppSettings();
        }
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Permission caméra refusée'),
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
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CallScreen()));
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
  int _selectedTab = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: colors.textHint),
                  border: InputBorder.none,
                ),
              )
            : const Text('Appels',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                )),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Appels',
                    icon: Icons.call_rounded,
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Réunions',
                    icon: Icons.video_call_rounded,
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
                color: colors.textSecondary),
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
      body: _selectedTab == 0
          ? _CallsContent(query: _query)
          : const _MeetingsTabContent(),
      floatingActionButton: _SpeedDialFAB(
        onCallPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewCallScreen()),
          );
        },
        onMeetingPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CreateMeetingSheet(),
          );
        },
      ),
    );
  }
}

class _SpeedDialFAB extends StatefulWidget {
  final VoidCallback onCallPressed;
  final VoidCallback onMeetingPressed;

  const _SpeedDialFAB({
    required this.onCallPressed,
    required this.onMeetingPressed,
  });

  @override
  State<_SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<_SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Réunion button
        SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: () {
                        _toggle();
                        widget.onMeetingPressed();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(
                          'Réunion',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    heroTag: 'meeting',
                    icon: Icons.video_call_rounded,
                    color: primaryColor,
                    onTap: () {
                      _toggle();
                      widget.onMeetingPressed();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Appel button
        SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: () {
                        _toggle();
                        widget.onCallPressed();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(
                          'Appel',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    heroTag: 'call',
                    icon: Icons.call_rounded,
                    color: primaryColor,
                    onTap: () {
                      _toggle();
                      widget.onCallPressed();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: primaryColor,
          elevation: 4,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Object heroTag;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: color.withOpacity(.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CallsContent extends ConsumerWidget {
  final String query;

  const _CallsContent({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alanyaIdString = ref.watch(currentAlanyaIDStringProvider);
    if (alanyaIdString.isEmpty) return const SizedBox();

    final callHistoryAsync = ref.watch(callHistoryProvider(alanyaIdString));
    final weeklyDurationAsync =
        ref.watch(weeklyCallDurationProvider(alanyaIdString));
    // Prefetch profils pour l'historique d'appels
    ref.listen(callHistoryProvider(alanyaIdString), (_, next) {
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
        final me = ref.read(currentAlanyaIDStringProvider);
        if (me.isNotEmpty) ids.remove(me);
        if (ids.isNotEmpty) {
          ref.read(prefetchUserProfilesProvider(ids.toList()));
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
              currentUserId: alanyaIdString, // ← CORRIGÉ
              query: query,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erreur: $e',
                  style:
                      TextStyle(color: context.appThemeColors.textSecondary)),
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
              color: context.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: context.primaryColor,
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
            child: Text(
              'Détails',
              style: TextStyle(
                color: context.primaryColor,
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
        'Janvier',
        'Février',
        'Mars',
        'Avril',
        'Mai',
        'Juin',
        'Juillet',
        'Août',
        'Septembre',
        'Octobre',
        'Novembre',
        'Décembre'
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
    final otherId =
        call.callerId == currentUserId ? call.receiverId : call.callerId;
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
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: context.primaryColor,
        backgroundImage:
            displayPhoto != null ? NetworkImage(displayPhoto) : null,
        child: displayPhoto == null
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
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
              color: context.primaryColor,
            ),
            onPressed: () {
              if (isGroup) {
                final currentId = ref.read(currentAlanyaIDStringProvider);
                final targetUserIds =
                    call.participantIds.where((id) => id != currentId).toList();
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

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final primaryColor = Theme.of(context).primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? primaryColor.withOpacity(.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? primaryColor : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primaryColor : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingsTabContent extends ConsumerWidget {
  const _MeetingsTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsListProvider);
    final colors = context.appThemeColors;
    final primaryColor = Theme.of(context).primaryColor;

    return meetingsAsync.when(
      data: (meetings) {
        if (meetings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_call_rounded,
                  size: 64,
                  color: colors.textSecondary.withOpacity(.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune réunion',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: meetings.length,
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            final now = DateTime.now();
            final diff = meeting.startTime.difference(now);
            final isImminent =
                diff.inMinutes <= 15 && diff.inMinutes > -meeting.duree;
            final isPast = meeting.startTime.isBefore(now);

            String timeLabel;
            if (isPast) {
              timeLabel = 'Passée';
            } else if (diff.inMinutes < 60) {
              timeLabel = 'Dans ${diff.inMinutes} min';
            } else if (diff.inHours < 24) {
              timeLabel = 'Dans ${diff.inHours}h';
            } else {
              timeLabel = DateFormat('dd/MM HH:mm').format(meeting.startTime);
            }

            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isImminent
                      ? primaryColor.withOpacity(.2)
                      : primaryColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                  border: isImminent
                      ? Border.all(color: primaryColor, width: 2)
                      : null,
                ),
                child: Icon(
                  meeting.isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                  color:
                      isImminent ? primaryColor : primaryColor.withOpacity(.7),
                  size: 22,
                ),
              ),
              title: Text(
                meeting.objet,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isImminent
                          ? primaryColor.withOpacity(.15)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isImminent ? FontWeight.w700 : FontWeight.w500,
                        color: isImminent ? primaryColor : colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${meeting.duree} min',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              trailing: meeting.isEnd
                  ? Chip(
                      label: const Text('Terminée',
                          style: TextStyle(fontSize: 10)),
                      backgroundColor: colors.surface,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MeetingRoomScreen(meeting: meeting),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Erreur: $e', style: TextStyle(color: colors.textSecondary)),
      ),
    );
  }
}
