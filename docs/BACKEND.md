# Backend Talky - Spécification Technique

## Stack Technique

| Couche | Technologie |
|--------|-------------|
| Serveur | Node.js + Express |
| Base de données | MySQL |
| Temps réel | Socket.io + WebRTC DataChannel |
| Authentification | Firebase Token (validé côté backend) |

---

## Structure du Projet

```
server/
├── src/
│   ├── index.js                 # Point d'entrée
│   ├── config/
│   │   ├── db.js                # Configuration MySQL
│   │   └── env.js               # Variables d'environnement
│   ├── middleware/
│   │   ├── auth.js              # Validation Firebase Token
│   │   ├── errorHandler.js      # Gestion erreurs centralisée
│   │   └── rateLimiter.js       # Protection API
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── userController.js
│   │   ├── conversationController.js
│   │   ├── messageController.js
│   │   ├── statutController.js
│   │   ├── callController.js
│   │   └── meetingController.js
│   ├── routes/
│   │   ├── auth.js
│   │   ├── users.js
│   │   ├── conversations.js
│   │   ├── messages.js
│   │   ├── status.js
│   │   ├── calls.js
│   │   └── meetings.js
│   ├── services/
│   │   ├── userService.js
│   │   ├── conversationService.js
│   │   ├── messageService.js
│   │   ├── notificationService.js  # FCM
│   │   └── webrtcService.js
│   └── socket/
│       ├── index.js             # Socket.io setup
│       ├── handlers/
│       │   ├── auth.js           # Auth socket
│       │   ├── signaling.js      # WebRTC signaling
│       │   ├── chat.js           # Messages temps réel
│       │   ├── presence.js       # Online/Offline
│       │   ├── calls.js          # Gestion appels
│       │   └── meetings.js      # Gestion meetings
├── package.json
└── .env
```

---

## Base de Données

Schéma disponible dans : `docs/talky_schema.sql`

---

## API REST Endpoints

### Base URL : `/api/v1`

#### Headers requis
```
Authorization: Bearer <firebase_id_token>
Content-Type: application/json
```

---

### 1. Authentification

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/auth/verify` | Vérifier token Firebase, retourner user |
| GET | `/auth/me` | Profil utilisateur courant |
| PUT | `/auth/me` | Mise à jour profil |
| POST | `/auth/logout` | Déconnexion (invalidate token) |

**Request Body (PUT /auth/me) :**
```json
{
  "nom": "John Doe",
  "pseudo": "John",
  "avatar_url": "https://...",
  "biometric": true,
  "fcm_token": "firebase_token"
}
```

---

### 2. Utilisateurs

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/users/:id` | Récupérer un utilisateur |
| GET | `/users/phone/:phone` | Recherche par téléphone |
| GET | `/users/search?q=` | Recherche par nom/pseudo |
| GET | `/users/:id/contacts` | Liste contacts |
| POST | `/users/:id/block` | Bloquer utilisateur |
| DELETE | `/users/:id/block` | Débloquer utilisateur |
| GET | `/users/blocked` | Liste utilisateurs bloqués |

---

### 3. Conversations

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/conversations` | Liste conversations utilisateur |
| POST | `/conversations` | Créer conversation 1-to-1 |
| POST | `/conversations/group` | Créer groupe |
| GET | `/conversations/:id` | Détails conversation |
| PUT | `/conversations/:id` | Mettre à jour (nom, photo) |
| DELETE | `/conversations/:id` | Supprimer conversation |
| POST | `/conversations/:id/read` | Marquer comme lu |
| POST | `/conversations/:id/leave` | Quitter groupe |

**Request Body (POST /conversations) :**
```json
{
  "participantId": 123
}
```

**Request Body (POST /conversations/group) :**
```json
{
  "groupName": "Mon Groupe",
  "participants": [123, 456, 789]
}
```

---

### 4. Messages

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/conversations/:id/messages?limit=50&before=msgID` | Liste messages (pagination) |
| POST | `/conversations/:id/messages` | Envoyer message |
| PUT | `/messages/:id` | Modifier message |
| DELETE | `/messages/:id` | Supprimer message (soft delete) |
| POST | `/messages/:id/reactions` | Ajouter réaction |

**Request Body (POST message) :**
```json
{
  "content": "Hello!",
  "type": 0,
  "replyToID": 456
}
```

