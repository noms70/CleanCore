import 'package:flutter/material.dart';
import 'package:cc/utils/colors.dart'; // For showToast

// Define the arguments needed for the page
class VerificationPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // NOTE: This is a simplified placeholder. In a real app, this screen would
    // send a verification email and constantly check Firebase if the email is verified.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: AppCol.btnbacks,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                'A verification email has been sent to $email.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppCol.btnbacks,
                  foregroundColor: AppCol.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                onPressed: () {
                  // Simulate successful verification.
                  // In a real app, this would check FirebaseAuth.currentUser.emailVerified
                  showToast(
                    "Simulating successful verification...",
                    isError: false,
                  );
                  // Return true to the calling function (_authenticate) in login.dart
                  Navigator.pop(context, true);
                },
                child: const Text(
                  'I Have Verified My Email',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
