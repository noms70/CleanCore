import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cc/models/user_model.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  bool _isSuccess = false;
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

  /// Silently fetch device GPS, reverse-geocode to city, and persist on the user's Firestore document.
  Future<void> _saveLocationIfAvailable(String uid) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      String city = '';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          city = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? '';
        }
      } catch (_) {}

      await _firestoreService.updateUser(uid, {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'locationUpdatedAt': Timestamp.now(),
        if (city.isNotEmpty) 'assignedArea': city,
      });
    } catch (_) {
      // Location unavailable — not a blocking error
    }
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
    if (_isLoading || _isSuccess) return; // Don't check if manual check is in progress

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
        _timer?.cancel();

        // Always write the full document so partial docs (e.g. from FCM writes)
        // never leave a new user with missing fields.
        final existingUser = await _firestoreService.getUser(user.uid);
        if (existingUser == null) {
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

        // Silently capture device location for route dispatch accuracy
        await _saveLocationIfAvailable(user.uid);

        if (!mounted) return;
        _isSuccess = true;
        Navigator.pop(context, true);
      } else {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // Manual check with loading indicator and error messages
  Future<void> _checkVerificationManually() async {
    if (_isSuccess) return;
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
        _timer?.cancel();

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

        await _saveLocationIfAvailable(user.uid);

        if (!mounted) return;
        _isSuccess = true;
        Navigator.pop(context, true);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppCol.btntext),
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
              SizedBox(height: screenHeight * 0.03),
              
              // Email icon with pulse animation
              Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    duration: const Duration(seconds: 2),
                    builder: (context, double value, child) {
                      return Container(
                        padding: EdgeInsets.all(30 * value),
                        decoration: BoxDecoration(
                          color: AppCol.appbodye.withOpacity(0.15 / value),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                    onEnd: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppCol.appbodye.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      size: 70,
                      color: AppCol.appbodye,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: screenHeight * 0.05),
              
              Text(
                "Check your Inbox",
                style: TextStyle(
                  fontSize: screenWidth * 0.075,
                  fontWeight: FontWeight.w800,
                  color: AppCol.btntext,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: screenHeight * 0.015),
              
              Text(
                "We've sent a secure verification link to",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: screenHeight * 0.015),
              
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.015,
                ),
                decoration: BoxDecoration(
                  color: AppCol.appbodys,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppCol.appbodye.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.email,
                  style: TextStyle(
                    fontSize: screenWidth * 0.042,
                    fontWeight: FontWeight.w700,
                    color: AppCol.btntext,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: screenHeight * 0.05),
              
              // Auto-checking indicator
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: AppCol.appbodye.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppCol.appbodye.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppCol.appbodye),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Waiting for verification...",
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w600,
                              color: AppCol.btntext,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Auto-checking in $_countdown seconds",
                            style: TextStyle(
                              fontSize: screenWidth * 0.034,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.03),
              
              // Instructions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppCol.appbodye, size: 22),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Text(
                      "Click the link in your email. This page will automatically take you to the app once verified.",
                      style: TextStyle(
                        fontSize: screenWidth * 0.036,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: screenHeight * 0.06),
              
              // Manual verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerificationManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCol.btntext,
                    foregroundColor: AppCol.white,
                    elevation: 4,
                    shadowColor: AppCol.btntext.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.022,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: AppCol.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'I have verified my email',
                          style: TextStyle(
                            fontSize: screenWidth * 0.042,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: screenHeight * 0.03),
              
              // Resend email button
              TextButton(
                onPressed: _isLoading ? null : _resendEmail,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  "Didn't receive it? Resend Email",
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    color: AppCol.appbodye,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                "Be sure to check your spam or junk folder.",
                style: TextStyle(
                  fontSize: screenWidth * 0.032,
                  color: Colors.grey[500],
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