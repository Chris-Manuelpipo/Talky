// lib/features/calls/presentation/new_call_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/services/phone_contacts_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/data/chat_service.dart';
import '../../chat/domain/contact_model.dart';
import '../data/call_providers.dart';
import 'calls_screen.dart';

class _ContactWithPhoto {
  final PhoneContact contact;
  final String? photoUrl;

  _ContactWithPhoto({required this.contact, this.photoUrl});
  String get displayName => contact.displayName;
}

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
  bool _hasPermission = false;
  bool _isLoadingContacts = true;
  bool _permissionDeniedPermanently = false;

  // Phone contacts matched with Talky users
  List<_ContactWithPhoto> _onTalkyContacts = [];
  List<PhoneContact> _notOnTalkyContacts = [];

  // For multi-select (group call)
  final Set<String> _selectedContacts = {};
  bool _isSelectionMode = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPhoneContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoneContacts() async {
    setState(() => _isLoadingContacts = true);

    try {
      final service = ref.read(phoneContactsServiceProvider);
      final hasPermission = await service.requestPermission();

      if (!hasPermission) {
        final status = await Permission.contacts.status;
        setState(() {
          _hasPermission = false;
          _permissionDeniedPermanently = status.isPermanentlyDenied;
          _isLoadingContacts = false;
        });
        return;
      }

      _hasPermission = true;
      final phoneContacts = await service.getContacts();

      if (phoneContacts.isEmpty) {
        setState(() {
          _onTalkyContacts = [];
          _notOnTalkyContacts = [];
          _isLoadingContacts = false;
        });
        return;
      }

      final allPhones = <String>[];
      for (final contact in phoneContacts) {
        allPhones.addAll(contact.phones);
      }

      final chatService = ref.read(chatServiceProvider);
      final talkyUsers = await chatService.findUsersByPhones(allPhones);

      final phoneToUser = <String, Map<String, dynamic>>{};
      for (final user in talkyUsers) {
        final phone = user['phone'] as String?;
        if (phone != null) {
          phoneToUser[phone.replaceAll(RegExp(r'[^\d]'), '')] = user;
        }
      }

      final onTalky = <_ContactWithPhoto>[];
      final notOnTalky = <PhoneContact>[];

      for (final contact in phoneContacts) {
        String? photoUrl;
        bool isOnTalky = false;
        
        for (final phone in contact.phones) {
          final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (phoneToUser.containsKey(normalized)) {
            isOnTalky = true;
            photoUrl = phoneToUser[normalized]?['photoUrl'] as String?;
            break;
          }
        }

        if (isOnTalky) {
          onTalky.add(_ContactWithPhoto(contact: contact, photoUrl: photoUrl));
        } else {
          notOnTalky.add(contact);
        }
      }

      setState(() {
        _onTalkyContacts = onTalky;
        _notOnTalkyContacts = notOnTalky;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
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
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) return;

      final chatService = ref.read(chatServiceProvider);

      final nameResults = await chatService.searchUsers(
        query: query,
        currentUserId: currentUser.uid,
      );

      List<Map<String, dynamic>> phoneResults = [];
      if (RegExp(r'^[\d\s\-+()]+$').hasMatch(query) && query.length >= 8) {
        final user = await chatService.findUserByPhone(query);
        if (user != null) {
          phoneResults = [user];
        }
      }

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
    CallsScreen.startCallFromContact(context, ref, userId, name, photo, isVideo);
  }

  void _startGroupCall() {
    // Group calls not available yet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Les appels de groupe ne sont pas encore disponibles'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: _isSelectionMode
            ? Text('${_selectedContacts.length} sélectionné(s)')
            : const Text('Nouvel appel'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedContacts.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                if (_selectedContacts.length >= 2)
                  TextButton.icon(
                    onPressed: _startGroupCall,
                    icon: const Icon(Icons.group, color: AppColors.primary),
                    label: const Text(
                      'Appeler le groupe',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.appThemeColors.textSecondary,
          indicatorColor: AppColors.primary,
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
    );
  }

  Widget _buildContactsTab() {
    if (_isLoadingContacts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Chargement des contacts...',
                style: TextStyle(color: context.appThemeColors.textSecondary)),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts, size: 64, color: context.appThemeColors.textHint),
              const SizedBox(height: 16),
              Text('Permission requise',
                  style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                _permissionDeniedPermanently
                    ? 'L\'accès aux contacts a été refusé. Veuillez l\'activer dans les paramètres.'
                    : 'Accordez l\'accès à vos contacts pour voir\nvos contacts Talky',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appThemeColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_permissionDeniedPermanently) {
                    await openAppSettings();
                  } else {
                    _loadPhoneContacts();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  _permissionDeniedPermanently
                      ? 'Ouvrir les paramètres'
                      : 'Autoriser',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: TextStyle(color: context.appThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher un contact...',
              hintStyle: TextStyle(color: context.appThemeColors.textHint),
              prefixIcon:
                  Icon(Icons.search_rounded, color: context.appThemeColors.textHint),
              filled: true,
              fillColor: context.appThemeColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        Expanded(
          child: _buildContactsList(),
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    final filteredOnTalky = _query.isEmpty
        ? _onTalkyContacts
        : _onTalkyContacts
            .where((c) => c.contact.displayName.toLowerCase().contains(_query))
            .toList();

    final filteredNotOnTalky = _query.isEmpty
        ? _notOnTalkyContacts
        : _notOnTalkyContacts
            .where((c) => c.displayName.toLowerCase().contains(_query))
            .toList();

    if (filteredOnTalky.isEmpty && filteredNotOnTalky.isEmpty) {
      final colors = context.appThemeColors;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 48, color: colors.textHint),
            const SizedBox(height: 12),
            Text('Aucun contact trouvé',
                style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Contacts sur Talky
        if (filteredOnTalky.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'CONTACTS SUR TALKY',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...filteredOnTalky.map((c) => _PhoneContactTile(
                contact: c.contact,
                photoUrl: c.photoUrl,
                isOnTalky: true,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedContacts.contains(
                    c.photoUrl != null ? c.contact.phones.first : null),
                onTap: () => _toggleSelection(c.contact.phones.first),
                onCallAudio: () {
                  // Find the user ID from the talky contacts
                  _startCall(c.contact.phones.first, c.displayName, c.photoUrl, false);
                },
                onCallVideo: () {
                  _startCall(c.contact.phones.first, c.displayName, c.photoUrl, true);
                },
              )),
        ],

        // Inviter sur Talky
        if (filteredNotOnTalky.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'INVITER SUR TALKY',
              style: TextStyle(
                color: context.appThemeColors.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...filteredNotOnTalky.map((contact) => _PhoneContactTile(
                contact: contact,
                isOnTalky: false,
                isSelectionMode: _isSelectionMode,
                isSelected: false,
                onTap: () {},
                onCallAudio: null,
                onCallVideo: null,
              )),
        ],
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _searchUsers,
            style: TextStyle(color: context.appThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher par numéro ou nom...',
              hintStyle: TextStyle(color: context.appThemeColors.textHint),
              prefixIcon:
                  Icon(Icons.search_rounded, color: context.appThemeColors.textHint),
              filled: true,
              fillColor: context.appThemeColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            _searchCtrl.text.isEmpty
                                ? 'Entrez un numéro ou un nom'
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
                        return _UserTile(
                          user: user,
                          onCallAudio: () => _startCall(
                            user['id'] as String,
                            user['name'] as String,
                            user['photoUrl'] as String?,
                            false,
                          ),
                          onCallVideo: () => _startCall(
                            user['id'] as String,
                            user['name'] as String,
                            user['photoUrl'] as String?,
                            true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────

class _PhoneContactTile extends StatelessWidget {
  final PhoneContact contact;
  final String? photoUrl;
  final bool isOnTalky;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onCallAudio;
  final VoidCallback? onCallVideo;

  const _PhoneContactTile({
    required this.contact,
    this.photoUrl,
    required this.isOnTalky,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onCallAudio,
    this.onCallVideo,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName;

    return ListTile(
      onTap: isOnTalky ? onTap : null,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          if (isSelectionMode && isOnTalky)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: TextStyle(
          color: context.appThemeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: contact.phones.isNotEmpty
          ? Text(
              contact.phones.first,
              style: TextStyle(color: context.appThemeColors.textSecondary),
            )
          : null,
      trailing: isOnTalky && !isSelectionMode
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_rounded, color: AppColors.primary),
                  onPressed: onCallAudio,
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_rounded, color: AppColors.accent),
                  onPressed: onCallVideo,
                ),
              ],
            )
          : !isOnTalky
              ? TextButton(
                  onPressed: () {
                    // Inviter sur Talky - à implémenter
                  },
                  child: const Text(
                    'Inviter',
                    style: TextStyle(color: AppColors.primary),
                  ),
                )
              : null,
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onCallAudio;
  final VoidCallback? onCallVideo;

  const _UserTile({
    required this.user,
    this.onCallAudio,
    this.onCallVideo,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Utilisateur';
    final photo = user['photoUrl'] as String?;

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
      title: Text(
        name,
        style: TextStyle(
          color: context.appThemeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: user['phone'] != null
          ? Text(
              user['phone'] as String,
              style: TextStyle(color: context.appThemeColors.textSecondary),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: onCallAudio,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.accent),
            onPressed: onCallVideo,
          ),
        ],
      ),
    );
  }
}