**Request Body (message média) :**
```json
{
  "type": 1,
  "mediaUrl": "https://...",
  "mediaName": "photo.jpg",
  "mediaDuration": null
}
```

---

### 5. Statuts (Stories)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/status` | Statuts actifs de mes contacts |
| POST | `/status` | Publier statut |
| DELETE | `/status/:id` | Supprimer statut |
| POST | `/status/:id/view` | Marquer comme vu |
| POST | `/status/:id/like` | Likestatut |

**Request Body (POST /status) :**
```json
{
  "type": 1,
  "text": "Mon statut",
  "mediaUrl": "https://...",
  "backgroundColor": "#7C5CFC"
}
```

---

### 6. Appels (Call History)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/calls` | Historique appels |
| GET | `/calls/:id` | Détails appel |
| POST | `/calls/initiate` | Initier appel (crée entrée callHistory) |
| PUT | `/calls/:id/end` | Terminer appel |
| POST | `/calls/:id/start` | Démarrer appel |

---

### 7. Meetings

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/meetings` | Liste meetings (à venir + passés) |
| POST | `/meetings` | Créer meeting |
| GET | `/meetings/:id` | Détails meeting |
| PUT | `/meetings/:id` | Modifier meeting |
| DELETE | `/meetings/:id` | Annuler meeting |
| POST | `/meetings/:id/join` | Rejoindre meeting (demande) |
| POST | `/meetings/:id/accept/:participantId` | Accepter participant (waiting room) |
| POST | `/meetings/:id/decline/:participantId` | Refuser participant |
| GET | `/meetings/:id/participants` | Liste participants |
| POST | `/meetings/:id/leave` | Quitter meeting |

**Request Body (POST /meetings) :**
```json
{
  "objet": "Réunion équipe",
  "start_time": "2024-06-15T14:00:00Z",
  "duree": 60,
  "type_media": 1,
  "participants": [123, 456, 789],
  "room": "salle-reunion-001"
}
```

---

## Socket.io Events

### Connection
```javascript
// Client connecte avec token Firebase
socket = io.connect('https://api.talky.com', {
  auth: { token: firebase_id_token }
});
```

### Rooms
- `user:{userId}` — Salle privée pour un utilisateur
- `conversation:{convId}` — Salle conversation
- `call:{callId}` — Salle d'appel
- `meeting:{meetingId}` — Salle de meeting

---

### Events : Chat & Messages

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `join_conversation` | C→S | `{conversationId}` | Rejoindre une conversation |
| `leave_conversation` | C→S | `{conversationId}` | Quitter une conversation |
| `message:send` | C→S | `{conversationId, content, type, ...}` | Envoyer message |
| `message:new` | S→C | `{message}` | Nouveau message reçu |
| `message:status` | C→S | `{messageId, status}` | Mise à jour statut |
| `message:status_update` | S→C | `{messageId, status}` | Diffusion statut |
| `typing:start` | C→S | `{conversationId}` | Début frappe |
| `typing:stop` | C→S | `{conversationId}` | Fin frappe |
| `typing` | S→C | `{conversationId, userId, isTyping}` | Notification frappe |

---

### Events : Présence

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `presence:online` | C→S | `{}` | Je suis en ligne |
| `presence:offline` | C→S | `{}` | Je suis hors ligne |
| `presence_update` | S→C | `{userId, isOnline, lastSeen}` | Changement présence |

---

### Events : Appels

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `call:initiate` | C→S | `{calleeId, type, isGroup}` | Initier appel |
| `call:incoming` | S→C | `{callId, callerId, type, isGroup}` | Appel entrant |
| `call:accept` | C→S | `{callId}` | Accepter appel |
| `call:decline` | C→S | `{callId}` | Refuser appel |
| `call:end` | C→S | `{callId}` | Terminer appel |
| `call:connected` | S→C | `{callId, participants}` | Appel connecté |
| `call:failed` | S→C | `{callId, reason}` | Échec appel |
| `call:participants` | S→C | `{callId, participants}` | Mise à jour participants |

---

### Events : WebRTC Signaling

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `webrtc:offer` | C→S | `{targetId, offer}` | Envoi offer SDP |
| `webrtc:answer` | C→S | `{targetId, answer}` | Envoi answer SDP |
| `webrtc:ice` | C→S | `{targetId, candidate}` | Envoi ICE candidate |
| `webrtc:signal` | S→C | `{fromId, type, data}` | Relai signal |

---

### Events : Meetings

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `meeting:create` | C→S | `{meetingData}` | Créer meeting |
| `meeting:join_request` | S→C | `{meetingId, participantId}` | Demande join |
| `meeting:join_accept` | C→S | `{meetingId, participantId}` | Accepter join |
| `meeting:join_decline` | C→S | `{meetingId, participantId}` | Refuser join |
| `meeting:joined` | S→C | `{meetingId, participants}` | Participant a join |
| `meeting:left` | S→C | `{meetingId, participantId}` | Participant quit |
| `meeting:start` | C→S | `{meetingId}` | Démarrer meeting |
| `meeting:end` | C→S | `{meetingId}` | Terminer meeting |
| `meeting:ended` | S→C | `{meetingId, recordingUrl}` | Meeting terminé |
| `meeting:chat` | C↔S | `{meetingId, message}` | Chat éphémère meeting |

---

## WebRTC - Architecture

### Signalement (via Socket.io)
```
[A]                    [Server]                    [B]
  |--- offer SDP ----->|                           |
  |                    |--- offer SDP ---------->|
  |                    |                           |
  |<-- answer SDP -----|<--- answer SDP ---------|
  |                    |                           |
  |--- ICE candidates->|                           |
  |                    |--- ICE candidates------>|
