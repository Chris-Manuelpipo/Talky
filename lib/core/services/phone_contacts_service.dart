// lib/core/services/phone_contacts_service.dart

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PhoneContact {
  final String id;
  final String displayName;
  final List<String> phones;

  const PhoneContact({
    required this.id,
    required this.displayName,
    required this.phones,
  });
}

class PhoneContactsService {
  List<PhoneContact>? _cachedContacts;
  Future<List<PhoneContact>>? _inFlightFetch;
  Map<String, String> _cachedNameByPhone = {};

  /// Demander la permission d'accéder aux contacts
  Future<bool> requestPermission() async {
    // Vérifier d'abord le statut actuel
    final status = await Permission.contacts.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      // La permission est définitivement refusée, ouvrir les paramètres
      await openAppSettings();
      return false;
    }
    
    // Demander la permission
    final result = await Permission.contacts.request();
    return result.isGranted;
  }

  /// Vérifier si la permission est accordée
  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Précharger les contacts si la permission est déjà accordée
  Future<void> warmUpIfPermitted() async {
    final permitted = await hasPermission();
    if (!permitted) return;
    // Déclenche un préchargement en arrière-plan
    // ignore: unawaited_futures
    getContactsCached();
  }

  /// Récupérer tous les contacts du téléphone (avec cache mémoire)
  Future<List<PhoneContact>> getContactsCached({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedContacts != null) {
      return _cachedContacts!;
    }
    if (!forceRefresh && _inFlightFetch != null) {
      return _inFlightFetch!;
    }

    _inFlightFetch = _getContactsFromPlatform();
    try {
      final contacts = await _inFlightFetch!;
      _cachedContacts = contacts;
      _buildNameCache(contacts);
      return contacts;
    } finally {
      _inFlightFetch = null;
    }
  }

  /// Récupérer tous les contacts du téléphone (accès direct plateforme)
  Future<List<PhoneContact>> _getContactsFromPlatform() async {
    try {
      // Using platform channel to get contacts
      final result = await const MethodChannel('com.example.talky/contacts')
          .invokeMethod<List<dynamic>>('getContacts');

      // ignore: avoid_print
      print('[PhoneContacts] Raw result: $result');

      if (result == null) {
        // ignore: avoid_print
        print('[PhoneContacts] Result is null, returning empty list');
        return [];
      }

      // ignore: avoid_print
      print('[PhoneContacts] Found ${result.length} contacts');

      return result.map((contact) {
        // Handle both Map<String, dynamic> and Map<Object?, Object?> types
        final Map<String, dynamic> c;
        if (contact is Map<String, dynamic>) {
          c = contact;
        } else if (contact is Map) {
          c = {};
          contact.forEach((key, value) {
            c[key.toString()] = value;
          });
        } else {
          return PhoneContact(id: '', displayName: 'Inconnu', phones: []);
        }
        
        // Handle phones list - may also need conversion
        List<String> phoneList = [];
        final phonesData = c['phones'];
        if (phonesData is List) {
          phoneList = phonesData.map((e) => e.toString()).toList();
        } else if (phonesData is List<String>) {
          phoneList = phonesData;
        }
        
        return PhoneContact(
          id: c['id']?.toString() ?? '',
          displayName: c['displayName']?.toString() ?? 'Inconnu',
          phones: phoneList,
        );
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[PhoneContacts] Error getting contacts: $e');
      // Fallback: try using flutter_contacts if available
      return _getContactsUsingPackage();
    }
  }

  /// Récupérer tous les contacts du téléphone (alias compat)
  Future<List<PhoneContact>> getContacts() async {
    return getContactsCached();
  }

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String resolveNameFromCache({
    required String fallbackName,
    String? phone,
  }) {
    if (phone == null || phone.isEmpty) return fallbackName;
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return fallbackName;
    return _cachedNameByPhone[normalized] ?? fallbackName;
  }

  Future<String> resolveName({
    required String fallbackName,
    String? phone,
  }) async {
    await getContactsCached();
    return resolveNameFromCache(fallbackName: fallbackName, phone: phone);
  }

  void _buildNameCache(List<PhoneContact> contacts) {
    final map = <String, String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = normalizePhone(phone);
        if (normalized.isNotEmpty) {
          map[normalized] = contact.displayName;
        }
      }
    }
    _cachedNameByPhone = map;
  }

  Future<List<PhoneContact>> _getContactsUsingPackage() async {
    // This is a fallback that would require adding flutter_contacts package
    // For now, return empty list
    return [];
  }

  /// Rechercher un contact par téléphone dans la liste des contacts
  PhoneContact? findContactByPhone(List<PhoneContact> contacts, String phone) {
    // Normalize phone number for comparison
    final normalizedPhone = _normalizePhoneNumber(phone);

    for (final contact in contacts) {
      for (final contactPhone in contact.phones) {
        if (_normalizePhoneNumber(contactPhone) == normalizedPhone) {
          return contact;
        }
      }
    }
    return null;
  }

  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }
}
