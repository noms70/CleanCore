import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cc/services/auth_service.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';

/// SFR-005: Session Management — Inactivity Timeout
///
/// Wrap any authenticated screen tree with this widget. It listens for
/// pointer (touch / mouse) events and resets a timer. When the timer
/// fires (default 30 minutes), the user is signed out and redirected
/// to the auth landing screen.
class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final int timeoutMinutes;

  const InactivityWrapper({
    super.key,
    required this.child,
    this.timeoutMinutes = 30,
  });

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper>
    with WidgetsBindingObserver {
  Timer? _timer;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when the app goes to background / foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — restart the timer
      _resetTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(
      Duration(minutes: widget.timeoutMinutes),
      _onInactivityTimeout,
    );
  }

  Future<void> _onInactivityTimeout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // already signed out

    debugPrint('[Session] Inactivity timeout — signing out.');
    await _authService.signOut();

    if (!mounted) return;

    // Navigate to auth screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
      (Route<dynamic> route) => false,
    );

    // Show a friendly message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You were signed out due to inactivity.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listener resets the timer on every pointer event (tap, drag, scroll)
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
