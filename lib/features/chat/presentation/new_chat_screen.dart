// lib/features/chat/presentation/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/phone_contacts_service.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
import '../domain/contact_model.dart';

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
  bool _hasPermission = false;
  bool _isLoadingContacts = true;
  bool _permissionDeniedPermanently = false;
  bool _contactsLoadInProgress = false;
  bool _contactsLoaded = false;
  final Map<String, String> _phoneToContactName = {};

  // Phone contacts matched with Talky users
  List<_ContactWithPhoto> _onTalkyContacts = [];
  List<PhoneContact> _notOnTalkyContacts = [];

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
    _loadPhoneContacts();
  }

  Future<void> _loadPhoneContacts() async {
    if (_contactsLoadInProgress) return;
    _contactsLoadInProgress = true;
    setState(() => _isLoadingContacts = true);

    try {
      final service = ref.read(phoneContactsServiceProvider);
      final hasPermission = await service.requestPermission();

      if (!hasPermission) {
        // Vérifier si la permission est définitivement refusée
        final status = await Permission.contacts.status;
        setState(() {
          _hasPermission = false;
          _permissionDeniedPermanently = status.isPermanentlyDenied;
          _isLoadingContacts = false;
        });
        _contactsLoadInProgress = false;
        return;
      }

      _hasPermission = true;
      final phoneContacts = await service.getContactsCached();

      // Debug: Show all contacts regardless
      // ignore: avoid_print
      print('[NewChatScreen] Phone contacts: ${phoneContacts.length}');

      if (phoneContacts.isEmpty) {
        setState(() {
          _onTalkyContacts = [];
          _notOnTalkyContacts = [];
          _isLoadingContacts = false;
        });
        _contactsLoadInProgress = false;
        _contactsLoaded = true;
        return;
      }

      // Extract all phone numbers from contacts
      final allPhones = <String>[];
      for (final contact in phoneContacts) {
        for (final phone in contact.phones) {
          final normalized = _normalizePhone(phone);
          if (normalized.isNotEmpty) {
            _phoneToContactName[normalized] = contact.displayName;
          }
        }
        allPhones.addAll(contact.phones);
      }

      // Find users on Talky by phone numbers (progressif)
      final chatService = ref.read(chatServiceProvider);
      await for (final talkyUsers
          in chatService.findUsersByPhonesProgressive(allPhones)) {
        if (!mounted) break;

        // Create a map of phone -> user for quick lookup
        final phoneToUser = <String, Map<String, dynamic>>{};
        for (final user in talkyUsers) {
          final phone = user['phone'] as String?;
          if (phone != null) {
            phoneToUser[phone.replaceAll(RegExp(r'[^\d]'), '')] = user;
          }
        }

        // Match contacts with Talky users - store with photo
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
            onTalky
                .add(_ContactWithPhoto(contact: contact, photoUrl: photoUrl));
          } else {
            notOnTalky.add(contact);
          }
        }

        setState(() {
          _onTalkyContacts = onTalky;
          _notOnTalkyContacts = notOnTalky;
        });
      }

      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
      _contactsLoadInProgress = false;
      _contactsLoaded = true;
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
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
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) return;

      final chatService = ref.read(chatServiceProvider);

      // Search by name
      final nameResults = await chatService.searchUsers(
        query: query,
        currentUserId: currentUser.uid,
      );

      // Also try to search by phone if it looks like a phone number
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
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts,
                  size: 64, color: context.appThemeColors.textHint),
              SizedBox(height: 16),
              Text('Permission requise',
                  style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                _permissionDeniedPermanently
                    ? 'L\'accès aux contacts a été refusé. Veuillez l\'activer dans les paramètres.'
                    : 'Accordez l\'accès à vos contacts pour voir\nvos contacts Talky',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appThemeColors.textSecondary),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_permissionDeniedPermanently) {
                    await openAppSettings();
                  } else {
                    _loadPhoneContacts();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                ),
                child: Text(
                  _permissionDeniedPermanently
                      ? 'Ouvrir les paramètres'
                      : 'Autoriser',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              hintText: 'Rechercher un contact...',
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
            if (_isLoadingContacts) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Chargement des contacts...',
                  style: TextStyle(color: colors.textSecondary)),
            ] else ...[
              Icon(AppIcons.group, size: 48, color: colors.textHint),
              SizedBox(height: 12),
              Text('Aucun contact trouvé',
                  style: TextStyle(color: colors.textSecondary)),
            ],
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Contacts sur Talky
        if (filteredOnTalky.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'CONTACTS SUR TALKY',
              style: TextStyle(
                color: context.primaryColor,
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
                onTap: () => _startChatWithContact(c.contact),
              )),
        ],

        // Inviter sur Talky
        if (filteredNotOnTalky.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                onTap: () => _inviteContact(contact),
              )),
        ],

        if (_isLoadingContacts)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chargement des contacts...',
                  style: TextStyle(color: context.appThemeColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
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
              hintText: 'Rechercher par numéro ou nom...',
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
                        final displayName = _resolveDisplayName(
                          userName: user['name'] as String?,
                          phone: user['phone'] as String?,
                        );
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

  Future<String?> _getMyPhotoFromFirestore(String uid) async {
    final profile = await ref.read(authServiceProvider).getUserProfile(uid);
    return profile?.photoUrl;
  }

  Future<void> _startChatWithContact(PhoneContact contact) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      // Find the Talky user for this contact
      final chatService = ref.read(chatServiceProvider);
      Map<String, dynamic>? talkyUser;

      for (final phone in contact.phones) {
        final user = await chatService.findUserByPhone(phone);
        if (user != null) {
          talkyUser = user;
          break;
        }
      }

      if (talkyUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur non trouvé sur Talky')),
          );
        }
        return;
      }

      final myName = await ref.read(currentUserNameProvider.future);
      final myPhoto = await _getMyPhotoFromFirestore(currentUser.uid);

      // Use contact's display name for the conversation
      final convId = await chatService.getOrCreateConversation(
        currentUserId: currentUser.uid,
        currentUserName: myName,
        currentUserPhoto: myPhoto,
        otherUserId: talkyUser['id'] as String,
        otherUserName: contact.displayName, // Use phone contact name
        otherUserPhoto: talkyUser['photoUrl'] as String?,
      );

      if (mounted) {
        context.push(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {
            'name': contact.displayName,
            'photo': talkyUser['photoUrl'],
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

  Future<void> _startChatWithUser(Map<String, dynamic> user) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      final myName = await ref.read(currentUserNameProvider.future);
      final myPhoto = await _getMyPhotoFromFirestore(currentUser.uid);

      final displayName = _resolveDisplayName(
        userName: user['name'] as String?,
        phone: user['phone'] as String?,
      );

      final convId =
          await ref.read(chatServiceProvider).getOrCreateConversation(
                currentUserId: currentUser.uid,
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

  void _inviteContact(PhoneContact contact) {
    // Show dialog to send invitation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appThemeColors.surface,
        title: Text('Inviter sur Talky',
            style: TextStyle(color: context.appThemeColors.textPrimary)),
        content: Text(
          'Voulez-vous inviter "${contact.displayName}" à rejoindre Talky?',
          style: TextStyle(color: context.appThemeColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a full implementation, this would send an SMS invitation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invitation envoyée à ${contact.displayName}!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
            ),
            child: Text('Inviter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String _resolveDisplayName({String? userName, String? phone}) {
    if (phone == null || phone.isEmpty) {
      return userName ?? 'Utilisateur';
    }
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return userName ?? 'Utilisateur';
    return _phoneToContactName[normalized] ?? (userName ?? 'Utilisateur');
  }
}

class _ContactWithPhoto {
  final PhoneContact contact;
  final String? photoUrl;

  const _ContactWithPhoto({required this.contact, this.photoUrl});
}

class _PhoneContactTile extends StatelessWidget {
  final PhoneContact contact;
  final bool isOnTalky;
  final String? photoUrl;
  final VoidCallback onTap;

  const _PhoneContactTile({
    required this.contact,
    required this.isOnTalky,
    this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: photoUrl == null ? context.primaryColor : null,
          image: photoUrl != null
              ? DecorationImage(
                  image: NetworkImage(photoUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: photoUrl == null
            ? Center(
                child: Text(
                  contact.displayName.isNotEmpty
                      ? contact.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              )
            : null,
      ),
      title: Text(contact.displayName,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.appThemeColors.textPrimary)),
      subtitle: Text(
        contact.phones.isNotEmpty ? contact.phones.first : '',
        style: TextStyle(
            color: context.appThemeColors.textSecondary, fontSize: 12),
      ),
      trailing: isOnTalky
          ? Icon(Icons.chat_rounded, color: context.primaryColor)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Inviter',
                style: TextStyle(
                  color: context.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
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
    final phone = user['phone'] as String? ?? '';
    final photo = user['photoUrl'] as String?;

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
            ? Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)))
            : null,
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.appThemeColors.textPrimary)),
      subtitle: Text(phone,
          style: TextStyle(
              color: context.appThemeColors.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chat_rounded, color: context.primaryColor),
    );
  }
}
