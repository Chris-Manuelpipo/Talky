// lib/features/calls/data/call_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// ⚠️ Remplace par ton URL Render après déploiement
const _signalingUrl = 'https://talky-signaling.onrender.com';

// Événements émis par le service
enum CallEvent {
  incomingCall,
  callAnswered,
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

  const IncomingCallData({
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.isVideo,
    required this.offer,
  });
}

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _myUserId;
  String? _remoteUserId;
  bool _isVideo = false;

  // Streams pour notifier l'UI
  final _eventCtrl   = StreamController<CallEvent>.broadcast();
  final _incomingCtrl = StreamController<IncomingCallData>.broadcast();

  Stream<CallEvent>       get events       => _eventCtrl.stream;
  Stream<IncomingCallData> get incomingCalls => _incomingCtrl.stream;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected => _socket?.connected ?? false;

  // ── Connexion au serveur de signaling ─────────────────────────────
  void connect(String userId) {
    if (_socket != null && _socket!.connected) return;

    _myUserId = userId;
    _socket = io.io(_signalingUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connecté ✅');
      _socket!.emit('register', userId);
    });

    _socket!.onDisconnect((_) => debugPrint('[Socket] Déconnecté'));

    // ── Écouter les événements ─────────────────────────────────────
    _socket!.on('incoming_call', (data) async {
      final incoming = IncomingCallData(
        callerId:    data['callerId'],
        callerName:  data['callerName'],
        callerPhoto: data['callerPhoto'],
        isVideo:     data['isVideo'] ?? false,
        offer:       Map<String, dynamic>.from(data['offer']),
      );
      _remoteUserId = incoming.callerId;
      _isVideo      = incoming.isVideo;
      _incomingCtrl.add(incoming);
      _eventCtrl.add(CallEvent.incomingCall);
    });

    _socket!.on('call_answered', (data) async {
      final answer = RTCSessionDescription(
        data['answer']['sdp'], data['answer']['type']);
      await _peerConnection?.setRemoteDescription(answer);
      _eventCtrl.add(CallEvent.callAnswered);
    });

    _socket!.on('call_rejected', (_) {
      _cleanup();
      _eventCtrl.add(CallEvent.callRejected);
    });

    _socket!.on('ice_candidate', (data) async {
      if (data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );
        await _peerConnection?.addCandidate(candidate);
      }
    });

    _socket!.on('call_ended', (_) {
      _cleanup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    _socket!.on('call_failed', (data) {
      _cleanup();
      _eventCtrl.add(CallEvent.callFailed);
    });
  }

  // ── Passer un appel ────────────────────────────────────────────────
  Future<void> callUser({
    required String targetUserId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
  }) async {
    _remoteUserId = targetUserId;
    _isVideo      = isVideo;

    await _setupPeerConnection();
    await _getLocalStream(isVideo: isVideo);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket!.emit('call_user', {
      'targetUserId': targetUserId,
      'callerId':     _myUserId,
      'callerName':   callerName,
      'callerPhoto':  callerPhoto,
      'isVideo':      isVideo,
      'offer': {
        'sdp':  offer.sdp,
        'type': offer.type,
      },
    });
  }

  // ── Accepter un appel ──────────────────────────────────────────────
  Future<void> answerCall(IncomingCallData incoming) async {
    await _setupPeerConnection();
    await _getLocalStream(isVideo: incoming.isVideo);

    final offer = RTCSessionDescription(
        incoming.offer['sdp'], incoming.offer['type']);
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket!.emit('answer_call', {
      'callerId': incoming.callerId,
      'answer': {
        'sdp':  answer.sdp,
        'type': answer.type,
      },
    });
  }

  // ── Refuser un appel ──────────────────────────────────────────────
  void rejectCall(String callerId) {
    _socket!.emit('reject_call', {'callerId': callerId});
    _cleanup();
  }

  // ── Terminer l'appel ──────────────────────────────────────────────
  void endCall() {
    if (_remoteUserId != null) {
      _socket!.emit('end_call', {'targetUserId': _remoteUserId});
    }
    _cleanup();
    _eventCtrl.add(CallEvent.callEnded);
  }

  // ── Toggle micro ──────────────────────────────────────────────────
  void toggleMute() {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  bool get isMuted =>
      _localStream?.getAudioTracks().firstOrNull?.enabled == false;

  // ── Toggle caméra ────────────────────────────────────────────────
  void toggleCamera() {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  // ── Retourner la caméra ───────────────────────────────────────────
  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  // ── Setup PeerConnection ──────────────────────────────────────────
  Future<void> _setupPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      _socket!.emit('ice_candidate', {
        'targetUserId': _remoteUserId,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
    };
  }

  // ── Obtenir le flux local (micro + caméra) ────────────────────────
  Future<void> _getLocalStream({required bool isVideo}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {
        'facingMode': 'user',
        'width':  {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  // ── Nettoyage ─────────────────────────────────────────────────────
  void _cleanup() {
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _remoteUserId = null;
  }

  void disconnect() {
    _cleanup();
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _cleanup();
    _socket?.disconnect();
    _eventCtrl.close();
    _incomingCtrl.close();
  }
}