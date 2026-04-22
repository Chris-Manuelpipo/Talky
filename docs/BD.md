# Structure de la Base de Données - Talky

## Base de données : MySQL

---

## 1. Table : `users`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `alnyaID` | INT | NO | ID unique (Firebase Auth UID) |
| `nom` | VARCHAR(255) | NO | Nom de l'utilisateur |
| `pseudo` | VARCHAR(255) | NO | Pseudo (par défaut: "Kamite") |
| `alanyaPhone` | VARCHAR(50) | NO | Numéro de téléphone |
| `idPays` | SMALLINT | NO | Référence pays → FK |
| `password` | VARCHAR(255) | NO | Mot de passe (hash) |
| `avatar_url` | VARCHAR(500) | NO | URL photo de profil |
| `type_compte` | SMALLINT | YES | Type de compte (défaut: 0) |
| `is_online` | TINYINT | NO | En ligne (0/1) |
| `last_seen` | DATETIME | NO | Dernière connexion |
| `exclus` | TINYINT | NO | Exclu (0/1) |
| `in_call` | TINYINT | NO | En appel (0/1) |
| `biometric` | TINYINT | NO | Auth biométrique activée (0/1) |
| `fcm_token` | VARCHAR(255) | NO | Token Firebase Cloud Messaging |
| `device_ID` | VARCHAR(255) | NO | ID appareil (Android/iOS) |
| `created_at` | DATETIME | NO | Date de création |

**Index :**
- PRIMARY KEY (`alnyaID`)
- INDEX sur `alanyaPhone`
- INDEX sur `idPays`

---

## 2. Table : `pays`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `idPays` | SMALLINT | NO | ID pays |
| `libelle` | VARCHAR(100) | NO | Nom du pays |
| `prefix` | VARCHAR(10) | NO | Préfixe téléphonique |
| `timeZone` | VARCHAR(50) | YES | Fuseau horaire |
| `decalageHoraire` | INT | NO | Décalage horaire (heures) |

**Index :** PRIMARY KEY (`idPays`)

---

## 3. Table : `conversation`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `conversID` | BIGINT | NO | ID conversation (auto_increment) |
| `isGroup` | TINYINT | NO | Conversation de groupe (0/1) |
| `groupName` | VARCHAR(255) | YES | Nom du groupe |
| `groupPhoto` | VARCHAR(500) | YES | Photo du groupe |
| `lastMessage` | TEXT | YES | Dernier message |
| `lastMessageAt` | DATETIME | YES | Date du dernier message |
| `isPinned` | TINYINT | NO | Épinglée (0/1) |
| `isArchived` | TINYINT | NO | Archivée (0/1) |
| `unreadCount` | SMALLINT | NO | Nombre de messages non lus |

**Index :**
- PRIMARY KEY (`conversID`)
- INDEX sur `lastMessageAt` (DESC)

---

## 4. Table : `conversation_participants`

> ⚠️ Table ajoutée pour corriger le schéma (conversation = 1 participant max)

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | INT | NO | ID auto_increment |
| `conversation_id` | BIGINT | NO | Référence conversation → FK |
| `participant_id` | INT | NO | Référence utilisateur → FK |
| `unread_count` | SMALLINT | NO | Messages non lus (défaut: 0) |
| `last_read_at` | DATETIME | YES | Dernier message lu |
| `joined_at` | DATETIME | NO | Date de join |

**Index :**
- PRIMARY KEY (`id`)
- UNIQUE KEY (`conversation_id`, `participant_id`)
- INDEX sur `participant_id`

---

## 5. Table : `message`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `msgID` | BIGINT | NO | ID message |
| `senderID` | INT | NO | Expéditeur → FK (users) |
| `conversationID` | BIGINT | NO | Conversation → FK |
| `content` | TEXT | YES | Contenu du message |
| `type` | SMALLINT | YES | Type (0=text, 1=image, 2=video, 3=audio, 4=file, 5=deleted) |
| `status` | TINYINT | NO | Statut (0=sending, 1=sent, 2=delivered, 3=read) |
| `sendAt` | DATETIME | NO | Date d'envoi |
| `readAt` | DATETIME | YES | Date de lecture |
| `mediaUrl` | VARCHAR(500) | YES | URL du média |
| `mediaName` | VARCHAR(255) | YES | Nom du fichier |
| `mediaDuration` | INT | YES | Durée (secondes) |
| `isDeleted` | TINYINT | NO | Supprimé (0/1) |
| `isEdited` | TINYINT | NO | Modifié (0/1) |
| `replyToID` | BIGINT | YES | Référence message répondu |

