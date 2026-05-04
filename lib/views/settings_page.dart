import 'package:cc/services/auth_service.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/widgets/appbar.dart';
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
  final AuthService _authService = AuthService();
  bool isNotificationsEnabled = true;
  bool isBikeUsageTrackingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBuild().buildAppBar(
        title: 'Settings',
        icon: Icons.settings,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(color: Color(0xFF141C40)),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: screenSize.width,
                  decoration: BoxDecoration(
                    color: Color(0xFFFCF5FD),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: screenSize.width * 0.05,
                      left: screenSize.width * 0.06,
                      right: screenSize.width * 0.06,
                      bottom: screenSize.width * 0.15,
                    ),
                    children: [
                      _buildSectionHeader("Account"),
                      _buildListTile(
                        icon: Icons.person,
                        title: "Personal Profile",
                        subtitle: "View and edit your profile",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        color: Colors.grey.withOpacity(0.4),
                        thickness: 1,
                      ),
                      _buildSectionHeader("Preferences"),
                      _buildSwitchTile(
                        icon: Icons.notifications,
                        title: "Route Notifications",
                        value: isNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            isNotificationsEnabled = value;
                          });
                        },
                      ),
                      _buildSwitchTile(
                        icon: Icons.track_changes,
                        title: "Location Tracking",
                        value: isBikeUsageTrackingEnabled,
                        onChanged: (value) {
                          setState(() {
                            isBikeUsageTrackingEnabled = value;
                          });
                        },
                      ),
                      Divider(
                        color: Colors.grey.withOpacity(0.4),
                        thickness: 1,
                      ),
                      _buildSectionHeader("About"),
                      _buildListTile(
                        icon: Icons.info,
                        title: "App Version",
                        subtitle: "1.0.0",
                        onTap: () {},
                      ),
                      _buildListTile(
                        icon: Icons.help,
                        title: "Help & Support",
                        subtitle: "Get assistance",
                        onTap: () {},
                      ),
                      Divider(
                        color: Colors.grey.withOpacity(0.4),
                        thickness: 1,
                      ),
                      _buildListTile(
                        icon: Icons.logout,
                        title: "Sign Out",
                        subtitle: "Sign out of your account",
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await _authService.signOut();
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => AuthLandingScreen(),
                            ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppCol.btnbacke,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Function() onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppCol.btnbacke, size: 32),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppCol.btnbacke,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6)),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: AppCol.btnbacke),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppCol.btnbacke, size: 28),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppCol.btnbacke,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppCol.btnbacke,
        inactiveThumbColor: AppCol.btnbacke.withOpacity(0.5),
        inactiveTrackColor: AppCol.btnbacke.withOpacity(0.3),
      ),
    );
  }
}
