import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String? phoneNumber;
  /// Role values match the backend exactly: 'worker', 'admin', 'manager'
  final String role;
  final String status; // 'active' | 'inactive'
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    this.phoneNumber,
    this.role = 'worker',
    this.status = 'active',
    required this.createdAt,
  });

  bool get isWorker => role == 'worker';
  bool get isAdmin => role == 'admin' || role == 'manager';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'phoneNumber': phoneNumber,
      'role': role,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      profilePicture: data['profilePicture'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      role: data['role'] as String? ?? 'worker',
      status: data['status'] as String? ?? 'active',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
