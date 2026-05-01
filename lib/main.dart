import 'package:cc/views/splash.dart';
import 'package:cc/utils/colors.dart'; // For AppCol
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
  
  // SFR-017: FCM Initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Listen to auth changes to update FCM token
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fcmToken': token}, SetOptions(merge: true)
        );
      }
      
      // Handle token refresh
      messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fcmToken': newToken}, SetOptions(merge: true)
        );
      });
    }
  });

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${message.notification!.title}: ${message.notification!.body}'),
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Clean Core - A Smartends Solution',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppCol.btnbacks,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppCol.btnbacks),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

