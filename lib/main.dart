import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'dependency_injector.dart';
import 'features/sms/presentation/bloc/sms_bloc.dart';
import 'features/sms/presentation/pages/main_app_page.dart';
import 'welcome_screen.dart';

/// Main entry point of the SpendTracker application
///
/// This function initializes dependencies and starts the Flutter app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await initializeDependencies();

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
    return BlocProvider(
      create: (context) => sl<SmsBloc>(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
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
        },
      ),
    );
  }
}
