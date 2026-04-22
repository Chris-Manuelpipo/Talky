// lib/features/auth/domain/user_model.dart
//
// Modèle utilisateur — aligné sur la table MySQL `users`.
// Conserve quelques champs legacy (email, status, preferredLanguage, etc.)
// pour compatibilité avec le code Firestore pas encore migré (auth_service,
// profile_settings, etc.). Ces champs sont optionnels côté backend.

class UserModel {
  final int alanyaID;       // Clé primaire MySQL (0 si inconnu / Firestore-only)
  final String uid;         // UID Firebase (conservé pour l'auth)
  final String name;        // nom
  final String pseudo;      // pseudo
  final String phone;       // alanyaPhone
  final String? photoUrl;   // avatar_url
  final bool isOnline;      // is_online
  final DateTime? lastSeen; // last_seen
  final bool ghostMode;     // exclus

  // ── Champs legacy (Firestore) ──────────────────────────────────────
  final String? email;
  final String status;
  final String preferredLanguage;

  const UserModel({
    this.alanyaID = 0,
    required this.uid,
    required this.name,
    this.pseudo = '',
    required this.phone,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.ghostMode = false,
    this.email,
    this.status = 'Disponible sur Talky',
    this.preferredLanguage = 'fr',
  });

  // ── API REST → UserModel ─────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      alanyaID: json['alanyaID'] as int? ?? 0,
      uid:      json['uid']      as String? ?? '',
      name:     json['nom']      as String? ?? '',
      pseudo:   json['pseudo']   as String? ?? '',
      phone:    json['alanyaPhone'] as String? ?? '',
      photoUrl: json['avatar_url']  as String?,
      isOnline: (json['is_online']  as int? ?? 0) == 1,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      ghostMode: (json['exclus'] as int? ?? 0) == 1,
    );
  }

  // ── Firestore compat (à supprimer une fois les features migrées) ──
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final lastSeenRaw = map['lastSeen'];
    DateTime? lastSeen;
    if (lastSeenRaw is DateTime) {
      lastSeen = lastSeenRaw;
    } else if (lastSeenRaw is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
    } else if (lastSeenRaw != null) {
      try {
        // Firestore Timestamp → toDate()
        final dyn = lastSeenRaw as dynamic;
        lastSeen = dyn.toDate() as DateTime?;
      } catch (_) {}
    }

    return UserModel(
      uid:      (map['uid']   ?? '').toString(),
      name:     (map['name']  ?? '').toString(),
      phone:    (map['phone'] ?? '').toString(),
      email:    map['email']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      status:   (map['status'] ?? 'Disponible sur Talky').toString(),
      preferredLanguage: (map['preferredLanguage'] ?? 'fr').toString(),
      isOnline: map['isOnline'] == true,
      lastSeen: lastSeen,
      ghostMode: map['ghostMode'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':                uid,
    'name':               name,
    'phone':              phone,
    'email':              email,
    'photoUrl':           photoUrl,
    'status':             status,
    'preferredLanguage':  preferredLanguage,
    'isOnline':           isOnline,
    if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
    'ghostMode':          ghostMode,
  };

  // ── UserModel → API REST ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'alanyaID':    alanyaID,
    'nom':         name,
    'pseudo':      pseudo,
    'alanyaPhone': phone,
    'avatar_url':  photoUrl,
    'is_online':   isOnline ? 1 : 0,
  };

  UserModel copyWith({
    String? name,
    String? pseudo,
    String? phone,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    bool? ghostMode,
    String? email,
    String? status,
    String? preferredLanguage,
  }) {
    return UserModel(
      alanyaID:  alanyaID,
      uid:       uid,
      name:      name      ?? this.name,
      pseudo:    pseudo    ?? this.pseudo,
      phone:     phone     ?? this.phone,
      photoUrl:  photoUrl  ?? this.photoUrl,
      isOnline:  isOnline  ?? this.isOnline,
      lastSeen:  lastSeen  ?? this.lastSeen,
      ghostMode: ghostMode ?? this.ghostMode,
      email:     email     ?? this.email,
      status:    status    ?? this.status,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
