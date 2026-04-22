// lib/features/chat/data/contact_local_store.dart
//
// Stockage local des contacts Talky (phonebook → utilisateur Talky).
// Basé sur Hive. Chaque utilisateur (courant) a sa propre box identifiée
// par son alanyaID.

import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/contact_model.dart';

class ContactLocalStore {
  ContactLocalStore._();
  static final ContactLocalStore instance = ContactLocalStore._();

  static const _boxPrefix = 'talky_contacts_';

  final Map<int, Box<Map>> _boxes = {};
  final Map<int, StreamController<List<ContactModel>>> _controllers = {};

  String _boxName(int ownerID) => '$_boxPrefix$ownerID';

  Future<Box<Map>> _box(int ownerID) async {
    final existing = _boxes[ownerID];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox<Map>(_boxName(ownerID));
    _boxes[ownerID] = box;
    return box;
  }

  StreamController<List<ContactModel>> _controllerFor(int ownerID) {
    return _controllers.putIfAbsent(
      ownerID,
      () => StreamController<List<ContactModel>>.broadcast(),
    );
  }

  Future<List<ContactModel>> _readAll(int ownerID) async {
    final box = await _box(ownerID);
    final list = box.values
        .map((raw) => ContactModel.fromMap(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  Future<void> _emit(int ownerID) async {
    final list = await _readAll(ownerID);
    _controllerFor(ownerID).add(list);
  }

  // ── API publique ────────────────────────────────────────────────────
  Stream<List<ContactModel>> watchContacts(int ownerID) async* {
    final initial = await _readAll(ownerID);
    final ctrl = _controllerFor(ownerID);
    yield initial;
    yield* ctrl.stream;
  }

  Future<List<ContactModel>> listContacts(int ownerID) => _readAll(ownerID);

  Future<void> addOrUpdateContact({
    required int ownerID,
    required int alanyaID,
    required String contactName,
    String? contactPhoto,
    String? phoneNumber,
  }) async {
    if (alanyaID <= 0) return;
    final box = await _box(ownerID);
    final contact = ContactModel(
      id: alanyaID.toString(),
      alanyaID: alanyaID,
      contactName: contactName,
      contactPhoto: contactPhoto,
      phoneNumber: phoneNumber,
      addedAt: DateTime.now(),
    );
    await box.put(alanyaID.toString(), contact.toMap());
    await _emit(ownerID);
  }

  Future<void> removeContact({
    required int ownerID,
    required int alanyaID,
  }) async {
    final box = await _box(ownerID);
    await box.delete(alanyaID.toString());
    await _emit(ownerID);
  }

  Future<bool> isContact({
    required int ownerID,
    required int alanyaID,
  }) async {
    final box = await _box(ownerID);
    return box.containsKey(alanyaID.toString());
  }

  Future<ContactModel?> getContact({
    required int ownerID,
    required int alanyaID,
  }) async {
    final box = await _box(ownerID);
    final raw = box.get(alanyaID.toString());
    if (raw == null) return null;
    return ContactModel.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> clear(int ownerID) async {
    final box = await _box(ownerID);
    await box.clear();
    await _emit(ownerID);
  }
}
