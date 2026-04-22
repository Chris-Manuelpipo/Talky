# 📱 Talky — Documentation Projet
> Fichier de référence du projet — mis à jour au fur et à mesure de l'avancement.

---

## 📌 Informations Générales

| Champ | Détail |
|---|---|
| **Nom du projet** | Talky |
| **Type** | Application mobile de messagerie d'entreprise |
| **Plateformes cibles** | iOS + Android |
| **Framework** | Flutter (Dart) |
| **IDE** | VS Code |
| **Niveau développeur** | Intermédiaire |
| **Objectif** | Usage interne / entreprise |
| **Thème visuel** | 🌑 Dark moderne — Noir & Violet/Bleu |
| **Statut** | 🟢 Phase 1 complétée — En attente Phase 2 |

---

## ✨ Fonctionnalités

### Core (base WhatsApp)
- [ ] Authentification (email)
- [ ] Profils utilisateurs
- [ ] Messagerie 1-to-1
- [ ] Groupes de discussion
- [ ] Statuts de message (envoyé ✓, reçu ✓✓, lu 🔵)
- [ ] Médias (photos, vidéos, documents, vocaux)
- [ ] Appels audio/vidéo (WebRTC)
- [ ] Statuts / Stories

### 🌍 Fonctionnalité Phare 1 — Traduction Instantanée
- [ ] Chaque message affiché dans la langue du destinataire
- [ ] Toggle "Voir l'original / Traduction"
- [ ] Détection automatique de la langue
- [ ] Indicateur de langue sur chaque message

### 🔒 Fonctionnalité Phare 2 — Mode Confidentiel
- [ ] Messages à durée de vie (5s, 10s, 1min, personnalisé)
- [ ] Blocage des captures d'écran
- [ ] Mode fantôme (pas de "vu", pas de statut en ligne)
- [ ] Conversations verrouillées par biométrie
- [ ] Suppression automatique côté serveur

---

## 🏗️ Stack Technique

| Couche | Technologie | Rôle |
|---|---|---|
| **Framework** | Flutter (Dart) | UI cross-platform |
| **État global** | Riverpod 2.0 | Gestion d'état moderne |
| **Navigation** | GoRouter | Routing déclaratif |
| **Backend API** | Node.js + Express | API REST |
| **Base de données** | MySQL | BDD relationnelle |
| **Temps réel** | Socket.io + WebRTC DataChannel | Messages, présence |
| **WebRTC** | flutter_webrtc | Appels audio/vidéo |
| **Signaling** | Socket.io (serveur Node.js) | Coordination WebRTC |
| **Auth** | Firebase Auth (Flutter) | Authentification |
| **Traduction** | Google Cloud Translation API | Traduction instantanée |
| **Stockage** | Firebase Storage | Médias |
| **Notifications** | Firebase Cloud Messaging | Push notifs |
| **Biométrie** | local_auth | Mode confidentiel |
| **Chiffrement** | encrypt (AES) | Sécurité messages |

---

## 🗂️ Navigation — Onglets de l'app

| # | Onglet | Icône | Phase |
|---|---|---|---|
| 1 | **Discussions** | chat_bubble | Phase 3 |
| 2 | **Groupes** | groups | Phase 3 |
| 3 | **Statuts** | history | Phase 3 |
| 4 | **Appels** | call | Phase 6 |
| 5 | **Paramètres** | settings | Phase 2 |

> ⚠️ Modification utilisateur (Session 4) : remplacement de "Contacts" par "Groupes" et ajout de l'onglet "Appels".

---

## 📁 Structure du Projet

```
talky/
├── lib/
│   ├── main.dart                          ✅ Créé
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart            ✅ Créé
│   │   │   └── app_constants.dart         ✅ Créé
│   │   ├── theme/
│   │   │   └── app_theme.dart             ✅ Créé
│   │   └── router/
│   │       └── app_router.dart            ✅ Créé
│   ├── features/
│   │   ├── splash/
│   │   │   └── presentation/
│   │   │       └── splash_screen.dart     ✅ Créé
│   │   ├── onboarding/
│   │   │   └── presentation/
│   │   │       └── onboarding_screen.dart ✅ Créé
│   │   ├── auth/
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart      ✅ Créé
│   │   │       └── register_screen.dart   ✅ Créé
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       └── home_screen.dart       ✅ Modifié par utilisateur
│   │   ├── chat/                          🔲 Phase 3
│   │   ├── groups/                        🔲 Phase 3
│   │   ├── status/                        🔲 Phase 3
│   │   ├── calls/                         🔲 Phase 6
│   │   ├── settings/                      🔲 Phase 2
│   │   ├── translation/                   🔲 Phase 4
│   │   ├── confidential/                  🔲 Phase 5
│   │   └── profile/                       🔲 Phase 2
│   └── shared/
│       └── widgets/
│           ├── talky_text_field.dart      ✅ Créé
│           └── talky_button.dart          ✅ Créé
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── pubspec.yaml                           ✅ Créé
└── firebase_options.dart                  🔲 À générer (flutterfire configure)
```

