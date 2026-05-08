import 'package:cc/Supporting/google.dart';
import 'package:cc/models/user_model.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods();
  final FirestoreService _firestoreService = FirestoreService();

  /// Stream to listen for auth state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get the current Firebase user.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Silently get the city name from the device's current GPS position.
  Future<String> _getCityFromLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return '';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return '';

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        return placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? '';
      }
    } catch (_) {}
    return '';
  }

  // Helper to return user-friendly error messages
  String _handleAuthException(FirebaseAuthException e) {
    return {
      'user-not-found': "No user found with this email.",
      'wrong-password': "Incorrect password.",
      'email-already-in-use': "This email is already in use.",
      'weak-password': "Your password is too weak.",
    }[e.code] ??
        "An error occurred: ${e.message}";
  }

  /// Signs in with email and password.
  /// Returns `null` on success, or an error [String] on failure.
  Future<String?> signInWithEmail(String email, String password) async {
    if (!email.toLowerCase().endsWith('@gmail.com')) {
      return "Only Gmail accounts are allowed.";
    }

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      // Check for email verification
      if (user != null && !user.emailVerified) {
        await _firebaseAuth.signOut();
        return "Please verify your email address before logging in.";
      }

      // Backfill assignedArea from GPS city if it was never set (fire-and-forget)
      if (user != null) _backfillAssignedAreaIfEmpty(user.uid);

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// If the user's assignedArea is empty, silently populate it from GPS city.
  void _backfillAssignedAreaIfEmpty(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final area = (doc.data()?['assignedArea'] as String? ?? '').trim();
      if (area.isNotEmpty) return;

      final city = await _getCityFromLocation();
      if (city.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'assignedArea': city});
    } catch (_) {}
  }

  /// Creates a new user and sends verification email.
  /// Does NOT create Firestore document - that happens after verification.
  /// Returns `null` on success, or an error [String] on failure.
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception("User creation failed unexpectedly.");
      }

      final user = userCredential.user!;

      // 2. Send verification email
      await user.sendEmailVerification();

      // 3. Sign out immediately - user must verify before accessing app
      await _firebaseAuth.signOut();

      // Note: Firestore document creation happens in VerificationPage
      // after email is verified

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Signs in with Google and saves user data to Firestore if new.
  /// Returns `null` on success, or an error [String] on failure.
Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      UserCredential userCredential;

      
        // Mobile sign-in
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return "Sign-in cancelled";

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await _firebaseAuth.signInWithCredential(credential);
      

      final user = userCredential.user;
      if (user == null) return "Google sign-in failed";

      // Check if user exists in Firestore
      final firestoreUser = await _firestoreService.getUser(user.uid);

      if (firestoreUser == null) {
        // New user: fetch city from device location before saving to Firestore
        final city = await _getCityFromLocation();
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          firstName: user.displayName?.split(' ')[0] ?? '',
          lastName: user.displayName?.split(' ').sublist(1).join(' ') ?? '',
          profilePicture: user.photoURL ?? '',
          createdAt: Timestamp.now(),
          assignedArea: city,
        );

        await _firestoreService.createUser(newUser);
      }

      return null; // Success
    } catch (e) {
      showToast(
        'An unexpected error occurred during Google sign-in: $e',
        isError: true,
      );
      return 'An unexpected error occurred.';
    }
  }

  /// Sends a password reset email.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _authMethods.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  /// Deletes the currently signed-in Firebase user account.
  /// Returns null on success, or an error String on failure.
  Future<String?> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return "No active user found to delete.";
    }

    try {
      await user.delete();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Security Error: Please sign out and sign in again to confirm account deletion.';
      }
      return _handleAuthException(e);
    } catch (e) {
      return 'An unexpected error occurred during account deletion.';
    }
  }
}