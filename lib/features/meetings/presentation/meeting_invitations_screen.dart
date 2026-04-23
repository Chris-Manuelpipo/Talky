// lib/features/meetings/presentation/meeting_invitations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/backend_user_providers.dart';
import '../data/meeting_providers.dart';
import '../domain/meeting_model.dart';

class MeetingInvitationsScreen extends ConsumerStatefulWidget {
  const MeetingInvitationsScreen({super.key});

  @override
  ConsumerState<MeetingInvitationsScreen> createState() =>
      _MeetingInvitationsScreenState();
}

class _MeetingInvitationsScreenState
    extends ConsumerState<MeetingInvitationsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final meetingsAsync = ref.watch(meetingsListProvider);
    final alanyaID = ref.watch(currentAlanyaIDProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Invitations de réunion',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: meetingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: TextStyle(color: colors.textSecondary)),
        ),
        data: (meetings) {
          // Filtrer les invitations en attente (status = 0, pas organisateur)
          final pendingInvitations = meetings
              .where((m) =>
                  m.idOrganiser != alanyaID &&
                  m.participants.any((p) =>
                      p.alanyaID == alanyaID && p.status == 0))
              .toList();

          if (pendingInvitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline_rounded,
                      size: 64, color: colors.textHint),
                  const SizedBox(height: 16),
                  Text('Aucune invitation',
                      style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pendingInvitations.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colors.divider),
            itemBuilder: (_, idx) =>
                _InvitationTile(meeting: pendingInvitations[idx]),
          );
        },
      ),
    );
  }
}

// ── Tuile d'invitation ──────────────────────────────────────────────

class _InvitationTile extends ConsumerStatefulWidget {
  final MeetingModel meeting;

  const _InvitationTile({required this.meeting});

  @override
  ConsumerState<_InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<_InvitationTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.primaryColor.withOpacity(.15),
                child: Icon(
                  widget.meeting.isVideo
                      ? Icons.videocam_rounded
                      : Icons.mic_rounded,
                  color: context.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.meeting.objet,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invité par ${widget.meeting.organiserDisplay}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Date et détails
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                fmt.format(widget.meeting.startTime),
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer_rounded, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${widget.meeting.duree} min',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ),

          // Boutons d'action
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _declineInvitation(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withOpacity(.5)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Refuser',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _acceptInvitation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Accepter',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvitation(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final alanyaID = ref.read(currentAlanyaIDProvider);
      await ApiService.instance.post(
        '/meetings/${widget.meeting.idMeeting}/accept/$alanyaID',
        body: {},
      );

      if (mounted) {
        ref.invalidate(meetingsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réunion acceptée ✅')),
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

  Future<void> _declineInvitation(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final alanyaID = ref.read(currentAlanyaIDProvider);
      await ApiService.instance.post(
        '/meetings/${widget.meeting.idMeeting}/decline/$alanyaID',
        body: {},
      );

      if (mounted) {
        ref.invalidate(meetingsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réunion refusée')),
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
