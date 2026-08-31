import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBuild {
  PreferredSizeWidget buildAppBar({
    required String title,
    final double titleSize = 0.0,
    IconData? icon,
    String? image,
    List<Widget>? actions,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(105),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth  = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isDark       = Theme.of(context).brightness == Brightness.dark;

          final double paddingLeft = screenWidth * 0.08;
          final double iconSize    = screenWidth * 0.13;
          final double fontSize    = screenWidth * 0.062;

          final gradient = isDark
              ? AppCol.headerDark
              : const LinearGradient(
                  colors: [AppCol.primary, AppCol.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                );
          final textColor = Colors.white;
          final iconColor = isDark ? AppCol.primary : Colors.white;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
            child: AppBar(
              automaticallyImplyLeading: true,
              iconTheme: IconThemeData(color: textColor),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: actions,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  // Subtle bottom border in primary color for dark mode polish
                  border: isDark
                      ? const Border(
                          bottom: BorderSide(color: AppCol.secondary, width: 1),
                        )
                      : null,
                ),
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
                            bottom: screenHeight * 0.025,
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: titleSize == 0 ? fontSize : titleSize,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Montserrat',
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.only(
                            right: screenWidth * 0.04,
                            bottom: screenHeight * 0.012,
                          ),
                          child: icon != null
                              ? Icon(icon, size: iconSize, color: iconColor)
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
