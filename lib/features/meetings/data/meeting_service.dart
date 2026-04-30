// lib/features/meetings/data/meeting_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/socket_service.dart';

enum MeetingEvent {
  joined,
  started,
  ended,
  failed,
  connected,
}

class MeetingParticipantEvent {
  final String type;
  final String userID;
  final List<String>? participantIDs;
  const MeetingParticipantEvent({
    required this.type,
    required this.userID,
    this.participantIDs,
  });
}

class MeetingChatMessage {
  final String userID;
  final String message;
  final DateTime sentAt;
  const MeetingChatMessage({
    required this.userID,
    required this.message,
    required this.sentAt,
  });
}

const _iceConfig = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': [
        'turn:global.relay.metered.ca:80',
        'turn:global.relay.metered.ca:80?transport=tcp',
        'turn:global.relay.metered.ca:443',
        'turns:global.relay.metered.ca:443?transport=tcp',
      ],
      'username': '4ccd30e6211751522c93c044',
      'credential': 'iB+/hPI3lLayZAKn',
    },
  ],
  'iceCandidatePoolSize': 10,
};

class MeetingService {
  static final MeetingService _instance = MeetingService._internal();
  factory MeetingService() => _instance;
  MeetingService._internal();

  io.Socket? get _socket => SocketService.instance.socket;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  String? _myUserID;
  String? _currentMeetingID;
  bool _connectedEmitted = false;

  bool _listenersInitialized = false;
  StreamSubscription<bool>? _connectionSub;
  Completer<void>? _roomJoinedCompleter;

  final Map<String, List<RTCIceCandidate>> _pendingIceCandidates = {};
  final Map<String, bool> _remoteDescriptionSet = {};

  final _eventCtrl = StreamController<MeetingEvent>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamsCtrl =
      StreamController<Map<String, MediaStream>>.broadcast();
  final _participantCtrl =
      StreamController<MeetingParticipantEvent>.broadcast();
  final _chatCtrl = StreamController<MeetingChatMessage>.broadcast();

  Stream<MeetingEvent> get events => _eventCtrl.stream;
  Stream<MediaStream?> get localStream => _localStreamCtrl.stream;
  Stream<Map<String, MediaStream>> get remoteStreams =>
      _remoteStreamsCtrl.stream;
  Stream<MeetingParticipantEvent> get participantEvents =>
      _participantCtrl.stream;
  Stream<MeetingChatMessage> get chatMessages => _chatCtrl.stream;

  MediaStream? get currentLocalStream => _localStream;
  Map<String, MediaStream> get currentRemoteStreams => Map.from(_remoteStreams);
  String? get currentMeetingID => _currentMeetingID;

  bool get isMuted =>
      _localStream?.getAudioTracks().firstOrNull?.enabled == false;

