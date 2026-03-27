// lib/features/auth/data/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/cache/local_cache.dart';
import '../domain/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Stream état de connexion ───────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ── AUTHENTIFICATION PAR TÉLÉPHONE ────────────────────────────────

  /// Étape 1 : Envoyer le code SMS
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-vérification (Android seulement)
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String message = 'Erreur de vérification';
          if (e.code == 'invalid-phone-number') {
            message = 'Numéro de téléphone invalide';
          } else if (e.code == 'too-many-requests') {
            message = 'Trop de tentatives. Réessayez plus tard.';
          } else if (e.code == 'quota-exceeded') {
            message = 'Quota SMS dépassé. Réessayez demain.';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Erreur inattendue: $e');
    }
  }

  /// Étape 2 : Vérifier le code SMS
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── PROFIL UTILISATEUR ────────────────────────────────────────────
  static const _profileCachePrefix = 'user_profile_';
  static const _profileCacheTtl = Duration(hours: 24);

  /// Créer ou mettre à jour le profil dans Firestore
  Future<void> saveUserProfile(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));

    // Garder Firebase Auth en sync (évite "Moi" si displayName est null)
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(user.name);
      if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
        await _auth.currentUser!.updatePhotoURL(user.photoUrl);
      }
    }

    await LocalCache.instance.set(
      '$_profileCachePrefix${user.uid}',
      _serializeUser(user),
      ttl: _profileCacheTtl,
    );
  }

  /// Récupérer le profil depuis Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    final cacheKey = '$_profileCachePrefix$uid';
    final entry = LocalCache.instance.getEntry(cacheKey);
    if (entry != null) {
      final cached = _deserializeUser(entry.data);
      if (cached != null) {
        if (entry.isExpired) {
          // Refresh en arrière-plan
          // ignore: unawaited_futures
          _refreshUserProfile(uid);
        }
        return cached;
      }
    }

    return _refreshUserProfile(uid);
  }

  /// Stream de profil (cache immédiat + mises à jour live)
  Stream<UserModel?> watchUserProfile(String uid) async* {
    final cacheKey = '$_profileCachePrefix$uid';
    final entry = LocalCache.instance.getEntry(cacheKey);
    if (entry != null) {
      final cached = _deserializeUser(entry.data);
      if (cached != null) {
        yield cached;
      }
    }

    yield* _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final user = UserModel.fromMap(doc.data()!);
      // Best-effort cache update
      // ignore: unawaited_futures
      LocalCache.instance.set(
        cacheKey,
        _serializeUser(user),
        ttl: _profileCacheTtl,
      );
      return user;
    });
  }

  /// Prefetch cache pour une liste d'utilisateurs
  Future<void> prefetchUserProfiles(List<String> uids) async {
    final unique = <String>{};
    for (final uid in uids) {
      if (uid.trim().isNotEmpty) unique.add(uid);
    }
    if (unique.isEmpty) return;

    final toFetch = <String>[];
    for (final uid in unique) {
      final entry = LocalCache.instance.getEntry('$_profileCachePrefix$uid');
      if (entry == null || entry.isExpired) {
        toFetch.add(uid);
      }
    }
    if (toFetch.isEmpty) return;

    const batchSize = 10;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      final end = (i + batchSize > toFetch.length) ? toFetch.length : i + batchSize;
      final batch = toFetch.sublist(i, end);
      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final user = UserModel.fromMap(doc.data());
          await LocalCache.instance.set(
            '$_profileCachePrefix${doc.id}',
            _serializeUser(user),
            ttl: _profileCacheTtl,
          );
        }
      } catch (_) {
        // Fallback: fetch individuel
        for (final uid in batch) {
          await _refreshUserProfile(uid);
        }
      }
    }
  }

  /// Vérifier si le profil est complet (nom renseigné)
  Future<bool> isProfileComplete(String uid) async {
    final user = await getUserProfile(uid);
    return user != null && user.name.isNotEmpty;
  }

  Future<UserModel?> _refreshUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final user = UserModel.fromMap(doc.data()!);
      await LocalCache.instance.set(
        '$_profileCachePrefix$uid',
        _serializeUser(user),
        ttl: _profileCacheTtl,
      );
      return user;
    }
    return null;
  }

  Map<String, dynamic> _serializeUser(UserModel user) {
    return {
      'uid': user.uid,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'status': user.status,
      'preferredLanguage': user.preferredLanguage,
      'isOnline': user.isOnline,
      'lastSeenMs': user.lastSeen?.millisecondsSinceEpoch,
      'ghostMode': user.ghostMode,
    };
  }

  UserModel? _deserializeUser(dynamic data) {
    if (data is! Map) return null;
    return UserModel(
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      status: data['status']?.toString() ?? 'Disponible sur Talky',
      preferredLanguage: data['preferredLanguage']?.toString() ?? 'fr',
      isOnline: data['isOnline'] == true,
      lastSeen: data['lastSeenMs'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSeenMs'] as int)
          : null,
      ghostMode: data['ghostMode'] == true,
    );
  }

  /// Mettre à jour le statut en ligne
  Future<void> setOnlineStatus(bool isOnline) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // ── FCM ───────────────────────────────────────────────────────────
  Future<void> saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(userId).update({
          'fcmToken': newToken,
        });
      });
    } catch (_) {
      // Best-effort: FCM token may be unavailable on some devices.
    }
  }

  // ── DÉCONNEXION ───────────────────────────────────────────────────
  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _auth.signOut();
  }
}
