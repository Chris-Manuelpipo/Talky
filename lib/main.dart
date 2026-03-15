// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_providers.dart';
import 'core/services/presence_service.dart';

// ── Handler notifications en arrière-plan (OBLIGATOIRE top-level) ─────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // TODO Phase 3 : traiter la notification en arrière-plan
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enregistrer le handler background FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Style de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: TalkyApp(),
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
      } else {
        PresenceService.instance.stop();
      }
    });
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
    return MaterialApp.router(
      title: 'Talky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
