// lib/features/chat/presentation/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/backend_user_providers.dart';
import '../data/chat_providers.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen>
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
        _searchResults = combined;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text('Nouvelle discussion',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
          // Contacts tab
          _buildContactsTab(),
          // Rechercher tab
          _buildSearchTab(),
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return Column(
      children: [
        // Bouton créer un groupe
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () => context.push(AppRoutes.createGroup),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.appThemeColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.primaryColor,
                    radius: 22,
                    child: Icon(Icons.group_add_rounded,
                        color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 14),
                  Text('Créer un groupe',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                ],
              ),
            ),
          ),
        ),

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
        return _UserTile(
          user: contact,
          onTap: () => _startChatWithUser(contact),
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
                        final displayName = user['name'] as String? ??
                            user['pseudo'] as String? ??
                            'Utilisateur';
                        return _UserTile(
                          user: user,
                          displayNameOverride: displayName,
                          onTap: () => _startChatWithUser(user),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _startChatWithUser(Map<String, dynamic> user) async {
    final currentUid = ref.read(currentAlanyaIDStringProvider);
    if (currentUid.isEmpty) return;

    try {
      final myName = await ref.read(currentUserNameProvider.future);
      final myPhoto = await ref
          .read(currentBackendUserProvider.future)
          .then((u) => u?.photoUrl);

      final displayName =
          user['name'] as String? ?? user['pseudo'] as String? ?? 'Utilisateur';

      final convId =
          await ref.read(chatServiceProvider).getOrCreateConversation(
                currentUserId: currentUid,
                currentUserName: myName,
                currentUserPhoto: myPhoto,
                otherUserId: user['id'] as String,
                otherUserName: displayName,
                otherUserPhoto: user['photoUrl'] as String?,
              );

      if (mounted) {
        context.push(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {
            'name': displayName,
            'photo': user['photoUrl'],
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? displayNameOverride;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.onTap,
    this.displayNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        displayNameOverride ?? (user['name'] as String? ?? 'Utilisateur');
    final pseudo = user['pseudo'] as String? ?? '';
    final _rawPhoto = user['photoUrl'] as String?;
    final photo =
        (_rawPhoto != null && _rawPhoto.startsWith('http')) ? _rawPhoto : null;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: photo == null ? context.primaryColor : null,
          image: photo != null
              ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
              : null,
        ),
        child: photo == null
            ? const Center(
                child:
                    Icon(Icons.person_rounded, color: Colors.white, size: 24))
            : null,
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.appThemeColors.textPrimary)),
      subtitle: Text(pseudo,
          style: TextStyle(
              color: context.appThemeColors.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chat_rounded, color: context.primaryColor),
    );
  }
}
