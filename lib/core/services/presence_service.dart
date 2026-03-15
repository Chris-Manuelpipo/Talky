// lib/core/services/presence_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  StreamSubscription<DatabaseEvent>? _connSub;
  StreamSubscription<DatabaseEvent>? _statusSub;

  Future<void> start(String uid) async {
    await stop();

    final db = FirebaseDatabase.instance;
    final fs = FirebaseFirestore.instance;

    final userStatusRef = db.ref('status/$uid');
    final connectedRef = db.ref('.info/connected');

    _connSub = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value == true;
      if (!connected) return;

      await userStatusRef.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      await userStatusRef.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      await fs.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    });

    _statusSub = userStatusRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final lastSeen = data['lastSeen'];

      await fs.collection('users').doc(uid).update({
        'isOnline': data['isOnline'] == true,
        'lastSeen': lastSeen is int
            ? Timestamp.fromMillisecondsSinceEpoch(lastSeen)
            : FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> stop() async {
    await _connSub?.cancel();
    await _statusSub?.cancel();
    _connSub = null;
    _statusSub = null;
  }
}