---

## 🎨 Design System Talky

| Token | Valeur |
|---|---|
| **Style** | Dark moderne — Noir & Violet/Bleu |
| **Couleur primaire** | `#7C5CFC` — Violet signature |
| **Couleur accent** | `#4FC3F7` — Cyan électrique |
| **Fond** | `#0A0A0F` — Noir profond |
| **Surface** | `#12121A` — Surface sombre |
| **Texte primaire** | `#F0EEFF` — Blanc cassé violet |
| **Texte secondaire** | `#9B96B8` — Gris violet |
| **Typographie** | Sora (Google Fonts) |
| **Border radius** | 16px (standard), 8px (small), 24px (large) |

---

## 🗺️ Plan de Développement Détaillé

### 🔧 PHASE 1 — Setup & Fondations ✅ COMPLÉTÉE

- [x] Structure de dossiers Feature-First
- [x] GoRouter + Riverpod configurés
- [x] Design System (couleurs, thème, typographie)
- [x] Splash Screen animé
- [x] Onboarding 3 slides
- [x] Login Screen + Register Screen (UI)
- [x] Home Screen avec 5 onglets (modifié par utilisateur)
- [x] Widgets partagés (TalkyTextField, TalkyButton)
- [x] pubspec.yaml complet
- [ ] `flutter pub get` sans erreur
- [ ] App qui tourne sur émulateur

---

### 🔐 PHASE 2 — Authentification & Profils
**Statut :** 🟡 En cours | **Dépend de :** Firebase + Backend Node.js

#### Étape 2.1 — Firebase Auth (Flutter)
- [ ] Créer projet Firebase + `flutterfire configure`
- [ ] Connecter LoginScreen à Firebase Auth
- [ ] Connecter RegisterScreen à Firebase Auth
- [ ] Gestion des erreurs (email invalide, mauvais mdp, etc.)
- [ ] Redirection automatique si déjà connecté (auth state listener)

#### Étape 2.2 — Backend Node.js (API + MySQL)
- [ ] Setup serveur Node.js + Express
- [ ] Connexion MySQL
- [ ] Endpoint `/auth/verify` (valide token Firebase, retourne user)
- [ ] Endpoint `/users/:id` et `/users/me`

#### Étape 2.3 — Gestion des sessions
- [ ] Persistance de session avec StreamProvider Riverpod
- [ ] Déconnexion depuis les paramètres
- [ ] Provider global `authStateProvider`

#### Étape 2.4 — Profil utilisateur
- [ ] Écran création de profil post-inscription (photo, nom, statut, langue)
- [ ] Upload photo vers Firebase Storage
- [ ] Sauvegarde dans MySQL via API REST
- [ ] Écran consultation/modification du profil

#### Étape 2.5 — Écran Paramètres
- [ ] Affichage du profil connecté
- [ ] Bouton déconnexion
- [ ] Toggle langue préférée (pour la traduction)
- [ ] Toggle thème dark/light

✅ **Validation Phase 2 :** Inscription → profil → connexion → déconnexion fonctionnels avec backend MySQL.

---

### 💬 PHASE 3 — Messagerie Core
**Statut :** 🔲 À faire | **Durée :** 3 à 4 semaines

#### Étape 3.1 — Backend MySQL + API REST
- [ ] Serveur Node.js + Express + MySQL
- [ ] Modèles API (conversation, message, participant)
- [ ] Authentification Firebase token côté backend

#### Étape 3.2 — Socket.io temps réel
- [ ] Connection Socket.io avec token Firebase
- [ ] Events temps réel (message:new, typing, presence)

#### Étape 3.3 — Liste des discussions
- [ ] Écran Discussions avec conversations en temps réel
- [ ] Badge non-lu, aperçu du dernier message, tri par date

#### Étape 3.4 — Écran de chat 1-to-1
- [ ] Bulles de messages (envoyé/reçu)
- [ ] Statuts ✓ ✓✓ 🔵
- [ ] Scroll automatique

#### Étape 3.5 — Groupes
- [ ] Création groupe (nom, photo, membres)
- [ ] Messagerie de groupe en temps réel
- [ ] Ajout/suppression de membres

#### Étape 3.6 — Médias
- [ ] Images, vidéos, fichiers, messages vocaux
- [ ] Upload vers Firebase Storage

#### Étape 3.7 — Notifications Push (FCM)
- [ ] Notification à la réception d'un message
- [ ] Navigation au tap de notification

✅ **Validation Phase 3 :** Chat complet avec médias et notifications.

---

### 🌍 PHASE 4 — Traduction Instantanée
**Statut :** 🔲 À faire | **Durée :** 1 à 2 semaines

