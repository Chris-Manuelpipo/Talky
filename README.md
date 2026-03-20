# 📱 Talky — Professional Messaging Application

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-blue?style=flat-square&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Firebase-Firestore-orange?style=flat-square&logo=firebase" alt="Firebase">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

---

## 📌 Project Overview

**Talky** is a full-featured enterprise messaging application built with Flutter, similar to WhatsApp. It provides real-time messaging, voice/video calls, status updates, and group chat functionality with a modern dark-themed UI.

### Key Capabilities

| Feature | Description |
|---------|-------------|
| 🔐 **Authentication** | Phone number OTP verification via Firebase Auth |
| 💬 **Messaging** | Text, images, videos, voice messages with read receipts |
| 📞 **Voice/Video Calls** | WebRTC-based peer-to-peer calls |
| 📰 **Status/Stories** | 24-hour disappearing status updates |
| 👥 **Group Chats** | Create and manage group conversations |
| ⚙️ **Settings** | Theme, language, privacy, and profile customization |
| 🌙 **Dark Theme** | Modern dark UI with violet accent colors |

---

## 🛠️ Tech Stack

### Framework & Language

| Technology | Version | Usage |
|------------|---------|-------|
| **Flutter** | ≥3.0.0 | Cross-platform UI framework |
| **Dart** | ≥3.0.0 | Programming language |

### Firebase Services

| Service | Version | Purpose |
|---------|---------|---------|
| **firebase_core** | ^3.15.2 | Firebase initialization |
| **firebase_auth** | ^5.7.0 | Phone OTP authentication |
| **cloud_firestore** | ^5.6.12 | Real-time database |
| **firebase_storage** | ^12.4.10 | Media file storage |
| **firebase_messaging** | ^15.2.10 | Push notifications |
| **firebase_database** | ^11.3.1 | Real-time presence |

### State Management & Navigation

| Package | Version | Purpose |
|---------|---------|---------|
| **flutter_riverpod** | ^2.6.1 | State management |
| **riverpod** | ^2.6.1 | Riverpod core |
| **go_router** | ^14.8.1 | Declarative navigation |

### Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **flutter_webrtc** | ^0.14.2 | Voice/video calls |
| **socket_io_client** | ^2.0.3+1 | WebSocket signaling |
| **google_fonts** | ^6.3.3 | Custom typography |
| **flutter_animate** | ^4.5.0 | Animations |
| **cached_network_image** | ^3.4.1 | Image caching |
| **video_player** | ^2.8.7 | Video playback |
| **just_audio** | ^0.9.36 | Audio playback |
| **image_picker** | ^1.1.2 | Media selection |
| **local_auth** | ^2.3.0 | Biometric authentication |
| **encrypt** | ^5.0.3 | Message encryption |
| **sqflite** | ^2.4.1 | Local database |
| **shared_preferences** | ^2.3.3 | Key-value storage |
| **permission_handler** | ^11.3.1 | Runtime permissions |
| **uuid** | ^4.5.1 | Unique ID generation |
| **record** | ^6.2.0 | Voice recording |
| **intl** | ^0.19.0 | Internationalization |
| **country_code_picker** | ^3.0.0 | Country selection |

---

## 🏗️ Architecture

### Project Structure

