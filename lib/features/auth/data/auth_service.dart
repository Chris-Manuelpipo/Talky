// lib/features/auth/data/auth_service.dart
//
// Service Auth — Firebase conservé pour OTP/Google Auth uniquement.
// Toutes les opérations de profil passent par l'API REST (MySQL).
// Firestore complètement supprimé.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../domain/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Stream état de connexion ───────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── AUTHENTIFICATION PAR TÉLÉPHONE ────────────────────────────────
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
        verificationCompleted: onAutoVerified,
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
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError('Erreur inattendue: $e');
    }
  }

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

  // ── AUTHENTIFICATION GOOGLE ──────────────────────────────────────
  Future<UserCredential?> signInWithGoogle({
    bool linkIfPossible = true,
    String? phoneHint,
  }) async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      final current = _auth.currentUser;
      if (linkIfPossible && current != null) {
        return await current.linkWithCredential(credential);
      }

      // Vérifier doublon de numéro côté MySQL
      final hint = phoneHint?.trim();
      if (hint != null && hint.isNotEmpty) {
        try {
          final res = await ApiService.instance.phoneExists(hint);
          if (res['exists'] == true) {
            await googleSignIn.signOut();
            throw Exception(
              'Compte déjà lié à ce numéro. '
              'Connectez-vous par SMS puis liez Google.',
            );
          }
        } on ApiException catch (_) {
          // Backend injoignable → on laisse passer
        }
      }

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await googleSignIn.signOut();
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'Un compte existe déjà avec un autre mode. '
          'Connectez-vous d\'abord avec le téléphone, puis liez Google.',
        );
      }
      if (e.code == 'credential-already-in-use') {
        throw Exception('Ce compte Google est déjà lié à un autre utilisateur.');
      }
      rethrow;
    }
  }

  // ── PROFIL UTILISATEUR (REST API) ─────────────────────────────────
  static const _profileCachePrefix = 'user_profile_';
  static const _profileCacheTtl = Duration(hours: 24);

  /// Créer ou mettre à jour le profil dans MySQL via l'API REST
  Future<void> saveUserProfile(UserModel user) async {
    await ApiService.instance.updateMe({
      'nom':        user.name,
      'pseudo':     user.pseudo,
      'avatar_url': user.photoUrl ?? '',
    });

    // Garder Firebase Auth en sync pour displayName (évite "Moi")
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(user.name);
      if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
        await _auth.currentUser!.updatePhotoURL(user.photoUrl);
      }
    }

    await _cacheUser(user);
  }

  /// Récupérer le profil depuis MySQL
  Future<UserModel?> getUserProfile(String uid) async {
    final cacheKey = '$_profileCachePrefix$uid';
    final entry = LocalCache.instance.getEntry(cacheKey);
    if (entry != null) {
      final cached = _deserializeUser(entry.data);
      if (cached != null) {
        if (entry.isExpired) {
          // ignore: unawaited_futures
          _refreshUserProfile(uid);
        }
        return cached;
      }
    }
    return _refreshUserProfile(uid);
  }

  /// Stream de profil — charge initiale REST + mise à jour via Socket présence
  Stream<UserModel?> watchUserProfile(String uid) async* {
    final cacheKey = '$_profileCachePrefix$uid';
    final entry = LocalCache.instance.getEntry(cacheKey);
    if (entry != null) {
      final cached = _deserializeUser(entry.data);
      if (cached != null) yield cached;
    }

    // Charge depuis l'API
    final user = await _refreshUserProfile(uid);
    if (user != null) yield user;

    // Mises à jour live via Socket (présence)
    await for (final event in SocketService.instance.onPresence) {
      if (event.userID.toString() != uid) continue;
      final current = await getUserProfile(uid);
      if (current == null) continue;
      final updated = current.copyWith(isOnline: event.online);
      await _cacheUser(updated);
      yield updated;
    }
  }

  /// Vérifier si le profil est complet
  Future<bool> isProfileComplete(String uid) async {
    final user = await getUserProfile(uid);
    return user != null && user.name.isNotEmpty && user.phone.isNotEmpty;
  }

  Future<UserModel?> _refreshUserProfile(String uid) async {
    try {
      final raw = await ApiService.instance.getMe();
      final user = UserModel.fromJson({...raw, 'uid': uid});
      await _cacheUser(user);
      return user;
    } catch (e) {
      debugPrint('[AuthService._refreshUserProfile] $e');
      return null;
    }
  }

  Future<void> _cacheUser(UserModel user) async {
    await LocalCache.instance.set(
      '$_profileCachePrefix${user.uid}',
      _serializeUser(user),
      ttl: _profileCacheTtl,
    );
  }

  // ── STATUT EN LIGNE (REST API) ────────────────────────────────────
  Future<void> setOnlineStatus(bool isOnline) async {
    try {
      await ApiService.instance.updateMe({'is_online': isOnline ? 1 : 0});
      if (isOnline) {
        SocketService.instance.setOnline();
      } else {
        SocketService.instance.setOffline();
      }
    } catch (e) {
      debugPrint('[AuthService.setOnlineStatus] $e');
    }
  }

  // ── FCM TOKEN (REST API) ──────────────────────────────────────────
  Future<void> saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiService.instance.updateMe({'fcm_token': token});

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await ApiService.instance.updateMe({'fcm_token': newToken});
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[AuthService.saveFcmToken] $e');
    }
  }

  // Alias conservé pour compatibilité avec main.dart / NotificationService
  Future<void> registerTokenForUser(String uid) => saveFcmToken(uid);

  // ── DÉCONNEXION ───────────────────────────────────────────────────
  Future<void> signOut() async {
    await setOnlineStatus(false);
    await SocketService.instance.disconnect();
    await _auth.signOut();
  }

  // ── Helpers sérialisation cache ───────────────────────────────────
  Map<String, dynamic> _serializeUser(UserModel user) => {
    'alanyaID':  user.alanyaID,
    'uid':       user.uid,
    'nom':       user.name,
    'pseudo':    user.pseudo,
    'alanyaPhone': user.phone,
    'avatar_url':  user.photoUrl,
    'is_online': user.isOnline ? 1 : 0,
    'last_seen': user.lastSeen?.toIso8601String(),
    'exclus':    user.ghostMode ? 1 : 0,
  };

  UserModel? _deserializeUser(dynamic data) {
    if (data is! Map) return null;
    return UserModel(
      alanyaID:  data['alanyaID']    as int? ?? 0,
      uid:       data['uid']?.toString() ?? '',
      name:      data['nom']?.toString() ?? '',
      pseudo:    data['pseudo']?.toString() ?? '',
      phone:     data['alanyaPhone']?.toString() ?? '',
      photoUrl:  data['avatar_url']?.toString(),
      isOnline:  (data['is_online'] as int? ?? 0) == 1,
      lastSeen:  data['last_seen'] != null
          ? DateTime.tryParse(data['last_seen'].toString())
          : null,
      ghostMode: (data['exclus'] as int? ?? 0) == 1,
    );
  }
}