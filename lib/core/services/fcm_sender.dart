import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Envoie des notifications push via le backend Node (FCM), pas l’ancien serveur signaling seul.
///
/// L’URL est dérivée de [API_BASE_URL] (`…/api` → `…/notify`), comme le reste du client.
/// Surcharge : `--dart-define=NOTIFY_BASE_URL=https://hôte/notify` (URL complète du POST).
class FcmSender {
  static String get _notifyEndpoint {
    const explicit = String.fromEnvironment('NOTIFY_BASE_URL');
    if (explicit.isNotEmpty) return explicit;
    const apiBase = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://talky-signaling.onrender.com/api',
    );
    final uri = Uri.parse(apiBase);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/notify',
    ).toString();
  }

  static Future<void> _post(Map<String, dynamic> body) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      await http.post(
        Uri.parse(_notifyEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      // Best-effort: notification failures shouldn't block sending.
    }
  }

  static Future<void> sendMessageNotification({
    required String toUserId,
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    await _post({
      'toUserId': toUserId,
      'title': senderName,
      'body': message,
      'type': 'message',
      'conversationId': conversationId,
    });
  }

  static Future<void> sendCallNotification({
    required String toUserId,
    required String callerName,
    required bool isVideo,
    required String callerId,
    Map<String, dynamic>? offer,
  }) async {
    await _post({
      'toUserId': toUserId,
      'title': callerName,
      'body': isVideo ? 'Appel video entrant' : 'Appel audio entrant',
      'type': 'call',
      'callerId': callerId,
      'offer': offer,
    });
  }

  static Future<void> sendGroupCallNotification({
    required String toUserId,
    required String callerName,
    required bool isVideo,
    required String callerId,
    required String roomId,
  }) async {
    await _post({
      'toUserId': toUserId,
      'title': callerName,
      'body': isVideo ? 'Appel vidéo de groupe' : 'Appel audio de groupe',
      'type': 'group_call',
      'callerId': callerId,
      'roomId': roomId,
      'isVideo': isVideo,
    });
  }
}
