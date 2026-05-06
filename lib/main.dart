import 'package:cc/utils/colors.dart';
import 'package:cc/utils/theme_service.dart';
import 'package:cc/views/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await loadThemePreference();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      });
    }
  });

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── App ThemeData definitions ─────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppCol.primaryDark,
        colorScheme: const ColorScheme.dark(
          primary: AppCol.primary,
          secondary: AppCol.success,
          surface: AppCol.card,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          outline: AppCol.secondary,
          tertiary: AppCol.accent,
        ),
        cardColor: AppCol.card,
        dividerColor: AppCol.secondary,
        iconTheme: const IconThemeData(color: AppCol.primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppCol.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppCol.primary
                  : AppCol.mutedFg),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppCol.primary.withValues(alpha: 0.4)
                  : AppCol.secondary),
        ),
        textTheme: const TextTheme(
          titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: AppCol.mutedFg),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: AppCol.mutedFg),
          labelLarge: TextStyle(
              color: AppCol.primary, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppCol.secondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppCol.secondary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppCol.secondary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppCol.primary, width: 2),
          ),
          labelStyle: const TextStyle(color: AppCol.mutedFg),
          hintStyle: const TextStyle(color: AppCol.mutedFg),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppCol.card,
          surfaceTintColor: Colors.transparent,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        colorScheme: ColorScheme.light(
          primary: AppCol.primary,
          secondary: AppCol.success,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppCol.primaryDark,
          outline: Colors.grey.shade200,
          tertiary: AppCol.accent,
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey.shade200,
        iconTheme: const IconThemeData(color: AppCol.primaryDark),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppCol.primaryDark,
          elevation: 0,
          iconTheme: IconThemeData(color: AppCol.primaryDark),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppCol.primary
                  : Colors.grey.shade400),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppCol.primary.withValues(alpha: 0.4)
                  : Colors.grey.shade300),
        ),
        textTheme: TextTheme(
          titleLarge: const TextStyle(
              color: AppCol.primaryDark, fontWeight: FontWeight.bold),
          titleMedium: const TextStyle(color: AppCol.primaryDark),
          titleSmall: TextStyle(color: Colors.grey.shade600),
          bodyLarge: const TextStyle(color: AppCol.primaryDark),
          bodyMedium: TextStyle(color: Colors.grey.shade600),
          labelLarge: const TextStyle(
              color: AppCol.primary, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppCol.primary, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${message.notification!.title}: ${message.notification!.body}'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Clean Core - A Smartends Solution',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const SplashScreen(),
        );
      },
    );
  }
}
