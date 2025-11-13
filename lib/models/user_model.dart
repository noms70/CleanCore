import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String? phoneNumber; // Optional
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    this.phoneNumber,
    required this.createdAt,
  });

  /// Helper function to convert a UserModel instance into a Map (for writing to Firestore).
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
    };
  }

  /// Helper function to create a UserModel instance from a Firestore DocumentSnapshot.
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      profilePicture: data['profilePicture'] ?? '',
      phoneNumber: data['phoneNumber'], // Can be null
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
