import 'package:cc/services/theme_notifier.dart';
import 'package:cc/views/splash.dart';
import 'package:cc/utils/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load persisted theme preference before first frame
  await ThemeNotifier.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (_, themeMode, __) {
        return MaterialApp(
          title: 'Clean Core - A Smartends Solution',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,

          // ── Light theme ─────────────────────────────────────────────
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: AppCol.btnbacks,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppCol.btnbacks,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // ── Dark theme ──────────────────────────────────────────────
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppCol.btnbacks,
            scaffoldBackgroundColor: const Color(0xFF0F1117),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppCol.btnbacks,
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1F2E),
              onSurface: Colors.white,
            ),
            cardColor: const Color(0xFF1E2430),
            dividerColor: Colors.white12,
            useMaterial3: true,
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}