```
talky/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── firebase_options.dart              # Firebase configuration
│   ├── core/
│   │   ├── constants/                     # App constants & icons
│   │   │   ├── app_colors.dart           # Color definitions
│   │   │   ├── app_constants.dart        # App-wide constants
│   │   │   └── app_icons.dart            # Icon definitions
│   │   ├── router/
│   │   │   └── app_router.dart           # GoRouter configuration
│   │   ├── services/
│   │   │   ├── fcm_sender.dart           # FCM notification sender
│   │   │   ├── notification_service.dart # Push notifications
│   │   │   ├── phone_contacts_service.dart # Contact sync
│   │   │   └── presence_service.dart     # Online status
│   │   └── theme/
│   │       ├── app_colors_provider.dart  # Theme color provider
│   │       └── app_theme.dart            # Light/dark themes
│   ├── features/
│   │   ├── auth/                         # Authentication
│   │   │   ├── data/
│   │   │   │   ├── auth_providers.dart   # Riverpod providers
│   │   │   │   └── auth_service.dart     # Auth logic
│   │   │   ├── domain/
│   │   │   │   └── user_model.dart       # User model
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       ├── otp_screen.dart        # OTP verification
│   │   │       ├── phone_screen.dart      # Phone input
│   │   │       └── register_screen.dart
│   │   ├── calls/                        # Voice/video calls
│   │   │   ├── data/
│   │   │   │   ├── call_providers.dart
│   │   │   │   └── call_service.dart     # WebRTC logic
│   │   │   ├── domain/
│   │   │   │   └── call_history_model.dart
│   │   │   └── presentation/
│   │   │       ├── call_screen.dart       # Active call UI
│   │   │       ├── calls_screen.dart      # Call history
│   │   │       ├── incoming_call_screen.dart
│   │   │       └── new_call_screen.dart
│   │   ├── chat/                         # Messaging
│   │   │   ├── data/
│   │   │   │   ├── chat_providers.dart
│   │   │   │   ├── chat_service.dart      # Firestore operations
│   │   │   │   └── media_service.dart     # Media upload
│   │   │   ├── domain/
│   │   │   │   ├── contact_model.dart
│   │   │   │   ├── conversation_model.dart
│   │   │   │   └── message_model.dart
│   │   │   └── presentation/
│   │   │       ├── chat_screen.dart       # Chat UI
│   │   │       ├── chat_details_screen.dart
│   │   │       ├── conversations_screen.dart
│   │   │       ├── create_group_screen.dart
│   │   │       ├── new_chat_screen.dart
│   │   │       ├── share_contact_screen.dart
│   │   │       ├── archived_conversations_screen.dart
│   │   │       └── widgets/
│   │   │           ├── media_picker_sheet.dart
│   │   │           ├── message_image_bubble.dart
│   │   │           ├── video_message_bubble.dart
│   │   │           └── voice_recorder_widget.dart
│   │   ├── groups/                       # Group management
│   │   ├── home/                        # Main navigation
│   │   ├── onboarding/                 # First-time user flow
│   │   ├── profile/                    # User profile setup
│   │   ├── settings/                   # App settings
│   │   │   ├── data/
│   │   │   │   └── settings_providers.dart
│   │   │   └── presentation/
│   │   │       ├── settings_screen.dart
│   │   │       ├── appearance_settings_screen.dart
│   │   │       ├── language_settings_screen.dart
│   │   │       ├── profile_settings_screen.dart
│   │   │       └── about_screen.dart
│   │   ├── splash/                      # Splash screen
│   │   └── status/                     # Status/stories
│   │       ├── data/
│   │       │   ├── status_providers.dart
│   │       │   └── status_service.dart
│   │       ├── domain/
│   │       │   └── status_model.dart
│   │       └── presentation/
│   │           ├── status_screen.dart
│   │           ├── add_status_screen.dart
│   │           ├── status_viewer_screen.dart
│   │           └── widgets/
│   │               └── status_ring.dart
│   └── shared/
│       └── widgets/                    # Reusable widgets
├── assets/
│   ├── images/
│   └── animations/
├── android/                            # Android platform files
├── ios/                                 # iOS platform files
├── pubspec.yaml                        # Dependencies
├── firebase.json                       # Firebase config
└── README.md                          # This file
```

### Clean Architecture Pattern

The project follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  (Screens, Widgets, Providers)                             │
├─────────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                           │
│  (Models, Business Logic)                                   │
├─────────────────────────────────────────────────────────────┤
│                       DATA LAYER                            │
│  (Services, Repositories, Firebase)                         │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action → Provider (Riverpod) → Service → Firebase Firestore
                ↓
          UI Update (State Change)
