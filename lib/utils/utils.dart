import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
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
  static const Color btntext = Color(0xFF3D003E);
  static const Color ngt = Colors.green;  //normal green text
  static const Color btnbacks = Color(0xFF4CAF50);  //button first color
  static const Color btnbacke = Color(0xFF009688);  //button second color
  static const Color loginBack = Color(0xFF212121);  //button second color
  static const Color headers = Color(0xFFFAF3FB);



  static const Color backbtn = Color(0xFFFAF3FB);
  static const Color appbg = Colors.teal;
  static const LinearGradient headerback = LinearGradient(
    colors: [Color(0xFFF5F0F8), Color(0xFFB9FBFB), Colors.teal],
    stops: [0.18, 0.5, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient drawerback = LinearGradient(
      colors: [AppCol.appbodys, AppCol.appbodye],
      stops: [0.06, 0.23], // First color takes up 2%, second color starts immediately after
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
  );
  static const LinearGradient main = LinearGradient(
    colors: [
      AppCol.appbodys,
      AppCol.appbodye,  // Example additional color
      AppCol.appbodye2,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient btncol = LinearGradient(
    colors: [
     Color(0xFF2AF5AE),
     Color(0xFF048A7E),  // Example additional color
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );


  // static const LinearGradient appback = LinearGradient(
  //   colors: [AppCol.appbodys, AppCol.appbodye],
  //   stops: [0.1, 0.7],
  //   begin: Alignment.topCenter,
  //   end: Alignment.bottomCenter,
  // );

}

void showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: isError ? Colors.red : Colors.green,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
