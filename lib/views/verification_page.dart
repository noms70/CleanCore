import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cc/models/user_model.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/utils/colors.dart';
import 'home_page.dart';
import 'dart:async';

class VerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const VerificationPage({
    super.key,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  bool _isLoading = false;
  bool _isCheckingAutomatically = true;
  Timer? _timer;
  final FirestoreService _firestoreService = FirestoreService();
  int _countdown = 3; // Start checking after 3 seconds

  @override
  void initState() {
    super.initState();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Auto-check verification status every 3 seconds
  void _startAutoCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Update countdown
      setState(() {
        _countdown = 3 - (timer.tick % 3);
      });

      // Check verification every 3 seconds
      if (timer.tick % 3 == 0) {
        await _checkVerificationSilently();
      }
    });
  }

  // Silent check that doesn't show loading or errors
  Future<void> _checkVerificationSilently() async {
    if (_isLoading) return; // Don't check if manual check is in progress

    try {
      // Sign in with the credentials to check verification status
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      // Reload user to get the latest verification status
      await userCredential.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Email is verified! Stop the timer
        _timer?.cancel();
        
        // Create Firestore document
        final firestoreUser = await _firestoreService.getUser(user.uid);
        
        if (firestoreUser == null) {
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            firstName: widget.firstName,
            lastName: widget.lastName,
            profilePicture: '',
            createdAt: Timestamp.now(),
          );
          await _firestoreService.createUser(newUser);
        }

        if (!mounted) return;

        // Show success message
        showToast("Email verified successfully! Welcome aboard.", isError: false);

        // Navigate to HomePage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        // Not verified yet, sign out and continue checking
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      // Silent failure - user might not be ready yet
      await FirebaseAuth.instance.signOut();
    }
  }

  // Manual check with loading indicator and error messages
  Future<void> _checkVerificationManually() async {
    setState(() => _isLoading = true);

    try {
      // Sign in with the credentials to check verification status
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      // Reload user to get the latest verification status
      await userCredential.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Stop auto-checking
        _timer?.cancel();
        
        // Create Firestore document
        final firestoreUser = await _firestoreService.getUser(user.uid);
        
        if (firestoreUser == null) {
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            firstName: widget.firstName,
            lastName: widget.lastName,
            profilePicture: '',
            createdAt: Timestamp.now(),
          );
          await _firestoreService.createUser(newUser);
        }

        if (!mounted) return;

        showToast("Email verified successfully! Welcome aboard.", isError: false);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        // Email not verified yet
        await FirebaseAuth.instance.signOut();
        
        if (!mounted) return;
        
        showToast(
          "Email not verified yet. Please check your inbox and click the verification link.",
          isError: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      if (e.code == 'wrong-password') {
        showToast("Authentication error. Please try signing up again.", isError: true);
      } else if (e.code == 'too-many-requests') {
        showToast("Too many attempts. Please wait a moment and try again.", isError: true);
      } else {
        showToast("Error: ${e.message}", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      showToast("An unexpected error occurred: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isLoading = true);

    try {
      // Sign in temporarily to resend email
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      await userCredential.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      
      showToast("Verification email sent again! Please check your inbox.", isError: false);
    } catch (e) {
      if (!mounted) return;
      showToast("Failed to resend email: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppCol.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppCol.primary),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context, false);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.05),
              
              // Email icon with gradient background and pulse animation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse animation
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    duration: const Duration(seconds: 2),
                    builder: (context, double value, child) {
                      return Container(
                        padding: EdgeInsets.all(30 * value),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppCol.btnbacks.withOpacity(0.1 / value),
                              AppCol.btnbacke.withOpacity(0.1 / value)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                    onEnd: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppCol.btnbacks.withOpacity(0.1), AppCol.btnbacke.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 80,
                      color: AppCol.primary,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: screenHeight * 0.04),
              
              // Title
              Text(
                "Verify Your Email",
                style: TextStyle(
                  fontSize: screenWidth * 0.07,
                  fontWeight: FontWeight.bold,
                  color: AppCol.primary,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Description
              Text(
                "We've sent a verification email to:",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: screenHeight * 0.01),
              
              // Email display
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.015,
                ),
                decoration: BoxDecoration(
                  color: AppCol.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppCol.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.email,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                    color: AppCol.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: screenHeight * 0.03),
              
              // Auto-checking indicator
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Text(
                        "Checking verification status automatically...\nNext check in $_countdown seconds",
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.green[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Text(
                        "Click the verification link in your email. This page will automatically detect when you've verified and take you to the app!",
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.blue[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.04),
              
              // Manual verify button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppCol.btnbacks, AppCol.btnbacke],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppCol.btnbacks.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerificationManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppCol.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppCol.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'I Have Verified My Email',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Resend email button
              TextButton.icon(
                onPressed: _isLoading ? null : _resendEmail,
                icon: Icon(Icons.refresh, color: AppCol.primary),
                label: Text(
                  "Didn't receive the email? Resend",
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    color: AppCol.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Help text
              Text(
                "Check your spam folder if you don't see the email",
                style: TextStyle(
                  fontSize: screenWidth * 0.032,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}