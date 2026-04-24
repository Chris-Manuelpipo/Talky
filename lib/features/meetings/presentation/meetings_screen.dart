// lib/features/meetings/presentation/meetings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:talky/core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/backend_user_providers.dart';
import '../data/meeting_providers.dart';
import '../domain/meeting_model.dart';
import 'meeting_room_screen.dart';
import 'select_meeting_participants_screen.dart';

class CreateMeetingSheet extends _CreateMeetingSheet {
  const CreateMeetingSheet();
}

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final meetings = ref.watch(meetingsListProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text('Réunions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
            onPressed: () => ref.invalidate(meetingsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.video_call_rounded),
        label: const Text('Nouvelle réunion'),
        backgroundColor: context.primaryColor,
      ),
      body: meetings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child:
              Text('Erreur: $e', style: TextStyle(color: colors.textSecondary)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_camera_front_outlined,
                      size: 64, color: colors.textSecondary.withOpacity(.4)),
                  const SizedBox(height: 16),
                  Text('Aucune réunion planifiée',
                      style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _MeetingTile(meeting: list[i]),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateMeetingSheet(),
    );
  }
}

// ── Tuile d'une réunion ──────────────────────────────────────────────

class _MeetingTile extends ConsumerWidget {
  final MeetingModel meeting;
  const _MeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appThemeColors;
    final alanyaID = ref.watch(currentAlanyaIDProvider);
    final isOrganiser = alanyaID == meeting.idOrganiser;

    final now = DateTime.now();
    final diff = meeting.startTime.difference(now);
    final isImminent = diff.inMinutes <= 15 && diff.inMinutes > -meeting.duree;
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isImminent
              ? context.primaryColor.withOpacity(.2)
              : context.primaryColor.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: isImminent
              ? Border.all(color: context.primaryColor, width: 2)
              : null,
        ),
        child: Icon(
          meeting.isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
          color: isImminent
              ? context.primaryColor
              : context.primaryColor.withOpacity(.7),
        ),
      ),
      title: Text(
        meeting.objet,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isImminent
                  ? context.primaryColor.withOpacity(.15)
                  : colors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timeLabel,
              style: TextStyle(
                color: isImminent ? context.primaryColor : colors.textSecondary,
                fontSize: 12,
                fontWeight: isImminent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${meeting.organiserDisplay} · ${meeting.duree} min',
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
        ],
      ),
      trailing: meeting.isEnd
          ? Chip(
              label: Text('Terminée',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              backgroundColor: colors.surface,
            )
          : SizedBox(
              width: 90,
              child: ElevatedButton(
                onPressed: () => _joinMeeting(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  isOrganiser ? 'Démarrer' : 'Rejoindre',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ),
    );
  }

  Future<void> _joinMeeting(BuildContext context, WidgetRef ref) async {
    // Charger les détails complets (avec participants)
    final detail = await ref.read(
      meetingDetailProvider(meeting.idMeeting).future,
    );

    if (!context.mounted) return;

    await ref.read(meetingRoomProvider.notifier).joinMeeting(detail);

    if (!context.mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MeetingRoomScreen(meeting: detail),
    ));
  }
}

// ── Bottom sheet — créer une réunion ─────────────────────────────────

class _CreateMeetingSheet extends ConsumerStatefulWidget {
  const _CreateMeetingSheet();

  @override
  ConsumerState<_CreateMeetingSheet> createState() =>
      _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends ConsumerState<_CreateMeetingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _objetCtrl = TextEditingController();
  DateTime _startTime = DateTime.now().add(const Duration(minutes: 15));
  int _duree = 60;
  bool _isVideo = true;
  bool _loading = false;
  List<int> _selectedParticipantIds = [];

  @override
  void dispose() {
    _objetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nouvelle réunion',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Objet
              TextFormField(
                controller: _objetCtrl,
                decoration: InputDecoration(
                  labelText: 'Objet de la réunion',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 16),

              // Date / heure
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.calendar_today, color: context.primaryColor),
                title: Text(fmt.format(_startTime),
                    style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Date de début',
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: _pickDateTime,
              ),
              const Divider(),

              // Durée
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.timer_outlined, color: context.primaryColor),
                title: Text('$_duree minutes',
                    style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Durée estimée',
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () {
                        if (_duree > 15) setState(() => _duree -= 15);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () => setState(() => _duree += 15),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Type
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary:
                    Icon(Icons.videocam_rounded, color: context.primaryColor),
                title: Text('Vidéo activée',
                    style: TextStyle(color: colors.textPrimary)),
                value: _isVideo,
                activeColor: context.primaryColor,
                onChanged: (v) => setState(() => _isVideo = v),
              ),
              const Divider(),

              // Participants
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.group_add_rounded, color: context.primaryColor),
                title: Text('Ajouter des participants',
                    style: TextStyle(color: colors.textPrimary)),
                subtitle: Text(
                  _selectedParticipantIds.isEmpty
                      ? 'Aucun participant'
                      : '${_selectedParticipantIds.length} participants',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.navigate_next_rounded),
                onTap: _selectParticipants,
              ),
              const SizedBox(height: 24),

              // Bouton créer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Créer la réunion',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _selectParticipants() async {
    final selected = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(
        builder: (_) => SelectMeetingParticipantsScreen(
          initialSelectedIds: _selectedParticipantIds,
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedParticipantIds = selected);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // Générer un room ID unique
      final room = 'talky_${DateTime.now().millisecondsSinceEpoch}';

      final response = await ApiService.instance.post('/meetings', body: {
        'start_time': _startTime.toIso8601String(),
        'duree': _duree,
        'objet': _objetCtrl.text.trim(),
        'room': room,
        'type_media': _isVideo ? 1 : 0,
      }) as Map<String, dynamic>;

      final meetingId = response['idMeeting'] as int?;

      // Inviter les participants si des participants ont été sélectionnés
      if (meetingId != null && _selectedParticipantIds.isNotEmpty) {
        try {
          await ApiService.instance.post(
            '/meetings/$meetingId/invite',
            body: {'participant_ids': _selectedParticipantIds},
          );
        } catch (e) {
          print('[Meeting] Erreur lors de l\'invitation: $e');
          // Ne pas bloquer la création si l'invitation échoue
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ref.invalidate(meetingsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réunion créée ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
