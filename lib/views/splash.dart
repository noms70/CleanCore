import 'package:cc/views/auth/auth_landing_screen.dart'; // MODIFIED: Point to auth screen
import 'package:cc/utils/colors.dart';
import 'package:cc/views/home_page.dart';
import 'package:flutter/material.dart';

// REMOVED: home_page.dart, login_view.dart, and firebase_auth.dart imports

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // REMOVED: _isLoggedIn state variable

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFadeAnimation();
    _fadeController?.forward(); // Start animation immediately

    // Navigate to AuthLandingScreen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  // REMOVED: _checkLoginStatus() function

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
          // MODIFIED: Always center the content
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // REMOVED: Conditional spacer

            // MODIFIED: Unconditional FadeTransition for the logo
            if (_fadeAnimation != null)
              FadeTransition(
                opacity: _fadeAnimation!,
                child: Image.asset(
                  'assets/cc_logo2.png',
                 // height: isPortrait ? screenHeight * 0.3 : screenHeight * 0.3,
                  width: isPortrait ? screenWidth * 0.6 : screenWidth * 0.7,
                  fit: BoxFit.contain,
                ),
              ),

            const SizedBox(height: 10),

            Text(
              'Eco-Friendly Solutions for you!',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: isPortrait
                    ? screenHeight * 0.017
                    : screenHeight * 0.03,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            // REMOVED: The "Already have an account? Login" TextButton
          ],
        ),
      ),
    );
  }
}
