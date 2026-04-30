// lib/features/meetings/data/meeting_providers.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/data/backend_user_providers.dart';
import '../domain/meeting_model.dart';
import 'meeting_service.dart';

final meetingServiceProvider = Provider<MeetingService>((ref) {
  final service = MeetingService();

  // Initialize when socket is connected
  final socketSub =
      SocketService.instance.onConnectedChange.listen((connected) {
    if (connected) {
      final alanyaID = ref.read(currentAlanyaIDProvider);
      if (alanyaID != null) {
        debugPrint(
            '[meetingServiceProvider] Socket connected, calling MeetingService.connect()');
        service.connect(alanyaID.toString());
      }
    }
  });

  // If socket is already connected at provider creation time
  if (SocketService.instance.isConnected) {
    final alanyaID = ref.read(currentAlanyaIDProvider);
    if (alanyaID != null) {
      debugPrint(
          '[meetingServiceProvider] Socket already connected, initializing immediately');
      service.connect(alanyaID.toString());
    }
  }

  // Listen for alanyaID changes
  ref.listen<int?>(currentAlanyaIDProvider, (_, next) {
    if (next != null && SocketService.instance.isConnected) {
      debugPrint('[meetingServiceProvider] alanyaID changed, re-registering');
      service.connect(next.toString());
    } else if (next == null) {
      debugPrint('[meetingServiceProvider] alanyaID cleared (logout)');
      service.disconnect();
    }
  });

  ref.onDispose(() {
    socketSub.cancel();
    service.dispose();
  });

  return service;
});

final meetingsListProvider =
    FutureProvider.autoDispose<List<MeetingModel>>((ref) async {
  final raw = await ApiService.instance.get('/meetings') as List<dynamic>;
  return raw
      .map((e) => MeetingModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final meetingDetailProvider =
    FutureProvider.family.autoDispose<MeetingModel, int>((ref, id) async {
  final raw =
      await ApiService.instance.get('/meetings/$id') as Map<String, dynamic>;
  return MeetingModel.fromJson(raw);
});

class MeetingRoomState {
  final bool isInRoom;
  final bool isStarted;
  final String? meetingID;
  final bool isMuted;
  final bool isCameraOff;
  final List<String> participantIDs;
  final List<MeetingChatMessage> chatMessages;
  final String? error;

  const MeetingRoomState({
    this.isInRoom = false,
    this.isStarted = false,
    this.meetingID,
    this.isMuted = false,
    this.isCameraOff = false,
    this.participantIDs = const [],
    this.chatMessages = const [],
    this.error,
  });

  MeetingRoomState copyWith({
    bool? isInRoom,
    bool? isStarted,
    String? meetingID,
    bool? isMuted,
    bool? isCameraOff,
    List<String>? participantIDs,
    List<MeetingChatMessage>? chatMessages,
    String? error,
  }) =>
      MeetingRoomState(
        isInRoom: isInRoom ?? this.isInRoom,
        isStarted: isStarted ?? this.isStarted,
        meetingID: meetingID ?? this.meetingID,
        isMuted: isMuted ?? this.isMuted,
        isCameraOff: isCameraOff ?? this.isCameraOff,
        participantIDs: participantIDs ?? this.participantIDs,
        chatMessages: chatMessages ?? this.chatMessages,
        error: error,
      );
}

class MeetingRoomNotifier extends StateNotifier<MeetingRoomState> {
  final MeetingService _service;
  final Ref _ref;

  MeetingRoomNotifier(this._service, this._ref)
      : super(const MeetingRoomState()) {
    _listenToService();
  }

  void _listenToService() {
    _service.events.listen((event) {
      switch (event) {
        case MeetingEvent.joined:
          state = state.copyWith(isInRoom: true);
          break;
        case MeetingEvent.started:
          state = state.copyWith(isStarted: true);
          break;
        case MeetingEvent.ended:
          state = const MeetingRoomState();
          break;
        case MeetingEvent.failed:
          state = state.copyWith(error: "Connexion à la réunion échouée");
          break;
        case MeetingEvent.connected:
          break;
      }
    });

    _service.participantEvents.listen((event) {
      if (event.type == 'joined') {
        final updated = List<String>.from(state.participantIDs);
        if (!updated.contains(event.userID)) updated.add(event.userID);
        state = state.copyWith(participantIDs: updated);
      } else if (event.type == 'left') {
        final updated =
            state.participantIDs.where((id) => id != event.userID).toList();
        state = state.copyWith(participantIDs: updated);
      }
    });

    _service.chatMessages.listen((msg) {
      state = state.copyWith(
        chatMessages: [...state.chatMessages, msg],
      );
    });
  }

  Future<void> joinMeeting(MeetingModel meeting) async {
    state = const MeetingRoomState();

    final alanyaID = _ref.read(currentAlanyaIDProvider);
    if (alanyaID == null) return;
    final myID = alanyaID.toString();

    // REST: register participation
    try {
      await ApiService.instance
          .post('/meetings/${meeting.idMeeting}/join', body: {});
    } catch (e) {
      debugPrint('[MeetingRoom] REST join failed: $e');
    }

    final existingIDs = meeting.participants
        .map((p) => p.alanyaID.toString())
        .where((id) => id != myID)
        .toList();

    await _service.joinRoom(
      meetingID: meeting.idMeeting.toString(),
      myUserID: myID,
      isVideo: meeting.isVideo,
      existingParticipantIDs: existingIDs,
    );

    state = state.copyWith(
      meetingID: meeting.idMeeting.toString(),
      participantIDs: existingIDs,
    );
  }

  Future<void> leaveMeeting() async {
    if (state.meetingID == null) return;

    try {
      await ApiService.instance
          .post('/meetings/${state.meetingID}/leave', body: {});
      debugPrint('[MeetingRoom] REST leave meeting succeeded');
    } catch (e) {
      debugPrint('[MeetingRoom] REST leave meeting failed: $e');
    }

    _service.leaveRoom();
    state = const MeetingRoomState();
  }

  Future<void> endMeeting(int meetingID) async {
    try {
      await ApiService.instance.put('/meetings/$meetingID', body: {'isEnd': 1});
    } catch (e) {
      debugPrint('[MeetingRoom] REST end meeting failed: $e');
    }
    _service.endMeetingForAll();
    state = const MeetingRoomState();
  }

  void startMeeting() {
    if (state.meetingID == null) return;
    _service.startMeeting(state.meetingID!);
    state = state.copyWith(isStarted: true);
  }

  void toggleMute() {
    _service.toggleMute();
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void toggleCamera() {
    _service.toggleCamera();
    state = state.copyWith(isCameraOff: !state.isCameraOff);
  }

  void sendChat(String message) => _service.sendChat(message);
}

final meetingRoomProvider =
    StateNotifierProvider<MeetingRoomNotifier, MeetingRoomState>((ref) {
  final service = ref.watch(meetingServiceProvider);
  return MeetingRoomNotifier(service, ref);
});
