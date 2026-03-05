import 'package:cc/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../widgets/navbar.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onNavigate;

  const SettingsPage({Key? key, required this.onNavigate}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _locationTracking = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF0F4F8);
    final cardColor = isDark ? const Color(0xFF1E2430) : Colors.white;
    final titleColor = isDark ? Colors.white : AppCol.btnbacke;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[500]!;
    final shadowColor = isDark ? Colors.black54 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Account ────────────────────────────────────────────────
            _sectionLabel('ACCOUNT'),
            const SizedBox(height: 12),
            _buildNavCard(
              icon: Icons.person_rounded,
              label: 'Personal Profile',
              subtitle: 'View and edit your profile',
              cardColor: cardColor,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              shadowColor: shadowColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            ),

            const SizedBox(height: 28),

            // ── Appearance ─────────────────────────────────────────────
            _sectionLabel('APPEARANCE'),
            const SizedBox(height: 12),

            // Dark mode toggle — wired to ThemeNotifier
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeNotifier.instance,
              builder: (_, __, ___) => _buildToggleCard(
                icon: ThemeNotifier.instance.isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                label: 'Dark Mode',
                value: ThemeNotifier.instance.isDark,
                cardColor: cardColor,
                titleColor: titleColor,
                shadowColor: shadowColor,
                onChanged: (_) => ThemeNotifier.instance.toggle(),
              ),
            ),

            const SizedBox(height: 28),

            // ── Preferences ────────────────────────────────────────────
            _sectionLabel('PREFERENCES'),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.notifications_rounded,
              label: 'Route Notifications',
              value: _notifications,
              cardColor: cardColor,
              titleColor: titleColor,
              shadowColor: shadowColor,
              onChanged: (v) => setState(() => _notifications = v),
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.my_location_rounded,
              label: 'Location Tracking',
              value: _locationTracking,
              cardColor: cardColor,
              titleColor: titleColor,
              shadowColor: shadowColor,
              onChanged: (v) => setState(() => _locationTracking = v),
            ),

            const SizedBox(height: 28),

            // ── About ──────────────────────────────────────────────────
            _sectionLabel('ABOUT'),
            const SizedBox(height: 12),
            _buildNavCard(
              icon: Icons.info_rounded,
              label: 'App Version',
              subtitle: '1.0.0',
              cardColor: cardColor,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              shadowColor: shadowColor,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              icon: Icons.help_rounded,
              label: 'Help & Support',
              subtitle: 'Get assistance',
              cardColor: cardColor,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              shadowColor: shadowColor,
              onTap: () {},
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavBar(
        currentPage: 'settings',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
        color: AppCol.btnbacks,
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color cardColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppCol.btnbacks.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppCol.btnbacks, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: titleColor)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: subtitleColor)),
        trailing:
            Icon(Icons.chevron_right_rounded, color: AppCol.btnbacks.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String label,
    required bool value,
    required Color cardColor,
    required Color titleColor,
    required Color shadowColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppCol.btnbacks.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppCol.btnbacks, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: titleColor)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppCol.btnbacks,
          activeTrackColor: AppCol.btnbacks.withOpacity(0.3),
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.grey.shade200,
        ),
      ),
    );
  }
}
