// lib/features/calls/presentation/new_call_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../data/call_providers.dart';
import 'calls_screen.dart';
import 'call_screen.dart';
import '../../../core/router/app_router.dart';

class NewCallScreen extends ConsumerStatefulWidget {
  const NewCallScreen({super.key});

  @override
  ConsumerState<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends ConsumerState<NewCallScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingContacts = true;
  bool _contactsLoadInProgress = false;
  bool _contactsLoaded = false;

  // Preferred contacts from backend
  List<Map<String, dynamic>> _preferredContacts = [];

  // For multi-select (group call)
  final Set<String> _selectedContacts = {};
  bool _isSelectionMode = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabController.index == 0) {
        _ensureContactsLoaded();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 0) {
      _ensureContactsLoaded();
    }
  }

  void _ensureContactsLoaded() {
    if (_contactsLoaded || _contactsLoadInProgress) return;
    _loadPreferredContacts();
  }

  Future<void> _loadPreferredContacts() async {
    if (_contactsLoadInProgress) return;
    _contactsLoadInProgress = true;
    setState(() => _isLoadingContacts = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final contacts = await chatService.getPreferredContacts();

      if (mounted) {
        setState(() {
          _preferredContacts = contacts;
          _isLoadingContacts = false;
        });
      }
      _contactsLoadInProgress = false;
      _contactsLoaded = true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
      _contactsLoadInProgress = false;
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final currentUid = ref.read(currentAlanyaIDStringProvider);
      if (currentUid.isEmpty) return;

      final chatService = ref.read(chatServiceProvider);

      // Search by name via API
      final nameResults = await chatService.searchUsers(
        query: query,
        currentUserId: currentUid,
      );

      // Also try to search by phone (alanyaPhone) if it looks like a phone number
      List<Map<String, dynamic>> phoneResults = [];
      if (RegExp(r'^[\d\s\-+()]+$').hasMatch(query) && query.length >= 8) {
        final user = await chatService.findUserByPhone(query);
        if (user != null) {
          phoneResults = [user];
        }
      }

      // Combine results, removing duplicates
      final combined = [...nameResults];
      for (final user in phoneResults) {
        if (!combined.any((u) => u['id'] == user['id'])) {
          combined.add(user);
        }
      }

      setState(() {
        _searchResults = combined.cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedContacts.contains(userId)) {
        _selectedContacts.remove(userId);
      } else {
        _selectedContacts.add(userId);
      }
      _isSelectionMode = _selectedContacts.isNotEmpty;
    });
  }

  void _startCall(String userId, String name, String? photo, bool isVideo) {
    // Navigate back to calls screen and start the call
    Navigator.of(context).pop();
    CallsScreen.startCallFromContact(
        context, ref, userId, name, photo, isVideo);
  }

  void _startGroupCall() {
    if (_selectedContacts.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appThemeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.appThemeColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.call_rounded, color: context.primaryColor),
                title: const Text('Appel audio de groupe'),
                onTap: () => _startGroupCallWithMode(false),
              ),
              ListTile(
                leading:
                    Icon(Icons.videocam_rounded, color: context.accentColor),
                title: const Text('Appel vidéo de groupe'),
                onTap: () => _startGroupCallWithMode(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startGroupCallWithMode(bool isVideo) async {
    Navigator.pop(context); // fermer le bottom sheet
    Navigator.of(context).pop(); // fermer l'écran de sélection

    final participants = _preferredContacts
        .where((c) => _selectedContacts.contains(c['id'].toString()))
        .map((c) => GroupParticipant(
              id: c['id'].toString(),
              name: c['name'] as String? ??
                  c['pseudo'] as String? ??
                  'Utilisateur',
              photo: c['photoUrl'] as String?,
            ))
        .toList();

    await ref.read(callProvider.notifier).startGroupCall(
          targetUserIds: _selectedContacts.toList(),
          isVideo: isVideo,
          initialParticipants: participants,
          groupName: 'Appel de groupe',
        );

    // Utiliser le root navigator global car l'écran courant est déjà pop
    final nav = rootNavigatorKey.currentState;
    nav?.push(MaterialPageRoute(builder: (_) => const CallScreen()));
  }

  String _resolveDisplayName(Map<String, dynamic> user) {
    return user['name'] as String? ??
        user['pseudo'] as String? ??
        'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: _isSelectionMode
            ? Text('${_selectedContacts.length} sélectionné(s)')
            : const Text('Nouvel appel',
                style: TextStyle(fontWeight: FontWeight.w700)),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.call_rounded),
                  onPressed: () => _startGroupCallWithMode(false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_rounded),
                  onPressed: () => _startGroupCallWithMode(true),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.appThemeColors.textSecondary,
          indicatorColor: context.primaryColor,
          tabs: const [
            Tab(text: 'Contacts'),
            Tab(text: 'Rechercher'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildSearchTab(),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedContacts.length >= 2
          ? FloatingActionButton(
              onPressed: _startGroupCall,
              backgroundColor: context.primaryColor,
              child: const Icon(Icons.call_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildContactsTab() {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: TextStyle(color: context.appThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou alanyaphone...',
              hintStyle: TextStyle(color: context.appThemeColors.textHint),
              prefixIcon: Icon(Icons.search_rounded,
                  color: context.appThemeColors.textHint),
              filled: true,
              fillColor: context.appThemeColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        // Liste des contacts
        Expanded(
          child: _buildContactsList(),
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    // Filter contacts based on query
    final filteredContacts = _query.isEmpty
        ? _preferredContacts
        : _preferredContacts
            .where((c) =>
                (c['name'] as String? ?? '').toLowerCase().contains(_query) ||
                (c['pseudo'] as String? ?? '').toLowerCase().contains(_query))
            .toList();

    if (filteredContacts.isEmpty) {
      final colors = context.appThemeColors;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingContacts) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Chargement des contacts...',
                  style: TextStyle(color: colors.textSecondary)),
            ] else ...[
              Icon(Icons.contacts, size: 48, color: colors.textHint),
              SizedBox(height: 12),
              Text(
                  _preferredContacts.isEmpty
                      ? 'Aucun contact préféré'
                      : 'Aucun contact trouvé',
                  style: TextStyle(color: colors.textSecondary)),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = filteredContacts[index];
        final contactId = contact['id'].toString();
        final isSelected = _selectedContacts.contains(contactId);

        return _ContactTile(
          contact: contact,
          isSelected: isSelected,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(contactId);
            } else {
              final name = _resolveDisplayName(contact);
              _startCall(
                contactId,
                name,
                contact['photoUrl'] as String?,
                false,
              );
            }
          },
          onLongPress: () => _toggleSelection(contactId),
          ref: ref,
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _searchUsers,
            style: TextStyle(color: context.appThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom...',
              hintStyle: TextStyle(color: context.appThemeColors.textHint),
              prefixIcon: Icon(Icons.search_rounded,
                  color: context.appThemeColors.textHint),
              filled: true,
              fillColor: context.appThemeColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        // Résultats de recherche
        Expanded(
          child: _isSearching
              ? Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 48,
                            color: context.appThemeColors.textHint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            _searchCtrl.text.isEmpty
                                ? 'Entrez un nom'
                                : 'Aucun utilisateur trouvé',
                            style: TextStyle(
                                color: context.appThemeColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final user = _searchResults[i];
                        final displayName = _resolveDisplayName(user);
                        return _ContactTile(
                          contact: user,
                          isSelected: false,
                          onTap: () => _startCall(
                            user['id'].toString(),
                            displayName,
                            user['photoUrl'] as String?,
                            false,
                          ),
                          ref: ref,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final WidgetRef ref;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
    required this.ref,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ??
        contact['pseudo'] as String? ??
        'Utilisateur';
    final pseudo = contact['pseudo'] as String? ?? '';
    final _rawPhoto = contact['photoUrl'] as String?;
    final photo =
        (_rawPhoto != null && _rawPhoto.startsWith('http')) ? _rawPhoto : null;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Stack(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: photo == null ? context.primaryColor : null,
              image: photo != null
                  ? DecorationImage(
                      image: NetworkImage(photo), fit: BoxFit.cover)
                  : null,
            ),
            child: photo == null
                ? const Center(
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 24))
                : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: context.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.appThemeColors.textPrimary)),
      subtitle: Text(pseudo,
          style: TextStyle(
              color: context.appThemeColors.textSecondary, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.call_rounded, color: context.primaryColor),
            onPressed: () {
              // Direct audio call
              final displayName = contact['name'] as String? ??
                  contact['pseudo'] as String? ??
                  'Utilisateur';
              Navigator.of(context).pop();
              CallsScreen.startCallFromContact(
                context,
                ref,
                contact['id'].toString(),
                displayName,
                contact['photoUrl'] as String?,
                false,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam_rounded, color: context.accentColor),
            onPressed: () {
              // Direct video call
              final displayName = contact['name'] as String? ??
                  contact['pseudo'] as String? ??
                  'Utilisateur';
              Navigator.of(context).pop();
              CallsScreen.startCallFromContact(
                context,
                ref,
                contact['id'].toString(),
                displayName,
                contact['photoUrl'] as String?,
                true,
              );
            },
          ),
        ],
      ),
    );
  }
}
