// lib/features/calls/data/call_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/services/fcm_sender.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/ringback_service.dart';

// serveur signaling
const _signalingUrl = 'https://talky-signaling.onrender.com';

// Platform channel pour l'audio
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

  io.Socket? _socket; 
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

  // Guard pour éviter d'émettre callConnected plusieurs fois
  bool _callConnectedEmitted = false;
  
  // Buffer pour les ICE candidates reçus avant que RemoteDescription ne soit défini
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  final _eventCtrl              = StreamController<CallEvent>.broadcast();
  final _incomingCtrl           = StreamController<IncomingCallData>.broadcast();
  final _localStreamCtrl        = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl       = StreamController<MediaStream?>.broadcast();
  final _groupRemoteStreamsCtrl  = StreamController<Map<String, MediaStream>>.broadcast();
  final _groupEventCtrl         = StreamController<GroupCallEvent>.broadcast();

  Stream<CallEvent>                    get events                  => _eventCtrl.stream;
  Stream<IncomingCallData>             get incomingCalls           => _incomingCtrl.stream;
  Stream<MediaStream?>                 get localStreamUpdates      => _localStreamCtrl.stream;
  Stream<MediaStream?>                 get remoteStreamUpdates     => _remoteStreamCtrl.stream;
  Stream<Map<String, MediaStream>>     get groupRemoteStreamsUpdates => _groupRemoteStreamsCtrl.stream;
  Stream<GroupCallEvent>               get groupEvents             => _groupEventCtrl.stream;

  MediaStream?                     get localStream        => _localStream;
  MediaStream?                     get remoteStream       => _remoteStream;
  Map<String, MediaStream>         get groupRemoteStreams  => _groupRemoteStreams;
  bool                             get isGroupCall         => _isGroupCall;
  String?                          get groupRoomId         => _groupRoomId;
  bool                             get isConnected         => _socket?.connected ?? false;
  String?                          get lastError           => _lastError;
  io.Socket? get socket => _socket;
  // ── Connexion au serveur de signaling ─────────────────────────────
  void connect(String userId) {
    _myUserId = userId;

     final alanyaID = int.parse(userId);

    if (_socket != null) {
      if (_socket!.connected) return;
      _socket!.dispose();
      _socket = null;
    }

    _socket = io.io(_signalingUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(10)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(10000)
        .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connecté ✅');
      _socket!.emit('register', {'alanyaID': alanyaID});
    });

    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnecté ✅');
      _socket!.emit('register', {'alanyaID': alanyaID});
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

    // ── Événements socket ─────────────────────────────────────────
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
      _incomingCtrl.add(incoming);
      _eventCtrl.add(CallEvent.incomingCall);

      // App en background → déclencher l'écran natif
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        NotificationService.instance.showIncomingCallFullScreen(
          callerId:   incoming.callerId,
          callerName: incoming.callerName,
          isVideo:    incoming.isVideo,
          isGroup:    false,
        );
      }
    });

    _socket!.on('call_answered', (data) async {
      debugPrint('[Socket] Call answered received: $data');
      final answer = RTCSessionDescription(
          data['answer']['sdp'], data['answer']['type']);
      await _peerConnection?.setRemoteDescription(answer);
      _remoteDescriptionSet = true;
      debugPrint('[Socket] OK Remote description set. Processing ${_pendingIceCandidates.length} pending ICE candidates...');
      
      // Ajouter tous les ICE candidates en attente
      for (final candidate in _pendingIceCandidates) {
        try {
          await _peerConnection?.addCandidate(candidate);
        } catch (e) {
          debugPrint('[Socket] Error adding pending candidate: $e');
        }
      }
      _pendingIceCandidates.clear();
      
      _eventCtrl.add(CallEvent.callAnswered);
    });

    _socket!.on('call_rejected', (_) {
      _cleanup();
      _eventCtrl.add(CallEvent.callRejected);
    });

    _socket!.on('ice_candidate', (data) async {
      debugPrint('[Socket] ICE candidate received');
      if (data != null && data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'] as String,
          data['candidate']['sdpMid'] as String?,
          data['candidate']['sdpMLineIndex'] as int,
        );
        
        // Si remote description n'est pas encore set, buffer le candidate
        if (!_remoteDescriptionSet) {
          debugPrint('[Socket] Buffering ICE candidate (remote description not yet set)');
          _pendingIceCandidates.add(candidate);
        } else {
          // Sinon, ajouter directement
          try {
            await _peerConnection?.addCandidate(candidate);
          } catch (e) {
            debugPrint('[Socket] Error adding ICE candidate: $e');
          }
        }
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

    // ── Group calls ──────────────────────────────────────────────
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

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        NotificationService.instance.showIncomingCallFullScreen(
          callerId:   incoming.callerId,
          callerName: incoming.callerName,
          isVideo:    incoming.isVideo,
          isGroup:    true,
          roomId:     incoming.roomId,
        );
      }
    });

    _socket!.on('group_user_joined', (data) {
      debugPrint('[Socket] group_user_joined: $data');
      final roomId = data['roomId'];
      final userId = data['userId'];
      if (roomId == _groupRoomId && userId != null) {
        _getOrCreateGroupPeer(userId).then((pc) async {
          final offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          _socket?.emit('group_offer', {
            'roomId':     roomId,
            'fromUserId': _myUserId,
            'toUserId':   userId,
            'offer':      {'sdp': offer.sdp, 'type': offer.type},
          });
        });
      }
      _groupEventCtrl.add(GroupCallEvent(
        type:      'user_joined',
        roomId:    roomId,
        userId:    userId,
        userName:  data['userName'],
        userPhoto: data['userPhoto'],
      ));
    });

    _socket!.on('group_participants', (data) {
      _groupEventCtrl.add(GroupCallEvent(
        type:         'participants',
        roomId:       data['roomId'],
        participants: (data['participants'] as List?)?.map((e) => e.toString()).toList(),
      ));
    });

    _socket!.on('group_offer', (data) async {
      final fromUserId = data['fromUserId'];
      final offer      = data['offer'];
      if (offer == null || fromUserId == null) return;
      final pc = await _getOrCreateGroupPeer(fromUserId);
      await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _socket!.emit('group_answer', {
        'roomId':     data['roomId'],
        'fromUserId': _myUserId,
        'toUserId':   fromUserId,
        'answer':     {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    _socket!.on('group_answer', (data) async {
      final fromUserId = data['fromUserId'];
      final answer     = data['answer'];
      if (fromUserId == null || answer == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
    });

    _socket!.on('group_ice_candidate', (data) async {
      final fromUserId = data['fromUserId'];
      final cand       = data['candidate'];
      if (fromUserId == null || cand == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null) return;
      await pc.addCandidate(RTCIceCandidate(
        cand['candidate'] as String,
        cand['sdpMid'] as String?,
        cand['sdpMLineIndex'] as int,
      ));
    });

    _socket!.on('group_call_ended', (data) {
      _cleanupGroup();
      _eventCtrl.add(CallEvent.callEnded);
    });

    _socket!.on('group_user_left', (data) {
      final userId = data['userId'];
      if (userId == null) return;
      _removeGroupPeer(userId);
      _groupEventCtrl.add(GroupCallEvent(
        type:   'user_left',
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

    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    // ✅ Arrêter le ringback/ringtone AVANT d'acquérir le stream audio
    await RingbackService.instance.stop();

    await _setupPeerConnection();
    await _getLocalStream(isVideo: isVideo);
    // Audio est déjà initialisé sur écouteur via initializeCallAudio() appelé avant

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket!.emit('call_user', {
      'targetUserId': targetUserId,
      'callerId':     _myUserId,
      'callerName':   callerName,
      'callerPhoto':  callerPhoto,
      'isVideo':      isVideo,
      'offer':        {'sdp': offer.sdp, 'type': offer.type},
    });

    if (_myUserId != null) {
      await FcmSender.sendCallNotification(
        toUserId:   targetUserId,
        callerName: callerName,
        isVideo:    isVideo,
        callerId:   _myUserId!,
        offer:      {'sdp': offer.sdp, 'type': offer.type},
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
    _isGroupCall  = true;
    _groupRoomId  = roomId;
    _remoteUserId = null;

    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    // ✅ Arrêter le ringback/ringtone AVANT d'acquérir le stream audio
    await RingbackService.instance.stop();

    await _getLocalStream(isVideo: isVideo);
    await setSpeaker(true);

    _socket!.emit('create_group_call', {
      'roomId':        roomId,
      'callerId':      _myUserId,
      'callerName':    callerName,
      'callerPhoto':   callerPhoto,
      'isVideo':       isVideo,
      'targetUserIds': targetUserIds,
    });

    if (_myUserId != null) {
      for (final uid in targetUserIds) {
        await FcmSender.sendGroupCallNotification(
          toUserId:   uid,
          callerName: callerName,
          isVideo:    isVideo,
          callerId:   _myUserId!,
          roomId:     roomId,
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
    _isGroupCall  = true;
    _groupRoomId  = roomId;
    _remoteUserId = null;

    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    // ✅ Arrêter le ringback/ringtone AVANT d'acquérir le stream audio
    await RingbackService.instance.stop();

    await _getLocalStream(isVideo: isVideo);
    // Audio est déjà initialisé sur écouteur via initializeCallAudio() appelé avant

    _socket!.emit('join_group_call', {
      'roomId':    roomId,
      'userId':    userId,
      'userName':  userName,
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
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    // ✅ Arrêter le ringback/ringtone AVANT d'acquérir le stream audio
    await RingbackService.instance.stop();

    _remoteUserId = incoming.callerId;  // ← DÉFINIR la source comme remote
    await _setupPeerConnection();
    await _getLocalStream(isVideo: incoming.isVideo);
    // Audio est déjà initialisé sur écouteur via initializeCallAudio() appelé avant

    final offer = RTCSessionDescription(incoming.offer['sdp'], incoming.offer['type']);
    await _peerConnection!.setRemoteDescription(offer);
    _remoteDescriptionSet = true;  // ← ACTIVER le flag après setRemoteDescription!
    debugPrint('[Call] OK Remote description set (answer side). Processing ${_pendingIceCandidates.length} pending candidates...');
    
    // Ajouter tous les ICE candidates en attente
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[Call] Error adding pending candidate: $e');
      }
    }
    _pendingIceCandidates.clear();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket!.emit('answer_call', {
      'callerId': incoming.callerId,
      'answer':   {'sdp': answer.sdp, 'type': answer.type},
    });

    // Annuler la notification d'appel entrant côté Android
    await NotificationService.instance.cancelIncomingCallNotification();
  }

  // ── Refuser un appel ──────────────────────────────────────────────
  void rejectCall(String callerId) {
    _socket?.emit('reject_call', {'callerId': callerId});
    _cleanup();
    // Annuler la notification
    NotificationService.instance.cancelIncomingCallNotification();
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
        _socket?.emit('end_call', {'targetUserId': _remoteUserId});
      }
      _cleanup();
    }
    _eventCtrl.add(CallEvent.callEnded);
    // Annuler la notification si encore visible
    NotificationService.instance.cancelIncomingCallNotification();
  }

  // ── Toggle micro / caméra / speaker ──────────────────────────────
  void toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
  }

  bool get isMuted =>
      _localStream?.getAudioTracks().firstOrNull?.enabled == false;

  void toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
  }

  Future<void> setSpeaker(bool enabled) async {
    try {
      debugPrint('[Audio] Setting speaker to: $enabled');
      await _audioChannel.invokeMethod('setSpeaker', {'enabled': enabled});
      debugPrint('[Audio] ✅ Speaker set successfully');
    } catch (e) {
      debugPrint('[Audio] ❌ Error setting speaker: $e');
    }
  }

  /// Initialise l'audio pour les appels avec écouteur interne par défaut.
  /// À appeler AVANT de jouer le ringtone ou le ringback !
  Future<void> initializeCallAudio() async {
    try {
      debugPrint('[Audio] Initializing call audio on earpiece');
      await _audioChannel.invokeMethod('initializeCallAudio');
      debugPrint('[Audio] ✅ Call audio initialized');
    } catch (e) {
      debugPrint('[Audio] ❌ Error initializing call audio: $e');
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  // ── Setup PeerConnection ──────────────────────────────────────────
  Future<void> _setupPeerConnection() async {
    _callConnectedEmitted = false;
    _remoteDescriptionSet = false;  // Réinitialiser le flag
    _pendingIceCandidates.clear();  // Nettoyer les candidates en attente

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
          'username':   '4ccd30e6211751522c93c044',
          'credential': 'iB+/hPI3lLayZAKn',
        },
        {
          'urls': [
            'turn:free.expressturn.com:3478',
            'turn:free.expressturn.com:3478?transport=tcp',
          ],
          'username':   '000000002089277421',
          'credential': 'MZNCzpa/GM4ZvRcYONi4+9qgZRU=',
        },
      ],
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('ice_candidate', {
        'targetUserId': _remoteUserId,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // onTrack : mettre à jour le stream distant et émettre callConnected en fallback
    _peerConnection!.onTrack = (event) async {
      debugPrint('[WebRTC] 🔊 Remote track received: ${event.track.kind}');
      
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else {
        _remoteStream = await createLocalMediaStream(
            'remote-${_remoteUserId ?? 'unknown'}');
        _remoteStream!.addTrack(event.track);
      }
      _remoteStreamCtrl.add(_remoteStream);
      
      // Émettre callConnected si pas encore fait (fallback pour 1-to-1)
      // Cela s'exécute si onConnectionState ou onIceConnectionState ne l'ont pas fait
      if (!_callConnectedEmitted) {
        _callConnectedEmitted = true;
        debugPrint('[WebRTC] ✅ Call connected via onTrack (fallback)');
        debugPrint('[CallService] >>> About to emit CallEvent.callConnected to listeners');
        _eventCtrl.add(CallEvent.callConnected);
        debugPrint('[CallService] >>> CallEvent.callConnected emitted');
      }
    };

    // onConnectionState : gérer les changements d'état et les erreurs
    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
      
      // Emitter callConnected si la connexion s'établit (backup du fallback)
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          !_callConnectedEmitted) {
        _callConnectedEmitted = true;
        debugPrint('[CallService] >>> About to emit CallEvent.callConnected from onConnectionState');
        _eventCtrl.add(CallEvent.callConnected);
        debugPrint('[CallService] >>> CallEvent.callConnected emitted from onConnectionState');
        debugPrint('[WebRTC] Call connected via onConnectionState');
      }
      
      // Gérer les erreurs et fermetures
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('[WebRTC] ❌ Connection lost or failed: $state');
        _lastError = 'Connection failed: $state';
        _eventCtrl.add(CallEvent.callFailed);
        _cleanup();  // ← Nettoyer proprement en cas d'erreur
      }
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('[WebRTC] Connection closed');
      }
    };

    // onIceConnectionState : source unique de vérité pour ICE diagnostics
    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[ICE] Connection state: $state');
      
      // Émettre callConnected si ICE est établie
      if ((state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) &&
          !_callConnectedEmitted) {
        _callConnectedEmitted = true;
        debugPrint('[CallService] >>> About to emit CallEvent.callConnected from onIceConnectionState');
        _eventCtrl.add(CallEvent.callConnected);
        debugPrint('[CallService] >>> CallEvent.callConnected emitted from onIceConnectionState');
        debugPrint('[ICE] ✅ Call connected via ICE');
      }
      
      // Surveiller les problèmes de connexion ICE
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('[ICE] ❌ ICE connection FAILED - this is likely a STUN/TURN or NAT issue');
        _lastError = 'ICE connection failed';
      }
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        debugPrint('[ICE] Connection disconnected, attempting to reconnect...');
      }
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        debugPrint('[ICE] Connection closed');
      }
    };

    _peerConnection!.onSignalingState = (state) {
      debugPrint('[Signaling] State: $state');
    };
    
    _peerConnection!.onIceGatheringState = (state) {
      debugPrint('[ICE] Gathering state: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        debugPrint('[ICE] ✅ ICE gathering completed');
      }
    };
  }

  Future<RTCPeerConnection> _getOrCreateGroupPeer(String userId) async {
    final existing = _groupPeerConnections[userId];
    if (existing != null) return existing;

    final Map<String, dynamic> config = {
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

    final pc = await createPeerConnection(config);
    _groupPeerConnections[userId] = pc;

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    pc.onIceCandidate = (candidate) {
      if (_groupRoomId == null) return;
      _socket?.emit('group_ice_candidate', {
        'roomId':     _groupRoomId,
        'fromUserId': _myUserId,
        'toUserId':   userId,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
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
    _groupRemoteStreamsCtrl.add(<String, MediaStream>{});
    _groupRoomId          = null;
    _isGroupCall          = false;
    _callConnectedEmitted = false;
    // Annuler la notification d'appel entrant
    NotificationService.instance.cancelIncomingCallNotification();
  }

  Future<void> _getLocalStream({required bool isVideo}) async {
    try {
      // ✅ Initialiser en mode earpiece (haut-parleur désactivé) par défaut
      await setSpeaker(false);
      
      debugPrint('[Media] Requesting local media stream (audio + ${isVideo ? 'video' : 'no video'})');
      
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl':  true,
        },
        'video': isVideo
            ? {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}}
            : false,
      });

      debugPrint('[Media] OK Local stream acquired: ${_localStream?.getTracks().length} tracks');
      
      // Ajouter les tracks au PeerConnection
      if (_peerConnection != null) {
        debugPrint('[Media] Adding ${_localStream?.getTracks().length} tracks to PeerConnection');
        _localStream!.getTracks().forEach((track) {
          debugPrint('[Media] Adding track: ${track.kind}');
          _peerConnection!.addTrack(track, _localStream!);
        });
        debugPrint('[Media] OK All tracks added to PeerConnection');
      } else {
        debugPrint('[Media] WARNING: _peerConnection is null when adding tracks!');
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

  // ── Nettoyage ─────────────────────────────────────────────────────
  void _cleanup() {
    setSpeaker(false);
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection       = null;
    _remoteUserId         = null;
    _callConnectedEmitted = false;
    _remoteDescriptionSet = false;  // Réinitialiser le flag
    _pendingIceCandidates.clear();  // Nettoyer les candidates en attente
    _localStreamCtrl.add(null);
    _remoteStreamCtrl.add(null);
    // Annuler la notification d'appel entrant
    NotificationService.instance.cancelIncomingCallNotification();
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