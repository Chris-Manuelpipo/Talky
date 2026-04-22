-- =============================================================
--  TALKY — Script SQL complet
--  MySQL 8.0+
--  Créé le : 2026-04-18
-- =============================================================

CREATE DATABASE IF NOT EXISTS talky
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE talky;

-- =============================================================
--  1. PAYS  (référentiel — pas de dépendances)
-- =============================================================
CREATE TABLE pays (
  idPays          SMALLINT     NOT NULL AUTO_INCREMENT,
  libelle         VARCHAR(100) NOT NULL,
  prefix          VARCHAR(4)   NOT NULL,
  timeZone        VARCHAR(100) NULL,
  decalageHoraire INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (idPays)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed data pays (référentiel pays avec préfixes téléphoniques)
INSERT INTO pays (idPays, libelle, prefix, timeZone, decalageHoraire) VALUES
(1, 'France', '+33', 'Europe/Paris', 1),
(2, 'United States', '+1', 'America/New_York', -5),
(3, 'United Kingdom', '+44', 'Europe/London', 0),
(4, 'Germany', '+49', 'Europe/Berlin', 1),
(5, 'Spain', '+34', 'Europe/Madrid', 1),
(6, 'Italy', '+39', 'Europe/Rome', 1),
(7, 'Belgium', '+32', 'Europe/Brussels', 1),
(8, 'Switzerland', '+41', 'Europe/Zurich', 1),
(9, 'Canada', '+1', 'America/Toronto', -5),
(10, 'Cameroon', '+237', 'Africa/Douala', 1),
(11, 'Congo', '+243', 'Africa/Kinshasa', 1),
(12, 'Gabon', '+241', 'Africa/Libreville', 1),
(13, 'Côte d''Ivoire', '+225', 'Africa/Abidjan', 0),
(14, 'Senegal', '+221', 'Africa/Dakar', 0),
(15, 'Mali', '+223', 'Africa/Bamako', 0),
(16, 'Burkina Faso', '+226', 'Africa/Ouagadougou', 0),
(17, 'Niger', '+227', 'Africa/Niamey', 1),
(18, 'Chad', '+235', 'Africa/Ndjamena', 1),
(19, 'Central African Republic', '+236', 'Africa/Bangui', 1),
(20, 'Equatorial Guinea', '+240', 'Africa/Malabo', 1),
(21, 'China', '+86', 'Asia/Shanghai', 8),
(22, 'Japan', '+81', 'Asia/Tokyo', 9),
(23, 'India', '+91', 'Asia/Kolkata', 5),
(24, 'Brazil', '+55', 'America/Sao_Paulo', -3),
(25, 'Argentina', '+54', 'America/Argentina/Buenos_Aires', -3),
(26, 'Mexico', '+52', 'America/Mexico_City', -6),
(27, 'Australia', '+61', 'Australia/Sydney', 10),
(28, 'Russia', '+7', 'Europe/Moscow', 3),
(29, 'South Africa', '+27', 'Africa/Johannesburg', 2),
(30, 'Nigeria', '+234', 'Africa/Lagos', 1);

-- =============================================================
--  2. USERS
-- =============================================================
CREATE TABLE users (
  alanyaID    INT          NOT NULL AUTO_INCREMENT,
  nom         VARCHAR(60)  NOT NULL,
  pseudo      VARCHAR(80)  NOT NULL DEFAULT 'Kamite',
  alanyaPhone VARCHAR(20)  NOT NULL,
  idPays      SMALLINT     NOT NULL,
  password    VARCHAR(255) NOT NULL,
  avatar_url  VARCHAR(255) NOT NULL DEFAULT 'NON DEFINI',
  type_compte SMALLINT     NULL     DEFAULT 0,
  is_online   TINYINT      NOT NULL DEFAULT 0,
  last_seen   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  exclus      TINYINT      NOT NULL DEFAULT 0,
  in_call     TINYINT      NOT NULL DEFAULT 0,
  biometric   TINYINT      NOT NULL DEFAULT 0,
  fcm_token   VARCHAR(255) NOT NULL DEFAULT 'INDEFINI',
  device_ID   VARCHAR(255) NOT NULL DEFAULT 'INDEFINI' COMMENT 'Android ID ou Apple ID',
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (alanyaID),
  UNIQUE KEY uq_phone (alanyaPhone),
  CONSTRAINT fk_users_pays FOREIGN KEY (idPays) REFERENCES pays(idPays) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  3. PREFERRED_CONTACT  (contacts / amis)
-- =============================================================
CREATE TABLE preferredContact (
  idPrefContact BIGINT   NOT NULL AUTO_INCREMENT,
  alanyaID      INT      NOT NULL,
  idFriend      INT      NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idPrefContact),
  UNIQUE KEY uq_friendship (alanyaID, idFriend),
  CONSTRAINT fk_pref_owner  FOREIGN KEY (alanyaID) REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_pref_friend FOREIGN KEY (idFriend) REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  4. BLOCKED
-- =============================================================
CREATE TABLE blocked (
  idBlock       INT      NOT NULL AUTO_INCREMENT,
  alanyaID      INT      NOT NULL,
  idCallerBlock INT      NOT NULL,
  dateBlock     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idBlock),
  UNIQUE KEY uq_block (alanyaID, idCallerBlock),
  CONSTRAINT fk_block_owner  FOREIGN KEY (alanyaID)      REFERENCES users(alanyaID) ON UPDATE CASCADE,
  CONSTRAINT fk_block_target FOREIGN KEY (idCallerBlock) REFERENCES users(alanyaID) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  5. USER_ACCESS  (journal de connexions)
-- =============================================================
CREATE TABLE userAccess (
  idLogin    BIGINT       NOT NULL AUTO_INCREMENT,
  alanyaID   INT          NOT NULL,
  device     VARCHAR(255) NOT NULL DEFAULT 'INDEFINI',
  dateLogin  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ipAdress   VARCHAR(255) NOT NULL DEFAULT 'INDEFINI',
  os_system  VARCHAR(255) NOT NULL DEFAULT 'INDEFINI',
  PRIMARY KEY (idLogin),
  CONSTRAINT fk_access_user FOREIGN KEY (alanyaID) REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  6. CONVERSATION
--     ⚠ participantID / isPinned / isArchived / unreadCount
--       sont gérés PAR UTILISATEUR dans conv_participants
-- =============================================================
CREATE TABLE conversation (
  conversID             BIGINT       NOT NULL AUTO_INCREMENT,
  isGroup               TINYINT      NOT NULL DEFAULT 0,
  GroupName             VARCHAR(255) NULL,
  groupPhoto            VARCHAR(255) NULL,
  lastMessage           TEXT         NULL,
  lastMessageAt         DATETIME     NULL,
  lastMessageSenderID   INT          NULL,
  lastMessageType       SMALLINT     NOT NULL DEFAULT 0  COMMENT '0=text 1=image 2=video 3=audio 4=file',
  lastMessageStatus     TINYINT      NOT NULL DEFAULT 0  COMMENT '0=sent 1=delivered 2=read',
  PRIMARY KEY (conversID),
  CONSTRAINT fk_conv_last_sender FOREIGN KEY (lastMessageSenderID) REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  7. CONV_PARTICIPANTS  (jointure conversation ↔ users)
--     Remplace conversation.participantID (un seul user)
--     Stocke isPinned / isArchived / unreadCount PAR USER
-- =============================================================
CREATE TABLE conv_participants (
  id          BIGINT   NOT NULL AUTO_INCREMENT,
  conversID   BIGINT   NOT NULL,
  alanyaID    INT      NOT NULL,
  unreadCount SMALLINT NOT NULL DEFAULT 0,
  isPinned    TINYINT  NOT NULL DEFAULT 0,
  isArchived  TINYINT  NOT NULL DEFAULT 0,
  joinedAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_conv_user (conversID, alanyaID),
  CONSTRAINT fk_cp_conv FOREIGN KEY (conversID) REFERENCES conversation(conversID) ON DELETE CASCADE,
  CONSTRAINT fk_cp_user FOREIGN KEY (alanyaID)  REFERENCES users(alanyaID)         ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  8. MESSAGE
-- =============================================================
CREATE TABLE message (
  msgID          BIGINT       NOT NULL AUTO_INCREMENT,
  senderID       INT          NOT NULL,
  conversationID BIGINT       NOT NULL,
  content        TEXT         NULL,
  type           SMALLINT     NULL     DEFAULT 0  COMMENT '0=text 1=image 2=video 3=audio 4=file 5=location',
  status         TINYINT      NOT NULL DEFAULT 0  COMMENT '0=sending 1=sent 2=delivered 3=read',
  sendAt         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  readAt         DATETIME     NULL,
  mediaUrl       VARCHAR(255) NULL,
  mediaName      VARCHAR(255) NULL,
  mediaDuration  INT          NULL     DEFAULT 0  COMMENT 'Durée en secondes (audio/vidéo)',
  isDeleted      TINYINT      NOT NULL DEFAULT 0,
  deletedForID   INT          NULL               COMMENT 'NULL=visible tous | id=supprimé pour cet user uniquement',
  isEdited       TINYINT      NOT NULL DEFAULT 0,
  editedAt       DATETIME     NULL,
  replyToID      BIGINT       NULL,
  replyToContent TEXT         NULL,
  isStatusReply  TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (msgID),
  CONSTRAINT fk_msg_sender    FOREIGN KEY (senderID)       REFERENCES users(alanyaID)        ON UPDATE CASCADE,
  CONSTRAINT fk_msg_conv      FOREIGN KEY (conversationID) REFERENCES conversation(conversID) ON DELETE CASCADE,
  CONSTRAINT fk_msg_reply     FOREIGN KEY (replyToID)      REFERENCES message(msgID)          ON DELETE SET NULL,
  CONSTRAINT fk_msg_del_for   FOREIGN KEY (deletedForID)   REFERENCES users(alanyaID)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  9. STATUT  (Stories 24h)
-- =============================================================
CREATE TABLE statut (
  ID              INT          NOT NULL AUTO_INCREMENT,
  alanyaID        INT          NOT NULL,
  type            SMALLINT     NOT NULL             COMMENT '0=text 1=image 2=video',
  text            TINYTEXT     NOT NULL,
  mediaUrl        VARCHAR(255) NULL,
  backgroundColor VARCHAR(20)  NULL,
  createdAt       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expiredAt       DATETIME     NOT NULL,
  viewedBy        INT          NOT NULL DEFAULT 0   COMMENT 'Compteur dénormalisé',
  likedBy         INT          NOT NULL DEFAULT 0   COMMENT 'Compteur dénormalisé',
  PRIMARY KEY (ID),
  CONSTRAINT fk_statut_user FOREIGN KEY (alanyaID) REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  10. STATUT_VIEWS  (détail des vues — qui a vu quand)
-- =============================================================
CREATE TABLE statut_views (
  id       BIGINT   NOT NULL AUTO_INCREMENT,
  statutID INT      NOT NULL,
  alanyaID INT      NOT NULL,
  seenAt   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_statut_viewer (statutID, alanyaID),
  CONSTRAINT fk_sv_statut FOREIGN KEY (statutID) REFERENCES statut(ID)           ON DELETE CASCADE,
  CONSTRAINT fk_sv_user   FOREIGN KEY (alanyaID) REFERENCES users(alanyaID)      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  11. MEETING  (appels de groupe / réunions)
-- =============================================================
CREATE TABLE meeting (
  idMeeting   INT          NOT NULL AUTO_INCREMENT,
  idOrganiser INT          NOT NULL,
  start_time  DATETIME     NOT NULL,
  duree       INT          NOT NULL DEFAULT 0,
  objet       VARCHAR(255) NOT NULL DEFAULT 'NON DEFINI',
  room        VARCHAR(100) NOT NULL,
  isEnd       TINYINT      NOT NULL DEFAULT 0,
  type_media  TINYINT      NOT NULL DEFAULT 0  COMMENT '0=audio 1=video',
  PRIMARY KEY (idMeeting),
  CONSTRAINT fk_meeting_organiser FOREIGN KEY (idOrganiser) REFERENCES users(alanyaID) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  12. PARTICIPANT  (membres d'une réunion/appel groupe)
-- =============================================================
CREATE TABLE participant (
  ID            INT      NOT NULL AUTO_INCREMENT,
  idMeeting     INT      NOT NULL,
  IDparticipant INT      NOT NULL,
  status        TINYINT  NOT NULL DEFAULT 0  COMMENT '0=invité 1=accepté 2=refusé',
  start_time    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  connecte      TINYINT  NULL,
  duree         INT      NOT NULL DEFAULT 0,
  PRIMARY KEY (ID),
  UNIQUE KEY uq_meeting_user (idMeeting, IDparticipant),
  CONSTRAINT fk_part_meeting FOREIGN KEY (idMeeting)     REFERENCES meeting(idMeeting)    ON DELETE CASCADE,
  CONSTRAINT fk_part_user    FOREIGN KEY (IDparticipant) REFERENCES users(alanyaID)        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  13. CALL_HISTORY  (appels 1-à-1)
-- =============================================================
CREATE TABLE callHistory (
  IDcall     BIGINT   NOT NULL AUTO_INCREMENT,
  idCaller   INT      NOT NULL,
  idReceiver INT      NOT NULL,
  type       SMALLINT NOT NULL DEFAULT 0  COMMENT '0=audio 1=video',
  status     SMALLINT NOT NULL DEFAULT 0  COMMENT '0=missed 1=answered 2=rejected',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  duree      INT      NOT NULL DEFAULT 0  COMMENT 'Durée en secondes',
  PRIMARY KEY (IDcall),
  CONSTRAINT fk_call_caller   FOREIGN KEY (idCaller)   REFERENCES users(alanyaID) ON UPDATE CASCADE,
  CONSTRAINT fk_call_receiver FOREIGN KEY (idReceiver) REFERENCES users(alanyaID) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  INDEX DE PERFORMANCE
-- =============================================================

-- Messages d'une conversation triés par date (requête la plus fréquente)
CREATE INDEX idx_message_conv_date    ON message(conversationID, sendAt DESC);

-- Conversations d'un utilisateur
CREATE INDEX idx_cp_user_conv         ON conv_participants(alanyaID, conversID);

-- Statuts actifs (non expirés) d'un utilisateur
CREATE INDEX idx_statut_user_exp      ON statut(alanyaID, expiredAt);

-- Historique appels
CREATE INDEX idx_call_caller_date     ON callHistory(idCaller,   created_at DESC);
CREATE INDEX idx_call_receiver_date   ON callHistory(idReceiver, created_at DESC);

-- Recherche user par téléphone (login)
CREATE INDEX idx_users_phone          ON users(alanyaPhone);

-- Statut online (présence)
CREATE INDEX idx_users_online         ON users(is_online, last_seen);
