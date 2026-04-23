// lib/features/chat/presentation/widgets/voice_recorder_widget.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(String path, int durationSeconds) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  String? _filePath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _startRecording();
    HapticFeedback.mediumImpact();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Permission micro refusée'),
              backgroundColor: Colors.red));
          widget.onCancel();
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      _filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: _filePath!,
      );

      setState(() => _isRecording = true);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
        if (_seconds >= 300) _stopRecording();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur micro: $e'), backgroundColor: Colors.red));
        widget.onCancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
      if (_filePath != null && _seconds > 0) {
        widget.onRecordingComplete(_filePath!, _seconds);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
      // Supprimer le fichier temporaire
      if (_filePath != null) {
        final file = File(_filePath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color:context.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Annuler
          GestureDetector(
            onTap: _cancelRecording,
            child:
                const Icon(Icons.delete_rounded, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 16),

          // Indicateur + timer
          Expanded(
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          Colors.red.withOpacity(0.5 + _pulseCtrl.value * 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_formattedTime,
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
                const SizedBox(width: 12),
                Expanded(child: _WaveformWidget(tick: _seconds)),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Envoyer
          GestureDetector(
            onTap: _isRecording ? _stopRecording : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primaryColor,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visualisation onde ─────────────────────────────────────────────────
class _WaveformWidget extends StatelessWidget {
  final int tick;
  const _WaveformWidget({required this.tick});

  @override
  Widget build(BuildContext context) {
    final heights = [
      8.0,
      16.0,
      24.0,
      12.0,
      20.0,
      8.0,
      18.0,
      14.0,
      22.0,
      10.0,
      16.0,
      24.0,
      8.0,
      20.0,
      12.0,
      18.0,
      24.0,
      10.0,
      16.0,
      8.0
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(20, (i) {
        final active = (tick % 20) > i;
        return Container(
          width: 3,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active
                ? context.primaryColor
                : context.primaryColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ── Bulle lecture vocale ───────────────────────────────────────────────
class VoiceMessageBubble extends StatefulWidget {
  final String? audioUrl;
  final int? durationSeconds;
  final bool isMine;
  final bool isGroup;
  final String senderName;
  final DateTime sentAt;

  const VoiceMessageBubble({
    super.key,
    this.audioUrl,
    this.durationSeconds,
    required this.isMine,
    required this.isGroup,
    required this.senderName,
    required this.sentAt,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isReady = false;
  bool _hasError = false;

  String _formatDuration(int? secs) {
    if (secs == null) return '0:00';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDurationFromDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.audioUrl;
    if (url == null || url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }
    try {
      await _player.setUrl(url);
      _durSub = _player.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d ?? Duration.zero);
      });
      _posSub = _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _isPlaying = s.playing);
      });
      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  double get _progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0, 1);
  }

  void _togglePlay() {
    if (!_isReady || _hasError) return;
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seek(double v) {
    if (!_isReady || _hasError) return;
    final total = _duration.inMilliseconds;
    if (total <= 0) return;
    final target = Duration(milliseconds: (v * total).round());
    _player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackDuration = widget.durationSeconds != null
        ? Duration(seconds: widget.durationSeconds!)
        : Duration.zero;
    final shownDuration =
        _duration.inSeconds > 0 ? _duration : fallbackDuration;

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment:
              widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Afficher le nom de l'expéditeur pour les messages de groupe
            if (!widget.isMine &&
                widget.isGroup &&
                widget.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  widget.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.primaryColor,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
                minWidth: 200,
              ),
              decoration: BoxDecoration(
                 
                color: widget.isMine ? context.primaryColor : context.appThemeColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(widget.isMine ? 18 : 4),
                  bottomRight: Radius.circular(widget.isMine ? 4 : 18),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isMine 
                          ? Colors.white.withValues(alpha : 0.4) 
                          : context.primaryColor.withValues(alpha : 0.4),
                      ),
                      child: _hasError
                          ? Icon(Icons.error_outline_rounded,
                              color: widget.isMine ? Colors.white :  context.primaryColor , size: 22)
                          : Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: widget.isMine ? Colors.white :  context.primaryColor ,
                              size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            activeTrackColor: widget.isMine ? Colors.white :  context.primaryColor ,
                            inactiveTrackColor:widget.isMine ? Colors.white.withValues(alpha: 0.4) :  context.primaryColor ,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _progress,
                            onChanged: _seek,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(AppIcons.mic,
                                  color: widget.isMine ? Colors.white.withValues(alpha :0.4) :  context.primaryColor ,
                                  size: 10),
                              Text(
                                  shownDuration.inSeconds > 0
                                      ? _formatDurationFromDuration(
                                          shownDuration)
                                      : _formatDuration(widget.durationSeconds),
                                  style: TextStyle(
                                      color: widget.isMine ? Colors.white.withValues(alpha :0.4) :  context.primaryColor ,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
