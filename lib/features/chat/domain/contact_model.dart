// lib/features/chat/domain/contact_model.dart
//
// Contact local — lien entre un utilisateur Talky (alanyaID) et un nom/photo
// personnalisé par l'utilisateur courant.
// Stocké en local (Hive) et non côté backend.

class ContactModel {
  /// alanyaID du contact (stocké en String pour compat UI).
  final String id;
  final int alanyaID;
  final String contactName;
  final String? contactPhoto;
  final String? phoneNumber;
  final DateTime addedAt;

  const ContactModel({
    required this.id,
    required this.alanyaID,
    required this.contactName,
    this.contactPhoto,
    this.phoneNumber,
    required this.addedAt,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map, [String? forcedId]) {
    final alanyaID = map['alanyaID'] is int
        ? map['alanyaID'] as int
        : int.tryParse(map['alanyaID']?.toString() ?? '') ?? 0;
    final id = forcedId ?? map['id']?.toString() ?? alanyaID.toString();
    return ContactModel(
      id: id,
      alanyaID: alanyaID,
      contactName: (map['contactName'] ?? 'Utilisateur').toString(),
      contactPhoto: map['contactPhoto']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      addedAt: map['addedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int)
          : (map['addedAt'] is String
              ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'alanyaID': alanyaID,
        'contactName': contactName,
        'contactPhoto': contactPhoto,
        'phoneNumber': phoneNumber,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}
