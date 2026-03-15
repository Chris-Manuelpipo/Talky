# Documentation du Design System Talky

## 1. Palette de Couleurs

### Mode Sombre (Dark Theme)

| Élément | Couleur | Code Hex | Usage |
|---------|---------|---------|-------|
| **Background Principal** | Noir profond | `#0A0A0F` | Fond d'écran principal |
| **Surface** | Gris très foncé | `#12121A` | Cartes, éléments flottants |
| **Surface Variant** | Gris foncé | `#1C1C28` | Éléments secondaires |
| **Surface High** | Gris moyen foncé | `#252535` | Éléments surélevés |
| **Texte Principal** | Blanc bleuté | `#F0EEFF` | Titres, textes importants |
| **Texte Secondaire** | Gris clair | `#9B96B8` | Descriptions, metadata |
| **Texte Hint** | Gris foncé | `#5A5570` | Placeholders, indices |
| **Bulle Envoyée** | Violet Talky | `#7C5CFC` | Messages de l'utilisateur |
| **Bulle Reçue** | Gris foncé | `#1C1C28` | Messages reçus |
| **Bulle Envoyée - Texte** | Blanc | `#FFFFFF` | Texte dans bulle envoyée |
| **Bulle Reçue - Texte** | Blanc bleuté | `#F0EEFF` | Texte dans bulle reçue |
| **Primary** | Violet Talky | `#7C5CFC` | Boutons, icônes principales |
| **Accent** | Bleu ciel | `#4FC3F7` | Éléments d'accent |
| **Success** | Vert | `#4CAF82` | Confirmations, succès |
| **Error** | Rouge | `#FF5C7A` | Erreurs, alertes |
| **Online** | Vert | `#4CAF82` | Statut en ligne |
| **Offline** | Gris foncé | `#5A5570` | Statut hors ligne |
| **Divider** | Gris foncé | `#1C1C28` | Séparateurs |
| **Border** | Gris | `#2A2A3C` | Bordures |

### Mode Clair (Light Theme)

| Élément | Couleur | Code Hex | Usage |
|---------|---------|---------|-------|
| **Background Principal** | Blanc cassé | `#F8F9FC` | Fond d'écran principal |
| **Surface** | Blanc pur | `#FFFFFF` | Cartes, éléments flottants |
| **Surface Variant** | Gris très clair | `#F0F2F5` | Éléments secondaires |
| **Surface High** | Gris clair | `#E8EAED` | Éléments surélevés |
| **Texte Principal** | Noir bleuté | `#1A1A2E` | Titres, textes importants |
| **Texte Secondaire** | Gris foncé | `#5A5A7A` | Descriptions, metadata |
| **Texte Hint** | Gris moyen | `#9E9EA8` | Placeholders, indices |
| **Bulle Envoyée** | Violet Talky | `#7C5CFC` | Messages de l'utilisateur |
| **Bulle Reçue** | Gris très clair | `#F0F2F5` | Messages reçus |
| **Bulle Envoyée - Texte** | Blanc | `#FFFFFF` | Texte dans bulle envoyée |
| **Bulle Reçue - Texte** | Noir bleuté | `#1A1A2E` | Texte dans bulle reçue |
| **Primary** | Violet Talky | `#7C5CFC` | Boutons, icônes principales |
| **Accent** | Bleu ciel | `#4FC3F7` | Éléments d'accent |
| **Success** | Vert foncé | `#2E7D32` | Confirmations, succès |
| **Error** | Rouge foncé | `#D32F2F` | Erreurs, alertes |
| **Online** | Vert foncé | `#2E7D32` | Statut en ligne |
| **Offline** | Gris moyen | `#9E9EA8` | Statut hors ligne |
| **Divider** | Gris clair | `#E0E2E5` | Séparateurs |
| **Border** | Gris | `#D0D2D5` | Bordures |

---

## 2. Système d'Icônes

Le projet utilise le style **Material Icons Outlined** pour maintenir une cohérence visuelle professionnelle.

### Constantes d'Icônes

Toutes les icônes sont définies dans [`lib/core/constants/app_icons.dart`](lib/core/constants/app_icons.dart).

#### Types de Messages
```dart
AppIcons.image      // Photos
AppIcons.video      // Vidéos
AppIcons.audio      // Messages vocaux
AppIcons.file       // Fichiers joints
AppIcons.deleted    // Messages supprimés
```

#### Communication Sociale
```dart
AppIcons.group      // Groupes
AppIcons.person     // Profil personne
AppIcons.waving     // Salutation
AppIcons.contact    // Contacts
AppIcons.chat       // Discussions
AppIcons.groups     // Liste des groupes
```

