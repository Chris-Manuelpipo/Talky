// lib/features/calls/data/call_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'call_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';

final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService();

  // Connecter immédiatement si déjà connecté
  final user = ref.read(authStateProvider).value;
  if (user != null) {
    service.connect(user.uid);
  }

  // Connecter au serveur dès que l'utilisateur est connecté
  ref.listen(authStateProvider, (_, next) {
    final user = next.value;
    if (user != null) {
      service.connect(user.uid);
    } else {
      service.disconnect();
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

// Notifier pour l'état d'un appel en cours
enum CallStatus { idle, calling, ringing, connected, ended }

class CallState {
  final CallStatus status;
  final String? remoteUserId;
  final String? remoteName;
  final String? remotePhoto;
  final bool isVideo;
  final bool isMuted;
  final bool isCameraOff;
  final IncomingCallData? incomingCall;
  final String? errorMessage;

  const CallState({
    this.status      = CallStatus.idle,
    this.remoteUserId,
    this.remoteName,
    this.remotePhoto,
    this.isVideo     = false,
    this.isMuted     = false,
    this.isCameraOff = false,
    this.incomingCall,
    this.errorMessage,
  });

  CallState copyWith({
    CallStatus? status,
    String? remoteUserId,
    String? remoteName,
    String? remotePhoto,
    bool? isVideo,
    bool? isMuted,
    bool? isCameraOff,
    IncomingCallData? incomingCall,
    String? errorMessage,
  }) => CallState(
    status:       status       ?? this.status,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    remoteName:   remoteName   ?? this.remoteName,
    remotePhoto:  remotePhoto  ?? this.remotePhoto,
    isVideo:      isVideo      ?? this.isVideo,
    isMuted:      isMuted      ?? this.isMuted,
    isCameraOff:  isCameraOff  ?? this.isCameraOff,
    incomingCall: incomingCall ?? this.incomingCall,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class CallNotifier extends StateNotifier<CallState> {
  final CallService _service;
  final Ref _ref;

  CallNotifier(this._service, this._ref) : super(const CallState()) {
    _listenEvents();
  }

  void _listenEvents() {
    _service.events.listen((event) {
      switch (event) {
        case CallEvent.callAnswered:
          state = state.copyWith(status: CallStatus.calling);
          break;
        case CallEvent.callConnected:
          state = state.copyWith(status: CallStatus.connected);
          break;
        case CallEvent.callRejected:
          state = const CallState();
          break;
        case CallEvent.callEnded:
          state = const CallState();
          break;
        case CallEvent.callFailed:
          state = state.copyWith(
            status: CallStatus.idle,
            errorMessage: _mapError(_service.lastError),
          );
          break;
        case CallEvent.incomingCall:
          break;
      }
    });

    _service.incomingCalls.listen((incoming) {
      state = state.copyWith(
        status:      CallStatus.ringing,
        incomingCall: incoming,
        remoteName:  incoming.callerName,
        remotePhoto: incoming.callerPhoto,
        isVideo:     incoming.isVideo,
      );
    });
  }

  Future<void> startCall({
    required String targetUserId,
    required String targetName,
    String? targetPhoto,
    required bool isVideo,
  }) async {
    final user   = _ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await _ref.read(currentUserNameProvider.future);

    state = state.copyWith(
      status:       CallStatus.calling,
      remoteUserId: targetUserId,
      remoteName:   targetName,
      remotePhoto:  targetPhoto,
      isVideo:      isVideo,
      errorMessage: null,
    );

    await _service.callUser(
      targetUserId: targetUserId,
      callerName:   myName,
      isVideo:      isVideo,
    );
  }

  Future<void> answerCall() async {
    if (state.incomingCall == null) return;
    await _service.answerCall(state.incomingCall!);
    state = state.copyWith(
      status:       CallStatus.calling,
      remoteUserId: state.incomingCall!.callerId,
    );
  }

  void rejectCall() {
    if (state.incomingCall != null) {
      _service.rejectCall(state.incomingCall!.callerId);
    }
    state = const CallState();
  }

  void endCall() {
    _service.endCall();
    state = const CallState();
  }

  void toggleMute() {
    _service.toggleMute();
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void toggleCamera() {
    _service.toggleCamera();
    state = state.copyWith(isCameraOff: !state.isCameraOff);
  }

  Future<void> switchCamera() => _service.switchCamera();

  String? _mapError(String? reason) {
    switch (reason) {
      case 'user_offline':
        return 'L’utilisateur n’est pas connecté';
      default:
        return reason == null ? 'Échec de l’appel' : 'Erreur: $reason';
    }
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  final service = ref.watch(callServiceProvider);
  return CallNotifier(service, ref);
});
