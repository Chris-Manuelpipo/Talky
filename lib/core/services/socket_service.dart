// lib/core/services/socket_service.dart
//
// Service Socket.IO central — connexion au backend Node.js.
// Gère :
//   - connexion/déconnexion/reconnexion automatique
//   - enregistrement (register) avec alanyaID
//   - streams broadcast pour les events temps réel
//   - rejoindre/quitter une conversation
//
// Firebase est conservé uniquement pour l'auth (token) — le reste passe par ici.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

/// Evénement socket générique représentant un message entrant.
class SocketMessageEvent {
  final int conversationID;
  final Map<String, dynamic> payload;
  const SocketMessageEvent(this.conversationID, this.payload);
}

/// Evénement typing (start / stop).
class SocketTypingEvent {
  final int conversationID;
  final int userID;
  final bool isTyping;
  const SocketTypingEvent({
    required this.conversationID,
    required this.userID,
    required this.isTyping,
  });
}

/// Evénement de mise à jour de présence (online / offline).
class SocketPresenceEvent {
  final int userID;
  final bool online;
  const SocketPresenceEvent({required this.userID, required this.online});
}

/// Evénement de mise à jour du statut d'un message (sent/delivered/read).
class SocketMessageStatusEvent {
  final int msgID;
  final int status;
  final int? conversationID;
  const SocketMessageStatusEvent({
    required this.msgID,
    required this.status,
    this.conversationID,
  });
}

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  int? _myAlanyaID;
  bool _registered = false;

  // ── Streams broadcast ───────────────────────────────────────────────
  final _connectedCtrl = StreamController<bool>.broadcast();
  final _messageCtrl = StreamController<SocketMessageEvent>.broadcast();
  final _typingCtrl = StreamController<SocketTypingEvent>.broadcast();
  final _presenceCtrl = StreamController<SocketPresenceEvent>.broadcast();
  final _statusCtrl = StreamController<SocketMessageStatusEvent>.broadcast();

  Stream<bool> get onConnectedChange => _connectedCtrl.stream;
  Stream<SocketMessageEvent> get onMessage => _messageCtrl.stream;
  Stream<SocketTypingEvent> get onTyping => _typingCtrl.stream;
  Stream<SocketPresenceEvent> get onPresence => _presenceCtrl.stream;
  Stream<SocketMessageStatusEvent> get onMessageStatus => _statusCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;
  int? get myAlanyaID => _myAlanyaID;

  // ── Connexion ────────────────────────────────────────────────────────
  Future<void> connect(int alanyaID) async {
    _myAlanyaID = alanyaID;

    if (_socket != null) {
      if (_socket!.connected) {
        _emitRegister();
        return;
      }
      _socket!.dispose();
      _socket = null;
    }

    final token = await _getFirebaseToken();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth(token != null ? {'token': token} : <String, dynamic>{})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('[SocketService] Connecté');
        _connectedCtrl.add(true);
        _emitRegister();
      })
      ..onReconnect((_) {
        debugPrint('[SocketService] Reconnecté');
        _emitRegister();
      })
      ..onDisconnect((_) {
        debugPrint('[SocketService] Déconnecté');
        _registered = false;
        _connectedCtrl.add(false);
      })
      ..onConnectError((err) {
        debugPrint('[SocketService] Erreur connexion: $err');
      })
      ..onError((err) {
        debugPrint('[SocketService] Erreur: $err');
      });

    _wireEvents();
    _socket!.connect();
  }

  Future<String?> _getFirebaseToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  void _emitRegister() {
    final id = _myAlanyaID;
    if (id == null || _socket == null) return;
    _socket!.emit('register', {'alanyaID': id});
    _registered = true;
    // Informer le backend qu'on est en ligne
    _socket!.emit('presence:online', {'userID': id});
  }

  void _wireEvents() {
    if (_socket == null) return;

    // Nouveau message reçu (diffusé par le backend après persistance)
    _socket!.on('message:received', (data) {
      if (data is Map) {
        final convId = _asInt(data['conversationID']);
        if (convId == null) return;
        _messageCtrl.add(SocketMessageEvent(
          convId,
          Map<String, dynamic>.from(data),
        ));
      }
    });

    // Typing
    _socket!.on('typing:started', (data) {
      if (data is Map) {
        final convId = _asInt(data['conversationID']);
        final uid = _asInt(data['userID']);
        if (convId == null || uid == null) return;
        _typingCtrl.add(SocketTypingEvent(
          conversationID: convId,
          userID: uid,
          isTyping: true,
        ));
      }
    });
    _socket!.on('typing:stopped', (data) {
      if (data is Map) {
        final convId = _asInt(data['conversationID']);
        final uid = _asInt(data['userID']);
        if (convId == null || uid == null) return;
        _typingCtrl.add(SocketTypingEvent(
          conversationID: convId,
          userID: uid,
          isTyping: false,
        ));
      }
    });

    // Présence
    _socket!.on('presence:updated', (data) {
      if (data is Map) {
        final uid = _asInt(data['userID']);
        if (uid == null) return;
        _presenceCtrl.add(SocketPresenceEvent(
          userID: uid,
          online: data['online'] == true,
        ));
      }
    });

    // Mise à jour de statut d'un message
    _socket!.on('message:status_update', (data) {
      if (data is Map) {
        final msgId = _asInt(data['msgID']);
        final status = _asInt(data['status']);
        if (msgId == null || status == null) return;
        _statusCtrl.add(SocketMessageStatusEvent(
          msgID: msgId,
          status: status,
          conversationID: _asInt(data['conversationID']),
        ));
      }
    });
  }

  // ── Rejoindre / quitter une conversation ─────────────────────────────
  void joinConversation(int conversationID) {
    _socket?.emit('join_conversation', {'conversationID': conversationID});
  }

  void leaveConversation(int conversationID) {
    _socket?.emit('leave_conversation', {'conversationID': conversationID});
  }

  // ── Typing ──────────────────────────────────────────────────────────
  void startTyping(int conversationID) {
    final uid = _myAlanyaID;
    if (uid == null) return;
    _socket?.emit('typing:start', {
      'conversationID': conversationID,
      'userID': uid,
    });
  }

  void stopTyping(int conversationID) {
    final uid = _myAlanyaID;
    if (uid == null) return;
    _socket?.emit('typing:stop', {
      'conversationID': conversationID,
      'userID': uid,
    });
  }

  // ── Broadcast du message envoyé (fallback si le backend ne broadcast pas) ──
  /// À appeler après un POST message réussi pour que les autres clients
  /// reçoivent `message:received` même si le backend n'émet rien.
  void broadcastSentMessage(Map<String, dynamic> message) {
    final convId = _asInt(message['conversationID']);
    if (convId == null) return;
    _socket?.emit('message:send', {
      'conversationID': convId,
      ...message,
    });
  }

  // ── Mise à jour de statut (delivered / read) ────────────────────────
  void sendMessageStatus({
    required int msgID,
    required int status,
    required int conversationID,
  }) {
    _socket?.emit('message:status', {
      'msgID': msgID,
      'status': status,
      'conversationID': conversationID,
    });
  }

  // ── Présence explicite ──────────────────────────────────────────────
  void setOnline() {
    final uid = _myAlanyaID;
    if (uid == null) return;
    _socket?.emit('presence:online', {'userID': uid});
  }

  void setOffline() {
    final uid = _myAlanyaID;
    if (uid == null) return;
    _socket?.emit('presence:offline', {'userID': uid});
  }

  // ── Déconnexion ─────────────────────────────────────────────────────
  Future<void> disconnect() async {
    setOffline();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _registered = false;
    _myAlanyaID = null;
    _connectedCtrl.add(false);
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is num) return v.toInt();
    return null;
  }

  // ignore: unused_element
  bool get _isRegistered => _registered;
}
