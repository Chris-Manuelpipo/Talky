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
        }),
      );
    } catch (_) {
      // Best-effort: notification failures shouldn't block calling.
    }
  }
}