```

### DataChannel (P2P, après connexion)
```
[A] ◄─────────────────────► [B]
  │    Messages directs     │
  │    (pas de serveur)      │
```

### Topologie appels de groupe (Mesh)
Pour 10 participants max, connections mesh directes:
```
    [A]
   / | \
  B  C  D
 /|\
E F ...
```

Pour plus de participants, utiliser SFU (Selective Forwarding Unit).

---

## Notifications Push (FCM)

### Triggers

| Événement | Notification |
|-----------|--------------|
| Nouveau message | "Nouveau message de {sender}" |
| Appel entrant | "Appel entrant de {caller}" |
| Meeting invité | "Vous êtes invité à {meeting}" |
| Statut nouveau | "{user} a publié un statut" |

### Format payload FCM
```json
{
  "notification": {
    "title": "Talky",
    "body": "Nouveau message de Jean"
  },
  "data": {
    "type": "message",
    "conversationId": "123",
    "senderId": "456"
  }
}
```

---

## Authentification Firebase (Backend)

### Middleware auth.js
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

async function verifyFirebaseToken(req, res, next) {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({error: 'No token'});
  
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = {
      alanyaID: decoded.uid,  // ou decoded.user_id
      email: decoded.email
    };
    next();
  } catch (error) {
    return res.status(401).json({error: 'Invalid token'});
  }
}
```

---

## Sécurité

### Rate Limiting
- API REST: 100 req/min par IP
- Socket.io: 50 messages/sec par connexion

### Validation
- Toutes les entrées validées avec `joi` ou `zod`
- SQL injecté via parameterized queries (pas de string concatenation)

### CORS
```javascript
const corsOptions = {
  origin: ['https://talky.app', 'https://admin.talky.app'],
  credentials: true
};
```

---

## Variables d'environnement (.env)

```env
# Serveur
PORT=3000
NODE_ENV=development

# Base de données
DB_HOST=localhost
DB_PORT=3306
DB_NAME=talky
DB_USER=root
DB_PASSWORD=password

# Firebase
FIREBASE_PROJECT_ID=your-project
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...

# JWT (pour Socket.io)
JWT_SECRET=your-jwt-secret

# FCM
FCM_SERVER_KEY=...

# Socket.io
SOCKET_PORT=3001
```

---

## Déploiement

### Production (PM2 + Nginx)

```bash
# Installation
npm install -g pm2
pm2 start src/index.js --name talky-api

# Nginx config
upstream talky_api {
    server 127.0.0.1:3000;
}
```

### Monitoring
- PM2 dashboard: `pm2 monit`
- Logs: `pm2 logs talky-api`

---

## Notes

- **Timeout appel** : 60 secondes avant automatique decline
- **Expiration statut** : 24 heures (suppression automatique via cron)
- **Participants max** : 10 (appels + meetings)
- **Chat éphémère meeting** : Pas de persistence BDD, uniquement Socket.io