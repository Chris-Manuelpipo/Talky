// lib/features/meetings/presentation/select_meeting_participants_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/backend_user_providers.dart';
import '../../chat/data/chat_providers.dart';

class SelectMeetingParticipantsScreen extends ConsumerStatefulWidget {
  /// Liste initiale de participants pré-sélectionnés (facultatif)
  final List<int> initialSelectedIds;

  const SelectMeetingParticipantsScreen({
    super.key,
    this.initialSelectedIds = const [],
  });

  @override
  ConsumerState<SelectMeetingParticipantsScreen> createState() =>
      _SelectMeetingParticipantsScreenState();
}

class _SelectMeetingParticipantsScreenState
    extends ConsumerState<SelectMeetingParticipantsScreen> {
  late Set<int> _selectedIds;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final myId = ref.watch(currentAlanyaIDProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ajouter des participants',
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedIds.toList()),
            child: Text(
              'Ajouter (${_selectedIds.length})',
              style: TextStyle(
                color: _selectedIds.isEmpty
                    ? colors.textSecondary.withOpacity(.5)
                    : context.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: colors.surface,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                hintStyle: TextStyle(color: colors.textHint),
                prefixIcon: Icon(Icons.search_rounded, color: colors.textHint),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.divider),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // ── Liste des contacts ──────────────────────────────────
          Expanded(
            child: conversationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erreur: $e',
                    style: TextStyle(color: colors.textSecondary)),
              ),
              data: (convs) {
                // Extraire les contacts uniques des conversations
                final contactsMap = <int, (String name, String? photo)>{};

                for (final conv in convs) {
                  // Ajouter tous les participants de la conversation
                  for (int i = 0; i < conv.participantIds.length; i++) {
                    final idStr = conv.participantIds[i];
                    final id = int.tryParse(idStr) ?? 0;
                    if (id != myId && id != 0) {
                      final name = conv.participantNames[idStr] ?? 'Utilisateur';
                      var photo = conv.participantPhotos[idStr];
                      
                      // Nettoyer la photo : remplacer "NON DEFINI" par null
                      if (photo != null && 
                          (photo.isEmpty || 
                           photo.toLowerCase() == 'non defini' ||
                           photo.toLowerCase().contains('non%20defini') ||
                           photo.toLowerCase().contains('undefined'))) {
                        photo = null;
                      }
                      
                      contactsMap[id] = (name, photo);
                    }
                  }
                }

                // Filtrer par recherche
                final filtered = contactsMap.entries
                    .where((e) =>
                        _query.isEmpty ||
                        e.value.$1.toLowerCase().contains(_query))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 48, color: colors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? 'Aucun contact'
                              : 'Aucun résultat',
                          style:
                              TextStyle(color: colors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (_, idx) {
                    final entry = filtered[idx];
                    final contactId = entry.key;
                    final (name, photo) = entry.value;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: context.primaryColor,
                        backgroundImage: photo != null 
                            ? NetworkImage(photo)
                            : null,
                        child: photo == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 48,
                        height: 48,
                        child: Checkbox(
                          value: _selectedIds.contains(contactId),
                          onChanged: (_) {
                            setState(() {
                              if (_selectedIds.contains(contactId)) {
                                _selectedIds.remove(contactId);
                              } else {
                                _selectedIds.add(contactId);
                              }
                            });
                          },
                          activeColor: context.primaryColor,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          if (_selectedIds.contains(contactId)) {
                            _selectedIds.remove(contactId);
                          } else {
                            _selectedIds.add(contactId);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
