// lib/core/services/api_service.dart
//
// Service HTTP centralisé — remplace tous les appels Firestore.
// Firebase est conservé UNIQUEMENT pour l'authentification (getIdToken).

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  // ── Singleton ────────────────────────────────────────────────────
  ApiService._();
  static final ApiService instance = ApiService._();

  static const Duration _timeout = Duration(seconds: 15);

  Future<String?> _getToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[ApiService] Token error: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var seg = parts[1];
      final pad = seg.length % 4;
      if (pad != 0) seg += '=' * (4 - pad);
      final json = utf8.decode(base64Url.decode(seg));
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool _payloadHasPhoneClaim(Map<String, dynamic>? p) {
    if (p == null) return false;
    return p['phone_number'] != null || p['talky_phone'] != null;
  }

  Future<void> _refreshTokenUntilPhoneClaim() async {
    for (var i = 0; i < 15; i++) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token != null) {
        final p = _decodeJwtPayload(token);
        if (_payloadHasPhoneClaim(p)) return;
      }
      await Future<void>.delayed(Duration(milliseconds: 150 + i * 50));
    }
    debugPrint(
      '[ApiService] Le jeton ne contient toujours pas phone_number / talky_phone après register.',
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = 'Erreur serveur';
    try {
      final body = jsonDecode(response.body);
      message = body['error'] ?? body['message'] ?? message;
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool skipAuth = false,
  }) async {
    final uri =
        Uri.parse('${AppConfig.apiUrl}$path').replace(queryParameters: query);
    final headers =
        skipAuth ? {'Content-Type': 'application/json'} : await _headers();
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    return _parse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool skipAuth = false,
  }) async {
    final headers =
        skipAuth ? {'Content-Type': 'application/json'} : await _headers();
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _parse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.apiUrl}$path'),
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _parse(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) async {
    final uri =
        Uri.parse('${AppConfig.apiUrl}$path').replace(queryParameters: query);
    final response =
        await http.delete(uri, headers: await _headers()).timeout(_timeout);
    return _parse(response);
  }

  // ════════════════════════════════════════════════════════════════
  //  AUTH
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getMe() async =>
      await get('/auth/me') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async =>
      await put('/auth/me', body: data) as Map<String, dynamic>;

  Future<Map<String, dynamic>> registerUser({
    required String nom,
    String? phone,
    String? pseudo,
    String? avatarUrl,
    int? idPays,
    String? fcmToken,
    String? deviceID,
  }) async {
    final result = await post('/auth/register', body: {
      'nom': nom,
      if (phone != null) 'phone': phone,
      if (pseudo != null) 'pseudo': pseudo,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (idPays != null) 'idPays': idPays,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (deviceID != null) 'device_ID': deviceID,
    }) as Map<String, dynamic>;

    try {
      await _refreshTokenUntilPhoneClaim();
    } catch (e) {
      debugPrint('[ApiService] token refresh after register failed: $e');
    }

    return result;
  }

  Future<Map<String, dynamic>> phoneExists(String phone) async =>
      await get('/auth/phone-exists/$phone', skipAuth: true)
          as Map<String, dynamic>;

  // ════════════════════════════════════════════════════════════════
  //  PAYS (référentiel)
  // ════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getPays() async =>
      await get('/pays', skipAuth: true) as List<dynamic>;

  Future<int?> getIdPaysByPrefix(String prefix) async {
    final pays = await getPays();
    for (final p in pays) {
      if (p['prefix'] == prefix) return p['idPays'] as int;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════
  //  USERS
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUserById(int alanyaID) async =>
      await get('/users/$alanyaID') as Map<String, dynamic>;

  Future<Map<String, dynamic>> getUserByPhone(String phone) async =>
      await get('/users/phone/$phone') as Map<String, dynamic>;

  Future<List<dynamic>> searchUsers(String query) async =>
      await get('/users/search', query: {'q': query}) as List<dynamic>;

  Future<void> blockUser(int alanyaID) async =>
      await post('/users/$alanyaID/block');

  Future<void> unblockUser(int alanyaID) async =>
      await delete('/users/$alanyaID/block');

  // ════════════════════════════════════════════════════════════════════════
  //  CONVERSATIONS
  // ════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getConversations() async =>
      await get('/conversations') as List<dynamic>;

  Future<Map<String, dynamic>> getConversationById(int conversID) async =>
      await get('/conversations/$conversID') as Map<String, dynamic>;

  Future<Map<String, dynamic>> getOrCreateConversation(
          int participantID) async =>
      await post('/conversations', body: {'participantID': participantID})
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> createGroup({
    required List<int> participantIDs,
    required String groupName,
    String? groupPhoto,
  }) async =>
      await post('/conversations/group', body: {
        'participantIDs': participantIDs,
        'groupName': groupName,
        if (groupPhoto != null) 'groupPhoto': groupPhoto,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateConversation(
          int conversID, Map<String, dynamic> data) async =>
      await put('/conversations/$conversID', body: data)
          as Map<String, dynamic>;

  Future<void> deleteConversation(int conversID) async =>
      await delete('/conversations/$conversID');

  Future<void> markConversationAsRead(int conversID) async =>
      await post('/conversations/$conversID/read');

  Future<void> leaveGroup(int conversID) async =>
      await post('/conversations/$conversID/leave');

  // ════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getMessages(
    int conversID, {
    int limit = 50,
    int? before,
  }) async =>
      await get(
        '/conversations/$conversID/messages',
        query: {
          'limit': limit.toString(),
          if (before != null) 'before': before.toString(),
        },
      ) as List<dynamic>;

  Future<Map<String, dynamic>> sendMessage(
    int conversID, {
    String? content,
    int type = 0,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? replyToID,
    String? replyToContent,
    bool isStatusReply = false,
  }) async =>
      await post('/conversations/$conversID/messages', body: {
        if (content != null) 'content': content,
        'type': type,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaName != null) 'mediaName': mediaName,
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
        if (replyToID != null) 'replyToID': replyToID,
        if (replyToContent != null) 'replyToContent': replyToContent,
        'isStatusReply': isStatusReply,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateMessage(int msgID, String content) async =>
      await put('/messages/$msgID', body: {'content': content})
          as Map<String, dynamic>;

  Future<void> deleteMessage(int msgID, {bool all = false}) async =>
      await delete('/messages/$msgID', query: {'all': all.toString()});

  // ════════════════════════════════════════════════════════════════
  //  STATUTS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getStatuses() async =>
      await get('/status') as List<dynamic>;

  Future<List<dynamic>> getMyStatuses() async =>
      await get('/status/me') as List<dynamic>;

  Future<List<dynamic>> getStatusViews(int statutID) async =>
      await get('/status/$statutID/views') as List<dynamic>;

  Future<Map<String, dynamic>> createStatus({
    required String text,
    int type = 0,
    String? mediaUrl,
    String? backgroundColor,
  }) async =>
      await post('/status', body: {
        'text': text,
        'type': type,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
      }) as Map<String, dynamic>;

  Future<void> deleteStatus(int statutID) async =>
      await delete('/status/$statutID');

  Future<void> viewStatus(int statutID) async =>
      await post('/status/$statutID/view');

  // ════════════════════════════════════════════════════════════════
  //  APPELS
  // ════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCalls() async =>
      await get('/calls') as List<dynamic>;

  Future<Map<String, dynamic>> createCall(
          {required int idReceiver, int type = 0}) async =>
      await post('/calls', body: {'idReceiver': idReceiver, 'type': type})
          as Map<String, dynamic>;

  Future<void> endCall(int IDcall, {int status = 1}) async =>
      await put('/calls/$IDcall/end', body: {'status': status});

  // ══════════════════════════════════════════���═════════════════════
  //  MEETINGS (RÉUNIONS)
  // ════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getMeetings() async =>
      await get('/meetings') as List<dynamic>;

  Future<Map<String, dynamic>> createMeeting({
    required DateTime startTime,
    required String objet,
    required String room,
    int duree = 60,
    int typeMedia = 0,
  }) async =>
      await post('/meetings', body: {
        'start_time': startTime.toIso8601String(),
        'duree': duree,
        'objet': objet,
        'room': room,
        'type_media': typeMedia,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getMeetingById(int meetingId) async =>
      await get('/meetings/$meetingId') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateMeeting(
    int meetingId, {
    DateTime? startTime,
    String? objet,
    String? room,
    int? duree,
    bool? isEnd,
  }) async =>
      await put('/meetings/$meetingId', body: {
        if (startTime != null) 'start_time': startTime.toIso8601String(),
        if (objet != null) 'objet': objet,
        if (room != null) 'room': room,
        if (duree != null) 'duree': duree,
        if (isEnd != null) 'isEnd': isEnd ? 1 : 0,
      }) as Map<String, dynamic>;

  Future<void> deleteMeeting(int meetingId) async =>
      await delete('/meetings/$meetingId');

  Future<void> joinMeeting(int meetingId) async =>
      await post('/meetings/$meetingId/join', body: {});

  Future<void> inviteParticipants(
          int meetingId, List<int> participantIds) async =>
      await post('/meetings/$meetingId/invite', body: {
        'participant_ids': participantIds,
      });

  Future<void> acceptJoinRequest(int meetingId, int userId) async =>
      await post('/meetings/$meetingId/accept/$userId', body: {});

  Future<void> declineJoinRequest(int meetingId, int userId) async =>
      await post('/meetings/$meetingId/decline/$userId', body: {});
}
