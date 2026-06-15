/// PINE - Pest Identification on Native Environments
///
/// Offline-first Android mobile application for detecting tiny agricultural pests
/// (e.g., mealybugs) on plant leaves using Ultralytics YOLO (TFLite).
/// Cloud sync via Supabase; offline persistence via local DB.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'core/app_state.dart';
import 'core/service_locator.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'services/biometric_service.dart';
import 'services/camera_service.dart';
import 'services/database_service.dart';
import 'services/geo_fence_service.dart';
import 'services/geo_service.dart';
import 'services/image_storage_service.dart';
import 'services/inference_service.dart';
import 'screens/demo_account_switch_screen.dart';
import 'screens/intro_flow_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/fields_list_screen.dart';
import 'screens/disease_info_screen.dart';
import 'screens/location_selector_screen.dart';
import 'screens/permission_screens.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/nickname_prompt_screen.dart';
import 'screens/captured_photos_screen.dart';
import 'screens/forgot_password_screen.dart'
    show ForgotPasswordRouteArgs, ForgotPasswordScreen;
import 'screens/reset_password_screen.dart';
import 'screens/config_required_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase. (Provide via `--dart-define`).
  final bool supabaseOk = await SupabaseClientProvider.instance.tryInitFromEnv();

  // Register core services for simple dependency injection.
  final ServiceLocator sl = ServiceLocator.instance;
  sl
    ..registerSingleton<BiometricService>(BiometricService())
    ..registerSingleton<CameraService>(CameraService())
    ..registerSingleton<InferenceService>(InferenceService())
    ..registerSingleton<DatabaseService>(DatabaseService())
    ..registerSingleton<GeoService>(GeoService())
    ..registerSingleton<GeoFenceService>(GeoFenceService())
    ..registerSingleton<ImageStorageService>(ImageStorageService());

  final AppState appState = AppState();
  await appState.loadPreferences();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MyApp(supabaseConfigured: supabaseOk),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    if (widget.supabaseConfigured) {
      // ignore: discarded_futures
      _initDeepLinks();
      _authSub = SupabaseClientProvider.instance.client.auth.onAuthStateChange
          .listen((AuthState state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _navKey.currentState?.pushNamed('/reset-password');
        }
      });
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final Uri? first = await _appLinks.getInitialLink();
      if (first != null) {
        // ignore: discarded_futures
        _handleIncomingUri(first);
      }
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        // ignore: discarded_futures
        _handleIncomingUri(uri);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // We only care about Supabase recovery links redirected to our custom scheme.
    if (uri.scheme != 'pine') return;
    if (uri.host != 'reset-password') return;
    try {
      await SupabaseClientProvider.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {}
    _navKey.currentState?.pushNamed('/reset-password');
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode =
        context.select<AppState, ThemeMode>((AppState s) => s.themeMode);
    if (!widget.supabaseConfigured) {
      return MaterialApp(
        title: 'PINYA-PIC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: ConfigRequiredScreen(
          message: (SupabaseClientProvider.instance.initError ?? '')
              .toString(),
        ),
      );
    }
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'PINYA-PIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => const IntroFlowScreen(),
        '/login': (BuildContext context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          if (args is LoginRouteArgs) {
            return LoginScreen(prefillEmail: args.email);
          }
          return const LoginScreen();
        },
        '/register': (BuildContext context) => const RegisterScreen(),
        '/forgot-password': (BuildContext context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          if (args is ForgotPasswordRouteArgs) {
            return ForgotPasswordScreen(prefillEmail: args.email);
          }
          return const ForgotPasswordScreen();
        },
        '/reset-password': (BuildContext context) =>
            const ResetPasswordScreen(),
        '/dashboard': (BuildContext context) => const MainDashboardScreen(),
        '/fields': (BuildContext context) => const FieldsListScreen(),
        '/diseases': (BuildContext context) => const DiseaseInfoScreen(),
        '/camera': (BuildContext context) => const PhotoSourcePicker(),
        '/captured': (BuildContext context) => const CapturedPhotosScreen(),
        '/location': (BuildContext context) => const LocationSelectorScreen(),
        '/settings': (BuildContext context) => const SettingsScreen(),
        '/profile': (BuildContext context) => const ProfileScreen(),
        '/notifications': (BuildContext context) =>
            const NotificationsScreen(),
        '/faq': (BuildContext context) => const FaqScreen(),
        '/privacy': (BuildContext context) => const PrivacyScreen(),
        '/terms': (BuildContext context) => const TermsScreen(),
        '/feedback': (BuildContext context) => const FeedbackScreen(),
        '/nickname-prompt': (BuildContext context) =>
            const NicknamePromptScreen(),
        '/demo-account-switch': (BuildContext context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          if (args is! DemoAccountSwitchArgs) {
            return const IntroFlowScreen();
          }
          return DemoAccountSwitchScreen(args: args);
        },
      },
    );
  }
}
