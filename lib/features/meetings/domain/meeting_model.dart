// lib/features/meetings/domain/meeting_model.dart

class MeetingParticipantModel {
  final int idMeeting;
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String? avatarUrl;
  final bool isOnline;
  final int status;   // 0=invité 1=accepté 2=refusé
  final bool connecte;
  final int duree;    // secondes

  const MeetingParticipantModel({
    required this.idMeeting,
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    this.avatarUrl,
    this.isOnline = false,
    this.status = 0,
    this.connecte = false,
    this.duree = 0,
  });

  factory MeetingParticipantModel.fromJson(Map<String, dynamic> json) {
    return MeetingParticipantModel(
      idMeeting:  json['idMeeting']  as int? ?? 0,
      alanyaID:   json['IDparticipant'] as int? ?? 0,
      nom:        json['nom']        as String? ?? '',
      pseudo:     json['pseudo']     as String? ?? '',
      avatarUrl:  json['avatar_url'] as String?,
      isOnline:   (json['is_online'] as int? ?? 0) == 1,
      status:     json['status']     as int? ?? 0,
      connecte:   (json['connecte']  as int? ?? 0) == 1,
      duree:      json['duree']      as int? ?? 0,
    );
  }

  String get displayName => pseudo.isNotEmpty ? pseudo : nom;
}

class MeetingModel {
  final int idMeeting;
  final int idOrganiser;
  final String organiserNom;
  final String organiserPseudo;
  final String? organiserAvatar;
  final DateTime startTime;
  final int duree;       // minutes
  final String objet;
  final String room;
  final bool isEnd;
  final int typeMedia;   // 0=audio 1=video
  final List<MeetingParticipantModel> participants;

  const MeetingModel({
    required this.idMeeting,
    required this.idOrganiser,
    this.organiserNom = '',
    this.organiserPseudo = '',
    this.organiserAvatar,
    required this.startTime,
    this.duree = 60,
    required this.objet,
    required this.room,
    this.isEnd = false,
    this.typeMedia = 0,
    this.participants = const [],
  });

  bool get isVideo => typeMedia == 1;
  bool get isActive => !isEnd && startTime.isBefore(
    DateTime.now().add(const Duration(minutes: 30)),
  );

  String get organiserDisplay =>
      organiserPseudo.isNotEmpty ? organiserPseudo : organiserNom;

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participants'] as List<dynamic>? ?? [];
    return MeetingModel(
      idMeeting:       json['idMeeting']        as int? ?? 0,
      idOrganiser:     json['idOrganiser']       as int? ?? 0,
      organiserNom:    json['organiser_nom']     as String? ?? '',
      organiserPseudo: json['organiser_pseudo']  as String? ?? '',
      organiserAvatar: json['organiser_avatar']  as String?,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      duree:    json['duree']      as int? ?? 60,
      objet:    json['objet']      as String? ?? '',
      room:     json['room']       as String? ?? '',
      isEnd:    (json['isEnd']     as int? ?? 0) == 1,
      typeMedia: json['type_media'] as int? ?? 0,
      participants: participantsRaw
          .map((e) => MeetingParticipantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'start_time': startTime.toIso8601String(),
    'duree':      duree,
    'objet':      objet,
    'room':       room,
    'type_media': typeMedia,
  };
}