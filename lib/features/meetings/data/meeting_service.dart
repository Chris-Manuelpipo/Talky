// lib/features/meetings/data/meeting_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../calls/data/call_service.dart';

// ── Événements de salle ──────────────────────────────────────────────
enum MeetingEvent {
  joined,
  started,
  ended,
  failed,
  connected, // premier flux distant reçu
}

class MeetingParticipantEvent {
  final String type;    // 'joined' | 'left' | 'participants'
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

// ── ICE config (identique à CallService) ─────────────────────────────
const _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun.relay.metered.ca:80'},
    {
      'urls': [
        'turn:global.relay.metered.ca:80',
        'turn:global.relay.metered.ca:80?transport=tcp',
        'turn:global.relay.metered.ca:443',
        'turns:global.relay.metered.ca:443?transport=tcp',
      ],
      'username':   '4ccd30e6211751522c93c044',
      'credential': 'iB+/hPI3lLayZAKn',
    },
  ],
  'iceCandidatePoolSize': 10,
};

class MeetingService {
  static final MeetingService _instance = MeetingService._internal();
  factory MeetingService() => _instance;
  MeetingService._internal();

  // ── Partagé avec CallService (même socket, même connexion) ──────
  final CallService _callService = CallService();

  // ── État WebRTC ──────────────────────────────────────────────────
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  String? _myUserID;
  String? _currentMeetingID;
  bool _connectedEmitted = false;

  // ── Streams publics ──────────────────────────────────────────────
  final _eventCtrl       = StreamController<MeetingEvent>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamsCtrl =
      StreamController<Map<String, MediaStream>>.broadcast();
  final _participantCtrl =
      StreamController<MeetingParticipantEvent>.broadcast();
  final _chatCtrl = StreamController<MeetingChatMessage>.broadcast();

  Stream<MeetingEvent>               get events         => _eventCtrl.stream;
  Stream<MediaStream?>               get localStream    => _localStreamCtrl.stream;
  Stream<Map<String, MediaStream>>   get remoteStreams  => _remoteStreamsCtrl.stream;
  Stream<MeetingParticipantEvent>    get participantEvents => _participantCtrl.stream;
  Stream<MeetingChatMessage>         get chatMessages   => _chatCtrl.stream;

  MediaStream?             get currentLocalStream  => _localStream;
  Map<String, MediaStream> get currentRemoteStreams => Map.from(_remoteStreams);
  String?                  get currentMeetingID    => _currentMeetingID;

  // ── Initialisation des listeners socket ─────────────────────────
  bool _socketListenersRegistered = false;

