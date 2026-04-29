// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'core/cache/local_cache.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/data/auth_providers.dart';
import 'core/services/presence_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/settings_providers.dart';
import 'features/calls/data/call_providers.dart';
import 'features/calls/presentation/incoming_call_screen.dart';

final _isDesktop = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);

// ── Handler notifications en arrière-plan (OBLIGATOIRE top-level) ─────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.showNotificationFromMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization: $e');
  }

  await LocalCache.init();

  final sharedPreferences = await SharedPreferences.getInstance();

  if (!_isDesktop) {
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (_) {}

    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

  // Canal pour recevoir les actions depuis IncomingCallActivity (natif)
  static const _callActionChannel =
      MethodChannel('com.example.talky/call_action');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ── Auth : démarrer les services quand l'utilisateur se connecte ──
    _authSub = ref.listenManual(authStateProvider, (_, next) {
      final user = next.value;
      if (user != null) {
        ref.read(authServiceProvider).setOnlineStatus(true);
        PresenceService.instance.start(user.uid);
        NotificationService.instance.registerTokenForUser(user.uid);
        // Forcer l'init du callService (socket) dès la connexion
        ref.read(callServiceProvider);
      } else {
        PresenceService.instance.stop();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ── Écouter les appels entrants via socket (app en foreground) ──
      ref.listenManual(callProvider, (prev, next) {
        if (next.status == CallStatus.ringing &&
            prev?.status != CallStatus.ringing) {
          // Afficher l'écran quel que soit l'état du lifecycle.
          // IncomingCallActivity (natif) gère le lock screen,
          // mais Flutter doit toujours afficher son propre écran
          // quand le socket arrive.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showIncomingCallScreen();
          });
        }
      });

      // ── Écouter les actions depuis IncomingCallActivity (natif) ─────
      // Quand l'utilisateur répond ou refuse depuis l'écran natif (lock screen),
      // MainActivity envoie l'action ici via MethodChannel.
      _callActionChannel.setMethodCallHandler((call) async {
        if (call.method != 'onCallAction') return;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final action = args['action'] as String?;

        switch (action) {
          case 'answer':
            _handleAnswerFromNative(args);
            break;
          case 'reject':
            _handleRejectFromNative(args);
            break;
        }
      });
    });
  }

  // ── Répondre depuis l'écran natif ─────────────────────────────────
  void _handleAnswerFromNative(Map<String, dynamic> args) {
    final callState = ref.read(callProvider);

    // Si le callProvider a déjà les données (socket arrivé avant le tap) → répondre
    if (callState.status == CallStatus.ringing &&
        callState.incomingCall != null) {
      _showIncomingCallScreen();
      return;
    }

    // Sinon : le socket n'a pas encore émis incoming_call.
    // On affiche IncomingCallScreen dès que le status passe à ringing.
    // Le listener ci-dessus dans initState s'en chargera automatiquement.
    // On amène juste l'app au premier plan (déjà fait par MainActivity).
    debugPrint('[CallAction] answer reçu — en attente du socket incoming_call');
  }

  // ── Refuser depuis l'écran natif ──────────────────────────────────
  void _handleRejectFromNative(Map<String, dynamic> args) {
    final callState = ref.read(callProvider);
    if (callState.incomingCall != null) {
      final isGroup = args['isGroup'] as bool? ?? false;
      if (isGroup) {
        ref.read(callProvider.notifier).rejectGroupCall();
      } else {
        ref.read(callProvider.notifier).rejectCall();
      }
    }
    // Annuler la notification si elle est encore visible
    NotificationService.instance.cancelIncomingCallNotification();
  }

  // ── Afficher IncomingCallScreen (foreground) ──────────────────────
  void _showIncomingCallScreen() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    // Éviter d'empiler plusieurs fois le même écran
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
    final accentColor = settings.accentColor;

    return MaterialApp.router(
      title: 'Talky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor),
      darkTheme: AppTheme.dark(accentColor),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
