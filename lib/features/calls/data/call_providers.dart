import '../../../core/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'call_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../domain/call_history_model.dart';

// APRÈS
final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService();

  // Connexion immédiate si l'alanyaID est déjà résolu (session active)
  final alanyaID = ref.read(currentAlanyaIDProvider);
  if (alanyaID != null) {
    service.connect(alanyaID.toString());
  }

  // Connexion / déconnexion au changement d'alanyaID (login / logout)
  ref.listen<int?>(currentAlanyaIDProvider, (prev, next) {
    if (next != null) {
      service.connect(next.toString());
    } else {
      service.disconnect();
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

// Notifier pour l'état d'un appel en cours
enum CallStatus { idle, calling, ringing, connected, ended }

class GroupParticipant {
  final String id;
  final String name;
  final String? photo;

  const GroupParticipant({
    required this.id,
    required this.name,
    this.photo,
  });
}

class CallState {
  final CallStatus status;
  final String? remoteUserId;
  final String? remoteName;
  final String? remotePhoto;
  final bool isGroup;
  final String? groupRoomId;
  final List<GroupParticipant> groupParticipants;
  final bool isVideo;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final IncomingCallData? incomingCall;
  final String? errorMessage;

  const CallState({
    this.status      = CallStatus.idle,
    this.remoteUserId,
    this.remoteName,
    this.remotePhoto,
    this.isGroup     = false,
    this.groupRoomId,
    this.groupParticipants = const [],
    this.isVideo     = false,
    this.isMuted     = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.incomingCall,
    this.errorMessage,
  });

  CallState copyWith({
    CallStatus? status,
    String? remoteUserId,
    String? remoteName,
    String? remotePhoto,
    bool? isGroup,
    String? groupRoomId,
    List<GroupParticipant>? groupParticipants,
    bool? isVideo,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    IncomingCallData? incomingCall,
    String? errorMessage,
  }) => CallState(
    status:       status       ?? this.status,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    remoteName:   remoteName   ?? this.remoteName,
    remotePhoto:  remotePhoto  ?? this.remotePhoto,
    isGroup:      isGroup      ?? this.isGroup,
    groupRoomId:  groupRoomId  ?? this.groupRoomId,
    groupParticipants: groupParticipants ?? this.groupParticipants,
    isVideo:      isVideo      ?? this.isVideo,
    isMuted:      isMuted      ?? this.isMuted,
    isCameraOff:  isCameraOff  ?? this.isCameraOff,
    isSpeakerOn:  isSpeakerOn  ?? this.isSpeakerOn,
    incomingCall: incomingCall ?? this.incomingCall,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class CallNotifier extends StateNotifier<CallState> {
  final CallService _service;
  final Ref _ref;
  DateTime? _callStartTime;
  String? _pendingTargetUserId;
  String? _pendingTargetName;
  String? _pendingTargetPhoto;
  bool _isOutgoing = true;
  final Map<String, GroupParticipant> _groupParticipants = {};

  CallNotifier(this._service, this._ref) : super(const CallState()) {
    debugPrint('[CallNotifier] >>> Initializing CallNotifier');
    _listenEvents();
    debugPrint('[CallNotifier] >>> Event listeners registered');
  }

  void _listenEvents() {
    // SYNC listener first - minimal delay for status updates
    _service.events.listen((event) {
      if (event == CallEvent.callConnected) {
        debugPrint('[CallNotifier] [SYNC] CallConnected detected - updating status immediately');
        _callStartTime = DateTime.now();
        state = state.copyWith(status: CallStatus.connected);
        debugPrint('[CallNotifier] [SYNC] Status updated to CONNECTED - state is now: ${state.status}');
      }
    }, onError: (error) {
      debugPrint('[CallNotifier] [SYNC] Error in listener: $error');
    });

    // ASYNC listener for non-status events (DB saves, etc)
    _service.events.listen((event) async {
      debugPrint('[CallNotifier] [ASYNC] Event received: $event');
      switch (event) {
        case CallEvent.callAnswered:
          // C'est juste un détail de signaling - ne pas changer le statut UI
          // Le status ne change qu'avec callConnected
          break;
        case CallEvent.callConnected:
          // Status already updated by SYNC listener above
          // This async listener only handles DB operations
          debugPrint('[CallNotifier] [ASYNC] CallConnected received - DB operations only');
          // Status update is handled by SYNC listener for zero-delay UI responsiveness
          break;
        case CallEvent.callRejected:
          // Sauvegarder l'appel manqué
          await _saveMissedCall();
          state = const CallState();
          break;
        case CallEvent.callEnded:
          // Sauvegarder l'appel terminé
          await _saveCompletedCall();
          state = const CallState();
          break;
        case CallEvent.callFailed:
          // Sauvegarder l'appel manqué en cas d'échec
          await _saveMissedCall();
          state = state.copyWith(
            status: CallStatus.idle,
            errorMessage: _mapError(_service.lastError),
          );
          break;
        case CallEvent.incomingCall:
          break;
      }
    }, onError: (error) {
      debugPrint('[CallNotifier] [ASYNC] Error in listener: $error');
    });

    _service.incomingCalls.listen((incoming) {
      state = state.copyWith(
        status:      CallStatus.ringing,
        incomingCall: incoming,
        remoteName:  incoming.callerName,
        remotePhoto: incoming.callerPhoto,
        isVideo:     incoming.isVideo,
        isGroup:     incoming.isGroup,
        groupRoomId: incoming.roomId,
      );
    });

    _service.groupEvents.listen((event) {
      if (event.type == 'participants' && event.participants != null) {
        // Reset list with ids only (names will be updated on join events)
        _groupParticipants.clear();
        for (final id in event.participants!) {
          _groupParticipants[id] = GroupParticipant(id: id, name: 'Utilisateur');
        }
      } else if (event.type == 'user_joined' && event.userId != null) {
        _groupParticipants[event.userId!] = GroupParticipant(
          id: event.userId!,
          name: event.userName ?? 'Utilisateur',
          photo: event.userPhoto,
        );
      } else if (event.type == 'user_left' && event.userId != null) {
        _groupParticipants.remove(event.userId!);
      }
      state = state.copyWith(
        groupParticipants: _groupParticipants.values.toList(),
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

    // Stocker les infos pour le保存
    _pendingTargetUserId = targetUserId;
    _pendingTargetName = targetName;
    _pendingTargetPhoto = targetPhoto;
    _isOutgoing = true;
    _callStartTime = null;

    state = state.copyWith(
      status:       CallStatus.calling,
      remoteUserId: targetUserId,
      remoteName:   targetName,
      remotePhoto:  targetPhoto,
      isVideo:      isVideo,
      isSpeakerOn:  false,
      errorMessage: null,
    );

    // Initialiser l'audio sur écouteur AVANT de lancer l'appel
    await _service.initializeCallAudio();

    await _service.callUser(
      targetUserId: targetUserId,
      callerName:   myName,
      isVideo:      isVideo,
    );
  }

  Future<void> startGroupCall({
    required List<String> targetUserIds,
    required bool isVideo,
    List<GroupParticipant> initialParticipants = const [],
    String groupName = 'Appel de groupe',
  }) async {
    // APRÈS
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await _ref.read(currentUserNameProvider.future);
    final myPhoto = user.photoURL;

    // Utiliser alanyaID pour le roomId (cohérent avec le signaling server)
    final alanyaID = _ref.read(currentAlanyaIDProvider);
    if (alanyaID == null) return;
    final roomId = '${alanyaID}_${DateTime.now().millisecondsSinceEpoch}';
    _isOutgoing = true;
    _callStartTime = null;
    _pendingTargetUserId = null;
    _pendingTargetName = 'Appel de groupe';
    _pendingTargetPhoto = null;

    _groupParticipants.clear();
    for (final p in initialParticipants) {
      _groupParticipants[p.id] = p;
    }

    state = state.copyWith(
      status: CallStatus.calling,
      isGroup: true,
      groupRoomId: roomId,
      groupParticipants: _groupParticipants.values.toList(),
      isVideo: isVideo,
      remoteName: groupName,
      remotePhoto: null,
      isSpeakerOn: false,
      errorMessage: null,
    );

    // Initialiser l'audio sur écouteur AVANT de lancer l'appel
    await _service.initializeCallAudio();

    await _service.startGroupCall(
      roomId: roomId,
      callerName: myName,
      callerPhoto: myPhoto,
      isVideo: isVideo,
      targetUserIds: targetUserIds,
    );
  }

  Future<void> answerCall() async {
    if (state.incomingCall == null) return;
    
    // Stocker les infos pour l'appel entrant
    _pendingTargetUserId = state.incomingCall!.callerId;
    _pendingTargetName = state.incomingCall!.callerName;
    _pendingTargetPhoto = state.incomingCall!.callerPhoto;
    _isOutgoing = false;
    _callStartTime = null;
    
    await _service.answerCall(state.incomingCall!);
    state = state.copyWith(
      status:       CallStatus.calling,
      remoteUserId: state.incomingCall!.callerId,
      isSpeakerOn:  false,
    );
  }

  Future<void> answerGroupCall() async {
    if (state.incomingCall == null) return;
    final incoming = state.incomingCall!;
    if (incoming.roomId == null || incoming.roomId!.isEmpty) return;
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await _ref.read(currentUserNameProvider.future);

    // alanyaID requis pour l'identification dans la room de groupe
    final alanyaID = _ref.read(currentAlanyaIDProvider);
    if (alanyaID == null) return;

    _isOutgoing = false;
    _callStartTime = null;

    await _service.joinGroupCall(
      roomId: incoming.roomId!,
      userId: alanyaID.toString(), // ← CORRIGÉ
      userName: myName,
      userPhoto: user.photoURL,
      isVideo: incoming.isVideo,
    );

    state = state.copyWith(
      status: CallStatus.calling,
      isGroup: true,
      groupRoomId: incoming.roomId,
      isVideo: incoming.isVideo,
      remoteName: incoming.callerName,
      remotePhoto: incoming.callerPhoto,
      incomingCall: incoming,
      isSpeakerOn: false,
    );
  }

  void rejectCall() {
    if (state.incomingCall != null) {
      _pendingTargetUserId = state.incomingCall!.callerId;
      _pendingTargetName = state.incomingCall!.callerName;
      _pendingTargetPhoto = state.incomingCall!.callerPhoto;
      _isOutgoing = false;
      
      _service.rejectCall(state.incomingCall!.callerId);
      _saveMissedCall();
    }
    state = const CallState();
  }

  void rejectGroupCall() {
    _service.leaveGroupCall();
    state = const CallState();
  }

  void leaveGroupCall() {
    _service.leaveGroupCall();
    state = const CallState();
  }

  void setIncomingCallData(IncomingCallData incoming) {
    state = state.copyWith(
      status:      CallStatus.ringing,
      incomingCall: incoming,
      remoteName:  incoming.callerName,
      remotePhoto: incoming.callerPhoto,
      isVideo:     incoming.isVideo,
      isGroup:     incoming.isGroup,
      groupRoomId: incoming.roomId,
    );
  }

  Future<void> _saveCompletedCall() async {
    if (state.isGroup) {
      final user = _ref.read(authStateProvider).value;
      if (user == null) return;
      final myName = await _ref.read(currentUserNameProvider.future);
      final myPhoto = user.photoURL;

      int durationSeconds = 0;
      if (_callStartTime != null) {
        durationSeconds = DateTime.now().difference(_callStartTime!).inSeconds;
      }

      final historyService = _ref.read(callHistoryServiceProvider);
      final participantIds = state.groupParticipants.map((p) => p.id).toList();
      final participantNames = {
        for (final p in state.groupParticipants) p.id: p.name,
      };
      final participantPhotos = {
        for (final p in state.groupParticipants) p.id: p.photo,
      };
      await historyService.saveCallHistory(
        currentUserId: user.uid,
        currentUserName: myName,
        currentUserPhoto: myPhoto,
        targetUserId: state.groupRoomId ?? 'group',
        targetUserName: state.remoteName ?? 'Appel de groupe',
        targetUserPhoto: null,
        isGroup: true,
        groupName: state.remoteName ?? 'Appel de groupe',
        participantIds: participantIds,
        participantNames: participantNames,
        participantPhotos: participantPhotos,
        type: _isOutgoing ? CallType.outgoing : CallType.incoming,
        durationSeconds: durationSeconds,
        isVideo: state.isVideo,
      );
      return;
    }
    if (_pendingTargetUserId == null) return;
    
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    
    final myName = await _ref.read(currentUserNameProvider.future);
    final myPhoto = user.photoURL;
    
    int durationSeconds = 0;
    if (_callStartTime != null) {
      durationSeconds = DateTime.now().difference(_callStartTime!).inSeconds;
    }
    
    final historyService = _ref.read(callHistoryServiceProvider);
    await historyService.saveCallHistory(
      currentUserId: user.uid,
      currentUserName: myName,
      currentUserPhoto: myPhoto,
      targetUserId: _pendingTargetUserId!,
      targetUserName: _pendingTargetName ?? 'Utilisateur',
      targetUserPhoto: _pendingTargetPhoto,
      type: _isOutgoing ? CallType.outgoing : CallType.incoming,
      durationSeconds: durationSeconds,
      isVideo: state.isVideo,
    );
    
    _clearPendingCall();
  }

  Future<void> _saveMissedCall() async {
    if (state.isGroup) {
      final user = _ref.read(authStateProvider).value;
      if (user == null) return;
      final myName = await _ref.read(currentUserNameProvider.future);
      final myPhoto = user.photoURL;

      final historyService = _ref.read(callHistoryServiceProvider);
      final participantIds = state.groupParticipants.map((p) => p.id).toList();
      final participantNames = {
        for (final p in state.groupParticipants) p.id: p.name,
      };
      final participantPhotos = {
        for (final p in state.groupParticipants) p.id: p.photo,
      };
      await historyService.saveCallHistory(
        currentUserId: user.uid,
        currentUserName: myName,
        currentUserPhoto: myPhoto,
        targetUserId: state.groupRoomId ?? 'group',
        targetUserName: state.remoteName ?? 'Appel de groupe',
        targetUserPhoto: null,
        isGroup: true,
        groupName: state.remoteName ?? 'Appel de groupe',
        participantIds: participantIds,
        participantNames: participantNames,
        participantPhotos: participantPhotos,
        type: _isOutgoing ? CallType.outgoing : CallType.missed,
        durationSeconds: 0,
        isVideo: state.isVideo,
      );
      return;
    }
    if (_pendingTargetUserId == null) return;
    
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    
    final myName = await _ref.read(currentUserNameProvider.future);
    final myPhoto = user.photoURL;
    
    final historyService = _ref.read(callHistoryServiceProvider);
    
    if (_isOutgoing) {
      // Appel sortant qui n'a pas été répondu
      await historyService.saveCallHistory(
        currentUserId: user.uid,
        currentUserName: myName,
        currentUserPhoto: myPhoto,
        targetUserId: _pendingTargetUserId!,
        targetUserName: _pendingTargetName ?? 'Utilisateur',
        targetUserPhoto: _pendingTargetPhoto,
        type: CallType.missed,
        durationSeconds: 0,
        isVideo: state.isVideo,
      );
    }
    
    _clearPendingCall();
  }

  void _clearPendingCall() {
    _pendingTargetUserId = null;
    _pendingTargetName = null;
    _pendingTargetPhoto = null;
    _callStartTime = null;
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

  Future<void> toggleSpeaker() async {
    final newSpeakerState = !state.isSpeakerOn;
    await _service.setSpeaker(newSpeakerState);
    state = state.copyWith(isSpeakerOn: newSpeakerState);
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

// ── Call History Provider ─────────────────────────────────────────────
 
final callHistoryProvider =
    FutureProvider.family<List<CallHistoryModel>, String>((ref, alanyaId) async {
  // alanyaId est ignoré côté serveur (JWT identifie l'utilisateur)
  // mais conservé comme paramètre family pour la compatibilité des call sites
  final raw = await ApiService.instance.get('/calls') as List<dynamic>;
  return raw
      .map((e) => CallHistoryModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// Provider pour la durée totale des appels de la semaine
// APRÈS
final weeklyCallDurationProvider =
    FutureProvider.family<int, String>((ref, alanyaId) async {
  final calls = await ref.watch(callHistoryProvider(alanyaId).future);
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final weekStart =
      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  return calls
      .where((c) => c.timestamp.isAfter(weekStart) && c.statusInt != 0)
      .fold<int>(0, (sum, c) => sum + c.durationSeconds);
});

// Service pour sauvegarder l'historique des appels

class CallHistoryService {
  /// L'historique 1-à-1 est géré automatiquement par le socket backend :
  ///   - call_user     → INSERT callHistory (status=missed par défaut)
  ///   - answer_call   → UPDATE status=1, start_time=NOW()
  ///   - reject_call   → UPDATE status=2
  ///   - end_call      → UPDATE duree=TIMESTAMPDIFF(...)
  ///
  /// Les appels de groupe ne sont pas encore trackés en MySQL
  /// (la table callHistory n'a pas de colonne groupe).
  /// Cette méthode est intentionnellement vide pour éviter les doublons.
  Future<void> saveCallHistory({
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhoto,
    required String targetUserId,
    required String targetUserName,
    String? targetUserPhoto,
    bool isGroup = false,
    String? groupName,
    List<String> participantIds = const [],
    Map<String, String> participantNames = const {},
    Map<String, String?> participantPhotos = const {},
    required CallType type,
    required int durationSeconds,
    required bool isVideo,
  }) async {
    // no-op — historique géré par le socket backend (MySQL)
  }
}
final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService();
});