#### Appels
```dart
AppIcons.call       // Appel audio
AppIcons.videoCall  // Appel vidéo
AppIcons.mic        // Microphone
AppIcons.smartphone // Téléphone
```

#### Sécurité & Paramètres
```dart
AppIcons.lock       // Verrouillage
AppIcons.security   // Sécurité
AppIcons.settings   // Paramètres
AppIcons.privacy    // Confidentialité
AppIcons.notifications // Notifications
```

#### Média & Contenu
```dart
AppIcons.photoLibrary // Galerie
AppIcons.music        // Musique
AppIcons.sound        // Son
AppIcons.vibration    // Vibration
AppIcons.play         // Lecture
AppIcons.pause        // Pause
```

#### Navigation & Actions
```dart
AppIcons.search  // Recherche
AppIcons.edit    // Modifier
AppIcons.delete  // Supprimer
AppIcons.share   // Partager
AppIcons.add     // Ajouter
AppIcons.close   // Fermer
AppIcons.back    // Retour
AppIcons.forward // Suivant
```

#### États & Statut
```dart
AppIcons.online   // En ligne
AppIcons.offline  // Hors ligne
AppIcons.check    // Sélectionné
AppIcons.success  // Succès
AppIcons.error    // Erreur
AppIcons.warning  // Avertissement
AppIcons.info     // Information
```

#### Authentification
```dart
AppIcons.email    // Email
AppIcons.password // Mot de passe
AppIcons.phone    // Téléphone
AppIcons.verify   // Vérification
```

---

## 3. Utilisation des Couleurs Dynamiques

### Via BuildContext

```dart
// Obtenir les couleurs du thème actuel
final colors = context.appThemeColors;

// Accéder aux couleurs
Color bg = colors.background;
Color surface = colors.surface;
Color textPrimary = colors.textPrimary;
Color bubbleSent = colors.bubbleSent;
Color bubbleReceived = colors.bubbleReceived;
Color primary = colors.primary;
```

### Via Provider

```dart
final colors = ref.watch(themeColorsProvider);
```

### Via Extension

```dart
// Couleurs directes via extension
Color bg = context.backgroundColor;
Color surface = context.surfaceColor;
Color bubbleSent = context.bubbleSentColor;
Color primary = context.primaryColor;
```

---

## 4. Recommandations UX

### Lisibilité
- **Mode sombre**: Contraste minimal de 7:1 pour le texte principal
- **Mode clair**: Contraste minimal de 4.5:1 pour le texte principal

### Messages de Chat
- **Bulle envoyée**: Violet (#7C5CFC) avec texte blanc
- **Bulle reçue**: Gris foncé (#1C1C28) / Gris clair (#F0F2F5) avec texte sombre

### Transitions
- Durée recommandée: 300ms
- Utiliser `AnimatedTheme` pour des transitions fluides entre les thèmes

---

## 5. Fichiers Clés

| Fichier | Description |
|---------|-------------|
| `lib/core/constants/app_colors.dart` | Définition des couleurs statiques |
| `lib/core/constants/app_icons.dart` | Définition des icônes |
| `lib/core/theme/app_theme.dart` | Configuration des thèmes |
| `lib/core/theme/app_colors_provider.dart` | Provider pour les couleurs dynamiques |

---

## 6. Émoticônes du Clavier

Le clavier d'émoticônes de l'application ([`chat_screen.dart`](lib/features/chat/presentation/chat_screen.dart)) utilise les émojis Unicode suivants pour l'expression personnelle:

```
😀 😁 😂 🤣 😊 😍 😘 😎 🤩 🥳 😇 🙂 🙃 😉 😌 😜 🤪 😢 😭 😡 😤 😱 🥶 🥵 🤯 😴 🤔 🤫 🤐 😬
👍 👎 👏 🙏 🤝 💪 ✌️ 🤟 🤘 👌
🔥 ✨ 🎉 💯 💥 ⭐ 🌈 ⚡ ☀️ 🌙
❤️ 💔 💙 💚 💛 🧡 💜 🤍 🤎 🖤
🐶 🐱 🐻 🐼 🐨 🐯 🦁 🐸 🐵 🐧
🍕 🍔 🍟 🌭 🥗 🍣 🍩 🍪 🍫 🍰
⚽ 🏀 🏈 🎮 🎧 🎵 🎬 📷 ✈️ 🚗
🏡 🌍 🧠 💡 📌 ✅ ❌ 🔔 📞 🎁
```

*Note: Ces émojis restent pour l'expression personnelle dans les messages.*
