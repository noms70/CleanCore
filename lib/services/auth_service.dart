import 'package:cc/Supporting/google.dart'; // Your Google AuthMethods
import 'package:cc/models/user_model.dart';
import 'package:cc/services/firestore_service.dart'; // Import FirestoreService
import 'package:cc/utils/colors.dart'; // For showToast
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods(); // Your Google sign-in logic
  final FirestoreService _firestoreService =
  FirestoreService(); // Instantiate FirestoreService

  /// Stream to listen for auth state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get the current Firebase user.
  User? get currentUser => _firebaseAuth.currentUser;

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
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check for email verification
      // if (userCredential.user != null && !userCredential.user!.emailVerified) {
      //   await _firebaseAuth.signOut(); // Sign out unverified user
      //   return "Please verify your email address before logging in.";
      // }

      // Success
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthException(e);
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Creates a new user, saves to Firestore, sends verification, and signs out.
  /// Returns `null` on success, or an error [String] on failure.
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    // Domain restriction check
    if (!email.toLowerCase().endsWith('@smartends.com')) {
      return "Sign up is restricted to @smartends.com company emails only.";
    }

    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user == null) {
        throw Exception("User creation failed unexpectedly.");
      }

      final user = userCredential.user!;

      // 2. Create a UserModel
      final newUser = UserModel(
        uid: user.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profilePicture: '', // Default empty URL
        createdAt: Timestamp.now(),
      );

      // 3. Save user data to Firestore
      await _firestoreService.createUser(newUser);

      // 4. Send verification email
      // await user.sendEmailVerification();

      // 5. Sign out to force verification
      // await _firebaseAuth.signOut();

      // Success (verification email sent)
      return null;
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
      // Your AuthMethods handles the Google sign-in popup and @smartends.com check
      bool isLoggedIn = await _authMethods.signInWithGoogle(context);

      if (isLoggedIn && _firebaseAuth.currentUser != null) {
        final user = _firebaseAuth.currentUser!;

        // Check if user already exists in Firestore
        final firestoreUser = await _firestoreService.getUser(user.uid);

        if (firestoreUser == null) {
          // New Google sign-in user, save to Firestore
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            firstName: user.displayName?.split(' ')[0] ?? '',
            lastName: user.displayName?.split(' ').sublist(1).join(' ') ?? '',
            profilePicture: user.photoURL ?? '',
            createdAt: Timestamp.now(),
          );
          await _firestoreService.createUser(newUser);
        }
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
      // Also sign out from Google
      await _authMethods.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
