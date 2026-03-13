// lib/features/auth/data/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  /// Récupérer le profil depuis Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Vérifier si le profil est complet (nom renseigné)
  Future<bool> isProfileComplete(String uid) async {
    final user = await getUserProfile(uid);
    return user != null && user.name.isNotEmpty;
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

  // ── DÉCONNEXION ───────────────────────────────────────────────────
  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _auth.signOut();
  }
}
