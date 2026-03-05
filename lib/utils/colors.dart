import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

// Class defining the application's color palette and gradients
class AppCol {
  static const Color appbodys = Color(0xFFF5F0F8);
  static const Color appbodye = Color(0xFF05978A);
  static const Color appbodye2 = Color(0xFF15495C);
  static const Color appbodys2 = Color(0xff2AF598);

  static const Color tgs = Color(0xFF83FF00);
  static const Color tge = Color(0xFF3EC392);
  static const Color forgetCol = Color(0xFF4CAF50);
  static const Color forgetTxt = Color(0xFFD6D6D6);
  static Color dialogbg = const Color(0xFF1C5D5C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color skipButton = Colors.blue;
  static const Color activeDot = Colors.blue;
  static const Color inactiveDot = Colors.grey;
  static const Color textGrey = Colors.grey;
  static const Color btntext = Color(0xFF0A0E27);
  static const Color ngt = Color(0xFF00D9D9); // normal green text
  static const Color btnbacks = Color(0xFF00D9D9); // button first color
  static const Color btnbacke = Color(0xFF0A0E27); // button second color
  static const Color loginBack = Color(0xFF212121); // button second color
  static const Color headers = Color(0xFFFAF3FB); // header section start color
  static const Color headere = Color(0xFFB9FBFB); // header section end color

  static const Color appbg = Colors.teal;

  // Modern surface colors for cards and elevated elements
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardSurfaceLight = Color(0xFFFCF5FD);
  static const Color backgroundLight = Color(0xFFF8F9FA);

  // Enhanced accent colors
  static const Color accentPrimary = Color(0xFF00D9D9);
  static const Color accentSecondary = Color(0xFF2AF598);
  static const Color accentDark = Color(0xFF048A7E);

  static const LinearGradient headerback = LinearGradient(
    colors: [Color(0xFFF5F0F8), AppCol.btnbacks, Color(0xFF141C40)],
    stops: [0.18, 0.5, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient drawerback = LinearGradient(
    colors: [AppCol.appbodys, AppCol.appbodye],
    stops: [0.06, 0.23],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient main = LinearGradient(
    colors: [AppCol.btnbacks, AppCol.btnbacke],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient btncol = LinearGradient(
    colors: [Color(0xFF2AF5AE), Color(0xFF048A7E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Modern card gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF00E5E5), Color(0xFF00A8A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shimmer gradient for loading states
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );
}

// Global utility function to display toast messages
void showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 3,
    backgroundColor: isError ? Colors.red.shade900 : Color(0xFF00D9D9),
    textColor: Color(0xFF0A0E27),
    fontSize: 16.0,
  );
}
