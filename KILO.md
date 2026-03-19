# Cahier des Charges - Talky

## 1. Technologies Utilisées

### A. Mobile (Frontend)

| Technologie | Version | Utilisation |
|-------------|---------|-------------|
| **Flutter** | 3.x | Framework cross-platform |
| **Dart** | 3.x | Langage de programmation |
| **flutter_webrtc** | ^0.11.x | Appels audio/vidéo WebRTC |
| **socket_io_client** | ^2.x | Communication temps réel |
| **firebase_core** | ^3.x | Initialisation Firebase |
| **firebase_auth** | ^5.x | Authentification (phone) |
| **cloud_firestore** | ^5.x | Base de données NoSQL |
| **firebase_messaging** | ^15.x | Notifications push |
| **provider** | ^6.x | Gestion d'état |
| **image_picker** | ^1.x | Sélection médias |
| **permission_handler** | ^11.x | Gestion permissions |
| **shared_preferences** | ^2.x | Stockage local |
| **uuid** | ^4.x | Génération ID uniques |
| **path_provider** | ^2.x | Accès fichiers |

### B. Backend (Serveur)

| Technologie | Version | Utilisation |
|------------|---------|-------------|
| **Node.js** | 18+ | Runtime JavaScript |
| **Express.js** | ^4.x | Framework web |
| **Socket.IO** | ^4.x | WebSockets signaling |
| **firebase-admin** | ^12.x | Firebase Admin SDK |
| **dotenv** | ^16.x | Variables d'environnement |

### C. Services Cloud

| Service | Fonction |
|---------|----------|
| **Firebase Authentication** | Authentification par téléphone |
| **Cloud Firestore** | Base de données (messages, utilisateurs, conversations) |
| **Firebase Cloud Messaging** | Notifications push (appels entrants, messages) |
| **Render.com** | Hébergement serveur signaling |

### D. Protocoles WebRTC

| Protocol | Rôle |
|----------|------|
| **STUN** (stun.l.google.com:19302) | Découverte IP publique (NAT) |
| **TURN** (global.relay.metered.ca) | Relais média quand NAT symétrique |
| **ICE** | Protocole de sélection des candidats |
| **SDP** | Échange描述 de session |

---

## 2. Architecture de l'Application

```
┌─────────────────────────────────────────────────────────────────┐
│                        TALKY APP                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Flutter    │    │  Firebase    │    │   Socket.IO  │      │
│  │   (App UI)   │◄──►│  (Auth/DB)   │    │  (Signaling) │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  WebRTC      │    │  FCM         │    │  WebRTC      │      │
│  │  (Media)     │    │  (Push)      │    │  (Peer)      │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Fonctionnalités

### 3.1 Authentification
- Inscription/Login par numéro de téléphone (Firebase Auth)
- Code OTP vérifié

### 3.2 Gestion des Contacts
- Synchronisation des contacts téléphoniques
- Recherche d'utilisateurs Talky

### 3.3 Messagerie
- Messages texte
- Images
- Vidéos
- Messages vocaux
- Statut de lecture (send, delivered, read)
- Conversations de groupe

### 3.4 Appels
- Appels audio (WebRTC)
- Appels vidéo (WebRTC)
- Notifications d'appels entrants (FCM)
- Gestion du speaker/micro

### 3.5 Paramètres
- Profil utilisateur
- Thème (clair/sombre)
- Langue
- Notifications

---

## 4. Structure des Données (Firestore)

### Collections :
- `users/` - Profil utilisateurs
- `conversations/` - Conversations
- `messages/` - Messages
- `groups/` - Groupes
- `settings/` - Paramètres utilisateur

---

## 5. Flux d'un Appel

1. **Appelant** initie → Socket émet `call_user`
2. **Serveur** reçoit → Notifications push FCM + routing Socket
3. **Appelé** reçoit notification → Écran appel entrant
4. **Appelé** accepte → Socket émet `answer_call`
5. **Échange SDP** via Socket (offer/answer)
6. **Échange ICE** via Socket (candidats)
7. **Connexion P2P** via STUN/TURN
8. **Audio/Vidéo** flows directement entre peers

---

## 6. Serveurs Requis

| Serveur | URL | Rôle |
|---------|-----|------|
| Signaling | talky-signaling.onrender.com | Routage WebSocket |
| STUN | stun.l.google.com:19302 | NAT traversal |
| TURN | global.relay.metered.ca | Relais média |
| Firebase | firebaseio.com | Auth, DB, Push |