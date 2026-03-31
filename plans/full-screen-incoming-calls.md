# Plan d'implémentation : Écran d'appel entrant plein écran (Android uniquement)

## 📋 Vue d'ensemble

Ce document détaille l'implémentation nécessaire pour afficher l'écran d'appel entrant **peu importe où se trouve l'utilisateur** sur Android : dans l'application, en arrière-plan, ou lorsque l'application est fermée.

---

## 🔍 Analyse de l'implémentation actuelle

### Problèmes identifiés

1. **Notification tap ne redirige pas vers l'écran d'appel** :
   - Quand l'utilisateur clique sur la notification d'appel entrant, il n'est pas redirigé vers l'écran d'appel
   - Le payload de la notification n'est pas correctement géré dans `_handleTap()`

2. **Écran d'appel ne s'affiche pas quand l'utilisateur est dans l'application** :
   - L'utilisateur est dans l'application mais voit seulement la notification
   - L'écran d'appel entrant ne s'affiche pas automatiquement
   - Le listener dans `main.dart` ne détecte pas toujours le changement d'état

3. **Full-Screen Intent non fonctionnel** :
   - La permission `USE_FULL_SCREEN_INTENT` est déclarée mais pas utilisée
   - Pas d'activité dédiée pour afficher l'écran d'appel en plein écran
   - La notification ne déclenche pas l'affichage automatique

4. **Cold start non géré** :
   - Quand l'application est fermée, la notification ne peut pas ouvrir l'écran d'appel
   - Les données d'appel ne sont pas préservées pour le cold start

---

## 🎯 Objectifs

1. **Fixer le tap sur notification** : Rediriger vers l'écran d'appel quand l'utilisateur clique sur la notification
2. **Affichage automatique** : Afficher l'écran d'appel automatiquement quand l'utilisateur est dans l'application
3. **Full-Screen Intent** : Afficher l'écran d'appel même quand l'application est en arrière-plan ou fermée
4. **Écran verrouillé** : Afficher l'écran d'appel même sur l'écran verrouillé

---

## 📱 Implémentation Android

### 1. Problème 1 : Notification tap ne redirige pas

**Cause** : Dans `notification_service.dart`, la méthode `_handleTap()` ne gère pas correctement les appels entrants.

**Solution** : Modifier `_handleTap()` pour gérer le payload d'appel et naviguer vers l'écran d'appel.

**Fichier** : `lib/core/services/notification_service.dart`

```dart
void _handleTap(String? payload) {
  if (payload == null) {
    rootNavigatorKey.currentContext?.go(AppRoutes.home);
    return;
  }
  
  // Parser le payload pour extraire les données
  final data = _parsePayload(payload);
  final type = data['type'] as String?;
  
  if (type == 'call') {
    // Naviguer vers l'écran d'appel entrant
    final callerId = data['callerId'] as String? ?? '';
    final callerName = data['callerName'] as String? ?? 'Appel entrant';
    final isVideo = (data['isVideo'] as String?) == 'true' || data['isVideo'] == true;
    final isGroup = (data['isGroup'] as String?) == 'true' || data['isGroup'] == true;
    final roomId = data['roomId'] as String?;
    
    rootNavigatorKey.currentContext?.push(
      AppRoutes.incomingCall,
      extra: {
        'callerId': callerId,
        'callerName': callerName,
        'isVideo': isVideo,
        'isGroup': isGroup,
        'roomId': roomId,
      },
    );
    return;
  }
  
  if (type == 'group_call') {
    final callerId = data['callerId'] as String? ?? '';
    final callerName = data['callerName'] as String? ?? 'Appel de groupe';
    final roomId = data['roomId'] as String? ?? '';
    final isVideo = (data['isVideo'] as String?) == 'true' || data['isVideo'] == true;
    
    if (roomId.isNotEmpty) {
      rootNavigatorKey.currentContext?.push(
        AppRoutes.incomingCall,
        extra: {
          'callerId': callerId,
          'callerName': callerName,
          'isVideo': isVideo,
          'isGroup': true,
          'roomId': roomId,
        },
      );
      return;
    }
  }
  
  // Fallback → accueil
  rootNavigatorKey.currentContext?.go(AppRoutes.home);
}

Map<String, dynamic> _parsePayload(String payload) {
  try {
    // Le payload est une chaîne de caractères représentant une Map
    // Format: "{key1: value1, key2: value2, ...}"
    final cleaned = payload.replaceAll('{', '').replaceAll('}', '');
    final pairs = cleaned.split(', ');
    final result = <String, dynamic>{};
    
    for (final pair in pairs) {
      final keyValue = pair.split(': ');
      if (keyValue.length == 2) {
        result[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    
    return result;
  } catch (e) {
    debugPrint('Erreur parsing payload: $e');
    return {};
  }
}
```

