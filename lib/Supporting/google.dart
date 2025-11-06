import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:flutter/services.dart';

// Imported showToast from utils for error messages
import 'package:cc/utils/colors.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use a more basic configuration first
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Signs in the user using Google Authentication with a domain restriction.
  Future<bool> signInWithGoogle(BuildContext context) async {
    try {
      print("Starting Google sign-in process");

      // Check for network connectivity
      if (!await _isConnectedToInternet()) {
        showToast('No internet connection. Please try again.', isError: true);
        return false;
      }

      // Force sign out first to ensure a clean state
      try {
        await _googleSignIn.signOut();
        print("Successfully signed out of Google");
      } catch (e) {
        print("Error signing out of Google: $e");
        // Continue anyway, as this is just a precaution
      }

      // Try the direct Firebase approach first
      try {
        print("Attempting direct Firebase Google sign-in");

        // This uses Firebase's built-in Google provider
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // Add scopes explicitly for better control (optional, but good practice)
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        // Use the native platform sign-in flow (signInWithPopup for web/desktop, signInWithCredential for mobile)
        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );

        // --- CRITICAL DOMAIN RESTRICTION CHECK ---
        final email = userCredential.user?.email ?? '';

        if (!email.toLowerCase().endsWith('@smartends.com')) {
          // 1. Sign out of Firebase and Google immediately
          await _auth.signOut();
          await _googleSignIn.signOut();

          // 2. Inform the user and block login using showToast
          showToast(
            "Access Restricted. Only @smartends.com company emails are allowed.",
            isError: true,
          );
          return false;
        }
        // ------------------------------------------

        // If the email passes the domain check, proceed with data storage
        if (userCredential.user != null) {
          await _storeUserData(userCredential.user!);
        }

        // Return true if successful and allowed
        return true;
      } on PlatformException catch (e) {
        if (e.code == 'network_request_failed') {
          showToast('Network error during Google sign-in.', isError: true);
        } else {
          showToast('Google Sign-in failed: ${e.message}', isError: true);
        }
        return false;
      } on FirebaseAuthException catch (e) {
        // Handle common auth errors
        if (e.code == 'account-exists-with-different-credential') {
          showToast(
            'An account already exists with the same email address but different sign-in credentials.',
            isError: true,
          );
        } else if (e.code == 'operation-not-allowed') {
          showToast(
            'Google Sign-in is not enabled in Firebase project.',
            isError: true,
          );
        } else if (e.code == 'popup-blocked' || e.code == 'cancelled-by-user') {
          print('Sign-in process cancelled or blocked.');
          // No need to show a toast for user cancellation
        } else {
          showToast('Firebase Auth Error: ${e.message}', isError: true);
        }
        return false;
      } catch (e) {
        showToast(
          "An unexpected error occurred during Google Sign-in: $e",
          isError: true,
        );
        return false;
      }
    } on Exception catch (e) {
      print("General error in signInWithGoogle: $e");
      // Fallback in case of an issue with the initial check/setup
      showToast("A general error occurred: $e", isError: true);
      return false;
    }
  }

  /// Helper to check for internet connectivity.
  Future<bool> _isConnectedToInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Stores user data in Firestore upon successful registration/login.
  Future<void> _storeUserData(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // Split display name into first and last name
        String firstName = user.displayName?.split(' ').first ?? 'User';
        String lastName = '';
        if (user.displayName != null &&
            user.displayName!.split(' ').length > 1) {
          lastName = user.displayName!.split(' ').skip(1).join(' ');
        }

        final userData = {
          'uid': user.uid,
          'firstName': firstName,
          'lastName': lastName,
          'email': user.email ?? 'No Email',
          'profilePicture': user.photoURL ?? '',
          'phoneNumber': user.phoneNumber ?? '',
          'tokens': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await userDoc.set(userData);
        print("User data saved to Firestore");
      } else {
        print("User already exists in Firestore");
      }
    } catch (e) {
      print("Error storing user data: $e");
    }
  }
}
