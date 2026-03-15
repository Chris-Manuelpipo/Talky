// lib/features/auth/domain/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String status;
  final String preferredLanguage;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool ghostMode;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.status = 'Disponible sur Talky',
    this.preferredLanguage = 'fr',
    this.isOnline = false,
    this.lastSeen,
    this.ghostMode = false,
  });

  // Firestore → UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid:               map['uid'] ?? '',
      name:              map['name'] ?? '',
      phone:             map['phone'] ?? '',
      email:             map['email'],
      photoUrl:          map['photoUrl'],
      status:            map['status'] ?? 'Disponible sur Talky',
      preferredLanguage: map['preferredLanguage'] ?? 'fr',
      isOnline:          map['isOnline'] ?? false,
      lastSeen:          map['lastSeen']?.toDate(),
      ghostMode:         map['ghostMode'] ?? false,
    );
  }

  // UserModel → Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid':               uid,
      'name':              name,
      'phone':             phone,
      'email':             email,
      'photoUrl':          photoUrl,
      'status':            status,
      'preferredLanguage': preferredLanguage,
      'isOnline':          isOnline,
      'lastSeen':          lastSeen,
      'ghostMode':         ghostMode,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    String? status,
    String? preferredLanguage,
    bool? isOnline,
    DateTime? lastSeen,
    bool? ghostMode,
  }) {
    return UserModel(
      uid:               uid,
      name:              name ?? this.name,
      phone:             phone ?? this.phone,
      email:             email ?? this.email,
      photoUrl:          photoUrl ?? this.photoUrl,
      status:            status ?? this.status,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isOnline:          isOnline ?? this.isOnline,
      lastSeen:          lastSeen ?? this.lastSeen,
      ghostMode:         ghostMode ?? this.ghostMode,
    );
  }
}