```

---

## ✅ Features

### 🔐 Authentication

- **Phone OTP Verification** — Firebase Auth with SMS verification
- **Auto-fill OTP** — Automatic code detection on Android
- **Profile Setup** — Name, photo, and status customization
- **Session Management** — Persistent login with presence tracking
- **Biometric Lock** — Optional local authentication

### 💬 Messaging

- **Text Messages** — Real-time text with emoji support
- **Media Messages** — Images, videos with thumbnails
- **Voice Messages** — Record and send voice messages
- **Message Status** — Sent ✓, Delivered ✓✓, Read 🔵
- **Reply to Message** — Quote and reply to specific messages
- **Delete Messages** — Delete for everyone or just yourself

### 👥 Group Chats

- **Create Groups** — Name, photo, and initial members
- **Group Management** — Add/remove members
- **Group Info** — View and edit group details
- **Media Sharing** — Share images/videos to groups

### 📞 Voice & Video Calls

- **WebRTC** — Peer-to-peer real-time communication
- **Audio Calls** — High-quality voice calls
- **Video Calls** — Front/back camera support
- **Call Controls** — Mute, speaker, camera toggle
- **Call History** — View past calls
- **Incoming Call Screen** — Accept/reject interface
- **Push Notifications** — FCM for call alerts

### 📰 Status/Stories

- **Photo/Video Status** — 24-hour disappearing content
- **View Status** — Full-screen status viewer
- **Status Rings** — Visual indicator of viewed status
- **Auto-Expiration** — Automatic deletion after 24h

### ⚙️ Settings & Customization

- **Profile Management** — Edit name, photo, status
- **Theme Toggle** — Dark/Light theme switching
- **Language Settings** — Multi-language support
- **Privacy Settings** — Online status visibility
- **About Section** — App information and version

---

## 📋 Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **Flutter SDK** | ≥3.0.0 | Framework |
| **Dart SDK** | ≥3.0.0 | Language |
| **Android SDK** | Latest | Android builds |
| **Xcode** | Latest (macOS) | iOS builds |
| **Node.js** | 18+ | Signaling server |

### Required Accounts

- **Firebase Project** — Create at [console.firebase.google.com](https://console.firebase.google.com)
- **Google Account** — For Firebase and Google Services

---

## 🚀 Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/talky.git
cd talky
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

#### Option A: Use Existing Configuration

The project already includes Firebase configuration in:
- `android/app/google-services.json`
- `lib/firebase_options.dart`

#### Option B: Re-configure Firebase

```bash
# Install FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure --project=your-project-id
```

### 4. Android Configuration

#### Update Package Name (if needed)

Edit `android/app/build.gradle.kts`:

```kotlin
namespace = "com.example.talky"  // Change to your package
```

#### Configure AndroidManifest.xml

The following permissions are already configured in [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

```xml
<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Camera & Microphone (Calls) -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>

<!-- Storage (Media) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

<!-- Contacts -->
<uses-permission android:name="android.permission.READ_CONTACTS"/>

<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<!-- Biometric -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

### 5. iOS Configuration

#### Update Bundle Identifier

Edit `ios/Runner/Info.plist` with your bundle ID.

#### Configure iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Talky needs camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Talky needs microphone for calls and voice messages</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Talky needs photo library access to share images</string>
<key>NSContactsUsageDescription</key>
<string>Talky needs contacts access to find friends</string>
```

### 6. Run the App

```bash
# Development mode
flutter run

# Specific device
flutter run -d android
flutter run -d iphone
```

---

## ⚙️ Configuration

### Firebase Console Setup

#### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: `talky-2026`
3. Enable **Authentication** → Phone provider
4. Enable **Firestore Database**
5. Enable **Firebase Storage**
6. Enable **Firebase Cloud Messaging**

#### 2. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversations - participants can read/write
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null 
        && request.auth.uid in resource.data.participantIds;
    }
    
    // Messages - participants can read/write
    match /conversations/{conversationId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    // Status - public read, own write
    match /statuses/{statusId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

#### 3. Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Push Notifications Setup

#### Enable FCM in Firebase

1. Go to **Project Settings** → **Cloud Messaging**
2. Copy the **Server Key** (for server-side use)
3. Android: Ensure `google-services.json` is up to date

#### Notification Service

The app includes [`lib/core/services/notification_service.dart`](lib/core/services/notification_service.dart) for:
- Foreground notifications
- Background message handling
- Notification tap navigation

### Call Signaling Server

Calls use WebRTC with a Socket.IO signaling server.

| Server | URL | Purpose |
|--------|-----|---------|
| **Signaling** | `https://talky-signaling.onrender.com` | WebSocket coordination |
| **STUN** | `stun.l.google.com:19302` | NAT traversal |
| **TURN** | `global.relay.metered.ca` | Media relay |

