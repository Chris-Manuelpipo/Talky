// lib/features/calls/data/call_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'call_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../domain/call_history_model.dart';

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
      errorMessage: null,
    );

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
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await _ref.read(currentUserNameProvider.future);
    final myPhoto = user.photoURL;

    final roomId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
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
      errorMessage: null,
    );

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
    );
  }

  Future<void> answerGroupCall() async {
    if (state.incomingCall == null) return;
    final incoming = state.incomingCall!;
    if (incoming.roomId == null || incoming.roomId!.isEmpty) return;
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await _ref.read(currentUserNameProvider.future);

    _isOutgoing = false;
    _callStartTime = null;

    await _service.joinGroupCall(
      roomId: incoming.roomId!,
      userId: user.uid,
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
final callHistoryProvider = StreamProvider.family<List<CallHistoryModel>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('callHistory')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => CallHistoryModel.fromMap(doc.id, doc.data()))
          .toList());
});

// Provider pour la durée totale des appels de la semaine
final weeklyCallDurationProvider = FutureProvider.family<int, String>((ref, userId) async {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('callHistory')
      .where('timestamp', isGreaterThan: startOfWeekMidnight.toIso8601String())
      .get();

  int totalSeconds = 0;
  for (final doc in snapshot.docs) {
    final data = doc.data();
    // Compter seulement les appels sortants et entrants (pas manqués)
    final type = data['type'] as String?;
    if (type != 'missed') {
      totalSeconds += (data['durationSeconds'] as int?) ?? 0;
    }
  }
  return totalSeconds;
});

// Service pour sauvegarder l'historique des appels
class CallHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    final callData = {
      'callerId': currentUserId,
      'callerName': currentUserName,
      'callerPhoto': currentUserPhoto,
      'receiverId': targetUserId,
      'receiverName': targetUserName,
      'receiverPhoto': targetUserPhoto,
      'isGroup': isGroup,
      'groupName': groupName,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'type': type.name,
      'timestamp': DateTime.now().toIso8601String(),
      'durationSeconds': durationSeconds,
      'isVideo': isVideo,
    };

    // Sauvegarder dans l'historique de l'appelant
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('callHistory')
        .add(callData);

    // Sauvegarder aussi dans l'historique du réceptionnaire (pour les appels entrants et manqués)
    if (!isGroup && type != CallType.outgoing) {
      await _db
          .collection('users')
          .doc(targetUserId)
          .collection('callHistory')
          .add({
        'callerId': currentUserId,
        'callerName': currentUserName,
        'callerPhoto': currentUserPhoto,
        'receiverId': targetUserId,
        'receiverName': targetUserName,
        'receiverPhoto': targetUserPhoto,
        'type': type == CallType.incoming ? CallType.outgoing.name : CallType.missed.name,
        'timestamp': DateTime.now().toIso8601String(),
        'durationSeconds': durationSeconds,
        'isVideo': isVideo,
      });
    }
  }
}

final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService();
});
