import 'package:just_audio/just_audio.dart';

class RingbackService {
  static final RingbackService instance = RingbackService._();
  RingbackService._();
  
  final _player = AudioPlayer();
  
  Future<void> play() async {
    await _player.setAsset('assets/sounds/475550__nucleartape__ring-back-tone.wav');
    _player.setLoopMode(LoopMode.one);
    await _player.play();
  }
  
  Future<void> stop() async {
    await _player.stop();
  }
}
