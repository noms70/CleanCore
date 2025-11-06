import 'package:cc/Supporting/google.dart'; // Your Google AuthMethods
import 'package:cc/utils/colors.dart'; // For showToast
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods(); // Your Google sign-in logic

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
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check for email verification
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await _firebaseAuth.signOut(); // Sign out unverified user
        return "Please verify your email address before logging in.";
      }

      // Success
      // You could fetch user data from Firestore here if needed
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Creates a new user, sends verification email, and signs out.
  /// Returns `null` on success, or an error [String] on failure.
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    // String? phone, // You can add this
  }) async {
    // Domain restriction check
    if (!email.toLowerCase().endsWith('@smartends.com')) {
      return "Sign up is restricted to @smartends.com company emails only.";
    }

    try {
      // 1. Create user
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      // 2. Send verification email
      await userCredential.user!.sendEmailVerification();

      // 3. TODO: Save user data (firstName, lastName) to Firestore
      // Example:
      // await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      //   'firstName': firstName,
      //   'lastName': lastName,
      //   'email': email,
      //   'phone': phone,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });

      // 4. Sign out to force verification
      await _firebaseAuth.signOut();

      // Success (verification email sent)
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Signs in with Google.
  /// Returns `null` on success, or an error [String] on failure.
  Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      // Your AuthMethods handles the @smartends.com check
      bool isLoggedIn = await _authMethods.signInWithGoogle(context);

      if (isLoggedIn) {
        return null; // Success
      } else {
        // AuthMethods already shows a toast, but we return a message
        // to prevent the UI from proceeding.
        return ""; // Empty string means failure but toast was already shown
      }
    } catch (e) {
      showToast(
        'An unexpected error occurred during Google sign-in: $e',
        isError: true,
      );
      return 'An unexpected error occurred.';
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}