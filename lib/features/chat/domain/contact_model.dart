// lib/features/chat/domain/contact_model.dart

class ContactModel {
  final String id; // The other user's ID
  final String contactName; // The name the user saved for this contact
  final String? contactPhoto;
  final String? phoneNumber;
  final DateTime addedAt;

  const ContactModel({
    required this.id,
    required this.contactName,
    this.contactPhoto,
    this.phoneNumber,
    required this.addedAt,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map, String id) {
    return ContactModel(
      id: id,
      contactName: map['contactName'] ?? 'Utilisateur',
      contactPhoto: map['contactPhoto'],
      phoneNumber: map['phoneNumber'],
      addedAt: (map['addedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contactName': contactName,
      'contactPhoto': contactPhoto,
      'phoneNumber': phoneNumber,
      'addedAt': addedAt,
    };
  }
}