import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/views/home_page.dart';
import 'package:cc/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';



class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFadeAnimation();
    _fadeController?.forward(); // Start animation immediately

    // After 3 seconds check existing session; skip login if already authenticated.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

 

  void _initializeFadeAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = screenHeight > screenWidth;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppCol.main),
        child: Column(
          
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            if (_fadeAnimation != null)
              FadeTransition(
                opacity: _fadeAnimation!,
                child: Image.asset(
                  'assets/cc_logo.png',
                  
                  width: isPortrait ? screenWidth * 0.6 : screenWidth * 0.7,
                  fit: BoxFit.contain,
                ),
              ),

            const SizedBox(height: 10),

            Text(
              'A Smartends Solution',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: isPortrait
                    ? screenHeight * 0.017
                    : screenHeight * 0.03,
                color: Colors.white,
                fontWeight: FontWeight.bold, 
              ),
              textAlign: TextAlign.center,
            ),

            
          ],
        ),
      ),
    );
  }
}
