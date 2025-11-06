import 'package:cc/views/splash.dart';
import 'package:cc/utils/colors.dart'; // For AppCol
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// You MUST have this file. Generate it using the FlutterFire CLI:
// `flutterfire configure`
import 'firebase_options.dart';

// Note: AuthWrapper was moved to its own file: auth_wrapper.dart

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartEnds App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppCol.btnbacks,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppCol.btnbacks),
        useMaterial3: true,
      ),
      // --- 2. MODIFICATION ---
      // Start with the SplashScreen, which will then navigate to the AuthWrapper
      home: const SplashScreen(),
      // --- END MODIFICATION ---
    );
  }
}
