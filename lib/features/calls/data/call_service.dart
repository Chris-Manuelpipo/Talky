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
  // Événements d'appel de groupe
  groupCallInvite,
  userJoinedGroupCall,
  userLeftGroupCall,
  groupCallConnected,
  groupCallEnded,
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

// Données pour les appels de groupe
class GroupCallParticipant {
  final String oderId;
  final String name;
  final String? photo;
  final bool isVideo;
  final RTCPeerConnection? peerConnection;
  final MediaStream? stream;

  GroupCallParticipant({
    required this.oderId,
    required this.name,
    this.photo,
    this.isVideo = false,
    this.peerConnection,
    this.stream,
  });
}

class GroupCallInviteData {
  final String roomId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final Map<String, dynamic> offer;

  const GroupCallInviteData({
    required this.roomId,
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
  String? _lastError;

  // ── Group call state ───────────────────────────────────────────────────
  String? _currentGroupRoomId;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};
  final Map<String, GroupCallParticipant> _groupParticipants = {};
  bool _isGroupCall = false;

  // Streams pour notifier l'UI
  final _eventCtrl   = StreamController<CallEvent>.broadcast();
  final _incomingCtrl = StreamController<IncomingCallData>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();
  // Group call streams
  final _groupInviteCtrl = StreamController<GroupCallInviteData>.broadcast();
  final _groupParticipantJoinedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _groupParticipantLeftCtrl = StreamController<String>.broadcast();
  final _groupParticipantsCtrl = StreamController<List<String>>.broadcast();
  final _groupRemoteStreamCtrl = StreamController<MapEntry<String, MediaStream>>.broadcast();

  Stream<CallEvent>       get events       => _eventCtrl.stream;
  Stream<IncomingCallData> get incomingCalls => _incomingCtrl.stream;
  Stream<MediaStream?> get localStreamUpdates => _localStreamCtrl.stream;
  Stream<MediaStream?> get remoteStreamUpdates => _remoteStreamCtrl.stream;
  // Group call streams
  Stream<GroupCallInviteData> get groupCallInvites => _groupInviteCtrl.stream;
  Stream<Map<String, dynamic>> get participantJoined => _groupParticipantJoinedCtrl.stream;
  Stream<String> get participantLeft => _groupParticipantLeftCtrl.stream;
  Stream<List<String>> get groupParticipantsList => _groupParticipantsCtrl.stream;
  Stream<MapEntry<String, MediaStream>> get groupRemoteStreamUpdates => _groupRemoteStreamCtrl.stream;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected => _socket?.connected ?? false;
  String? get lastError => _lastError;
  
  // Group call getters
  String? get currentGroupRoomId => _currentGroupRoomId;
  bool get isInGroupCall => _currentGroupRoomId != null;
  Map<String, GroupCallParticipant> get groupParticipants => _groupParticipants;
  Map<String, MediaStream> get groupRemoteStreams => _groupRemoteStreams;

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

    // ── Événements d'appel de groupe ───────────────────────────────────
    _socket!.on('group_call_invite', (data) async {
      debugPrint('[Socket] group_call_invite received: $data');
      final invite = GroupCallInviteData(
        roomId: data['roomId'],
        callerId: data['callerId'],
        callerName: data['callerName'],
        callerPhoto: data['callerPhoto'],
        isVideo: data['isVideo'] ?? false,
        offer: Map<String, dynamic>.from(data['offer'] ?? {}),
      );
      _groupInviteCtrl.add(invite);
      _eventCtrl.add(CallEvent.groupCallInvite);
    });

    _socket!.on('user_joined_group_call', (data) async {
      debugPrint('[Socket] user_joined_group_call received: $data');
      final userId = data['userId'] as String;
      final userName = data['userName'] as String?;
      final userPhoto = data['userPhoto'] as String?;
      final offer = Map<String, dynamic>.from(data['offer'] ?? {});
      final roomId = data['roomId'] as String;
      
      // Créer une connexion peer pour ce participant
      if (offer.isNotEmpty) {
        await _createGroupPeerConnection(userId, roomId, isInitiator: true, remoteOffer: offer);
      }
      
      _groupParticipantJoinedCtrl.add({
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
      });
    });

    _socket!.on('group_call_participants', (data) {
      debugPrint('[Socket] group_call_participants received: $data');
      final roomId = data['roomId'] as String;
      final participants = List<String>.from(data['participants'] ?? []);
      _currentGroupRoomId = roomId;
      _groupParticipantsCtrl.add(participants);
      
      // Créer des connexions avec chaque participant existant
      for (final participantId in participants) {
        _createGroupPeerConnection(participantId, roomId, isInitiator: true);
      }
    });

    _socket!.on('user_left_group_call', (data) {
      debugPrint('[Socket] user_left_group_call received: $data');
      final userId = data['userId'] as String;
      final roomId = data['roomId'] as String;
      
      // Nettoyer la connexion peer
      _groupPeerConnections[userId]?.close();
      _groupPeerConnections.remove(userId);
      _groupRemoteStreams[userId]?.dispose();
      _groupRemoteStreams.remove(userId);
      _groupParticipants.remove(userId);
      
      _groupParticipantLeftCtrl.add(userId);
    });

    _socket!.on('group_call_answer', (data) async {
      debugPrint('[Socket] group_call_answer received: $data');
      final answer = RTCSessionDescription(
        data['answer']['sdp'], data['answer']['type']);
      final roomId = data['roomId'] as String;
      
      // Trouver la connexion correspondante et définir la description distante
      for (final entry in _groupPeerConnections.entries) {
        final pc = entry.value;
        try {
          final remoteDesc = await pc.getRemoteDescription();
          if (remoteDesc == null) {
            await pc.setRemoteDescription(answer);
            break;
          }
        } catch (_) {
          // Continuer
        }
      }
    });

    _socket!.on('group_ice_candidate', (data) async {
      debugPrint('[Socket] group_ice_candidate received: $data');
      if (data != null && data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'] as String,
          data['candidate']['sdpMid'] as String?,
          data['candidate']['sdpMLineIndex'] as int,
        );
        
        // Trouver la connexion correspondante
        for (final pc in _groupPeerConnections.values) {
          try {
            await pc.addCandidate(candidate);
          } catch (_) {
            // Ignorer les erreurs
          }
        }
      }
    });

