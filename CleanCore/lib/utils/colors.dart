import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class AppCol {
  // ── Core brand palette (mirrors Admin Panel CSS variables) ───────────────
  static const Color primary     = Color(0xFF0BBFC9); // --primary  (teal)
  static const Color primaryDark = Color(0xFF080E26); // --background (dark navy)
  static const Color card        = Color(0xFF111A35); // --card
  static const Color secondary   = Color(0xFF1A2240); // --secondary
  static const Color accent      = Color(0xFF00E0E0); // --accent
  static const Color success     = Color(0xFF1DD1A1); // --success
  static const Color mutedFg     = Color(0xFF9CA3B3); // --muted-foreground

  // ── Legacy aliases (preserve existing references) ────────────────────────
  static const Color btnbacks  = primary;
  static const Color btnbacke  = primaryDark;
  static const Color btntext   = primaryDark;
  static const Color ngt       = primary;
  static const Color white     = Color(0xFFFFFFFF);
  static const Color textGrey  = Colors.grey;
  static const Color loginBack = Color(0xFF212121);
  static const Color headers   = Color(0xFFF5F7FA);
  static const Color headere   = Color(0xFFB9FBFB);
  static const Color appbg     = primary;

  // Kept for any auth-screen references
  static const Color appbodys  = Color(0xFFF5F0F8);
  static const Color appbodye  = Color(0xFF05978A);
  static const Color appbodye2 = Color(0xFF15495C);
  static const Color appbodys2 = Color(0xFF2AF598);
  static const Color tgs       = Color(0xFF83FF00);
  static const Color tge       = Color(0xFF3EC392);
  static const Color forgetCol = Color(0xFF4CAF50);
  static const Color forgetTxt = Color(0xFFD6D6D6);
  static Color dialogbg        = const Color(0xFF1C5D5C);
  static const Color skipButton  = Colors.blue;
  static const Color activeDot   = Colors.blue;
  static const Color inactiveDot = Colors.grey;

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Splash / loading gradient — teal → dark navy (matches Admin Panel vibe)
  static const LinearGradient main = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Button gradient
  static const LinearGradient btncol = LinearGradient(
    colors: [accent, Color(0xFF048A7E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// AppBar gradient used in LIGHT mode
  static const LinearGradient headerback = LinearGradient(
    colors: [Color(0xFFF5F0F8), primary, primaryDark],
    stops: [0.18, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// AppBar gradient used in DARK mode
  static const LinearGradient headerDark = LinearGradient(
    colors: [primaryDark, card],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient drawerback = LinearGradient(
    colors: [Color(0xFFF5F0F8), Color(0xFF05978A)],
    stops: [0.06, 0.23],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

void showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 3,
    backgroundColor: isError ? Colors.red.shade900 : AppCol.primary,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
