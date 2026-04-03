// lib/core/services/ringback_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class RingbackService {
  static final RingbackService instance = RingbackService._();
  RingbackService._();

  final _player = AudioPlayer();
  bool _isRinging = false;

  // ── Appelant : ringback tone ───────────────────────────────────────
  Future<void> play() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      await _player.setAsset(
          'assets/sounds/475550__nucleartape__ring-back-tone.wav');
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (e) {
      debugPrint('[RingbackService.play()] Erreur: $e');
      _isRinging = false;  // ← Réinitialiser le flag en cas d'erreur
    }
  }

  // ── Appelé : sonnerie système du téléphone ─────────────────────────
  Future<void> playRingtone() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
    } catch (e) {
      debugPrint('[RingbackService.playRingtone()] Erreur: $e');
      _isRinging = false;  // ← Réinitialiser le flag en cas d'erreur
    }
  }

  // ── Arrêter tout ───────────────────────────────────────────────────
  Future<void> stop() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await FlutterRingtonePlayer().stop();
    } catch (_) {}
  }
}