**Index :**
- PRIMARY KEY (`msgID`)
- INDEX sur `conversationID`
- INDEX sur `senderID`
- INDEX sur `sendAt` (DESC)

---

## 6. Table : `statut` (Statuts/Stories)

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `ID` | INT | NO | ID statut |
| `alnyaID` | INT | NO | Utilisateur → FK |
| `type` | SMALLINT | NO | Type (0=texte, 1=image, 2=video) |
| `text` | TINYTEXT | NO | Texte du statut |
| `mediaUrl` | VARCHAR(500) | YES | URL média |
| `backgroundColor` | VARCHAR(20) | YES | Couleur de fond |
| `createdAt` | DATETIME | NO | Date de création |
| `expiredAt` | DATETIME | NO | Date d'expiration |
| `viewedBy` | INT | NO | Nombre de vues |
| `likedBy` | INT | NO | Nombre de likes |

**Index :**
- PRIMARY KEY (`ID`)
- INDEX sur `alnyaID`
- INDEX sur `expiredAt`

---

## 7. Table : `statut_views`

> ⚠️ Table ajoutée pour corriger statut (un statut peut être vu par plusieurs utilisateurs)

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `statut_id` | INT | NO | Référence statut → FK |
| `viewer_id` | INT | NO | Observateur → FK |
| `viewed_at` | DATETIME | NO | Date de vue |

**Index :**
- PRIMARY KEY (`statut_id`, `viewer_id`)

---

## 8. Table : `blocked`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `idBlock` | INT | NO | ID du blocage |
| `alanyaID` | INT | NO | Bloqueur → FK |
| `idCallerBlock` | INT | NO | Bloqué → FK |
| `dateBlock` | DATETIME | NO | Date du blocage |

**Index :**
- PRIMARY KEY (`idBlock`)
- INDEX sur `alanyaID`

---

## 9. Table : `callHistory`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `IDcall` | BIGINT | NO | ID de l'appel |
| `idCaller` | INT | NO | Appelant → FK |
| `idReceiver` | INT | NO | Recevant → FK |
| `type` | SMALLINT | NO | Type (0=audio, 1=vidéo) |
| `status` | SMALLINT | NO | Statut (0=missed, 1=completed, 2=declined) |
| `created_at` | DATETIME | NO | Date de création |
| `start_time` | DATETIME | NO | Début de l'appel |
| `duree` | INT | NO | Durée (secondes) |

**Index :**
- PRIMARY KEY (`IDcall`)
- INDEX sur `idCaller`
- INDEX sur `idReceiver`

---

## 10. Table : `meeting`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `idMeeting` | INT | NO | ID du meeting |
| `idOrganiser` | INT | NO | Organisateur → FK |
| `start_time` | DATETIME | NO | Début计划 |
| `duree` | INT | NO | Durée (minutes) |
| `objet` | VARCHAR(255) | NO | Objet/Titre du meeting |
| `room` | VARCHAR(100) | NO | Nom de la room |
| `isEnd` | TINYINT | NO | Terminé (0/1) |
| `type_media` | TINYINT | NO | Type (0=audio, 1=vidéo, 2=screen share) |

**Index :**
- PRIMARY KEY (`idMeeting`)
- INDEX sur `idOrganiser`
- INDEX sur `start_time`

---

## 11. Table : `participant` (Participants meeting)

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `ID` | INT | NO | ID participation |
| `idMeeting` | INT | NO | Meeting → FK |
| `IDparticipant` | INT | NO | Participant → FK |
| `status` | TINYINT | NO | Statut (0=pending, 1=accepted, 2=declined) |
| `start_time` | DATETIME | NO | Date de connexion |
| `connecte` | TINYINT | NO | Connecté (0/1) |
| `duree` | INT | NO | Durée de présence |

**Index :**
- PRIMARY KEY (`ID`)
- INDEX sur `idMeeting`
- INDEX sur `IDparticipant`

---

## 12. Table : `preferredContact`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `idPrefContact` | BIGINT | NO | ID |
| `alanyaID` | INT | NO | Utilisateur → FK |
| `idFriend` | INT | NO | Contact préféré → FK |
| `created_at` | DATETIME | NO | Date d'ajout |

