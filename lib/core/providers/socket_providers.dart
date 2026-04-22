// lib/core/providers/socket_providers.dart
//
// Providers Riverpod autour de SocketService.
// Le service est initialisé dès que currentUserProfileProvider fournit un alanyaID.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/socket_service.dart';

/// Service Socket.IO singleton.
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService.instance;
});

/// Stream de l'état de connexion socket (true/false).
final socketConnectedProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.onConnectedChange;
});
