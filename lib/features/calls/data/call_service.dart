// lib/features/calls/data/call_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/services/fcm_sender.dart';

// serveur signaling
const _signalingUrl = 'https://talky-signaling.onrender.com';

// Événements émis par le service
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
  final String type; // user_joined, user_left, participants
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

  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};

  String? _myUserId;
  String? _remoteUserId;
  bool _isVideo = false;
  bool _isGroupCall = false;
  String? _groupRoomId;
  String? _lastError;

  // Streams pour notifier l'UI
  final _eventCtrl   = StreamController<CallEvent>.broadcast();
  final _incomingCtrl = StreamController<IncomingCallData>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _groupRemoteStreamsCtrl =
      StreamController<Map<String, MediaStream>>.broadcast();
  final _groupEventCtrl = StreamController<GroupCallEvent>.broadcast();

  Stream<CallEvent>       get events       => _eventCtrl.stream;
  Stream<IncomingCallData> get incomingCalls => _incomingCtrl.stream;
  Stream<MediaStream?> get localStreamUpdates => _localStreamCtrl.stream;
  Stream<MediaStream?> get remoteStreamUpdates => _remoteStreamCtrl.stream;
  Stream<Map<String, MediaStream>> get groupRemoteStreamsUpdates =>
      _groupRemoteStreamsCtrl.stream;
  Stream<GroupCallEvent> get groupEvents => _groupEventCtrl.stream;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  Map<String, MediaStream> get groupRemoteStreams => _groupRemoteStreams;
  bool get isGroupCall => _isGroupCall;
  String? get groupRoomId => _groupRoomId;
  bool get isConnected => _socket?.connected ?? false;
  String? get lastError => _lastError;

  // ── Connexion au serveur de signaling ─────────────────────────────
  void connect(String userId) {
    _myUserId = userId;

    // Si socket existe mais déconnecté → nettoyer et reconnecter
    if (_socket != null) {
      if (_socket!.connected) return; // déjà connecté ✅
      _socket!.dispose();
      _socket = null;
    }

    _socket = io.io(_signalingUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()         // ← reconnexion auto
        .setReconnectionAttempts(10) // ← Augmenté à 10 tentatives
        .setReconnectionDelay(2000)  // ← attendre 2s entre chaque
        .setReconnectionDelayMax(10000) // ← max 10s entre tentatives
        .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connecté ✅');
      if (_myUserId != null) {
        _socket!.emit('register', _myUserId);
      }
    });

    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnecté ✅');
      if (_myUserId != null) {
        _socket!.emit('register', _myUserId);
      }
    }); 

    _socket!.onReconnectAttempt((attempt) {
      debugPrint('[Socket] Tentative de reconnexion $attempt...');
      _lastError = 'Connexion au serveur en cours. Réessaie dans ${11 - attempt} secondes';
    });

    _socket!.onReconnectFailed((_) {
      debugPrint('[Socket] Échec de reconnexion');
      _lastError = 'Impossible de se connecter au serveur';
    });

    _socket!.onConnectError((error) {
      debugPrint('[Socket] Erreur de connexion: $error');
      _lastError = 'Erreur de connexion au serveur';
    });

    _socket!.onDisconnect((_) => debugPrint('[Socket] Déconnecté'));

    // ── Écouter les événements ─────────────────────────────────────
    _socket!.on('incoming_call', (data) async {
      debugPrint('[Socket] incoming_call received: $data');
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
      debugPrint('[Socket] Call answered received: $data');
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
      debugPrint('[Socket] ICE candidate received: $data');
      if (data != null && data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'] as String,
          data['candidate']['sdpMid'] as String?,
          data['candidate']['sdpMLineIndex'] as int,
        );
        await _peerConnection?.addCandidate(candidate);
        debugPrint('[Socket] ICE candidate added to peer connection');
      }
    });

    _socket!.on('call_ended', (_) {
      _cleanup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    _socket!.on('call_failed', (data) {
      _cleanup();
      _lastError = data is Map ? data['reason']?.toString() : null;
      _eventCtrl.add(CallEvent.callFailed);
    });

    // ── Group calls events ───────────────────────────────────────────
    _socket!.on('group_call_invite', (data) {
      debugPrint('[Socket] group_call_invite received: $data');
      final incoming = IncomingCallData(
        callerId:    data['callerId'],
        callerName:  data['callerName'],
        callerPhoto: data['callerPhoto'],
        isVideo:     data['isVideo'] ?? false,
        offer:       const {},
        isGroup:     true,
        roomId:      data['roomId'],
      );
      _groupRoomId = incoming.roomId;
      _isGroupCall = true;
      _incomingCtrl.add(incoming);
      _eventCtrl.add(CallEvent.incomingCall);
    });

    _socket!.on('group_user_joined', (data) {
      debugPrint('[Socket] group_user_joined: $data');
      final roomId = data['roomId'];
      final userId = data['userId'];
      if (roomId == _groupRoomId && userId != null) {
        // Créer une offre vers le nouvel utilisateur
        _getOrCreateGroupPeer(userId).then((pc) async {
          final offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          _socket?.emit('group_offer', {
            'roomId': roomId,
            'fromUserId': _myUserId,
            'toUserId': userId,
            'offer': {
              'sdp': offer.sdp,
              'type': offer.type,
            },
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

    _socket!.on('group_participants', (data) {
      debugPrint('[Socket] group_participants: $data');
      _groupEventCtrl.add(GroupCallEvent(
        type: 'participants',
        roomId: data['roomId'],
        participants:
            (data['participants'] as List?)?.map((e) => e.toString()).toList(),
      ));
    });

    _socket!.on('group_offer', (data) async {
      debugPrint('[Socket] group_offer received: $data');
      final roomId = data['roomId'];
      final fromUserId = data['fromUserId'];
      final offer = data['offer'];
      if (offer == null || fromUserId == null) return;

      final pc = await _getOrCreateGroupPeer(fromUserId);
      final remoteDesc = RTCSessionDescription(
        offer['sdp'],
        offer['type'],
      );
      await pc.setRemoteDescription(remoteDesc);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket!.emit('group_answer', {
        'roomId': roomId,
        'fromUserId': _myUserId,
        'toUserId': fromUserId,
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });
    });

    _socket!.on('group_answer', (data) async {
      debugPrint('[Socket] group_answer received: $data');
      final fromUserId = data['fromUserId'];
      final answer = data['answer'];
      if (fromUserId == null || answer == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      final remoteDesc = RTCSessionDescription(
        answer['sdp'],
        answer['type'],
      );
      await pc.setRemoteDescription(remoteDesc);
    });

    _socket!.on('group_ice_candidate', (data) async {
      final fromUserId = data['fromUserId'];
      final cand = data['candidate'];
      if (fromUserId == null || cand == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      final candidate = RTCIceCandidate(
        cand['candidate'] as String,
        cand['sdpMid'] as String?,
        cand['sdpMLineIndex'] as int,
      );
      await pc.addCandidate(candidate);
    });

    _socket!.on('group_call_ended', (data) {
      debugPrint('[Socket] group_call_ended: $data');
      _cleanupGroup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    _socket!.on('group_user_left', (data) {
      debugPrint('[Socket] group_user_left: $data');
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

  // ── Passer un appel ────────────────────────────────────────────────
  Future<void> callUser({
    required String targetUserId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
  }) async {
    _remoteUserId = targetUserId;
    _isVideo      = isVideo;

    // Vérifier si le socket est connecté
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    await _setupPeerConnection();
    await _getLocalStream(isVideo: isVideo);
    
    // Activer le haut-parleur pour les appels
    await setSpeaker(true);

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
    debugPrint('[Socket] call_user emitted to $targetUserId');

    if (_myUserId != null) {
      await FcmSender.sendCallNotification(
        toUserId: targetUserId,
        callerName: callerName,
        isVideo: isVideo,
        callerId: _myUserId!,
        offer: {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      );
    }
  }

  // ── Créer un appel de groupe ──────────────────────────────────────
  Future<void> startGroupCall({
    required String roomId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    required List<String> targetUserIds,
  }) async {
    _isGroupCall = true;
    _groupRoomId = roomId;
    _isVideo = isVideo;
    _remoteUserId = null;

    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

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

    // Best-effort push notifications
    if (_myUserId != null) {
      for (final uid in targetUserIds) {
        await FcmSender.sendGroupCallNotification(
          toUserId: uid,
          callerName: callerName,
          isVideo: isVideo,
          callerId: _myUserId!,
          roomId: roomId,
        );
      }
    }
  }

  // ── Rejoindre un appel de groupe ───────────────────────────────────
  Future<void> joinGroupCall({
    required String roomId,
    required String userId,
    required String userName,
    String? userPhoto,
    required bool isVideo,
  }) async {
    _isGroupCall = true;
    _groupRoomId = roomId;
    _isVideo = isVideo;
    _remoteUserId = null;

    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    await _getLocalStream(isVideo: isVideo);
    await setSpeaker(true);

    _socket!.emit('join_group_call', {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
    });
  }

  // ── Quitter un appel de groupe ────────────────────────────────────
  void leaveGroupCall() {
    if (_groupRoomId != null) {
      _socket?.emit('leave_group_call', {'roomId': _groupRoomId});
    }
    _cleanupGroup();
    _eventCtrl.add(CallEvent.callEnded);
  }

  // ── Accepter un appel ──────────────────────────────────────────────
  Future<void> answerCall(IncomingCallData incoming) async {
    // Vérifier si le socket est connecté
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    await _setupPeerConnection();
    await _getLocalStream(isVideo: incoming.isVideo);

    // Activer le haut-parleur pour les appels
    await setSpeaker(true);

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
    debugPrint('[Socket] answer_call emitted to ${incoming.callerId}');
  }

  // ── Refuser un appel ──────────────────────────────────────────────
  void rejectCall(String callerId) {
    _socket!.emit('reject_call', {'callerId': callerId});
    _cleanup();
  }

  // ── Terminer l'appel ──────────────────────────────────────────────
  void endCall() {
    if (_isGroupCall) {
      if (_groupRoomId != null) {
        _socket?.emit('end_group_call', {'roomId': _groupRoomId});
      }
      _cleanupGroup();
    } else {
      if (_remoteUserId != null) {
        _socket!.emit('end_call', {'targetUserId': _remoteUserId});
      }
      _cleanup();
    }
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

  // ── Activer/désactiver le haut-parleur ─────────────────────────────
  Future<void> setSpeaker(bool enabled) async {
    // Note: Le haut-parleur est géré automatiquement par flutter_webrtc
    // Cette méthode n'est plus nécessaire avec les nouvelles versions
    // mais conservée pour compatibilité
    try {
      // Essayer différentes méthodes selon la version du plugin
      await WebRTC.invokeMethod('setSpeakerphoneOn', {'enabled': enabled});
      debugPrint('[Audio] Speakerphone set to: $enabled');
    } catch (e) {
      // Ignorer l'erreur - le speaker fonctionne par défaut sur Android
      debugPrint('[Audio] Speaker mode: using default (earpiece)');
    }
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
    // final config = {
    //   'iceServers': [
    //     // Serveurs STUN publics de Google
    //     {'urls': 'stun:stun.l.google.com:19302'},
    //     {'urls': 'stun:stun1.l.google.com:19302'},
    //     {'urls': 'stun:stun2.l.google.com:19302'},
    //     {'urls': 'stun:stun3.l.google.com:19302'},
    //     {'urls': 'stun:stun4.l.google.com:19302'},
    //     // Serveurs STUN supplémentaires
    //     {'urls': 'stun:stun.freecall.com:3478'},
    //     {'urls': 'stun:stun.qq.com:3478'},
    //   ],
    //   'iceCandidatePoolSize': 10,
    // };

    final Map<String, dynamic> config = {
      'iceServers': [
        // STUN servers
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
        {'urls': 'stun:stun.relay.metered.ca:80'},
        
        // TURN server Metered (credentials utilisateur)
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
        // TURN server ExpressTurn (free)
        {
          'urls': [
            'turn:free.expressturn.com:3478',
            'turn:free.expressturn.com:3478?transport=tcp',
          ],
          'username': '000000002089277421',
          'credential': 'MZNCzpa/GM4ZvRcYONi4+9qgZRU=',
        },
      ],
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('[WebRTC] Sending ICE candidate: ${candidate.candidate}');
      _socket!.emit('ice_candidate', {
        'targetUserId': _remoteUserId,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
      debugPrint('[WebRTC] ICE candidate sent to $_remoteUserId');
    };

    _peerConnection!.onTrack = (event) async {
      debugPrint('[WebRTC] onTrack received, tracks: ${event.track.kind}');
      // Notifier que l'appel est connecté quand on reçoit un track distant
      _eventCtrl.add(CallEvent.callConnected);
      
      // Utiliser le stream de l'événement si disponible
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        debugPrint('[WebRTC] Using stream from event: ${event.streams[0].id}');
      } else {
        // Créer un nouveau stream local si nécessaire
        debugPrint('[WebRTC] Creating new remote stream');
        _remoteStream = await createLocalMediaStream('remote-${_remoteUserId ?? 'unknown'}');
        _remoteStream!.addTrack(event.track);
      }
      _remoteStreamCtrl.add(_remoteStream);
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _eventCtrl.add(CallEvent.callConnected);
      }
      // Gérer les autres états de connexion
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('[WebRTC] Connection lost or failed');
      }
    };

    // Gestion de l'état ICE pour détecter la connexion
    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[ICE] Connection state: $state');
      // Considérer la connexion établie quand ICE est connecté ou completed
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        debugPrint('[ICE] Connection established!');
        _eventCtrl.add(CallEvent.callConnected);
      }
      // Gérer les états d'erreur
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        debugPrint('[ICE] Connection failed or disconnected');
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

    final Map<String, dynamic> config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
        {'urls': 'stun:stun.relay.metered.ca:80'},
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
        {
          'urls': [
            'turn:free.expressturn.com:3478',
            'turn:free.expressturn.com:3478?transport=tcp',
          ],
          'username': '000000002089277421',
          'credential': 'MZNCzpa/GM4ZvRcYONi4+9qgZRU=',
        },
      ],
      'iceCandidatePoolSize': 10,
    };

    final pc = await createPeerConnection(config);
    _groupPeerConnections[userId] = pc;

    // Ajouter les tracks locaux au peer
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
      _groupRemoteStreamsCtrl.add(Map<String, MediaStream>.from(_groupRemoteStreams));
      _eventCtrl.add(CallEvent.callConnected);
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
    _groupRemoteStreamsCtrl.add(Map<String, MediaStream>.from(_groupRemoteStreams));
  }

  void _cleanupGroup() {
    // Désactiver le haut-parleur
    setSpeaker(false);

    _localStream?.dispose();
    _localStream = null;
    _localStreamCtrl.add(null);

    _groupPeerConnections.keys.toList().forEach(_removeGroupPeer);
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();
    _groupRemoteStreamsCtrl.add(<String, MediaStream>{});
    _groupRoomId = null;
    _isGroupCall = false;
  }

  // ── Obtenir le flux local (micro + caméra) ────────────────────────
  Future<void> _getLocalStream({required bool isVideo}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo ? {
        'facingMode': 'user',
        'width':  {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    });

    if (_peerConnection != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
    _localStreamCtrl.add(_localStream);
  }

  // ── Nettoyage ─────────────────────────────────────────────────────
  void _cleanup() {
    // Désactiver le haut-parleur
    setSpeaker(false);
    
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _remoteUserId = null;
    _localStreamCtrl.add(null);
    _remoteStreamCtrl.add(null);
  }

  void disconnect() {
    _cleanupGroup();
    _cleanup();
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _cleanupGroup();
    _cleanup();
    _socket?.disconnect();
    _eventCtrl.close();
    _incomingCtrl.close();
    _localStreamCtrl.close();
    _remoteStreamCtrl.close();
    _groupRemoteStreamsCtrl.close();
    _groupEventCtrl.close();
  }
}
