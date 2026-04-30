// lib/features/calls/data/call_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/socket_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/ringback_service.dart';

const _audioChannel = MethodChannel('com.example.talky/audio');

enum CallEvent {
  incomingCall,
  callAnswered,
  callConnected,
  callRejected,
  callEnded,
  callFailed,
}

class IncomingCallData {
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final Map<String, dynamic> offer;
  final bool isGroup;
  final String? roomId;

  const IncomingCallData({
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.isVideo,
    required this.offer,
    this.isGroup = false,
    this.roomId,
  });
}

class GroupCallEvent {
  final String type;
  final String roomId;
  final String? userId;
  final String? userName;
  final String? userPhoto;
  final List<String>? participants;

  const GroupCallEvent({
    required this.type,
    required this.roomId,
    this.userId,
    this.userName,
    this.userPhoto,
    this.participants,
  });
}

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  io.Socket? get _socket => SocketService.instance.socket;
  bool get _socketConnected => SocketService.instance.isConnected;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};

  String? _myUserId;
  String? _remoteUserId;
  bool _isGroupCall = false;
  String? _groupRoomId;
  String? _lastError;

  bool _callConnectedEmitted = false;
  bool _listenersInitialized = false;
  StreamSubscription<bool>? _connectionSub;

  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  final Map<String, bool> _groupRemoteDescriptionSet = {};
  final Map<String, List<RTCIceCandidate>> _groupPendingCandidates = {};

  final _eventCtrl = StreamController<CallEvent>.broadcast();
  final _incomingCtrl = StreamController<IncomingCallData>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _groupRemoteStreamsCtrl =
      StreamController<Map<String, MediaStream>>.broadcast();
  final _groupEventCtrl = StreamController<GroupCallEvent>.broadcast();

  Stream<CallEvent> get events => _eventCtrl.stream;
  Stream<IncomingCallData> get incomingCalls => _incomingCtrl.stream;
  Stream<MediaStream?> get localStreamUpdates => _localStreamCtrl.stream;
  Stream<MediaStream?> get remoteStreamUpdates => _remoteStreamCtrl.stream;
  Stream<Map<String, MediaStream>> get groupRemoteStreamsUpdates =>
      _groupRemoteStreamsCtrl.stream;
  Stream<GroupCallEvent> get groupEvents => _groupEventCtrl.stream;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  Map<String, MediaStream> get groupRemoteStreams => _groupRemoteStreams;
  bool get isGroupCall => _isGroupCall;
  String? get groupRoomId => _groupRoomId;
  bool get isConnected => _socketConnected;
  String? get lastError => _lastError;
  io.Socket? get socket => _socket;

  Future<bool> waitForConnection({int timeoutSeconds = 5}) async {
    if (_socketConnected) return true;
    final completer = Completer<bool>();
    Timer? timer;
    late StreamSubscription sub;
    void onConnect() {
      timer?.cancel();
      sub.cancel();
      if (!completer.isCompleted) completer.complete(true);
    }

    sub = SocketService.instance.onConnectedChange.listen((connected) {
      if (connected) onConnect();
    });
    timer = Timer(Duration(seconds: timeoutSeconds), () {
      sub.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });
    return await completer.future;
  }

  /// Idempotent — enregistre les listeners une seule fois.
  /// Se réinitialise automatiquement en cas de reconnexion socket.
  void initListeners() {
    if (_listenersInitialized) return;
    if (_myUserId == null) {
      debugPrint('[CallService.initListeners()] No userId set, skipping');
      return;
    }
    final socket = _socket;
    if (socket == null) {
      debugPrint('[CallService.initListeners()] Socket is null, skipping');
      return;
    }

    _listenersInitialized = true;
    debugPrint(
        '[CallService.initListeners()] Registering all socket listeners');

    // ── 1-to-1 calls ──────────────────────────────────────────────
    socket.on('incoming_call', (data) async {
      debugPrint('[CallService] [incoming_call] Event received: $data');
      final incoming = IncomingCallData(
        callerId: data['callerId'].toString(),
        callerName: data['callerName'].toString(),
        callerPhoto: data['callerPhoto'],
        isVideo: data['isVideo'] == true || data['isVideo'] == 'true',
        offer: data['offer'] != null
            ? Map<String, dynamic>.from(data['offer'])
            : const {},
      );
      _remoteUserId = incoming.callerId;
      _incomingCtrl.add(incoming);
      _eventCtrl.add(CallEvent.incomingCall);

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        NotificationService.instance.showIncomingCallFullScreen(
          callerId: incoming.callerId,
          callerName: incoming.callerName,
          isVideo: incoming.isVideo,
          isGroup: false,
        );
      }
    });

    socket.on('call_answered', (data) async {
      debugPrint('[CallService] [call_answered] Event received');
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _peerConnection?.setRemoteDescription(answer);
      _remoteDescriptionSet = true;
      debugPrint(
          '[CallService] [call_answered] Remote description set. Flushing ${_pendingIceCandidates.length} pending ICE candidates');
      for (final candidate in _pendingIceCandidates) {
        try {
          await _peerConnection?.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[CallService] [call_answered] Error adding pending candidate: $e');
        }
      }
      _pendingIceCandidates.clear();
      _eventCtrl.add(CallEvent.callAnswered);
    });

    socket.on('call_rejected', (_) {
      debugPrint('[CallService] [call_rejected] Event received');
      _cleanup();
      _eventCtrl.add(CallEvent.callRejected);
    });

    socket.on('ice_candidate', (data) async {
      debugPrint('[CallService] [ice_candidate] Event received');
      if (data == null || data['candidate'] == null) return;
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'] as String,
        data['candidate']['sdpMid'] as String?,
        (data['candidate']['sdpMLineIndex'] as int?) ?? 0,
      );
      if (!_remoteDescriptionSet) {
        _pendingIceCandidates.add(candidate);
      } else {
        try {
          await _peerConnection?.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[CallService] [ice_candidate] Error adding candidate: $e');
        }
      }
    });

    socket.on('call_ended', (_) {
      debugPrint('[CallService] [call_ended] Event received');
      _cleanup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    socket.on('call_failed', (data) {
      debugPrint('[CallService] [call_failed] Event received: $data');
      _cleanup();
      final reason = data is Map ? data['reason']?.toString() : null;
      _lastError = _mapError(reason);
      _eventCtrl.add(CallEvent.callFailed);
    });

    // ── Group calls ──────────────────────────────────────────────
    socket.on('group_call_invite', (data) {
      debugPrint('[CallService] [group_call_invite] Event received: $data');
      final incoming = IncomingCallData(
        callerId: data['callerId'].toString(),
        callerName: data['callerName'].toString(),
        callerPhoto: data['callerPhoto'],
        isVideo: data['isVideo'] == true || data['isVideo'] == 'true',
        offer: const {},
        isGroup: true,
        roomId: data['roomId'],
      );
      _groupRoomId = incoming.roomId;
      _isGroupCall = true;
      _incomingCtrl.add(incoming);
      _eventCtrl.add(CallEvent.incomingCall);

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        NotificationService.instance.showIncomingCallFullScreen(
          callerId: incoming.callerId,
          callerName: incoming.callerName,
          isVideo: incoming.isVideo,
          isGroup: true,
          roomId: incoming.roomId,
        );
      }
    });

    socket.on('group_user_joined', (data) {
      debugPrint('[CallService] [group_user_joined] Event received: $data');
      final roomId = data['roomId'];
      final userId = data['userId'];
      if (roomId == _groupRoomId && userId != null) {
        _getOrCreateGroupPeer(userId).then((pc) async {
          final offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          _socket?.emit('group_offer', {
            'roomId': roomId,
            'fromUserId': _myUserId,
            'toUserId': userId,
            'offer': {'sdp': offer.sdp, 'type': offer.type},
          });
        });
      }
      _groupEventCtrl.add(GroupCallEvent(
        type: 'user_joined',
        roomId: roomId,
        userId: userId,
        userName: data['userName'],
        userPhoto: data['userPhoto'],
      ));
    });

    socket.on('group_participants', (data) {
      debugPrint('[CallService] [group_participants] Event received: $data');
      _groupEventCtrl.add(GroupCallEvent(
        type: 'participants',
        roomId: data['roomId'],
        participants:
            (data['participants'] as List?)?.map((e) => e.toString()).toList(),
      ));
    });

    socket.on('group_offer', (data) async {
      debugPrint(
          '[CallService] [group_offer] Event received from: ${data['fromUserId']}');
      final fromUserId = data['fromUserId'];
      final offer = data['offer'];
      if (offer == null || fromUserId == null) return;
      final pc = await _getOrCreateGroupPeer(fromUserId);
      await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']));
      _groupRemoteDescriptionSet[fromUserId] = true;
      final pending = _groupPendingCandidates[fromUserId] ?? [];
      for (final candidate in pending) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[CallService] [group_offer] Error adding pending group candidate: $e');
        }
      }
      _groupPendingCandidates[fromUserId]?.clear();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _socket?.emit('group_answer', {
        'roomId': data['roomId'],
        'fromUserId': _myUserId,
        'toUserId': fromUserId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    socket.on('group_answer', (data) async {
      debugPrint(
          '[CallService] [group_answer] Event received from: ${data['fromUserId']}');
      final fromUserId = data['fromUserId'];
      final answer = data['answer'];
      if (fromUserId == null || answer == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']));
      _groupRemoteDescriptionSet[fromUserId] = true;
      final pending = _groupPendingCandidates[fromUserId] ?? [];
      for (final candidate in pending) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[CallService] [group_answer] Error adding pending group candidate: $e');
        }
      }
      _groupPendingCandidates[fromUserId]?.clear();
    });

    socket.on('group_ice_candidate', (data) async {
      debugPrint(
          '[CallService] [group_ice_candidate] Event received from: ${data['fromUserId']}');
      final fromUserId = data['fromUserId'];
      final cand = data['candidate'];
      if (fromUserId == null || cand == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      final candidate = RTCIceCandidate(
        cand['candidate'] as String,
        cand['sdpMid'] as String?,
        (cand['sdpMLineIndex'] as int?) ?? 0,
      );
      if (_groupRemoteDescriptionSet[fromUserId] != true) {
        _groupPendingCandidates.putIfAbsent(fromUserId, () => []);
        _groupPendingCandidates[fromUserId]?.add(candidate);
      } else {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint(
              '[CallService] [group_ice_candidate] Error adding group ICE candidate: $e');
        }
      }
    });

    socket.on('group_call_ended', (data) {
      debugPrint('[CallService] [group_call_ended] Event received: $data');
      _cleanupGroup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    socket.on('group_user_left', (data) {
      debugPrint('[CallService] [group_user_left] Event received: $data');
      final userId = data['userId'];
      if (userId == null) return;
      _removeGroupPeer(userId);
      _groupEventCtrl.add(GroupCallEvent(
        type: 'user_left',
        roomId: data['roomId'],
        userId: userId,
      ));
    });
  }

  void _removeListeners() {
    final socket = _socket;
    if (socket == null) return;
    socket.off('incoming_call');
    socket.off('call_answered');
    socket.off('call_rejected');
    socket.off('ice_candidate');
    socket.off('call_ended');
    socket.off('call_failed');
    socket.off('group_call_invite');
    socket.off('group_user_joined');
    socket.off('group_participants');
    socket.off('group_offer');
    socket.off('group_answer');
    socket.off('group_ice_candidate');
    socket.off('group_call_ended');
    socket.off('group_user_left');
    _listenersInitialized = false;
  }

  /// Appelée une seule fois par le callServiceProvider.
  /// Gère connexion initiale + reconnexion.
  void connect(String userId) {
    _myUserId = userId;
    _connectionSub?.cancel();
    _connectionSub =
        SocketService.instance.onConnectedChange.listen((connected) {
      if (connected) {
        debugPrint('[CallService] Socket reconnected, re-init listeners');
        _removeListeners();
        initListeners();
      }
    });
    initListeners();
  }

  // ── 1-to-1 call ────────────────────────────────────────────────
  Future<void> callUser({
    required String targetUserId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
  }) async {
    _remoteUserId = targetUserId;
    if (!_socketConnected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }
    await RingbackService.instance.stop();
    await _setupPeerConnection();
    await _getLocalStream(isVideo: isVideo);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket!.emit('call_user', {
      'targetUserId': targetUserId,
      'callerId': _myUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'isVideo': isVideo,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  // ── Group call ─────────────────────────────────────────────────
  Future<void> startGroupCall({
    required String roomId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    required List<String> targetUserIds,
  }) async {
    _isGroupCall = true;
    _groupRoomId = roomId;
    _remoteUserId = null;
    if (!_socketConnected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }
    await RingbackService.instance.stop();
    await _getLocalStream(isVideo: isVideo);
    await setSpeaker(true);

    _socket!.emit('create_group_call', {
      'roomId': roomId,
      'callerId': _myUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'isVideo': isVideo,
      'targetUserIds': targetUserIds,
    });
  }

  Future<void> joinGroupCall({
    required String roomId,
    required String userId,
    required String userName,
    String? userPhoto,
    required bool isVideo,
  }) async {
    _isGroupCall = true;
    _groupRoomId = roomId;
    _remoteUserId = null;
    if (!_socketConnected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }
    await RingbackService.instance.stop();
    await _getLocalStream(isVideo: isVideo);

    _socket!.emit('join_group_call', {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
    });
  }

  void leaveGroupCall() {
    if (_groupRoomId != null) {
      _socket?.emit('leave_group_call', {'roomId': _groupRoomId});
    }
    _cleanupGroup();
    _eventCtrl.add(CallEvent.callEnded);
  }

  // ── Answer / reject ────────────────────────────────────────────
  Future<void> answerCall(IncomingCallData incoming) async {
    if (!_socketConnected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }
    await RingbackService.instance.stop();
    _remoteUserId = incoming.callerId;
    await _setupPeerConnection();
    await _getLocalStream(isVideo: incoming.isVideo);

    final offer =
        RTCSessionDescription(incoming.offer['sdp'], incoming.offer['type']);
    await _peerConnection!.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    debugPrint(
        '[CallService] Remote description set (answer side). Flushing ${_pendingIceCandidates.length} pending candidates');
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[CallService] Error adding pending candidate: $e');
      }
    }
    _pendingIceCandidates.clear();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket!.emit('answer_call', {
      'callerId': incoming.callerId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    await NotificationService.instance.cancelIncomingCallNotification();
  }

  void rejectCall(String callerId) {
    _socket?.emit('reject_call', {'callerId': callerId});
    _cleanup();
    NotificationService.instance.cancelIncomingCallNotification();
  }

  // ── End ────────────────────────────────────────────────────────
  void endCall() {
    if (_isGroupCall) {
      if (_groupRoomId != null) {
        _socket?.emit('end_group_call', {'roomId': _groupRoomId});
      }
      _cleanupGroup();
    } else {
      final targetId = _remoteUserId ?? _myUserId;
      if (targetId != null) {
        _socket?.emit('end_call', {'targetUserId': targetId});
      }
      _cleanup();
    }
    _eventCtrl.add(CallEvent.callEnded);
    NotificationService.instance.cancelIncomingCallNotification();
  }

  // ── Media controls ─────────────────────────────────────────────
  void toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
  }

  bool get isMuted =>
      _localStream?.getAudioTracks().firstOrNull?.enabled == false;

  void toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
  }

  bool get isCameraOff =>
      _localStream?.getVideoTracks().firstOrNull?.enabled == false;

  Future<void> setSpeaker(bool enabled) async {
    try {
      debugPrint('[Audio] Setting speaker to: $enabled');
      await _audioChannel.invokeMethod('setSpeaker', {'enabled': enabled});
      debugPrint('[Audio] Speaker set successfully');
    } catch (e) {
      debugPrint('[Audio] Error setting speaker: $e');
    }
  }

  Future<void> initializeCallAudio() async {
    try {
      debugPrint('[Audio] Initializing call audio on earpiece');
      await _audioChannel.invokeMethod('initializeCallAudio');
      debugPrint('[Audio] Call audio initialized');
    } catch (e) {
      debugPrint('[Audio] Error initializing call audio: $e');
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  // ── PeerConnection setup ───────────────────────────────────────
  Map<String, dynamic> get _iceConfig => {
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

  Future<void> _setupPeerConnection() async {
    _callConnectedEmitted = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    _peerConnection = await createPeerConnection(_iceConfig);

    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('ice_candidate', {
        'targetUserId': _remoteUserId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _peerConnection!.onTrack = (event) async {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else {
        _remoteStream = await createLocalMediaStream(
            'remote-${_remoteUserId ?? 'unknown'}');
        _remoteStream!.addTrack(event.track);
      }
      _remoteStreamCtrl.add(_remoteStream);
      if (!_callConnectedEmitted) {
        _callConnectedEmitted = true;
        _eventCtrl.add(CallEvent.callConnected);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          !_callConnectedEmitted) {
        _callConnectedEmitted = true;
        _eventCtrl.add(CallEvent.callConnected);
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
          _peerConnection != null) {
        _lastError = 'Connection failed: $state';
        _eventCtrl.add(CallEvent.callFailed);
        _cleanup();
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[ICE] Connection state: $state');
      if ((state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) &&
          !_callConnectedEmitted) {
        _callConnectedEmitted = true;
        _eventCtrl.add(CallEvent.callConnected);
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _lastError = 'ICE connection failed';
      }
    };

    _peerConnection!.onSignalingState = (state) {
      debugPrint('[Signaling] State: $state');
    };

    _peerConnection!.onIceGatheringState = (state) {
      debugPrint('[ICE] Gathering state: $state');
    };
  }

  Future<RTCPeerConnection> _getOrCreateGroupPeer(String userId) async {
    final existing = _groupPeerConnections[userId];
    if (existing != null) return existing;

    _groupRemoteDescriptionSet[userId] = false;
    _groupPendingCandidates[userId] = [];

    final pc = await createPeerConnection(_iceConfig);
    _groupPeerConnections[userId] = pc;

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    pc.onIceCandidate = (candidate) {
      if (_groupRoomId == null) return;
      _socket?.emit('group_ice_candidate', {
        'roomId': _groupRoomId,
        'fromUserId': _myUserId,
        'toUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[userId] = event.streams[0];
      } else {
        final stream = await createLocalMediaStream('remote-$userId');
        stream.addTrack(event.track);
        _groupRemoteStreams[userId] = stream;
      }
      _groupRemoteStreamsCtrl
          .add(Map<String, MediaStream>.from(_groupRemoteStreams));
      if (!_callConnectedEmitted) {
        _callConnectedEmitted = true;
        _eventCtrl.add(CallEvent.callConnected);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _removeGroupPeer(userId);
      }
    };

    return pc;
  }

  void _removeGroupPeer(String userId) {
    _groupPeerConnections[userId]?.close();
    _groupPeerConnections.remove(userId);
    _groupRemoteStreams[userId]?.dispose();
    _groupRemoteStreams.remove(userId);
    _groupRemoteDescriptionSet.remove(userId);
    _groupPendingCandidates.remove(userId);
    _groupRemoteStreamsCtrl
        .add(Map<String, MediaStream>.from(_groupRemoteStreams));
  }

  void _cleanupGroup() {
    setSpeaker(false);
    _localStream?.dispose();
    _localStream = null;
    _localStreamCtrl.add(null);
    _groupPeerConnections.keys.toList().forEach(_removeGroupPeer);
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();
    _groupRemoteDescriptionSet.clear();
    _groupPendingCandidates.clear();
    _groupRemoteStreamsCtrl.add(<String, MediaStream>{});
    _groupRoomId = null;
    _isGroupCall = false;
    _callConnectedEmitted = false;
    NotificationService.instance.cancelIncomingCallNotification();
  }

  String _mapError(String? reason) {
    if (reason == 'Utilisateur non disponible') {
      return 'Utilisateur non disponible';
    }
    return reason ?? 'Erreur lors de l\'appel';
  }

  Future<void> _getLocalStream({required bool isVideo}) async {
    try {
      await setSpeaker(false);
      debugPrint(
          '[Media] Requesting local media stream (audio + ${isVideo ? 'video' : 'no video'})');

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720}
              }
            : false,
      });

      debugPrint(
          '[Media] Local stream acquired: ${_localStream?.getTracks().length} tracks');

      if (_peerConnection != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      } else {
        _lastError = 'PeerConnection not initialized when adding tracks';
      }

      _localStreamCtrl.add(_localStream);
    } catch (e) {
      debugPrint('[Media] ERROR getting local media: $e');
      _lastError = 'Failed to get local media: $e';
      _eventCtrl.add(CallEvent.callFailed);
      rethrow;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────
  void _cleanup() {
    setSpeaker(false);
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _remoteUserId = null;
    _callConnectedEmitted = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();
    _localStreamCtrl.add(null);
    _remoteStreamCtrl.add(null);
    NotificationService.instance.cancelIncomingCallNotification();
  }

  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _removeListeners();
    _cleanupGroup();
    _cleanup();
  }

  void dispose() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _removeListeners();
    _cleanupGroup();
    _cleanup();
    _eventCtrl.close();
    _incomingCtrl.close();
    _localStreamCtrl.close();
    _remoteStreamCtrl.close();
    _groupRemoteStreamsCtrl.close();
    _groupEventCtrl.close();
  }
}
