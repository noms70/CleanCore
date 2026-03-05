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

  String _formatFieldName(String fieldName) {
    final words = fieldName.split(' ');
    return words
        .asMap()
        .entries
        .map((entry) {
          if (entry.key == 0) return entry.value.toLowerCase();
          return entry.value[0].toUpperCase() +
              entry.value.substring(1).toLowerCase();
        })
        .join('');
  }

  void _navigateToEdit(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit $field',
          style: const TextStyle(
            color: AppCol.btnbacke,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            labelStyle: TextStyle(color: AppCol.btnbacks),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppCol.btnbacks, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppCol.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppCol.btnbacks,
              foregroundColor: AppCol.btnbacke,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty && newValue != currentValue) {
                final formattedField = _formatFieldName(field);
                await _firestoreService.updateUser(_user!.uid, {
                  formattedField: newValue,
                });
                showToast('Profile Updated');
                _loadUserData();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppCol.btnbacke, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. '
          'All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppCol.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);

              if (_user == null || _user!.uid.isEmpty) {
                showToast('Error: User not found.', isError: true);
                return;
              }

              final uid = _user!.uid;

              try {
                await _firestoreService.deleteUserDocument(uid);
                final authError = await _authService.deleteAccount();

                if (!mounted) return;

                if (authError != null) {
                  showToast(authError, isError: true);
                  await _authService.signOut();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const AuthLandingScreen()),
                        (_) => false,
                      );
                    }
                  });
                } else {
                  showToast('Your account has been successfully deleted.');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const AuthLandingScreen()),
                        (_) => false,
                      );
                    }
                  });
                }
              } catch (e) {
                if (!mounted) return;
                showToast(
                  'Account deletion failed. Please try again.',
                  isError: true,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBuild().buildAppBar(title: 'Personal Profile'),
      body: Container(
        // Use the same dark navy as the app bar / settings page
        color: AppCol.btnbacke,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: screenSize.width,
                decoration: const BoxDecoration(
                  color: AppCol.backgroundLight,
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

  // ─── Shimmer ────────────────────────────────────────────────────────────────

  Widget _buildShimmerLayout(Size screenSize) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: EdgeInsets.all(screenSize.width * 0.05),
        children: [
          const Center(
            child: CircleAvatar(radius: 50, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          _buildShimmerTile(showSubtitle: true),
          _buildShimmerTile(showSubtitle: true),
          _buildShimmerTile(showSubtitle: true),
          _buildShimmerTile(showSubtitle: true),
          const Divider(),
          _buildShimmerTile(showSubtitle: false),
          _buildShimmerTile(showSubtitle: false),
        ],
      ),
    );
  }

  Widget _buildShimmerTile({required bool showSubtitle}) {
    return ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.white, radius: 16),
      title: Container(
        height: 14,
        margin: const EdgeInsets.only(bottom: 6),
        color: Colors.white,
      ),
      subtitle: showSubtitle
          ? Container(height: 12, color: Colors.white)
          : null,
      trailing: Container(
        width: 20,
        height: 20,
        color: Colors.white,
      ),
    );
  }

  // ─── Profile Content ────────────────────────────────────────────────────────

  Widget _buildProfileContent(Size screenSize) {
    return ListView(
      padding: EdgeInsets.all(screenSize.width * 0.05),
      children: [
        Center(child: _buildProfilePicture()),
        const SizedBox(height: 20),
        _buildEditableTile(
          title: 'First Name',
          value: _user?.firstName ?? 'Unknown',
          icon: Icons.person_rounded,
          onEdit: () => _navigateToEdit('First Name', _user?.firstName ?? ''),
        ),
        _buildEditableTile(
          title: 'Last Name',
          value: _user?.lastName ?? 'Unknown',
          icon: Icons.person_outline_rounded,
          onEdit: () => _navigateToEdit('Last Name', _user?.lastName ?? ''),
        ),
        _buildEditableTile(
          title: 'Email',
          value: _user?.email ?? 'Unknown',
          icon: Icons.email_rounded,
          onEdit: null, // email is not editable
        ),
        _buildEditableTile(
          title: 'Phone Number',
          value: _user?.phoneNumber ?? 'Not set',
          icon: Icons.phone_rounded,
          onEdit: () =>
              _navigateToEdit('Phone Number', _user?.phoneNumber ?? ''),
        ),
        Divider(color: Colors.grey.withOpacity(0.3), thickness: 1, height: 30),
        _buildSectionHeader('Account Management'),
        _buildActionTile(
          icon: Icons.delete_rounded,
          title: 'Delete Account',
          iconColor: Colors.red,
          onTap: _showDeleteAccountDialog,
        ),
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          iconColor: AppCol.btnbacks,
          onTap: () async {
            await _authService.signOut();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
              (_) => false,
            );
          },
        ),
      ],
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _buildProfilePicture() {
    final profilePic = _user?.profilePicture;
    final initials = (_user?.firstName.isNotEmpty == true)
        ? _user!.firstName[0].toUpperCase()
        : '?';

    ImageProvider? backgroundImage;
    if (profilePic != null && profilePic.isNotEmpty) {
      if (profilePic.startsWith('http')) {
        backgroundImage = NetworkImage(profilePic);
      } else {
        try {
          backgroundImage = MemoryImage(base64Url.decode(profilePic));
        } catch (_) {
          backgroundImage = null;
        }
      }
    }

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppCol.btncol,
        boxShadow: [
          BoxShadow(
            color: AppCol.btnbacks.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
            child: backgroundImage == null
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
            child: GestureDetector(
              onTap: _updateProfilePicture,
              child: Container(
                width: 110,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.38),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(55),
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                    SizedBox(height: 2),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
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

  Widget _buildEditableTile({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onEdit,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppCol.btnbacks.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppCol.btnbacks, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppCol.textGrey,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppCol.btnbacke,
        ),
      ),
      trailing: onEdit != null
          ? IconButton(
              icon: Icon(
                Icons.edit_rounded,
                color: AppCol.btnbacks,
                size: 20,
              ),
              onPressed: onEdit,
            )
          : null,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: iconColor,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: iconColor.withOpacity(0.6),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _updateProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await _firestoreService.uploadProfilePicture(_user!.uid, imageFile);
        showToast('Profile picture updated successfully');
        _loadUserData();
      }
    } catch (e) {
      showToast('Failed to update profile picture', isError: true);
    }
  }
}
