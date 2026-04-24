// lib/features/auth/data/auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/api_service.dart';
import 'auth_service.dart';
import 'backend_user_providers.dart';
import '../domain/user_model.dart';

// ── Service Auth ───────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── State connexion custom (email + password) ────────────────────────
class AuthCustomState {
  final bool isLoggedIn;
  final UserModel? user;
  final String? token;

  const AuthCustomState({
    this.isLoggedIn = false,
    this.user,
    this.token,
  });

  AuthCustomState copyWith({
    bool? isLoggedIn,
    UserModel? user,
    String? token,
  }) {
    return AuthCustomState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      token: token ?? this.token,
    );
  }
}

class AuthCustomNotifier extends StateNotifier<AuthCustomState> {
  AuthCustomNotifier() : super(const AuthCustomState());

  void setUser(UserModel user, String token) {
    state = AuthCustomState(isLoggedIn: true, user: user, token: token);
  }

  void logout() {
    ApiService.instance.logout();
    state = const AuthCustomState();
  }
}

final authCustomProvider =
    StateNotifierProvider<AuthCustomNotifier, AuthCustomState>((ref) {
  return AuthCustomNotifier();
});

// ── Stream : état de connexion Firebase (conservé pour OTP/Google optionnel) ──
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── Provider : profil utilisateur courant (backend /api/auth/me) ──────
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  return ref.watch(currentBackendUserProvider.future);
});

// ── Stream : profil utilisateur par ID (backend + live presence socket) ─
// L'ID attendu est maintenant l'alanyaID sérialisé en String (ex: "42").
final userProfileStreamProvider =
    StreamProvider.family<UserModel?, String>((ref, id) {
  final alanyaID = int.tryParse(id);
  if (alanyaID == null || alanyaID <= 0) {
    return const Stream.empty();
  }
  return ref.watch(backendUserStreamProvider(alanyaID).stream);
});

// ── Prefetch cache pour une liste d'utilisateurs ──────────────────────
final prefetchUserProfilesProvider =
    FutureProvider.family<void, List<String>>((ref, ids) async {
  final alanyaIDs = <int>[];
  for (final id in ids) {
    final i = int.tryParse(id);
    if (i != null && i > 0) alanyaIDs.add(i);
  }
  if (alanyaIDs.isEmpty) return;
  await ref.read(prefetchBackendUsersProvider(alanyaIDs).future);
});

// ── Notifier : gestion du flux OTP ────────────────────────────────────
class OtpNotifier extends StateNotifier<OtpState> {
  final AuthService _authService;

  OtpNotifier(this._authService) : super(const OtpState());

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verificationId,
          codeSent: true,
        );
      },
      onError: (error) {
        state = state.copyWith(isLoading: false, error: error);
      },
      onAutoVerified: (credential) async {
        state = state.copyWith(isLoading: true);
        await _authService.verifyOtp(
          verificationId: state.verificationId!,
          smsCode: '',
        );
        state = state.copyWith(isLoading: false, isVerified: true);
      },
    );
  }

  Future<bool> verifyOtp(String smsCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _authService.verifyOtp(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      if (result != null) {
        state = state.copyWith(isLoading: false, isVerified: true);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Code incorrect');
      return false;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: 'Code invalide: $e');
      return false;
    }
  }

  void reset() => state = const OtpState();
}

class OtpState {
  final bool isLoading;
  final bool codeSent;
  final bool isVerified;
  final String? verificationId;
  final String? error;

  const OtpState({
    this.isLoading = false,
    this.codeSent = false,
    this.isVerified = false,
    this.verificationId,
    this.error,
  });

  OtpState copyWith({
    bool? isLoading,
    bool? codeSent,
    bool? isVerified,
    String? verificationId,
    String? error,
  }) {
    return OtpState(
      isLoading: isLoading ?? this.isLoading,
      codeSent: codeSent ?? this.codeSent,
      isVerified: isVerified ?? this.isVerified,
      verificationId: verificationId ?? this.verificationId,
      error: error,
    );
  }
}

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>((ref) {
  return OtpNotifier(ref.read(authServiceProvider));
});
