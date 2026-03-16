// lib/core/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../router/app_router.dart';
import '../../features/calls/presentation/incoming_call_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // Stocker les données d'appel entrant pour les utiliser après navigation
  static Map<String, dynamic>? _pendingIncomingCall;
  
  static Map<String, dynamic>? get pendingIncomingCall => _pendingIncomingCall;

  static const _messageChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'Notifications de nouveaux messages',
    importance: Importance.high,
  );

  static const _callChannel = AndroidNotificationChannel(
    'calls',
    'Appels',
    description: 'Notifications d’appels entrants',
    importance: Importance.max,
  );

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

    FirebaseMessaging.onMessage.listen(showNotificationFromMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      // Updated when user is known via registerTokenForUser.
      _lastToken = token;
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleMessageNavigation(initial);
  }

  String? _lastToken;

  Future<void> registerTokenForUser(String uid) async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    _lastToken = token;
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  Future<void> showNotificationFromMessage(RemoteMessage message) async {
    if (!_initialized) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);
      await _local.initialize(initSettings);
      _initialized = true;
    }
    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_messageChannel);
      await android?.createNotificationChannel(_callChannel);
    }

    final data = message.data;
    final type = data['type'] as String? ?? 'message';
    final title = message.notification?.title ?? data['title'] ?? 'Talky';
    final body = message.notification?.body ?? data['body'] ?? '';
    final payload = data.isNotEmpty ? data.toString() : null;

    if (type == 'call') {
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

  void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    
    // Gérer les appels entrants - afficher l'écran d'appel
    if (type == 'call') {
      final callerId = data['callerId'] as String?;
      final callerName = message.notification?.title ?? data['title'] as String? ?? 'Appel entrant';
      final isVideo = (data['body'] as String?)?.contains('vidéo') ?? false;
      
      // Extraire l'offre SDP de la notification (si présent)
      Map<String, dynamic> offer = {};
      if (data['offer'] != null) {
        final offerData = data['offer'];
        if (offerData is Map) {
          offer = Map<String, dynamic>.from(offerData);
        } else if (offerData is String && offerData.isNotEmpty) {
          // Parser le JSON stringifié si nécessaire
          try {
            offer = Map<String, dynamic>.from(
              jsonDecode(offerData) as Map
            );
          } catch (_) {
            // Garder offer vide si le parsing échoue
          }
        }
      }
      
      if (callerId != null && rootNavigatorKey.currentContext != null) {
        // Stocker les données d'appel pour les utiliser après la navigation
        _pendingIncomingCall = {
          'callerId': callerId,
          'callerName': callerName,
          'isVideo': isVideo,
          'offer': offer,
        };
        
        Navigator.of(rootNavigatorKey.currentContext!, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallScreen(
              callerId: callerId,
              callerName: callerName,
              isVideo: isVideo,
              offer: offer,
            ),
          ),
        );
        return;
      }
    }
    
    if (type == 'message') {
      final convId = data['conversationId'] as String?;
      final name = data['name'] as String? ?? 'Discussion';
      final photo = data['photo'];
      if (convId != null && convId.isNotEmpty) {
        rootNavigatorKey.currentContext?.push(
          AppRoutes.chat.replaceAll(':conversationId', convId),
          extra: {'name': name, 'photo': photo},
        );
        return;
      }
    }

    // Fallback → accueil
    rootNavigatorKey.currentContext?.go(AppRoutes.home);
  }

  void _handleTap(String? payload) {
    // Si besoin, parser le payload string pour navigation
    rootNavigatorKey.currentContext?.go(AppRoutes.home);
  }
}
