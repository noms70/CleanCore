import 'dart:convert';
import 'dart:io';
import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/widgets/appbar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';

import 'package:cc/utils/colors.dart';
import 'package:cc/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Simulate a network delay for the shimmer effect to be visible
    await Future.delayed(const Duration(seconds: 2));
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final user = await _firestoreService.getUser(currentUser.uid);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    }
  }

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
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty && newValue != currentValue) {
                String formattedField = formatFieldName(field);
                await _firestoreService.updateUser(_user!.uid, {
                  formattedField: newValue,
                });
                showToast('Profile Updated', isError: false);
                _loadUserData();
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

    return Scaffold(
      appBar: AppBuild().buildAppBar(
        title: 'Personal Profile',
      ),
      body: Container(
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
                child: _isLoading
                    ? _buildShimmerLayout(screenSize)
                    : _buildProfileContent(screenSize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLayout(Size screenSize) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: EdgeInsets.all(screenSize.width * 0.05),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          _buildShimmerEditableTile(),
          _buildShimmerEditableTile(),
          _buildShimmerEditableTile(),
          _buildShimmerEditableTile(),
          Divider(
            color: Colors.grey.withOpacity(0.4),
            thickness: 1,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(
              height: 24,
              width: 200,
              color: Colors.white,
            ),
          ),
          _buildShimmerListTile(),
          _buildShimmerListTile(),
        ],
      ),
    );
  }

  Widget _buildShimmerEditableTile() {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.white, radius: 16),
      title: Container(
        height: 16,
        width: 100,
        margin: const EdgeInsets.only(bottom: 8.0),
        color: Colors.white,
      ),
      subtitle: Container(
        height: 14,
        width: 200,
        color: Colors.white,
      ),
      trailing: Icon(Icons.edit, color: Colors.white),
    );
  }

  Widget _buildShimmerListTile() {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.white, radius: 16),
      title: Container(
        height: 16,
        width: 150,
        color: Colors.white,
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white),
    );
  }

  Widget _buildProfileContent(Size screenSize) {
    return ListView(
      padding: EdgeInsets.all(screenSize.width * 0.05),
      children: [
        _buildProfilePicture(),
        SizedBox(height: 20),
        _buildEditableTile(
          title: "First Name",
          value: _user?.firstName ?? 'Unknown',
          icon: Icons.person,
          onEdit: () => _navigateToEdit(
            "First Name",
            _user?.firstName ?? 'Unknown',
          ),
        ),
        _buildEditableTile(
          title: "Last Name",
          value: _user?.lastName ?? 'Unknown',
          icon: Icons.person,
          onEdit: () => _navigateToEdit(
            "Last Name",
            _user?.lastName ?? 'Unknown',
          ),
        ),
        _buildEditableTile(
          title: "Email",
          value: _user?.email ?? 'Unknown',
          icon: Icons.email,
          onEdit: null,
        ),
        _buildEditableTile(
          title: "Phone Number",
          value: _user?.phoneNumber ?? 'Not set',
          icon: Icons.phone,
          onEdit: () => _navigateToEdit(
            "Phone Number",
            _user?.phoneNumber ?? '',
          ),
        ),
        Divider(
          color: Colors.grey.withOpacity(0.4),
          thickness: 1,
        ),
        _buildSectionHeader("Account Management"),
        _buildListTile(
          icon: Icons.delete,
          title: "Delete Account",
          onTap: _showDeleteAccountDialog,
        ),
        _buildListTile(
          icon: Icons.logout,
          title: "Sign Out",
          onTap: () async {
          // 1. Sign out the user
          await _authService.signOut();
    
            if (!mounted) return;
      
            // 2. Navigate to the AuthLandingScreen and clear all previous history.
            Navigator.of(context).pushAndRemoveUntil( 
            // Redirect to the screen that correctly handles unauthenticated state
            MaterialPageRoute(builder: (context) => AuthLandingScreen()), 
            (Route<dynamic> route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfilePicture() {
    final profilePic = _user?.profilePicture;
    final initials = _user?.firstName.isNotEmpty == true
        ? _user!.firstName[0].toUpperCase()
        : '?';

    ImageProvider? backgroundImage;
    if (profilePic != null && profilePic.isNotEmpty) {
      if (profilePic.startsWith('http')) {
        backgroundImage = NetworkImage(profilePic);
      } else {
        try {
          backgroundImage = MemoryImage(base64Url.decode(profilePic));
        } catch (e) {
          print("Error decoding base64 image: $e");
          backgroundImage = null;
        }
      }
    }

    return Container(
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
            backgroundImage: backgroundImage,
            child: (backgroundImage == null)
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
                    Icon(Icons.edit, color: Colors.black45, size: 20),
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

  Future<void> _updateProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await _firestoreService.uploadProfilePicture(_user!.uid, imageFile);
        showToast('Profile picture updated successfully', isError: false);
        _loadUserData();
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