#### Setting Up Your Own Signaling Server

```bash
# Clone and deploy the signaling server
git clone https://github.com/your-repo/talky-signaling-server.git
cd talky-signaling-server
npm install
npm start
```

Update the URL in [`lib/features/calls/data/call_service.dart`](lib/features/calls/data/call_service.dart:10):

```dart
const _signalingUrl = 'https://your-server-url.com';
```

---

## 🏃 Running the App

### Development Commands

```bash
# Run in debug mode
flutter run

# Hot reload
flutter run --hot

# Run with custom device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Build Commands

#### Android

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

#### iOS

```bash
# Simulator
flutter build ios --simulator --no-codesign

# Device (requires Apple Developer account)
flutter build ios --release
```

#### Web

```bash
flutter build web
```

### Analyzing & Testing

```bash
# Analyze code
flutter analyze

# Run tests
flutter test

# Run with verbose output
flutter run -v
```

---

## 🎨 Design System

### Color Palette (Dark Theme)

| Element | Color | Hex |
|---------|-------|-----|
| Background | Deep Black | `#0A0A0F` |
| Surface | Dark Gray | `#12121A` |
| Primary | Talky Violet | `#7C5CFC` |
| Accent | Electric Cyan | `#4FC3F7` |
| Text Primary | Off White | `#F0EEFF` |
| Text Secondary | Gray Purple | `#9B96B8` |
| Sent Bubble | Talky Violet | `#7C5CFC` |
| Received Bubble | Dark Gray | `#1C1C28` |
| Success | Green | `#4CAF82` |
| Error | Red | `#FF5C7A` |

### Typography

- **Font Family**: Sora (Google Fonts)
- **Headings**: Bold, 20-28sp
- **Body**: Regular, 14-16sp
- **Caption**: Regular, 12sp

### Border Radius

| Element | Radius |
|---------|--------|
| Standard | 16px |
| Small | 8px |
| Large | 24px |
| Message Bubble | 16px |

---

## 🤝 Contributing Guidelines

### Code Style

1. **Follow Dart/Flutter conventions**
   - Use `flutter_lints` (included in dev_dependencies)
   - Run `flutter analyze` before committing

2. **Naming Conventions**
   - Classes: `PascalCase` (e.g., `ChatService`)
   - Methods/variables: `camelCase` (e.g., `sendMessage`)
   - Files: `snake_case.dart` (e.g., `chat_service.dart`)

3. **File Organization**
   ```
   feature_name/
   ├── data/
   │   ├── providers.dart
   │   └── service.dart
   ├── domain/
   │   └── model.dart
   └── presentation/
       ├── screen.dart
       └── widgets/
   ```

### Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make Changes**
   - Write clean, documented code
   - Add comments for complex logic

3. **Test Your Changes**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Commit & Push**
   ```bash
   git add .
   git commit -m "Add: your feature description"
   git push origin feature/your-feature
   ```

5. **Create Pull Request**
   - Describe your changes
   - Link any related issues

### Best Practices

- **State Management**: Use Riverpod providers for all state
- **Error Handling**: Always handle Firebase and network errors
- **Performance**: Use lazy loading for lists and images
- **Security**: Never expose sensitive data in client code

---

## 📁 Project Documentation

Additional documentation files are available:

| File | Description |
|------|-------------|
| [`KILO.md`](KILO.md) | Technical specifications & call flow |
| [`BD.md`](BD.md) | Firestore database schema |
| [`CLAUDE.md`](CLAUDE.md) | Project roadmap & history |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | UI/UX design guidelines |

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation files

---

*Last updated: March 2026*
