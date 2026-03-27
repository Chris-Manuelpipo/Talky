import 'dart:convert';
import 'package:http/http.dart' as http;

class FcmSender {
  static const _serverUrl = 'https://talky-signaling.onrender.com';

  static Future<void> sendMessageNotification({
    required String toUserId,
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'toUserId': toUserId,
          'title': senderName,
          'body': message,
          'type': 'message',
          'conversationId': conversationId,
        }),
      );
    } catch (_) {
      // Best-effort: notification failures shouldn't block sending.
    }
  }

  static Future<void> sendCallNotification({
    required String toUserId,
    required String callerName,
    required bool isVideo,
    required String callerId,
    Map<String, dynamic>? offer,
  }) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'toUserId': toUserId,
          'title': callerName,
          'body': isVideo ? 'Appel video entrant' : 'Appel audio entrant',
          'type': 'call',
          'callerId': callerId,
          'offer': offer,
        }),
      );
    } catch (_) {
      // Best-effort: notification failures shouldn't block calling.
    }
  }

  static Future<void> sendGroupCallNotification({
    required String toUserId,
    required String callerName,
    required bool isVideo,
    required String callerId,
    required String roomId,
  }) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'toUserId': toUserId,
          'title': callerName,
          'body': isVideo ? 'Appel vidéo de groupe' : 'Appel audio de groupe',
          'type': 'group_call',
          'callerId': callerId,
          'roomId': roomId,
          'isVideo': isVideo,
        }),
      );
    } catch (_) {
      // Best-effort: notification failures shouldn't block calling.
    }
  }
}
