import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppCol.btnbacks, AppCol.btnbacke],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppCol.btnbacks.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: currentPage == 'home' ? 0 : 1,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
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
    );
  }
}
