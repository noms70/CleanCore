import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cc/models/user_model.dart'; // Import your new user model

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection('users');

  /// Creates a new user document in Firestore after registration.
  Future<void> createUser(UserModel user) async {
    try {
      // Use the user's UID as the document ID
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      print("Error creating user document: $e");
      // Re-throw the error to be handled by the AuthService
      throw Exception("Failed to save user data. Please try again.");
    }
  }

  /// Fetches a user document from Firestore by their UID.
  Future<UserModel?> getUser(String uid) async {
    try {
      final docSnap = await _usersCollection.doc(uid).get();
      if (docSnap.exists) {
        return UserModel.fromDocument(docSnap);
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }

  /// Updates user data in Firestore.
  /// 'data' is a Map of fields to update, e.g., {'firstName': 'John'}
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      print("Error updating user: $e");
      throw Exception("Failed to update profile.");
    }
  }

  /// Encodes an image to base64 and saves it to Firestore.
  Future<void> uploadProfilePicture(String uid, File imageFile) async {
    try {
      // 1. Read image bytes
      final imageBytes = await imageFile.readAsBytes();

      // 2. Encode to base64
      final base64Image = base64Url.encode(imageBytes);

      // 3. Update user document
      await updateUser(uid, {'profilePicture': base64Image});

    } catch (e) {
      print("Error uploading profile picture: $e");
      throw Exception("Failed to upload image.");
    }
  }

  Future<void> deleteUserDocument(String uid) async {
  try {
    await _usersCollection.doc(uid).delete();
  } catch (e) {
    print("Error deleting user document: $e");
    throw Exception("Failed to delete user data.");
  }
}
}