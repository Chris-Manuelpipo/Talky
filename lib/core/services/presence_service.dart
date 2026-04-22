// lib/core/services/presence_service.dart
//
// Service de présence — migré de Firebase Realtime Database vers Socket.IO.
// Firebase RTDB et Firestore complètement supprimés.
// La présence est gérée via SocketService (emit presence:online/offline)
// et persistée dans MySQL par le backend.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';
import '../../features/auth/data/auth_service.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  String? _currentUid;
  bool _isRunning = false;

  // ── Démarrer la présence ─────────────────────────────────────────
  Future<void> start(String uid) async {
    if (_isRunning && _currentUid == uid) return;
    await stop();

    _currentUid = uid;
    _isRunning  = true;

    // Signaler la présence en ligne via socket
    // (le backend met à jour is_online = 1 dans MySQL)
    SocketService.instance.setOnline();

    debugPrint('[PresenceService] Présence démarrée pour $uid');
  }

  // ── Arrêter la présence ──────────────────────────────────────────
  Future<void> stop() async {
    if (!_isRunning) return;

    // Signaler le départ avant de couper
    SocketService.instance.setOffline();

    // Mettre à jour MySQL via REST (fallback si socket déjà déconnecté)
    try {
      final authService = AuthService();
      await authService.setOnlineStatus(false);
    } catch (e) {
      debugPrint('[PresenceService.stop] $e');
    }

    _currentUid = null;
    _isRunning  = false;
    debugPrint('[PresenceService] Présence arrêtée');
  }

  bool get isRunning => _isRunning;
  String? get currentUid => _currentUid;
}