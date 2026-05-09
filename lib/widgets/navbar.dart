import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const NavBar({Key? key, required this.currentPage, required this.onNavigate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const double maxNavBarWidth = 500.0;
    const double mobileHorizontalPadding = 16.0;

    double horizontalPadding;
    if (screenWidth > (maxNavBarWidth + mobileHorizontalPadding * 2)) {
      horizontalPadding = (screenWidth - maxNavBarWidth) / 2;
    } else {
      horizontalPadding = mobileHorizontalPadding;
    }

    // Dark: card navy with teal accent. Light: white with teal accent.
    final Color navBg      = isDark ? AppCol.card : Colors.white;
    final Color selectedFg = AppCol.primary;
    final Color unselectedFg =
        isDark ? AppCol.mutedFg : Colors.grey.shade500;
    final Color shadowColor =
        isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.12);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 20.0,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Container(
        height: 68.0,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(40.0),
          border: isDark
              ? Border.all(color: AppCol.secondary, width: 1)
              : Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: 0,
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
                selectedFg: selectedFg,
                unselectedFg: unselectedFg,
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                pageName: 'Map',
                selectedFg: selectedFg,
                unselectedFg: unselectedFg,
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                pageName: 'settings',
                selectedFg: selectedFg,
                unselectedFg: unselectedFg,
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
    required Color selectedFg,
    required Color unselectedFg,
  }) {
    final bool isSelected = (currentPage == pageName);
    final Color itemColor = isSelected ? selectedFg : unselectedFg;

    return Expanded(
      child: InkWell(
        onTap: () => onNavigate(pageName),
        splashColor: AppCol.primary.withValues(alpha: 0.12),
        highlightColor: AppCol.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 14 : 0,
                  vertical: 4,
                ),
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppCol.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Icon(icon, color: itemColor, size: 22),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.normal,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