    _socket!.on('group_call_ended', (data) {
      debugPrint('[Socket] group_call_ended received: $data');
      _cleanupGroupCall();
      _eventCtrl.add(CallEvent.groupCallEnded);
    });

    _socket!.on('group_call_error', (data) {
      debugPrint('[Socket] group_call_error received: $data');
      _lastError = data is Map ? data['reason']?.toString() : 'group_call_error';
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
    if (_remoteUserId != null) {
      _socket!.emit('end_call', {'targetUserId': _remoteUserId});
    }
    _cleanup();
    _eventCtrl.add(CallEvent.callEnded);
  }

  // ── Créer un appel de groupe ──────────────────────────────────────────
  Future<void> createGroupCall({
    required String roomId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
  }) async {
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    _currentGroupRoomId = roomId;
    _isGroupCall = true;
    _isVideo = isVideo;

    // Obtenir le flux local
    await _getLocalStream(isVideo: isVideo);
    await setSpeaker(true);

    // Créer l'offre pour chaque participant
    final config = _getPeerConnectionConfig();
    _groupPeerConnections.clear();

    final offer = await createPeerConnection(config).then((pc) async {
      // Ajouter les tracks locales
      _localStream?.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
      
      final o = await pc.createOffer();
      await pc.setLocalDescription(o);
      return o;
    });

    // Émettre l'événement de création de groupe
    _socket!.emit('create_group_call', {
      'roomId': roomId,
      'callerId': _myUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'isVideo': isVideo,
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });

    debugPrint('[GroupCall] Created room $roomId');
  }

  // ── Rejoindre un appel de groupe ───────────────────────────────────────
  Future<void> joinGroupCall({
    required String roomId,
    required String userName,
    String? userPhoto,
  }) async {
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    _currentGroupRoomId = roomId;
    _isGroupCall = true;

    // Obtenir le flux local
    await _getLocalStream(isVideo: false);
    await setSpeaker(true);

    _socket!.emit('join_group_call', {
      'roomId': roomId,
      'userId': _myUserId,
      'userName': userName,
      'userPhoto': userPhoto,
      'offer': null,
    });

    debugPrint('[GroupCall] Joined room $roomId');
  }

  // ── Quitter un appel de groupe ─────────────────────────────────────────
  void leaveGroupCall() {
    if (_currentGroupRoomId != null) {
      _socket!.emit('leave_group_call', {'roomId': _currentGroupRoomId});
    }
    _cleanupGroupCall();
    _eventCtrl.add(CallEvent.groupCallEnded);
  }

  // ── Terminer un appel de groupe (pour le créateur) ─────────────────────
  void endGroupCall() {
    if (_currentGroupRoomId != null) {
      _socket!.emit('end_group_call', {'roomId': _currentGroupRoomId});
    }
    _cleanupGroupCall();
    _eventCtrl.add(CallEvent.groupCallEnded);
  }

  // ── Répondre à une invitation d'appel de groupe ───────────────────────
  Future<void> answerGroupCall(GroupCallInviteData invite) async {
    if (_socket == null || !_socket!.connected) {
      _lastError = 'Connexion au serveur en cours. Réessaie dans 5 secondes';
      _eventCtrl.add(CallEvent.callFailed);
      return;
    }

    _currentGroupRoomId = invite.roomId;
    _isGroupCall = true;
    _isVideo = invite.isVideo;

    // Obtenir le flux local
    await _getLocalStream(isVideo: invite.isVideo);
    await setSpeaker(true);

    // Configurer la connexion peer avec l'offre
    final pc = await _setupGroupPeerConnection(invite.callerId, invite.roomId);

    if (invite.offer.isNotEmpty) {
      final offer = RTCSessionDescription(
        invite.offer['sdp'], invite.offer['type']);
      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket!.emit('answer_group_call', {
        'roomId': invite.roomId,
        'targetUserId': invite.callerId,
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });
    }

    // Rejoindre officiellement le groupe
    _socket!.emit('join_group_call', {
      'roomId': invite.roomId,
      'userId': _myUserId,
      'userName': '',
      'userPhoto': null,
      'offer': null,
    });

    debugPrint('[GroupCall] Answered invite from ${invite.callerId}');
  }

  // ── Créer une connexion peer pour un participant ───────────────────────
  Future<RTCPeerConnection> _createGroupPeerConnection(
    String participantId,
    String roomId, {
    bool isInitiator = false,
    Map<String, dynamic>? remoteOffer,
  }) async {
    final pc = await _setupGroupPeerConnection(participantId, roomId);

    if (isInitiator && remoteOffer == null) {
      // Créer une offre pour ce participant
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _socket!.emit('join_group_call', {
        'roomId': roomId,
        'userId': _myUserId,
        'userName': '',
        'userPhoto': null,
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      });
    }

    return pc;
  }

  // ── Configurer une connexion peer pour un participant ─────────────────
  Future<RTCPeerConnection> _setupGroupPeerConnection(
    String participantId,
    String roomId,
  ) async {
    final config = _getPeerConnectionConfig();
    final pc = await createPeerConnection(config);

    _groupPeerConnections[participantId] = pc;

    // Ajouter le flux local
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Gestion des ICE candidates
    pc.onIceCandidate = (candidate) {
      debugPrint('[GroupCall] ICE candidate for $participantId');
      _socket!.emit('group_ice_candidate', {
        'roomId': roomId,
        'targetUserId': participantId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // Réception des tracks distants
    pc.onTrack = (event) async {
      debugPrint('[GroupCall] onTrack from $participantId: ${event.track.kind}');
      
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[participantId] = event.streams[0];
      } else {
        final stream = await createLocalMediaStream('remote-$participantId');
        stream.addTrack(event.track!);
        _groupRemoteStreams[participantId] = stream;
      }
      
      _groupRemoteStreamCtrl.add(MapEntry(participantId, _groupRemoteStreams[participantId]!));
      _eventCtrl.add(CallEvent.groupCallConnected);
    };

    pc.onConnectionState = (state) {
      debugPrint('[GroupCall] Connection state with $participantId: $state');
    };

    pc.onIceConnectionState = (state) {
      debugPrint('[GroupCall] ICE state with $participantId: $state');
    };

    return pc;
  }

  // ── Configuration des serveurs ICE ─────────────────────────────────────
  Map<String, dynamic> _getPeerConnectionConfig() {
    return {
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
          'username': '000000002089217611',
          'credential': '8W315Gw7cTZY2+PRhdVv+rHHPRU=',
        },
      ],
      'iceCandidatePoolSize': 10,
    };
  }

  // ── Nettoyage appel de groupe ──────────────────────────────────────────
  void _cleanupGroupCall() {
    setSpeaker(false);
    
    // Fermer toutes les connexions peer
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    _groupPeerConnections.clear();
    
    // Disposer les streams distants
    for (final stream in _groupRemoteStreams.values) {
      stream.dispose();
    }
    _groupRemoteStreams.clear();
    _groupParticipants.clear();
    
    _currentGroupRoomId = null;
    _isGroupCall = false;
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

    final config = {
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
          'username': '000000002089217611',
          'credential': '8W315Gw7cTZY2+PRhdVv+rHHPRU=',
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
        _remoteStream!.addTrack(event.track!);
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

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
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
    _cleanup();
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _cleanup();
    _cleanupGroupCall();
    _socket?.disconnect();
    _eventCtrl.close();
    _incomingCtrl.close();
    _localStreamCtrl.close();
    _remoteStreamCtrl.close();
    _groupInviteCtrl.close();
    _groupParticipantJoinedCtrl.close();
    _groupParticipantLeftCtrl.close();
    _groupParticipantsCtrl.close();
    _groupRemoteStreamCtrl.close();
  }
}

