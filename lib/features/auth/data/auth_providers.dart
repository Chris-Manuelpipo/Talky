// lib/features/auth/data/auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import '../domain/user_model.dart';

// ── Service Auth ───────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── Stream : état de connexion Firebase ───────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── Provider : profil utilisateur courant ─────────────────────────────
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      return ref.read(authServiceProvider).getUserProfile(user.uid);
    },
    loading: () => null,
    error: (_, __) => null,
  );
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
      isLoading:      isLoading      ?? this.isLoading,
      codeSent:       codeSent       ?? this.codeSent,
      isVerified:     isVerified     ?? this.isVerified,
      verificationId: verificationId ?? this.verificationId,
      error:          error,
    );
  }
}

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>((ref) {
  return OtpNotifier(ref.read(authServiceProvider));
});