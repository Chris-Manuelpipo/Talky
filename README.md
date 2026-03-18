# Talky - Application de Messagerie et Appels

Talky est une application de messagerie instantanée et d'appels vocaux/vidéo construite avec Flutter et Firebase.

## Fonctionnalités

### Authentification
- Inscription/Login par numéro de téléphone (Firebase Auth)
- Vérification par code OTP

### Messagerie
- Messages texte
- Images et vidéos
- Messages vocaux
- Statut de lecture (send, delivered, read)
- Conversations de groupe
- Partage de contacts

### Appels
- Appels audio (WebRTC)
- Appels vidéo (WebRTC)
- **Appels de groupe** (WebRTC - topologie mesh)
- Notifications d'appels entrants (FCM)
- Gestion du micro, caméra et haut-parleur

### Paramètres
- Profil utilisateur (photo, nom, statut)
- Thème (clair/sombre)
- Langue
- Gestion des notifications

---

## Technologies Utilisées

### Mobile (Frontend)
- **Flutter** 3.x - Framework cross-platform
- **Dart** 3.x - Langage de programmation
- **flutter_webrtc** - Appels audio/vidéo WebRTC
- **socket_io_client** - Communication temps réel
- **Firebase** - Auth, Firestore, Cloud Messaging

### Backend (Serveur)
- **Node.js** - Runtime JavaScript
- **Express.js** - Framework web
- **Socket.IO** - WebSockets pour le signaling WebRTC
- **firebase-admin** - Firebase Admin SDK

### Services Cloud
| Service | Fonction |
|---------|----------|
| Firebase Authentication | Authentification par téléphone |
| Cloud Firestore | Base de données NoSQL |
| Firebase Cloud Messaging | Notifications push |
| Render.com | Hébergement serveur signaling |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TALKY APP                                │
├─────────────────────────────────────────────────────────────────┤
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
└─────────────────────────────────────────────────────────────────┘
```

---

## Structure du Projet

```
lib/
├── core/
│   ├── constants/       # Couleurs, icônes, constantes
│   ├── router/          # Navigation
│   ├── services/        # Services partagés (FCM, contacts, etc.)
│   └── theme/           # Thèmes et couleurs
├── features/
│   ├── auth/           # Authentification
│   ├── calls/          # Appels audio/vidéo/groupes
│   ├── chat/           # Messagerie
│   ├── groups/         # Gestion des groupes
│   ├── home/           # Écran principal
│   ├── onboarding/     # Tutoriel
│   ├── profile/       # Profil utilisateur
│   ├── settings/      # Paramètres
│   └── splash/        # Écran de chargement
└── main.dart

Serveur/
└── server.js          # Serveur de signaling WebRTC
```

---

## Flux d'un Appel

### Appel individuel
1. **Appelant** initie → Socket émet `call_user`
2. **Serveur** reçoit → Notifications push FCM + routing Socket
3. **Appelé** reçoit notification → Écran appel entrant
4. **Appelé** accepte → Socket émet `answer_call`
5. **Échange SDP** via Socket (offer/answer)
6. **Échange ICE** via Socket (candidats)
7. **Connexion P2P** via STUN/TURN
8. **Audio/Vidéo** flows directement entre peers

### Appel de groupe
1. **Créateur** initie → Socket émet `create_group_call`
2. **Serveur** crée la salle et notifie les participants
3. **Participants** reçoivent invitation → `group_call_invite`
4. **Participants** acceptent → Socket émet `join_group_call`
5. **Mesh P2P** : chaque participant connecté à tous les autres
6. **Signaling** via Socket.IO entre tous les participants

---

## Serveurs Requis

| Serveur | URL | Rôle |
|---------|-----|------|
| Signaling | talky-signaling.onrender.com | Routage WebSocket |
| STUN | stun.l.google.com:19302 | NAT traversal |
| TURN | global.relay.metered.ca | Relais média |
| Firebase | firebaseio.com | Auth, DB, Push |

---

## Installation

### Prérequis
- Flutter SDK 3.x
- Node.js 18+
- Compte Firebase

### Configuration

1. **Firebase** :
   - Créer un projet Firebase
   - Activer Authentication (phone)
   - Activer Cloud Firestore
   - Activer Cloud Messaging
   - Télécharger `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)

2. **Serveur de signaling** :
   ```bash
   cd Serveur
   npm install
   # Configurer FIREBASE_SERVICE_ACCOUNT dans les variables d'environnement
   npm start
   ```

3. **Application** :
   ```bash
   flutter pub get
   flutter run
   ```

---

## License

MIT License
