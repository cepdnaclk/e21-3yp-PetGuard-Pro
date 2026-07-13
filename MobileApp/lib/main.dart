import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/screens/loading_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/owner/location/services/notification_service.dart';
import 'features/owner/location/services/location_history_service.dart';
import 'features/owner/location/services/cloud_service.dart';
import 'features/owner/health/screens/health_dashboard_screen.dart';
import 'core/constants/routes.dart';
import 'features/owner/health/services/health_service.dart';
import 'features/owner/activity/screens/activity_dashboard_screen.dart';
import 'features/owner/activity/services/activity_notification_service.dart';
import 'features/owner/screens/user_profile_page.dart';
import 'features/owner/screens/settings_screen.dart';
import 'features/owner/screens/help_support_page.dart';
import 'features/owner/screens/about_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stack) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('$stack');
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('geofences');
  await Hive.openBox('location_history');

  // Initialize GPS services
  await NotificationService().initialize();
  await NotificationService().requestPermissions();
  await LocationHistoryService().initialize();

  try {
    await CloudService().initialize();
  } catch (e) {
    debugPrint('Cloud service initialization error: $e');
  }

  try {
    await HealthService().initialize();
  } catch (e) {
    debugPrint('Health service initialization error: $e');
  }

  try {
    await ActivityNotificationService().initialize();
  } catch (e) {
    debugPrint('Activity notification service error: $e');
  }

  runApp(
    const ProviderScope(
      // Wrap with Riverpod
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themePreferencesProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PetGuard Pro',
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const LoadingScreen(),
      routes: {
        Routes.login: (context) => const LoginScreen(),
        Routes.healthDashboard: (context) => const HealthDashboardScreen(),
        Routes.activityDashboard: (context) => const ActivityDashboardScreen(),
        Routes.userProfile: (context) => const UserProfilePage(),
        Routes.settings: (context) => const SettingsScreen(),
        Routes.helpSupport: (context) => const HelpSupportPage(),
        Routes.about: (context) => const AboutPage(),
      },
    );
  }
}
