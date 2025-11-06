import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/views/home_page.dart'; // Make sure this file exists
import 'package:cc/utils/colors.dart'; // For AppCol
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// You MUST have this file. Generate it using the FlutterFire CLI:
// `flutterfire configure`
import 'firebase_options.dart';

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
      home:  HomePage(), // This widget handles auth logic
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to the auth state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. While checking, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If user IS logged in (and verified, based on our service logic)
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage(); // Go to your app's home page
        }

        // 3. If user is NOT logged in
        return const AuthLandingScreen(); // Show the login/signup screen
      },
    );
  }
}