**Index :**
- PRIMARY KEY (`idPrefContact`)

---

## 13. Table : `userAccess`

| Champ | Type | Nullable | Description |
|-------|------|----------|-------------|
| `idLogin` | BIGINT | NO | ID connexion |
| `alnyaID` | INT | NO | Utilisateur → FK |
| `device` | VARCHAR(100) | NO | Appareil |
| `dateLogin` | DATETIME | NO | Date de connexion |
| `ipAdress` | VARCHAR(50) | NO | Adresse IP |
| `os_system` | VARCHAR(50) | NO | Système d'exploitation |

**Index :**
- PRIMARY KEY (`idLogin`)
- INDEX sur `alnyaID`

---

## 14. Schéma Visualisé (MySQL)

```
MySQL
│
├── users
│   ├── alanyaID (PK), nom, pseudo, alanyaPhone
│   ├── idPays → pays
│   ├── password, avatar_url, type_compte
│   ├── is_online, last_seen, in_call
│   ├── biometric, fcm_token, device_ID
│   └── created_at
│
├── pays
│   └── idPays (PK), libelle, prefix, timeZone, decalageHoraire
│
├── conversation
│   ├── conversID (PK)
│   ├── isGroup, groupName, groupPhoto
│   ├── lastMessage, lastMessageAt
│   ├── isPinned, isArchived, unreadCount
│   │
│   └── conversation_participants
│       ├── id (PK), conversation_id → conversation
│       ├── participant_id → users
│       ├── unread_count, last_read_at, joined_at
│
├── message
│   ├── msgID (PK), conversationID → conversation
│   ├── senderID → users
│   ├── content, type, status
│   ├── sendAt, readAt
│   ├── mediaUrl, mediaName, mediaDuration
│   ├── isDeleted, isEdited, replyToID
│
├── statut
│   ├── ID (PK), alanyaID → users
│   ├── type, text, mediaUrl, backgroundColor
│   ├── createdAt, expiredAt
│   ├── viewedBy, likedBy
│   │
│   └── statut_views
│       ├── statut_id → statut
│       ├── viewer_id → users
│       └── viewed_at
│
├── blocked
│   ├── idBlock (PK)
│   ├── alanyaID → users (bloqueur)
│   ├── idCallerBlock → users (bloqué)
│   └── dateBlock
│
├── callHistory
│   ├── IDcall (PK)
│   ├── idCaller → users (appelant)
│   ├── idReceiver → users (recevant)
│   ├── type, status
│   ├── created_at, start_time, duree
│
├── meeting
│   ├── idMeeting (PK)
│   ├── idOrganiser → users
│   ├── start_time, duree, objet
│   ├── room, isEnd, type_media
│   │
│   └── participant
│       ├── ID (PK), idMeeting → meeting
│       ├── IDparticipant → users
│       ├── status, start_time, connecte, duree
│
├── preferredContact
│   ├── idPrefContact (PK)
│   ├── alanyaID → users
│   ├── idFriend → users
│   └── created_at
│
└── userAccess
    ├── idLogin (PK)
    ├── alanyaID → users
    ├── device, dateLogin, ipAdress, os_system
```

---

## 15. Index Recommandés

```sql
-- Messages
CREATE INDEX idx_message_conversation ON message(conversationID);
CREATE INDEX idx_message_sender ON message(senderID);
CREATE INDEX idx_message_sentat ON message(sendAt DESC);

-- Conversation participants
CREATE INDEX idx_conv_part_participant ON conversation_participants(participant_id);

-- Call history
CREATE INDEX idx_call_caller ON callHistory(idCaller);
CREATE INDEX idx_call_receiver ON callHistory(idReceiver);

-- Meetings
CREATE INDEX idx_meeting_organiser ON meeting(idOrganiser);
CREATE INDEX idx_meeting_start ON meeting(start_time);

-- Statut (pour expiration automatique)
CREATE INDEX idx_statut_expired ON statut(expiredAt);
```

---

## 16. Notes Techniques

- **Authentification** : Firebase Auth → `alnyaID` correspond au Firebase UID
- **Appels** : WebRTC + Socket.io (signalement) + DataChannel (P2P)
- **Limitations** : 10 participants max par appel de groupe / meeting
- **Waiting room** : Gérée dans la table `participant.status`
- **Chat éphémère** : Pendant appels/meetings (table dédiée à créer si besoin)
- **Partage d'écran** : Type média 2 dans `meeting.type_media`