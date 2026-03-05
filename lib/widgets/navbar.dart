import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double maxNavBarWidth = 500.0;
    const double mobileHorizontalPadding = 15.0;

    double horizontalPadding;
    if (screenWidth > (maxNavBarWidth + (mobileHorizontalPadding * 2))) {
      horizontalPadding = (screenWidth - maxNavBarWidth) / 2;
    } else {
      horizontalPadding = mobileHorizontalPadding;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: 20.0,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Container(
        height: 70.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40.0),
          gradient: LinearGradient(
            colors: [AppCol.btnbacks, AppCol.btnbacks.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppCol.btnbacks.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40.0),
          child: Row(
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                pageName: 'home',
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                pageName: 'Map',
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                pageName: 'settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String pageName,
  }) {
    final bool isSelected = (currentPage == pageName);
    final Color itemColor = isSelected
        ? Colors.white
        : Colors.white.withOpacity(0.5);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onNavigate(pageName),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(isSelected ? 1.0 : 0.95),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isSelected ? 8 : 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: itemColor,
                    size: isSelected ? 26 : 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: isSelected ? 13 : 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