  void initSocketListeners(String myUserID) {
    _myUserID = myUserID;
    if (_socketListenersRegistered) return;
    _socketListenersRegistered = true;

    final socket = _callService.socket;
    if (socket == null) {
      debugPrint('[MeetingService] Socket non disponible');
      return;
    }

    // ── Salle ──────────────────────────────────────────────────
    socket.on('meeting:started', (data) {
      debugPrint('[Meeting] meeting:started');
      _eventCtrl.add(MeetingEvent.started);
    });

    socket.on('meeting:ended', (data) {
      debugPrint('[Meeting] meeting:ended');
      _cleanup();
      _eventCtrl.add(MeetingEvent.ended);
    });

    socket.on('meeting:accepted', (data) {
      debugPrint('[Meeting] meeting:accepted — on peut rejoindre la room');
      // Le REST join + socket join_meeting_room sont gérés par MeetingNotifier
    });

    socket.on('meeting:declined', (data) {
      debugPrint('[Meeting] meeting:declined');
      _cleanup();
      _eventCtrl.add(MeetingEvent.failed);
    });

    socket.on('meeting:user_joined', (data) {
      final userID = data['userID']?.toString() ?? '';
      debugPrint('[Meeting] user_joined: $userID');
      // Initier une PeerConnection vers le nouveau participant
      _initiatePeerTo(userID);
      _participantCtrl.add(MeetingParticipantEvent(
        type: 'joined', userID: userID,
      ));
    });

    socket.on('meeting:user_left', (data) {
      final userID = data['userID']?.toString() ?? '';
      debugPrint('[Meeting] user_left: $userID');
      _removePeer(userID);
      _participantCtrl.add(MeetingParticipantEvent(
        type: 'left', userID: userID,
      ));
    });

    socket.on('meeting:message', (data) {
      _chatCtrl.add(MeetingChatMessage(
        userID:  data['userID']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
        sentAt:  DateTime.now(),
      ));
    });

    // ── WebRTC ─────────────────────────────────────────────────
    socket.on('meeting:offer', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final offer      = data['offer'];
      if (fromUserID == null || offer == null) return;
      debugPrint('[Meeting] offer from $fromUserID');

      final pc = await _getOrCreatePeer(fromUserID);
      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _callService.socket?.emit('meeting:answer', {
        'meetingID': _currentMeetingID,
        'toUserID':  fromUserID,
        'answer':    {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    socket.on('meeting:answer', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final answer     = data['answer'];
      if (fromUserID == null || answer == null) return;
      debugPrint('[Meeting] answer from $fromUserID');

      final pc = _peerConnections[fromUserID];
      await pc?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    });

    socket.on('meeting:ice_candidate', (data) async {
      final fromUserID = data['fromUserID']?.toString();
      final cand       = data['candidate'];
      if (fromUserID == null || cand == null) return;

      final pc = _peerConnections[fromUserID];
      await pc?.addCandidate(RTCIceCandidate(
        cand['candidate'] as String,
        cand['sdpMid']    as String?,
        cand['sdpMLineIndex'] as int,
      ));
    });
  }

  // ── Rejoindre une réunion (après REST join + socket join_request) ──
  Future<void> joinRoom({
    required String meetingID,
    required String myUserID,
    required bool isVideo,
    required List<String> existingParticipantIDs,
  }) async {
    _currentMeetingID = meetingID;
    _myUserID         = myUserID;
    _connectedEmitted = false;

    // Rejoindre la room socket
    _callService.socket?.emit('meeting:create', {
      'meetingID':   meetingID,
      'organiserID': myUserID,
      'meetingName': '',
    });

    // Acquérir le flux local
    await _getLocalStream(isVideo: isVideo);

    // Initier une PeerConnection vers chaque participant déjà présent
    for (final uid in existingParticipantIDs) {
      if (uid != myUserID) await _initiatePeerTo(uid);
    }

    _eventCtrl.add(MeetingEvent.joined);
  }

  // ── Quitter la réunion ────────────────────────────────────────────
  void leaveRoom() {
    if (_currentMeetingID != null) {
      _callService.socket?.emit('meeting:leave', {
        'meetingID': _currentMeetingID,
      });
    }
    _cleanup();
    _eventCtrl.add(MeetingEvent.ended);
  }

  // ── Terminer pour tout le monde (organisateur) ────────────────────
  void endMeetingForAll() {
    if (_currentMeetingID != null) {
      _callService.socket?.emit('meeting:end', {
        'meetingID': _currentMeetingID,
      });
    }
    _cleanup();
    _eventCtrl.add(MeetingEvent.ended);
  }

  // ── Envoyer un message de chat ────────────────────────────────────
  void sendChat(String message) {
    if (_currentMeetingID == null || _myUserID == null) return;
    _callService.socket?.emit('meeting:chat', {
      'meetingID': _currentMeetingID,
      'userID':    _myUserID,
      'message':   message,
    });
  }

  // ── Démarrer la réunion (organisateur) ───────────────────────────────
  void startMeeting(String meetingID) {
    _callService.socket?.emit('meeting:start', {'meetingID': meetingID});
  }

  // ── Toggle micro / caméra ─────────────────────────────────────────
  void toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
  }

  void toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
  }

  bool get isMuted =>
      _localStream?.getAudioTracks().firstOrNull?.enabled == false;

  // ── Initier une PeerConnection (offer) vers un pair ───────────────
  Future<void> _initiatePeerTo(String userID) async {
    if (userID == _myUserID) return;
    final pc = await _getOrCreatePeer(userID);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _callService.socket?.emit('meeting:offer', {
      'meetingID': _currentMeetingID,
      'toUserID':  userID,
      'offer':     {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  // ── Créer ou récupérer une PeerConnection pour un pair ────────────
  Future<RTCPeerConnection> _getOrCreatePeer(String userID) async {
    final existing = _peerConnections[userID];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_iceServers);
    _peerConnections[userID] = pc;

    // Ajouter les tracks locaux
    _localStream?.getTracks().forEach((t) => pc.addTrack(t, _localStream!));

    // ICE candidates
    pc.onIceCandidate = (candidate) {
      _callService.socket?.emit('meeting:ice_candidate', {
        'meetingID': _currentMeetingID,
        'toUserID':  userID,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // Flux distants
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

    // Gestion déconnexion d'un pair
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _removePeer(userID);
      }
    };

    return pc;
  }

  // ── Supprimer un pair ─────────────────────────────────────────────
  void _removePeer(String userID) {
    _peerConnections[userID]?.close();
    _peerConnections.remove(userID);
    _remoteStreams[userID]?.dispose();
    _remoteStreams.remove(userID);
    _remoteStreamsCtrl.add(Map.from(_remoteStreams));
  }

  // ── Acquérir le flux local ────────────────────────────────────────
  // Demande les permissions nécessaires ET WITH FALLBACK audio-only si vidéo échoue
  Future<void> _getLocalStream({required bool isVideo}) async {
    try {
      // Vérifier et demander les permissions
      final audioPermission = await _requestAudioPermission();
      if (!audioPermission) {
        debugPrint('[MeetingService] Audio permission refusée');
        _eventCtrl.add(MeetingEvent.failed);
        return;
      }

      // Essayer d'acquérir le flux avec vidéo si demandé
      if (isVideo) {
        final videoPermission = await _requestVideoPermission();
        if (videoPermission) {
          try {
            _localStream = await navigator.mediaDevices.getUserMedia({
              'audio': {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl':  true,
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
            debugPrint('[MeetingService] Erreur vidéo: $e, fallback audio...');
          }
        }
      }

      // Fallback: audio-only
      debugPrint('[MeetingService] Utilisation audio-only');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl':  true,
        },
        'video': false,
      });
      _localStreamCtrl.add(_localStream);
    } catch (e) {
      debugPrint('[MeetingService] Erreur getUserMedia: $e');
      _eventCtrl.add(MeetingEvent.failed);
    }
  }

  // ── Demander permission audio ────────────────────────────────────
  Future<bool> _requestAudioPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isDenied;
    } catch (e) {
      debugPrint('[MeetingService] Erreur permission audio: $e');
      return false;
    }
  }

  // ── Demander permission vidéo ────────────────────────────────────
  Future<bool> _requestVideoPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted || status.isDenied;
    } catch (e) {
      debugPrint('[MeetingService] Erreur permission vidéo: $e');
      return false;
    }
  }

  // ── Nettoyage ─────────────────────────────────────────────────────
  void _cleanup() {
    _localStream?.dispose();
    _localStream = null;
    _localStreamCtrl.add(null);
    _peerConnections.keys.toList().forEach(_removePeer);
    _peerConnections.clear();
    _remoteStreams.clear();
    _remoteStreamsCtrl.add({});
    _currentMeetingID = null;
    _connectedEmitted = false;
  }

  void dispose() {
    _cleanup();
    _eventCtrl.close();
    _localStreamCtrl.close();
    _remoteStreamsCtrl.close();
    _participantCtrl.close();
    _chatCtrl.close();
  }
}