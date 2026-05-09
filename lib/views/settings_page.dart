import 'package:cc/services/auth_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/utils/theme_service.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/widgets/appbar.dart';
import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onNavigate;

  const SettingsPage({Key? key, required this.onNavigate}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool isNotificationsEnabled = true;
  bool isLocationTrackingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final screenSz = MediaQuery.of(context).size;

    // Header strip is always dark navy — consistent in both modes
    const headerColor  = AppCol.primaryDark;
    final surfaceColor = isDark ? AppCol.card : Colors.white;

    return Scaffold(
      appBar: AppBuild().buildAppBar(
        title: 'Settings',
        icon: Icons.settings_rounded,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(color: headerColor),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: screenSz.width,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                    ),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(-4, 0),
                            )
                          ]
                        : null,
                  ),
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: screenSz.width * 0.05,
                      left: screenSz.width * 0.06,
                      right: screenSz.width * 0.06,
                      bottom: screenSz.width * 0.18,
                    ),
                    children: [
                      // ── Account ─────────────────────────────────────────
                      _buildSectionHeader(context, "Account"),
                      _buildListTile(
                        context: context,
                        icon: Icons.person_rounded,
                        title: "Personal Profile",
                        subtitle: "View and edit your profile",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfilePage()),
                        ),
                      ),
                      _buildDivider(context),

                      // ── Preferences ──────────────────────────────────────
                      _buildSectionHeader(context, "Preferences"),
                      _buildSwitchTile(
                        context: context,
                        icon: Icons.notifications_rounded,
                        title: "Route Notifications",
                        value: isNotificationsEnabled,
                        onChanged: (v) =>
                            setState(() => isNotificationsEnabled = v),
                      ),
                      _buildSwitchTile(
                        context: context,
                        icon: Icons.location_on_rounded,
                        title: "Location Tracking",
                        value: isLocationTrackingEnabled,
                        onChanged: (v) =>
                            setState(() => isLocationTrackingEnabled = v),
                      ),
                      _buildDivider(context),

                      // ── Appearance ───────────────────────────────────────
                      _buildSectionHeader(context, "Appearance"),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (_, mode, __) => _buildSwitchTile(
                          context: context,
                          icon: mode == ThemeMode.dark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          title: "Dark Mode",
                          subtitle: mode == ThemeMode.dark
                              ? "Switch to light theme"
                              : "Switch to dark theme",
                          value: mode == ThemeMode.dark,
                          onChanged: (_) => toggleTheme(),
                          activeColor: AppCol.primary,
                        ),
                      ),
                      _buildDivider(context),

                      // ── About ─────────────────────────────────────────────
                      _buildSectionHeader(context, "About"),
                      _buildListTile(
                        context: context,
                        icon: Icons.info_rounded,
                        title: "App Version",
                        subtitle: "1.0.0",
                        onTap: () {},
                      ),
                      _buildListTile(
                        context: context,
                        icon: Icons.help_rounded,
                        title: "Help & Support",
                        subtitle: "Get assistance",
                        onTap: () {},
                      ),
                      _buildDivider(context),

                      // ── Sign Out ──────────────────────────────────────────
                      _buildListTile(
                        context: context,
                        icon: Icons.logout_rounded,
                        title: "Sign Out",
                        subtitle: "Sign out of your account",
                        iconColor: Colors.redAccent,
                        titleColor: Colors.redAccent,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await _authService.signOut();
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => AuthLandingScreen()),
                            (Route<dynamic> route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavBar(
        currentPage: 'settings',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: Theme.of(context).dividerColor,
      thickness: 1,
      height: 8,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppCol.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Function() onTap,
    String subtitle = '',
    Color? iconColor,
    Color? titleColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedIcon  = iconColor  ?? scheme.onSurface;
    final resolvedTitle = titleColor ?? scheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: resolvedIcon.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: resolvedIcon, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: resolvedTitle,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurface.withValues(alpha: 0.35),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String subtitle = '',
    Color? activeColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppCol.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppCol.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeColor ?? AppCol.primary,
      ),
    );
  }
}
