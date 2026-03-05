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
  bool isNotificationsEnabled = true;
  bool isBikeUsageTrackingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBuild().buildAppBar(
        title: 'Settings',
        icon: Icons.settings_rounded,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF141C40)),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: screenSize.width,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCF5FD),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: screenSize.width * 0.06,
                      left: screenSize.width * 0.05,
                      right: screenSize.width * 0.05,
                      bottom: screenSize.width * 0.25,
                    ),
                    children: [
                      _buildSectionHeader("Account"),
                      _buildCard(
                        child: _buildListTile(
                          icon: Icons.person_rounded,
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
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader("Preferences"),
                      _buildCard(
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              icon: Icons.notifications_rounded,
                              title: "Route Notifications",
                              value: isNotificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  isNotificationsEnabled = value;
                                });
                              },
                            ),
                            Divider(
                              color: Colors.grey.withOpacity(0.2),
                              height: 1,
                            ),
                            _buildSwitchTile(
                              icon: Icons.track_changes_rounded,
                              title: "Location Tracking",
                              value: isBikeUsageTrackingEnabled,
                              onChanged: (value) {
                                setState(() {
                                  isBikeUsageTrackingEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader("About"),
                      _buildCard(
                        child: Column(
                          children: [
                            _buildListTile(
                              icon: Icons.info_rounded,
                              title: "App Version",
                              subtitle: "1.0.0",
                              onTap: () {},
                            ),
                            Divider(
                              color: Colors.grey.withOpacity(0.2),
                              height: 1,
                            ),
                            _buildListTile(
                              icon: Icons.help_rounded,
                              title: "Help & Support",
                              subtitle: "Get assistance",
                              onTap: () {},
                            ),
                          ],
                        ),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppCol.btnbacks.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppCol.btnbacke,
          letterSpacing: 0.5,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppCol.btnbacks.withOpacity(0.15),
              AppCol.btnbacks.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppCol.btnbacks, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppCol.btntext,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.5)),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppCol.btnbacks.withOpacity(0.6),
        size: 18,
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppCol.btnbacks.withOpacity(0.15),
              AppCol.btnbacks.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppCol.btnbacks, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppCol.btntext,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppCol.btnbacks,
        activeTrackColor: AppCol.btnbacks.withOpacity(0.5),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade300,
      ),
    );
  }
}
