import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // NEW: Wrap the Container with ClipRRect
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
      child: ClipRRect(
        // NEW: Define the border radius here
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40.0), // Adjust the radius as you like
          topRight: Radius.circular(40.0), // Adjust the radius as you like
          bottomLeft: Radius.circular(40.0), // Adjust the radius as you like
          bottomRight: Radius.circular(40.0), // Adjust the radius as you like
        ),
        // Set the desired height of the navbar
        child: Container(
          decoration: BoxDecoration(
            color: AppCol.btnbacks,
            // gradient: LinearGradient(
            //   colors: [AppCol.btnbacks, AppCol.btnbacke],
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ),
            // boxShadow: [
            //   BoxShadow(
            //     color: AppCol.btnbacks.withOpacity(0.3),
            //     blurRadius: 8,
            //     offset: const Offset(0, -2),
            //   ),
            // ],
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: currentPage == 'home' ? 0 : 1,
            selectedItemColor: AppCol.btnbacke,
            unselectedItemColor: AppCol.btnbacke.withOpacity(0.4),
            onTap: (index) {
              if (index == 0) {
                onNavigate('home');
              } else {
                onNavigate('settings');
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
