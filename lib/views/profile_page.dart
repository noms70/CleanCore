import 'dart:io';
import 'package:cc/widgets/appbar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cc/utils/colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Map<String, dynamic> _userData = {
    'firstName': 'John',
    'lastName': 'Doe',
    'email': 'john.doe@example.com',
    'phoneNumber': '+1 (555) 123-4567',
    'profilePicture': null,
  };

  String formatFieldName(String fieldName) {
    List<String> words = fieldName.split(' ');
    return words
        .asMap()
        .entries
        .map((entry) {
          if (entry.key == 0) {
            return entry.value.toLowerCase();
          } else {
            return entry.value[0].toUpperCase() +
                entry.value.substring(1).toLowerCase();
          }
        })
        .join('');
  }

  void _navigateToEdit(String field, String currentValue) {
    TextEditingController controller = TextEditingController(
      text: currentValue,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty && newValue != currentValue) {
                String formattedField = formatFieldName(field);
                setState(() {
                  _userData[formattedField] = newValue;
                });
                showToast('Profile Updated', isError: false);
              }
              Navigator.pop(context);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Account"),
        content: Text(
          "Are you sure you want to delete your account? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              showToast(
                'This is a UI-only preview. Delete functionality coming soon.',
              );
              Navigator.pop(context);
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final firstname = _capitalize(_userData['firstName'] ?? '');
    final profilePicUrl = _userData['profilePicture'] as String?;
    final initials = firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBuild().buildAppBar(
        title: 'Personal Profile',
        icon: Icons.directions_bike,
      ),
      body: Container(
        decoration: BoxDecoration(color: AppCol.appbg),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: screenSize.width,
                decoration: BoxDecoration(
                  color: Color(0xFFFCF5FD),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(35)),
                ),
                child: ListView(
                  padding: EdgeInsets.all(screenSize.width * 0.05),
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2AF297), Colors.tealAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                (profilePicUrl?.isNotEmpty ?? false)
                                ? (profilePicUrl!.startsWith('http')
                                      ? NetworkImage(profilePicUrl)
                                      : FileImage(File(profilePicUrl))
                                            as ImageProvider)
                                : null,
                            child: (profilePicUrl?.isEmpty ?? true)
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 110,
                              height: 55,
                              decoration: BoxDecoration(
                                color: Color(0x5F101010),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(55),
                                ),
                              ),
                              child: InkWell(
                                onTap: _updateProfilePicture,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.black45,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Edit",
                                      style: TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildEditableTile(
                      title: "First Name",
                      value: _userData['firstName'] ?? 'Unknown',
                      icon: Icons.person,
                      onEdit: () => _navigateToEdit(
                        "First Name",
                        _userData['firstName'] ?? 'Unknown',
                      ),
                    ),
                    _buildEditableTile(
                      title: "Last Name",
                      value: _userData['lastName'] ?? 'Unknown',
                      icon: Icons.person,
                      onEdit: () => _navigateToEdit(
                        "Last Name",
                        _userData['lastName'] ?? 'Unknown',
                      ),
                    ),
                    _buildEditableTile(
                      title: "Email",
                      value: _userData['email'] ?? 'Unknown',
                      icon: Icons.email,
                      onEdit: null,
                    ),
                    _buildEditableTile(
                      title: "Phone Number",
                      value: _userData['phoneNumber'] ?? 'Unknown',
                      icon: Icons.phone,
                      onEdit: () => _navigateToEdit(
                        "Phone Number",
                        _userData['phoneNumber'] ?? 'Unknown',
                      ),
                    ),
                    Divider(color: Colors.grey.withOpacity(0.4), thickness: 1),
                    _buildSectionHeader("Account Management"),
                    _buildListTile(
                      icon: Icons.delete,
                      title: "Delete Account",
                      onTap: _showDeleteAccountDialog,
                    ),
                    _buildListTile(
                      icon: Icons.logout,
                      title: "Sign Out",
                      onTap: () {
                        showToast(
                          'This is a UI-only preview. Sign out functionality coming soon.',
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
          color: Color(0xFF5B2245),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required Function onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF5B2245), size: 32),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5B2245),
        ),
      ),
      onTap: () => onTap(),
      trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF5B2245)),
    );
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;

    return input
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  Future<void> _updateProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _userData['profilePicture'] = pickedFile.path;
        });
        showToast('Profile picture updated successfully', isError: false);
      }
    } catch (e) {
      print('Failed to update profile picture: $e');
      showToast('Failed to update profile picture: $e');
    }
  }

  Widget _buildEditableTile({
    required String title,
    required String value,
    required IconData icon,
    Function? onEdit,
  }) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF5B2245), size: 32),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5B2245),
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6)),
      ),
      trailing: onEdit != null
          ? IconButton(
              icon: Icon(Icons.edit, color: Color(0xFF5B2245)),
              onPressed: () => onEdit(),
            )
          : null,
    );
  }
}