### 2. Problème 2 : Écran d'appel ne s'affiche pas quand l'utilisateur est dans l'application

**Cause** : Le listener dans `main.dart` ne détecte pas toujours le changement d'état, et la notification est affichée même quand l'application est au premier plan.

**Solution** : 
- Modifier le listener pour être plus réactif
- Ne pas afficher de notification quand l'application est au premier plan
- Afficher directement l'écran d'appel

**Fichier** : `lib/main.dart`

```dart
// Dans initState de _TalkyAppState
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);

  _authSub = ref.listenManual(authStateProvider, (_, next) {
    final user = next.value;
    if (user != null) {
      ref.read(authServiceProvider).setOnlineStatus(true);
      PresenceService.instance.start(user.uid);
      NotificationService.instance.registerTokenForUser(user.uid);
      ref.read(callServiceProvider);
    } else {
      PresenceService.instance.stop();
    }
  });

  // Écouter les appels entrants globalement - PLUS RÉACTIF
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.listenManual(callProvider, (prev, next) {
      // Détecter le passage à l'état ringing
      if (next.status == CallStatus.ringing &&
          prev?.status != CallStatus.ringing) {
        // Vérifier si l'application est au premier plan
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          // Afficher directement l'écran d'appel
          _showIncomingCall();
        }
        // Sinon, la notification full-screen intent s'en charge
      }
    });
  });
}

void _showIncomingCall() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  
  // Vérifier si l'écran d'appel n'est pas déjà affiché
  final currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == AppRoutes.incomingCall) return;
  
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      settings: const RouteSettings(name: AppRoutes.incomingCall),
      builder: (_) => const IncomingCallScreen(),
    ),
  );
}
```

**Fichier** : `lib/core/services/notification_service.dart`

```dart
// Modifier showNotificationFromMessage pour ne pas afficher de notification quand l'app est au premier plan
Future<void> showNotificationFromMessage(
  RemoteMessage message, {
  bool forceLocal = false,
}) async {
  // Si l'application est au premier plan, ne pas afficher de notification
  // L'écran d'appel sera affiché directement par le listener dans main.dart
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    debugPrint('[Notification] App au premier plan, pas de notification affichée');
    return;
  }
  
  // ... reste du code existant ...
}
```

### 3. Problème 3 : Full-Screen Intent non fonctionnel

**Cause** : Pas d'activité dédiée pour afficher l'écran d'appel en plein écran.

**Solution** : Créer une activité `IncomingCallActivity` qui sera déclenchée par la notification.

**Fichier** : `android/app/src/main/kotlin/com/example/talky/IncomingCallActivity.kt`

```kotlin
package com.example.talky

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class IncomingCallActivity : FlutterActivity() {
    private val CHANNEL = "com.example.talky/incoming_call"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // Afficher l'activité même si l'écran est verrouillé
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCallData" -> {
                    val callData = mapOf(
                        "callerId" to intent.getStringExtra("callerId"),
                        "callerName" to intent.getStringExtra("callerName"),
                        "isVideo" to intent.getBooleanExtra("isVideo", false),
                        "isGroup" to intent.getBooleanExtra("isGroup", false),
                        "roomId" to intent.getStringExtra("roomId"),
                        "offer" to intent.getStringExtra("offer")
                    )
                    result.success(callData)
                }
                "finish" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    companion object {
        fun createIntent(context: Context, data: Map<String, Any?>): Intent {
            return Intent(context, IncomingCallActivity::class.java).apply {
                putExtra("callerId", data["callerId"] as? String)
                putExtra("callerName", data["callerName"] as? String)
                putExtra("isVideo", data["isVideo"] as? Boolean ?: false)
                putExtra("isGroup", data["isGroup"] as? Boolean ?: false)
                putExtra("roomId", data["roomId"] as? String)
                putExtra("offer", data["offer"] as? String)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }
}
```

