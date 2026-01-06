import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/scan/presentation/screens/scan_qr_screen.dart';
import 'features/history/presentation/screens/history_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Test logging
  print('═══════════════════════════════════════');
  print('🚀 CopyPaws Mobile App Starting...');
  print('═══════════════════════════════════════');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize app configuration
  await AppConfig.initialize();

  print('✅ App initialization complete');
  print('═══════════════════════════════════════');

  runApp(const CopyPawsApp());
}

class CopyPawsApp extends StatelessWidget {
  const CopyPawsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark theme to match desktop
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/scan': (context) => const ScanQRScreen(),
        '/history': (context) => const HistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
