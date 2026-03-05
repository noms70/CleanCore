import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBuild {
  PreferredSizeWidget buildAppBar({
    required String title,
    final double titleSize = 0.0,
    IconData? icon, // Use IconData for icons
    String? image, // Use a string path for images
    List<Widget>? actions, // ✅ Add actions here
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(125),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = MediaQuery.of(context).size.width;
          double screenHeight = MediaQuery.of(context).size.height;

          double paddingLeft = screenWidth * 0.08;
          double iconSize = screenWidth * 0.15;
          double fontSize = screenWidth * 0.065;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
            child: AppBar(
              automaticallyImplyLeading: true,
              iconTheme: IconThemeData(color: AppCol.btntext),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: actions, // ✅ Set actions here
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: AppCol.headerback),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: paddingLeft,
                            bottom: screenHeight * 0.03,
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: titleSize == 0 ? fontSize : titleSize,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Montserrat',
                              color: AppCol.btntext.withOpacity(0.95),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.only(right: screenWidth * 0.04, bottom: screenHeight * 0.015),
                          child: icon != null
                              ? Icon(
                                  icon,
                                  size: iconSize,
                                  color: AppCol.btntext,
                                )
                              : image != null
                              ? Image.asset(
                                  image,
                                  height: iconSize * 1.1,
                                  width: iconSize * 2,
                                  fit: BoxFit.contain,
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