### 4. Mettre à jour AndroidManifest.xml

**Fichier** : `android/app/src/main/AndroidManifest.xml`

Ajouter l'activité `IncomingCallActivity` :

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions existantes -->
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    
    <application
        android:label="talky"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Activité principale -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- NOUVEAU: Activité pour les appels entrants plein écran -->
        <activity
            android:name=".IncomingCallActivity"
            android:exported="false"
            android:showOnLockScreen="true"
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            android:taskAffinity=""
            android:theme="@style/IncomingCallTheme"
            android:excludeFromRecents="true"
            android:launchMode="singleInstance" />
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

### 5. Ajouter le thème IncomingCallTheme

**Fichier** : `android/app/src/main/res/values/styles.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Thème existant -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
    
    <!-- NOUVEAU: Thème pour l'activité d'appel entrant -->
    <style name="IncomingCallTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@android:color/black</item>
        <item name="android:windowIsTranslucent">true</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowContentOverlay">@null</item>
        <item name="android:windowShowWallpaper">false</item>
    </style>
</resources>
```

### 6. Créer un service de notification natif

**Fichier** : `android/app/src/main/kotlin/com/example/talky/CallNotificationService.kt`

```kotlin
package com.example.talky

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class CallNotificationService(private val context: Context) {
    
    companion object {
        const val CHANNEL_ID = "incoming_calls"
        const val NOTIFICATION_ID = 1001
    }
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Appels entrants",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications pour les appels entrants"
                setSound(null, null)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    fun showIncomingCallNotification(data: Map<String, Any?>) {
        val fullScreenIntent = IncomingCallActivity.createIntent(context, data)
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent pour ouvrir l'application quand on clique sur la notification
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("callerId", data["callerId"] as? String)
            putExtra("callerName", data["callerName"] as? String)
            putExtra("isVideo", data["isVideo"] as? Boolean ?: false)
            putExtra("isGroup", data["isGroup"] as? Boolean ?: false)
            putExtra("roomId", data["roomId"] as? String)
            putExtra("offer", data["offer"] as? String)
            putExtra("type", "call")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            1,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(data["callerName"] as? String ?: "Appel entrant")
            .setContentText(if (data["isVideo"] as? Boolean == true) "Appel vidéo entrant" else "Appel audio entrant")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(mainPendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .build()
        
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    fun cancelNotification() {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
```

### 7. Mettre à jour MainActivity.kt

**Fichier** : `android/app/src/main/kotlin/com/example/talky/MainActivity.kt`

```kotlin
package com.example.talky

import android.content.ContentResolver
import android.database.Cursor
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.talky/contacts"
    private val CALL_CHANNEL = "com.example.talky/call_notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal pour les contacts
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getContacts") {
                val contacts = getContacts()
                result.success(contacts)
            } else {
                result.notImplemented()
            }
        }
        
        // Canal pour les notifications d'appel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCall" -> {
                    val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val service = CallNotificationService(this)
                    service.showIncomingCallNotification(data)
                    result.success(null)
                }
                "cancelNotification" -> {
                    val service = CallNotificationService(this)
                    service.cancelNotification()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Gérer les intents d'appel au démarrage
        handleIncomingCallIntent()
    }
    
    private fun handleIncomingCallIntent() {
        val intent = intent
        if (intent != null && intent.getStringExtra("type") == "call") {
            // Stocker les données d'appel pour Flutter
            val callData = mapOf(
                "callerId" to intent.getStringExtra("callerId"),
                "callerName" to intent.getStringExtra("callerName"),
                "isVideo" to intent.getBooleanExtra("isVideo", false),
                "isGroup" to intent.getBooleanExtra("isGroup", false),
                "roomId" to intent.getStringExtra("roomId"),
                "offer" to intent.getStringExtra("offer")
            )
            
            // Envoyer les données à Flutter via un canal
            val channel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, "com.example.talky/incoming_call")
            channel.invokeMethod("onIncomingCall", callData)
        }
    }
    
    private fun getContacts(): List<Map<String, Any?>> {
        // ... code existant ...
    }
}
```

