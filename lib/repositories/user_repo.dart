import 'dart:io';
import 'package:cc/models/user_model.dart';
import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A repository to manage user data, combining auth and database services.
/// The UI will interact with this class.
class UserRepository extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  UserRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService {
    // Listen to auth changes to automatically fetch user data
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  /// Called when the auth state changes (login/logout).
  void _onAuthStateChanged(User? user) async {
    _setLoading(true);
    if (user != null) {
      // User is logged in, fetch their Firestore data
      _currentUser = await _firestoreService.getUser(user.uid);
    } else {
      // User is logged out
      _currentUser = null;
    }
    _setLoading(false);
  }

  /// Fetches the user data for the currently logged-in user.
  /// This is often used on app startup.
  Future<void> fetchCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null && _currentUser == null) {
      _setLoading(true);
      _currentUser = await _firestoreService.getUser(user.uid);
      _setLoading(false);
    }
  }

  /// Updates the user's profile data.
  Future<void> updateUserProfile(
      String firstName, String lastName, String phone) async {
    if (_currentUser == null) return;

    _setLoading(true);
    final dataToUpdate = {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone, // Assuming you add 'phone' to your UserModel
    };

    try {
      await _firestoreService.updateUser(_currentUser!.uid, dataToUpdate);
      // Refresh local user model
      _currentUser = await _firestoreService.getUser(_currentUser!.uid);
    } catch (e) {
      // Re-throw to be caught by the UI
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the user's profile picture.
  Future<void> updateUserProfilePicture(File imageFile) async {
    if (_currentUser == null) return;

    _setLoading(true);
    try {
      await _firestoreService.uploadProfilePicture(
          _currentUser!.uid, imageFile);
      // Refresh local user model
      _currentUser = await _firestoreService.getUser(_currentUser!.uid);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs the user out.
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // --- Helper for loading state ---
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}