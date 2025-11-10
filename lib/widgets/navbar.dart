import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- 1. RESPONSIVE LOGIC (Same as before) ---
    final double screenWidth = MediaQuery.of(context).size.width;
    const double maxNavBarWidth = 500.0;
    const double mobileHorizontalPadding = 15.0;

    double horizontalPadding;
    if (screenWidth > (maxNavBarWidth + (mobileHorizontalPadding * 2))) {
      horizontalPadding = (screenWidth - maxNavBarWidth) / 2;
    } else {
      horizontalPadding = mobileHorizontalPadding;
    }
    // --- END RESPONSIVE LOGIC ---

    return Padding(
      padding: EdgeInsets.only(
        bottom: 20.0,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.0),
        child: Container(
          // Give the nav bar a consistent height
          height: 70.0, // You can adjust this height
          decoration: BoxDecoration(
            color: AppCol.btnbacks,
          ),
          // --- 2. LABELS + CENTERING FIX ---
          // Use a Row for horizontal layout
          child: Row(
            // Each item will be an 'Expanded' widget to take up equal space
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                pageName: 'home',
              ),
              _buildNavItem(
                icon: Icons.map,
                label: 'Map',
                pageName: 'Map',
              ),
              _buildNavItem(
                icon: Icons.settings,
                label: 'Settings',
                pageName: 'settings',
              ),
            ],
          ),
          // --- END FIX ---
        ),
      ),
    );
  }

  // --- 3. HELPER WIDGET ---
  // We create a helper function to build each nav item.
  // This avoids repeating code.
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String pageName,
  }) {
    // Check if this item is the currently selected one
    final bool isSelected = (currentPage == pageName);

    // Determine the color based on selection
    final Color itemColor =
        isSelected ? AppCol.btnbacke : AppCol.btnbacke.withOpacity(0.4);

    // Expanded makes the widget fill 1/3 of the Row
    return Expanded(
      child: InkWell(
        // Use InkWell for tap effect
        onTap: () => onNavigate(pageName),
        // Make the splash effect match the icon color
        splashColor: AppCol.btnbacke.withOpacity(0.1),
        highlightColor: AppCol.btnbacke.withOpacity(0.1),
        child: Column(
          // Center the icon and text vertically
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: itemColor,
            ),
            const SizedBox(height: 4), // Space between icon and label
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 12, // Standard label font size
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}