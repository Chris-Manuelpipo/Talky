# Structure de la Base de Données - Talky

## Base de données : Firebase Firestore (NoSQL)

---

## 1. Collection : `users`

| Champ | Type | Description |
|-------|------|-------------|
| `uid` | string | ID unique Firebase Auth |
| `name` | string | Nom de l'utilisateur |
| `phone` | string | Numéro de téléphone |
| `email` | string? | Email (optionnel) |
| `photoUrl` | string? | URL photo de profil |
| `status` | string | Statut personnalisé (ex: "Disponible sur Talky") |
| `preferredLanguage` | string | Langue préférée (défaut: "fr") |
| `isOnline` | boolean | En ligne ou non |
| `lastSeen` | timestamp | Dernière connexion |
| `fcmToken` | string | Token Firebase Cloud Messaging |
| `ghostMode` | boolean | Mode fantôme (invisible) |

**Sous-collection :** `users/{uid}/contacts/`

| Champ | Type | Description |
|-------|------|-------------|
| `userId` | string | ID du contact |
| `name` | string | Nom du contact |
| `phone` | string | Numéro |
| `photoUrl` | string? | Photo |
| `addedAt` | timestamp | Date d'ajout |

---

## 2. Collection : `conversations`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | ID conversation (UUID) |
| `participantIds` | array | Liste des IDs participants |
| `participantNames` | map | {uid: name} |
| `participantPhotos` | map | {uid: photoUrl} |
| `lastMessage` | string? | Dernier message |
| `lastMessageSenderId` | string | ID de l'expéditeur |
| `lastMessageType` | enum | text, image, video, audio, file, deleted |
| `lastMessageStatus` | enum | sending, sent, delivered, read |
| `lastMessageAt` | timestamp | Date du dernier message |
| `unreadCount` | map | {uid: nombre} |
| `isGroup` | boolean | Conversation de groupe ? |
| `groupName` | string? | Nom du groupe |
| `groupPhoto` | string? | Photo du groupe |

**Sous-collection :** `conversations/{convId}/messages/`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | ID message (UUID) |
| `conversationId` | string | ID conversation |
| `senderId` | string | ID expéditeur |
| `senderName` | string | Nom expéditeur |
| `content` | string? | Texte du message |
| `type` | enum | text, image, video, audio, file, deleted |
| `status` | enum | sending, sent, delivered, read |
| `sentAt` | timestamp | Date d'envoi |
| `readAt` | timestamp? | Date de lecture |
| `mediaUrl` | string? | URL média (Firebase Storage) |
| `mediaName` | string? | Nom du fichier |
| `mediaDuration` | int? | Durée en secondes (audio/video) |
| `replyToId` | string? | ID message répondu |
| `replyToContent` | string? | Contenu cité |
| `isDeleted` | boolean | Message supprimé ? |

---

## 3. Collection : `statuses` (Statuts)

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | ID statut |
| `userId` | string | ID utilisateur |
| `mediaUrl` | string | URL image/vidéo |
| `mediaType` | enum | image, video |
| `createdAt` | timestamp | Date de création |
| `expiresAt` | timestamp | Date d'expiration (24h) |

---

## 4. Schéma Visualisé

```
Firestore
│
├── users (collection)
│   │
│   ├── {uid} (document)
│   │   ├── uid, name, phone, email, photoUrl
│   │   ├── status, preferredLanguage
│   │   ├── isOnline, lastSeen, fcmToken, ghostMode
│   │   │
│   │   └── contacts (subcollection)
│   │       └── {contactUid}
│   │           ├── userId, name, phone, photoUrl, addedAt
│   │
│   └── ...
│
├── conversations (collection)
│   │
│   └── {convId} (document)
│       ├── id, participantIds[], participantNames{}
│       ├── participantPhotos{}, lastMessage
│       ├── lastMessageSenderId, lastMessageType
│       ├── lastMessageStatus, lastMessageAt
│       ├── unreadCount{}, isGroup
│       ├── groupName, groupPhoto
│       │
│       └── messages (subcollection)
│           └── {messageId}
│               ├── id, conversationId, senderId, senderName
│               ├── content, type, status
│               ├── sentAt, readAt
│               ├── mediaUrl, mediaName, mediaDuration
│               ├── replyToId, replyToContent, isDeleted
│
└── statuses (collection)
    │
    └── {statusId}
        ├── id, userId, mediaUrl, mediaType
        ├── createdAt, expiresAt
```

---

## 5. Index Utilisés

- `conversations` : index sur `participantIds` (array-contains)
- `conversations` : index sur `lastMessageAt` (desc)
- `messages` : index sur `sentAt` (desc)
- `users` : index sur `phone`
- `users` : index sur `name`