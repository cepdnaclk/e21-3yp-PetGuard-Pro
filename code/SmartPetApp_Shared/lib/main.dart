import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/loading_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/owner/location/services/notification_service.dart';
import 'features/owner/location/services/location_history_service.dart';
import 'features/owner/location/services/cloud_service.dart';

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

  runApp(
    const ProviderScope(
      // Wrap with Riverpod
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetGuard Pro',
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoadingScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