  /// Idempotent — registers listeners once, resets on reconnection.
  void initListeners() {
    if (_listenersInitialized) return;
    if (_myUserID == null) {
      debugPrint('[MeetingService.initListeners()] No userId set, skipping');
      return;
    }
    final socket = _socket;
    if (socket == null) {
      debugPrint('[MeetingService.initListeners()] Socket is null, skipping');
      return;
    }

    _listenersInitialized = true;
    debugPrint(
        '[MeetingService.initListeners()] Registering all socket listeners');

    socket.on('meeting:room_joined', (data) {
      debugPrint('[Meeting] meeting:room_joined — room joined successfully');
      _roomJoinedCompleter?.complete();
      _roomJoinedCompleter = null;
    });

    socket.on('meeting:started', (data) {
      debugPrint('[Meeting] meeting:started');
      _eventCtrl.add(MeetingEvent.started);
    });

    socket.on('meeting:ended', (data) {
      debugPrint('[Meeting] meeting:ended');
      _cleanup();
      _eventCtrl.add(MeetingEvent.ended);
    });

    socket.on('meeting:user_joined', (data) {
      final userID = data['userID']?.toString() ?? '';
      debugPrint('[Meeting] user_joined: $userID');
      _initiatePeerTo(userID);
      _participantCtrl.add(MeetingParticipantEvent(
        type: 'joined',
        userID: userID,
      ));
    });

    socket.on('meeting:user_left', (data) {
      final userID = data['userID']?.toString() ?? '';
      debugPrint('[Meeting] user_left: $userID');
      _removePeer(userID);
      _participantCtrl.add(MeetingParticipantEvent(
        type: 'left',
        userID: userID,
      ));
    });

    socket.on('meeting:message', (data) {
      _chatCtrl.add(MeetingChatMessage(
        userID: data['userID']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
        sentAt: DateTime.now(),
      ));
    });

    // ── WebRTC signaling ─────────────────────────────────────────
    socket.on('meeting:offer', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final offer = data['offer'];
      if (fromUserID == null || offer == null) return;
      debugPrint('[Meeting] offer from $fromUserID');

      final pc = await _getOrCreatePeer(fromUserID);
      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      _remoteDescriptionSet[fromUserID] = true;

      // Flush pending ICE candidates for this user
      final pending = _pendingIceCandidates[fromUserID] ?? [];
      for (final candidate in pending) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[Meeting] Error adding pending ICE candidate from $fromUserID: $e');
        }
      }
      _pendingIceCandidates[fromUserID]?.clear();

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket?.emit('meeting:answer', {
        'meetingID': _currentMeetingID,
        'toUserID': fromUserID,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    socket.on('meeting:answer', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final answer = data['answer'];
      if (fromUserID == null || answer == null) return;
      debugPrint('[Meeting] answer from $fromUserID');

      final pc = _peerConnections[fromUserID];
      if (pc == null) return;
      await pc.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      _remoteDescriptionSet[fromUserID] = true;

      // Flush pending ICE candidates
      final pending = _pendingIceCandidates[fromUserID] ?? [];
      for (final candidate in pending) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[Meeting] Error adding pending ICE candidate from $fromUserID: $e');
        }
      }
      _pendingIceCandidates[fromUserID]?.clear();
    });

    socket.on('meeting:ice_candidate', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final cand = data['candidate'];
      if (fromUserID == null || cand == null) return;

      final pc = _peerConnections[fromUserID];
      if (pc == null) return;

      final candidate = RTCIceCandidate(
        cand['candidate'] as String,
        cand['sdpMid'] as String?,
        (cand['sdpMLineIndex'] as int?) ?? 0,
      );

      if (_remoteDescriptionSet[fromUserID] != true) {
        _pendingIceCandidates.putIfAbsent(fromUserID, () => []);
        _pendingIceCandidates[fromUserID]?.add(candidate);
      } else {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[Meeting] Error adding ICE candidate from $fromUserID: $e');
        }
      }
    });
  }

  void _removeListeners() {
    final socket = _socket;
    if (socket == null) return;
    socket.off('meeting:room_joined');
    socket.off('meeting:started');
    socket.off('meeting:ended');
    socket.off('meeting:user_joined');
    socket.off('meeting:user_left');
    socket.off('meeting:message');
    socket.off('meeting:offer');
    socket.off('meeting:answer');
    socket.off('meeting:ice_candidate');
    _listenersInitialized = false;
  }

  /// Called once by meetingServiceProvider.
  /// Handles initial connection + reconnection.
  void connect(String userId) {
    _myUserID = userId;
    _connectionSub?.cancel();
    _connectionSub =
        SocketService.instance.onConnectedChange.listen((connected) {
      if (connected) {
        debugPrint('[MeetingService] Socket reconnected, re-init listeners');
        _removeListeners();
        initListeners();
      }
    });
    initListeners();
  }

  /// Join a meeting room. Emits meeting:join_room and waits for meeting:room_joined
  /// (with 5s timeout) before initiating PeerConnections.
  Future<void> joinRoom({
    required String meetingID,
    required String myUserID,
    required bool isVideo,
    required List<String> existingParticipantIDs,
  }) async {
    _currentMeetingID = meetingID;
    _myUserID = myUserID;
    _connectedEmitted = false;

    _roomJoinedCompleter = Completer<void>();
    _socket?.emit('meeting:join_room', {
      'meetingID': meetingID,
      'userID': myUserID,
    });

    try {
      await _roomJoinedCompleter?.future.timeout(const Duration(seconds: 5));
      debugPrint('[Meeting] Room joined successfully');
    } catch (e) {
      debugPrint('[Meeting] Timeout waiting for room_joined: $e');
      _roomJoinedCompleter = null;
    }

    await _getLocalStream(isVideo: isVideo);

    for (final uid in existingParticipantIDs) {
      if (uid != myUserID) await _initiatePeerTo(uid);
    }

    _eventCtrl.add(MeetingEvent.joined);
  }

  void leaveRoom() {
    if (_currentMeetingID != null) {
      _socket?.emit('meeting:leave', {
        'meetingID': _currentMeetingID,
      });
    }
    _cleanup();
    _eventCtrl.add(MeetingEvent.ended);
  }

  void endMeetingForAll() {
    if (_currentMeetingID != null) {
      _socket?.emit('meeting:end', {
        'meetingID': _currentMeetingID,
      });
    }
    _cleanup();
    _eventCtrl.add(MeetingEvent.ended);
  }

  void startMeeting(String meetingID) {
    _socket?.emit('meeting:start', {'meetingID': meetingID});
  }

  void sendChat(String message) {
    if (_currentMeetingID == null || _myUserID == null) return;
    _socket?.emit('meeting:chat', {
      'meetingID': _currentMeetingID,
      'userID': _myUserID,
      'message': message,
    });
  }

  void toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
  }

  void toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
  }

  Future<void> _initiatePeerTo(String userID) async {
    if (userID == _myUserID) return;
    final pc = await _getOrCreatePeer(userID);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _socket?.emit('meeting:offer', {
      'meetingID': _currentMeetingID,
      'toUserID': userID,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<RTCPeerConnection> _getOrCreatePeer(String userID) async {
    final existing = _peerConnections[userID];
    if (existing != null) return existing;

    _pendingIceCandidates[userID] = [];
    _remoteDescriptionSet[userID] = false;

    final pc = await createPeerConnection(_iceConfig);
    _peerConnections[userID] = pc;

    _localStream?.getTracks().forEach((t) => pc.addTrack(t, _localStream!));

    pc.onIceCandidate = (candidate) {
      _socket?.emit('meeting:ice_candidate', {
        'meetingID': _currentMeetingID,
        'toUserID': userID,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (event) async {
      MediaStream stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams[0];
      } else {
        stream = await createLocalMediaStream('remote-$userID');
        stream.addTrack(event.track);
      }
      _remoteStreams[userID] = stream;
      _remoteStreamsCtrl.add(Map.from(_remoteStreams));

      if (!_connectedEmitted) {
        _connectedEmitted = true;
        _eventCtrl.add(MeetingEvent.connected);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _removePeer(userID);
      }
    };

    return pc;
  }

  void _removePeer(String userID) {
    _peerConnections[userID]?.close();
    _peerConnections.remove(userID);
    _remoteStreams[userID]?.dispose();
    _remoteStreams.remove(userID);
    _pendingIceCandidates.remove(userID);
    _remoteDescriptionSet.remove(userID);
    _remoteStreamsCtrl.add(Map.from(_remoteStreams));
  }

  Future<void> _getLocalStream({required bool isVideo}) async {
    try {
      final audioPermission = await _requestAudioPermission();
      if (!audioPermission) {
        debugPrint('[MeetingService] Audio permission denied');
        _eventCtrl.add(MeetingEvent.failed);
        return;
      }

      if (isVideo) {
        final videoPermission = await _requestVideoPermission();
        if (videoPermission) {
          try {
            _localStream = await navigator.mediaDevices.getUserMedia({
              'audio': {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              },
              'video': {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720}
              },
            });
            _localStreamCtrl.add(_localStream);
            return;
          } catch (e) {
            debugPrint(
                '[MeetingService] Video error: $e, fallback to audio...');
          }
        }
      }

      debugPrint('[MeetingService] Using audio-only');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      _localStreamCtrl.add(_localStream);
    } catch (e) {
      debugPrint('[MeetingService] getUserMedia error: $e');
      _eventCtrl.add(MeetingEvent.failed);
    }
  }

  Future<bool> _requestAudioPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[MeetingService] Audio permission error: $e');
      return false;
    }
  }

  Future<bool> _requestVideoPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[MeetingService] Video permission error: $e');
      return false;
    }
  }

  void _cleanup() {
    _localStream?.dispose();
    _localStream = null;
    _localStreamCtrl.add(null);
    _peerConnections.keys.toList().forEach(_removePeer);
    _peerConnections.clear();
    _remoteStreams.clear();
    _pendingIceCandidates.clear();
    _remoteDescriptionSet.clear();
    _remoteStreamsCtrl.add({});
    _currentMeetingID = null;
    _connectedEmitted = false;
    _roomJoinedCompleter = null;
  }

  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _removeListeners();
    _cleanup();
  }

  void dispose() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _removeListeners();
    _cleanup();
    _eventCtrl.close();
    _localStreamCtrl.close();
    _remoteStreamsCtrl.close();
    _participantCtrl.close();
    _chatCtrl.close();
  }
}