### 8. Mettre à jour notification_service.dart

**Fichier** : `lib/core/services/notification_service.dart`

Ajouter les méthodes pour Android :

```dart
// Méthode pour afficher un appel entrant via Full-Screen Intent (Android)
Future<void> showIncomingCallFullScreen({
  required String callerId,
  required String callerName,
  required bool isVideo,
  bool isGroup = false,
  String? roomId,
  Map<String, dynamic>? offer,
}) async {
  if (Platform.isAndroid) {
    const platform = MethodChannel('com.example.talky/call_notification');
    await platform.invokeMethod('showIncomingCall', {
      'callerId': callerId,
      'callerName': callerName,
      'isVideo': isVideo,
      'isGroup': isGroup,
      'roomId': roomId,
      'offer': offer?.toString(),
    });
  }
}

// Méthode pour annuler la notification d'appel
Future<void> cancelIncomingCallNotification() async {
  if (Platform.isAndroid) {
    const platform = MethodChannel('com.example.talky/call_notification');
    await platform.invokeMethod('cancelNotification');
  }
}
```

### 9. Mettre à jour call_service.dart

**Fichier** : `lib/features/calls/data/call_service.dart`

Modifier la méthode qui reçoit l'appel entrant pour déclencher la notification full-screen :

```dart
_socket!.on('incoming_call', (data) async {
  debugPrint('[Socket] incoming_call received: $data');
  final incoming = IncomingCallData(
    callerId:    data['callerId'],
    callerName:  data['callerName'],
    callerPhoto: data['callerPhoto'],
    isVideo:     data['isVideo'] ?? false,
    offer:       Map<String, dynamic>.from(data['offer']),
  );
  _remoteUserId = incoming.callerId;
  _isVideo      = incoming.isVideo;
  _incomingCtrl.add(incoming);
  _eventCtrl.add(CallEvent.incomingCall);
  
  // NOUVEAU: Déclencher la notification full-screen si l'app n'est pas au premier plan
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    NotificationService.instance.showIncomingCallFullScreen(
      callerId: incoming.callerId,
      callerName: incoming.callerName,
      isVideo: incoming.isVideo,
      isGroup: false,
      offer: incoming.offer,
    );
  }
});
```

---

## 📝 Checklist d'implémentation

### Android

- [ ] Modifier `notification_service.dart` pour gérer le tap sur notification
- [ ] Modifier `main.dart` pour améliorer la détection d'appel entrant
- [ ] Créer `IncomingCallActivity.kt`
- [ ] Créer `CallNotificationService.kt`
- [ ] Mettre à jour `AndroidManifest.xml` avec la nouvelle activité
- [ ] Ajouter le thème `IncomingCallTheme` dans `styles.xml`
- [ ] Mettre à jour `MainActivity.kt` pour gérer les intents d'appel
- [ ] Mettre à jour `call_service.dart` pour déclencher la notification full-screen
- [ ] Tester le tap sur notification
- [ ] Tester l'affichage automatique quand l'utilisateur est dans l'app
- [ ] Tester le full-screen intent quand l'app est en arrière-plan
- [ ] Tester le cold start

---

## 🔗 Ressources

- [Android Full-Screen Intent](https://developer.android.com/reference/android/app/PendingIntent.html#FLAG_FULLSCREEN_INTENT)
- [Android Notification Channels](https://developer.android.com/training/notify-user/channels)
- [Flutter Method Channels](https://docs.flutter.dev/platform-integration/platform-channels)
