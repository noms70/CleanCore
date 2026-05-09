import 'package:cc/utils/colors.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/views/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    // Stagger: slide starts 150ms after fade
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), _slideCtrl.forward);

    Future.delayed(const Duration(seconds: 3), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            (user != null && user.emailVerified) ? const HomePage() : AuthLandingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppCol.primaryDark, AppCol.card, AppCol.primaryDark],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative teal circle (top-right) ──────────────────────────
            Positioned(
              top: -size.width * 0.3,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppCol.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            // ── Decorative teal circle (bottom-left) ─────────────────────────
            Positioned(
              bottom: -size.width * 0.25,
              left: -size.width * 0.15,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppCol.primary.withValues(alpha: 0.06),
                ),
              ),
            ),

            // ── Centre content ───────────────────────────────────────────────
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing teal backdrop behind the logo
                      Container(
                        padding: EdgeInsets.all(size.width * 0.07),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppCol.primary.withValues(alpha: 0.10),
                          boxShadow: [
                            BoxShadow(
                              color: AppCol.primary.withValues(alpha: 0.25),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/app_logo_2.png',
                          width: size.width * 0.36,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: size.height * 0.04),

                      // Brand name
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Clean',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: 'Core',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppCol.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: size.height * 0.012),

                      // Tagline
                      Text(
                        'Smart Waste Collection',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 2.0,
                        ),
                      ),

                      SizedBox(height: size.height * 0.015),

                      // Thin teal divider line
                      Container(
                        width: size.width * 0.12,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppCol.primary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── "A Smartends Solution" footer ────────────────────────────────
            Positioned(
              bottom: size.height * 0.05,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  'A Smartends Solution',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