- [ ] Google Cloud Translation API
- [ ] Détection automatique de la langue
- [ ] Traduction + stockage Firestore
- [ ] Toggle original/traduit dans l'UI
- [ ] Paramètre on/off dans profil

✅ **Validation Phase 4 :** Message en anglais affiché en français automatiquement.

---

### 🔒 PHASE 5 — Mode Confidentiel
**Statut :** 🔲 À faire | **Durée :** 2 semaines

- [ ] Messages éphémères avec timer visuel
- [ ] Blocage screenshots (Android + iOS)
- [ ] Mode fantôme (statut en ligne masqué)
- [ ] Verrouillage biométrique (app + conversation)
- [ ] Chiffrement AES des messages

✅ **Validation Phase 5 :** Mode confidentiel complet sur les deux plateformes.

---

### 📞 PHASE 6 — Appels Audio & Vidéo (WebRTC) + Meetings
**Statut :** 🔲 À faire | **Durée :** 3 à 4 semaines

#### Appels
- [ ] Serveur Node.js + Socket.io (signaling WebRTC)
- [ ] WebRTC DataChannel (messages P2P sans passer par serveur)
- [ ] Appels audio 1-to-1
- [ ] Appels vidéo 1-to-1
- [ ] Appels de groupe (jusqu'à 10 participants, topologie mesh)
- [ ] Notifications d'appel entrant (au-dessus du lock screen)
- [ ] Chat éphémère pendant appel (pas de persistence)

#### Meetings
- [ ] Création meeting (planifié avec date/heure)
- [ ] Waiting room (validation organisateur)
- [ ] Participants obligatoires/optionnels
- [ ] Visioconférence (vidéo + audio)
- [ ] Partage d'écran
- [ ] Chat éphémère pendant meeting
- [ ] Enregistrement vidéo
- [ ] Limite 10 participants

✅ **Validation Phase 6 :** Appel audio/vidéo + meeting fonctionnel.

---

### 🎨 PHASE 7 — Polish, Tests & Déploiement
**Statut :** 🔲 À faire | **Durée :** 2 semaines

- [ ] Animations & transitions, retour haptique, shimmer
- [ ] Performance (lazy loading, cache images)
- [ ] Tests unitaires et d'intégration
- [ ] Build Android (APK + AAB signé)
- [ ] Build iOS + TestFlight
- [ ] Distribution Firebase App Distribution

✅ **Validation Phase 7 :** Talky installé sur appareils Android et iOS réels.

---

## 📊 Avancement Global

| Phase | Description | Statut |
|---|---|---|
| Phase 1 | Setup & Fondations | ✅ Complétée |
| Phase 2 | Authentification & Profils | 🟡 En cours |
| Phase 3 | Messagerie Core (MySQL + Socket.io) | 🔲 À faire |
| Phase 4 | 🌍 Traduction Instantanée | 🔲 À faire |
| Phase 5 | 🔒 Mode Confidentiel | 🔲 À faire |
| Phase 6 | 📞 Appels + 📅 Meetings (WebRTC) | 🔲 À faire |
| Phase 7 | 🎨 Polish, Tests & Déploiement | 🔲 À faire |

**Progression globale : 1 / 7 phases complétées**

---

## 🚀 Commandes Utiles

```bash
flutter run                          # Lancer en développement
flutter devices                      # Lister les appareils
flutter pub get                      # Installer les dépendances
flutter analyze                      # Analyser le code
flutter test                         # Lancer les tests
flutter build apk --release          # Build Android
flutter build appbundle --release    # Build Android (AAB)
flutter build ios --release          # Build iOS
flutterfire configure                # Connecter Firebase
```

---

## 📝 Journal de Bord

### Session 1 — Initialisation
- ✅ Définition du projet, framework Flutter, fonctionnalités phares

### Session 2 — Planification
- ✅ Nom : Talky | Objectif : usage entreprise | Plan 7 phases

### Session 3 — Phase 1 : Code généré
- ✅ Thème Dark Moderne (Violet/Bleu)
- ✅ 13 fichiers générés : design system, navigation, écrans, widgets

### Session 4 — Modifications utilisateur sur home_screen.dart
- ✅ Onglet "Contacts" → remplacé par **"Groupes"**
- ✅ Onglet **"Appels"** ajouté (5 onglets au total)
- ⏳ **Prochaine étape :** Phase 2 — Firebase Auth + Profils

---

## 🔗 Ressources Utiles

- [Flutter Documentation](https://docs.flutter.dev)
- [Firebase pour Flutter](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
- [flutter_webrtc](https://pub.dev/packages/flutter_webrtc)
- [Riverpod](https://riverpod.dev)
- [GoRouter](https://pub.dev/packages/go_router)
- [Google Cloud Translation API](https://cloud.google.com/translate/docs)
- [Firebase App Distribution](https://firebase.google.com/docs/app-distribution)
- [Console Firebase](https://console.firebase.google.com)

---

*Dernière mise à jour : Session 4 — Modifications home_screen + passage en Phase 2*