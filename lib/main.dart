// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/cache/local_cache.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/data/auth_providers.dart';
import 'core/services/presence_service.dart';
import 'core/services/notification_service.dart';
import 'features/settings/data/settings_providers.dart';
import 'features/calls/data/call_providers.dart'; 
import 'features/calls/presentation/incoming_call_screen.dart';

// ── Handler notifications en arrière-plan (OBLIGATOIRE top-level) ─────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.showNotificationFromMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for French locale
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialiser Hive (cache local)
  await LocalCache.init();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Enregistrer le handler background FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Style de la barre de statut (sera mis à jour selon le thème)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const TalkyApp(),
    ),
  );
}

class TalkyApp extends ConsumerStatefulWidget {
  const TalkyApp({super.key});

  @override
  ConsumerState<TalkyApp> createState() => _TalkyAppState();
}

class _TalkyAppState extends ConsumerState<TalkyApp>
    with WidgetsBindingObserver {
  ProviderSubscription? _authSub;

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
        ref.read(callServiceProvider); // ← AJOUTER CETTE LIGNE
      } else {
        PresenceService.instance.stop();
      }
    });

    // Écouter les appels entrants globalement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(callProvider, (prev, next) {
        if (next.status == CallStatus.ringing &&
            prev?.status != CallStatus.ringing) {
          _showIncomingCall();
        }
      });
    });
  }
  
  void _showIncomingCall() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const IncomingCallScreen(),
    ),
  );
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    if (state == AppLifecycleState.resumed) {
      ref.read(authServiceProvider).setOnlineStatus(true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(authServiceProvider).setOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Talky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
