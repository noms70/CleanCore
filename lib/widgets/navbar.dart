import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 15.0, right: 15.0),
      child: ClipRRect(
        // Suggestion: Simpler radius if all corners are the same
        borderRadius: BorderRadius.circular(40.0),
        // borderRadius: const BorderRadius.only(
        //   topLeft: Radius.circular(40.0),
        //   topRight: Radius.circular(40.0),
        //   bottomLeft: Radius.circular(40.0),
        //   bottomRight: Radius.circular(40.0),
        // ),
        child: Container(
          decoration: BoxDecoration(
            color: AppCol.btnbacks,
            // ... (your commented-out styles)
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            // --- FIX 1 ---
            currentIndex: currentPage == 'home'
                ? 0
                : currentPage == 'Map'
                ? 1
                : 2,
            // --- END FIX 1 ---
            selectedItemColor: AppCol.btnbacke,
            unselectedItemColor: AppCol.btnbacke.withOpacity(0.4),
            // --- FIX 2 ---
            onTap: (index) {
              if (index == 0) {
                onNavigate('home');
              } else if (index == 1) {
                onNavigate('Map');
              } else {
                onNavigate('settings');
              }
            },
            // --- END FIX 2 ---
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
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
