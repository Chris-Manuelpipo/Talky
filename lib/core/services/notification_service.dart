// lib/core/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';
import '../router/app_router.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _messageChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'Notifications de nouveaux messages',
    importance: Importance.high,
  );

  static const _callChannel = AndroidNotificationChannel(
    'calls',
    'Appels',
    description: 'Notifications d\'appels entrants',
    importance: Importance.max,
  );

  // ── Init ──────────────────────────────────────────────────────────
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        _handleTap(resp.payload);
      },
    );
    _initialized = true;

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_messageChannel);
      await android?.createNotificationChannel(_callChannel);
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground FCM
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App en background → tap sur notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);

    // Refresh token 
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await ApiService.instance.updateMe({'fcm_token': newToken});
        debugPrint('[FCM] Token rafraîchi et mis à jour en MySQL ✅');
      } catch (e) {
        debugPrint('[FCM] Échec mise à jour token rafraîchi: $e');
      }
    });

    // App fermée → tap sur notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(initial);
      });
    }
  }

  // ── Token FCM ─────────────────────────────────────────────────────
 
  Future<void> registerTokenForUser(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    try {
      // Sauvegarde dans MySQL via PUT /api/auth/me
      // uid (Firebase) non utilisé : le JWT dans ApiService identifie l'utilisateur
      await ApiService.instance.updateMe({'fcm_token': token});
      debugPrint('[FCM] Token enregistré en MySQL ✅');
    } catch (e) {
      debugPrint('[FCM] Échec enregistrement token: $e');
    }
  }

  // ── Message en foreground ─────────────────────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] as String? ?? 'message';

    if (type == 'call' || type == 'group_call') {
      // Le socket émet incoming_call → listener dans main.dart gère l'affichage
      debugPrint('[Notification] Appel en foreground — géré par socket');
      return;
    }

    if (type == 'meeting_invite' || type == 'meeting_reminder') {
      // Afficher une notification locale pour les réunions
      debugPrint('[Notification] Meeting ${type} en foreground');
      showNotificationFromMessage(message, forceLocal: true);
      return;
    }

    // Message normal en foreground → afficher une notif locale
    showNotificationFromMessage(message, forceLocal: true);
  }

  // ── Afficher une notification locale ─────────────────────────────
  Future<void> showNotificationFromMessage(
    RemoteMessage message, {
    bool forceLocal = false,
  }) async {
    // En background, si le système affiche déjà la notification, ne pas dupliquer
    if (!forceLocal && message.notification != null) return;

    if (!_initialized) await _ensureInitialized();

    final data = message.data;
    final type = data['type'] as String? ?? 'message';
    final title =
        message.notification?.title ?? data['title'] as String? ?? 'Talky';
    final body =
        message.notification?.body ?? data['body'] as String? ?? '';

    // Payload en JSON propre — plus de toString() qui casse le parsing
    final payload = jsonEncode(data);

    if (type == 'call' || type == 'group_call') {
      await _local.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _callChannel.id,
            _callChannel.name,
            channelDescription: _callChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.call,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
      return;
    }

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannel.id,
          _messageChannel.name,
          channelDescription: _messageChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ── Navigation depuis FCM (background / app fermée) ───────────────
  void _handleNavigation(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  // ── Tap sur notification locale ───────────────────────────────────
  void _handleTap(String? payload) {
    if (payload == null) {
      rootNavigatorKey.currentContext?.go(AppRoutes.home);
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('[Notification] Erreur parsing payload: $e');
      rootNavigatorKey.currentContext?.go(AppRoutes.home);
    }
  }

  // ── Logique de navigation centralisée ─────────────────────────────
  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'call':
        // Ramener l'app au premier plan. Le socket va émettre incoming_call
        // avec l'offre SDP réelle → listener dans main.dart affiche l'écran.
        // Ne pas naviguer vers IncomingCallScreen ici (race condition socket).
        GoRouter.of(context).go(AppRoutes.home);
        break;

      case 'group_call':
        final callerId = data['callerId'] as String? ?? '';
        final callerName =
            data['callerName'] as String? ?? 'Appel de groupe';
        final roomId = data['roomId'] as String? ?? '';
        final isVideo =
            data['isVideo'] == true || data['isVideo'] == 'true';
        if (roomId.isNotEmpty) {
          GoRouter.of(context).push(
            AppRoutes.incomingCall,
            extra: {
              'callerId': callerId,
              'callerName': callerName,
              'isVideo': isVideo,
              'isGroup': true,
              'roomId': roomId,
            },
          );
        } else {
          GoRouter.of(context).go(AppRoutes.home);
        }
        break;

      case 'message':
        final convId = data['conversationId'] as String?;
        final name = data['name'] as String? ?? 'Discussion';
        final photo = data['photo'];
        if (convId != null && convId.isNotEmpty) {
          GoRouter.of(context).push(
            AppRoutes.chat.replaceAll(':conversationId', convId),
            extra: {'name': name, 'photo': photo},
          );
        } else {
          GoRouter.of(context).go(AppRoutes.home);
        }
        break;

      case 'meeting_invite':
        // Naviguer vers l'écran des invitations de réunion
        GoRouter.of(context).push(AppRoutes.meetings);
        break;

      case 'meeting_reminder':
        // Naviguer vers l'écran des réunions
        GoRouter.of(context).push(AppRoutes.meetings);
        break;

      default:
        GoRouter.of(context).go(AppRoutes.home);
    }
  }

  // ── Notification full-screen appel entrant (background/socket) ───
  Future<void> showIncomingCallFullScreen({
    required String callerId,
    required String callerName,
    required bool isVideo,
    bool isGroup = false,
    String? roomId,
    Map<String, dynamic>? offer,
  }) async {
    if (!Platform.isAndroid) return;
    const platform = MethodChannel('com.example.talky/call_notification');
    try {
      await platform.invokeMethod('showIncomingCall', {
        'callerId': callerId,
        'callerName': callerName,
        'isVideo': isVideo,
        'isGroup': isGroup,
        'roomId': roomId ?? '',
        // offre SDP volontairement omise — récupérée via socket au réveil
      });
    } catch (e) {
      debugPrint('[Notification] showIncomingCall erreur: $e');
    }
  }

  Future<void> cancelIncomingCallNotification() async {
    if (!Platform.isAndroid) return;
    const platform = MethodChannel('com.example.talky/call_notification');
    try {
      await platform.invokeMethod('cancelNotification');
    } catch (e) {
      debugPrint('[Notification] cancelNotification erreur: $e');
    }
  }

  // ── Helper privé ──────────────────────────────────────────────────
  Future<void> _ensureInitialized() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings);
    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_messageChannel);
      await android?.createNotificationChannel(_callChannel);
    }
    _initialized = true;
  }
}