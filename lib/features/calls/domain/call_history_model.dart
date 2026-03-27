// lib/features/calls/domain/call_history_model.dart

enum CallType { incoming, outgoing, missed }

class CallHistoryModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final bool isGroup;
  final String? groupName;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final CallType type;
  final DateTime timestamp;
  final int durationSeconds; // Durée en secondes (0 pour appels manqués)
  final bool isVideo;

  CallHistoryModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    this.isGroup = false,
    this.groupName,
    this.participantIds = const [],
    this.participantNames = const {},
    this.participantPhotos = const {},
    required this.type,
    required this.timestamp,
    this.durationSeconds = 0,
    this.isVideo = false,
  });

  Map<String, dynamic> toMap() => {
        'callerId': callerId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhoto': receiverPhoto,
        'isGroup': isGroup,
        'groupName': groupName,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'isVideo': isVideo,
      };

  factory CallHistoryModel.fromMap(String id, Map<String, dynamic> map) =>
      CallHistoryModel(
        id: id,
        callerId: map['callerId'] as String,
        callerName: map['callerName'] as String,
        callerPhoto: map['callerPhoto'] as String?,
        receiverId: map['receiverId'] as String,
        receiverName: map['receiverName'] as String,
        receiverPhoto: map['receiverPhoto'] as String?,
        isGroup: map['isGroup'] as bool? ?? false,
        groupName: map['groupName'] as String?,
        participantIds: List<String>.from(map['participantIds'] ?? const []),
        participantNames:
            Map<String, String>.from(map['participantNames'] ?? const {}),
        participantPhotos:
            Map<String, String?>.from(map['participantPhotos'] ?? const {}),
        type: CallType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => CallType.missed,
        ),
        timestamp: DateTime.parse(map['timestamp'] as String),
        durationSeconds: map['durationSeconds'] as int? ?? 0,
        isVideo: map['isVideo'] as bool? ?? false,
      );

  /// Returns formatted duration string (e.g., "5:30" or "1:05:30")
  String get formattedDuration {
    if (durationSeconds == 0) return '';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns the name of the other person in the call
  String getDisplayName(String currentUserId) {
    if (isGroup) return groupName ?? 'Appel de groupe';
    if (callerId == currentUserId) {
      return receiverName;
    }
    return callerName;
  }

  /// Returns the photo of the other person in the call
  String? getDisplayPhoto(String currentUserId) {
    if (isGroup) return null;
    if (callerId == currentUserId) {
      return receiverPhoto;
    }
    return callerPhoto;
  }

  /// Check if this call was made by the current user
  bool isOutgoing(String currentUserId) => callerId == currentUserId;
}
