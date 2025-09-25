import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/constants/app_constants.dart';
import 'core/services/telephony_sms_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/sms_catchup_service.dart';
import 'core/services/sync_status_service.dart';
import 'core/services/data_sync_service.dart';
import 'dependency_injector.dart';
import 'features/sms/presentation/bloc/sms_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/sms/presentation/pages/main_app_page.dart';
import 'features/auth/presentation/pages/google_login_page.dart';
import 'welcome_screen.dart';

/// Main entry point of the SpendTracker application
///
/// This function initializes dependencies and starts the Flutter app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize dependency injection
  await initializeDependencies();

  // Initialize notification service
  await NotificationService.initialize();

  // Initialize sync status service
  await SyncStatusService.initialize();

  // Initialize connectivity-aware sync
  DataSyncService.initializeConnectivitySync();

  // Initialize telephony SMS service for background SMS handling
  try {
    await TelephonySmsService.initialize();
    final permissionsGranted = await TelephonySmsService.requestPermissions();

    if (permissionsGranted) {
      await TelephonySmsService.startListening();

      // Perform SMS catch-up to process missed messages
      try {
        final smsCatchupService = sl<SmsCatchupService>();
        await smsCatchupService.performSmsCatchup();
      } catch (e) {
        print('Error during SMS catch-up: $e');
      }
    }
  } catch (e) {
    print('Error initializing telephony SMS service: $e');
  }

  runApp(const SpendTrackerApp());
}

/// Root widget of the SpendTracker application
///
/// This widget sets up the app theme, routing, and provides BLoCs
/// to the widget tree using BlocProvider
class SpendTrackerApp extends StatelessWidget {
  const SpendTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<SmsBloc>()),
        BlocProvider(create: (context) => sl<AuthBloc>()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationService.navigatorKey,
        theme: ThemeData(
          // App color scheme based on the blue theme from the design
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0288D1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,

          // App bar theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0288D1),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),

          // Elevated button theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0288D1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Card theme
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Initial route is the welcome screen
        initialRoute: '/',

        // Route configuration
        routes: {
          '/': (context) => const WelcomeScreen(),
          '/main': (context) => const MainAppPage(),
          '/login': (context) => const LoginPage(),
        },
      ),
    );
  }
}
