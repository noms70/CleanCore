import 'dart:convert';
import 'dart:io';
import 'package:cc/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/widgets/appbar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cc/views/auth/auth_landing_screen.dart';
import 'package:cc/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
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
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final user = await _firestoreService.getUser(currentUser.uid);
    if (mounted) {
      setState(() {
        _user = user ??
            UserModel(
              uid: currentUser.uid,
              email: currentUser.email ?? '',
              firstName: currentUser.displayName?.split(' ').first ?? '',
              lastName: currentUser.displayName != null &&
                      currentUser.displayName!.contains(' ')
                  ? currentUser.displayName!.split(' ').sublist(1).join(' ')
                  : '',
              profilePicture: currentUser.photoURL ?? '',
              createdAt: Timestamp.now(),
            );
        _isLoading = false;
      });
    }
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .split(' ')
        .asMap()
        .entries
        .map((e) => e.key == 0
            ? e.value.toLowerCase()
            : e.value[0].toUpperCase() + e.value.substring(1).toLowerCase())
        .join('');
  }

  void _navigateToEdit(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppCol.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty && newValue != currentValue) {
                await _firestoreService.updateUser(
                    _user!.uid, {_formatFieldName(field): newValue});
                showToast('Profile Updated', isError: false);
                _loadUserData();
              }
              nav.pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone. "
          "All your data will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                            builder: (_) => AuthLandingScreen()),
                        (route) => false,
                      );
                    }
                  });
                } else {
                  showToast('Your account has been successfully deleted.');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => AuthLandingScreen()),
                        (route) => false,
                      );
                    }
                  });
                }
              } catch (e) {
                if (!mounted) return;
                showToast(
                    'Account deletion failed. Please try again.',
                    isError: true);
              }
            },
            child: const Text("Delete",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final screenSize   = MediaQuery.of(context).size;
    // Header strip matches AppBar — teal in light, navy in dark
    final headerColor  = isDark ? AppCol.card : AppCol.primary;
    final surfaceColor = isDark ? AppCol.card : Colors.white;

    return Scaffold(
      appBar: AppBuild().buildAppBar(title: 'Personal Profile'),
      body: Container(
        decoration: BoxDecoration(color: headerColor),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: screenSize.width,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                  ),
                ),
                child: _isLoading
                    ? _buildShimmerLayout(screenSize, isDark)
                    : _buildProfileContent(screenSize, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLayout(Size screenSize, bool isDark) {
    final baseColor      = isDark ? AppCol.secondary : Colors.grey[300]!;
    final highlightColor = isDark ? AppCol.card       : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: EdgeInsets.all(screenSize.width * 0.05),
        children: [
          const Center(
            child: CircleAvatar(radius: 50, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          _shimmerTile(),
          _shimmerTile(),
          _shimmerTile(),
          _shimmerTile(),
          const Divider(),
          _shimmerTile(trailing: false),
        ],
      ),
    );
  }

  Widget _shimmerTile({bool trailing = true}) => ListTile(
        leading: const CircleAvatar(
            backgroundColor: Colors.white, radius: 16),
        title: Container(
            height: 14,
            margin: const EdgeInsets.only(bottom: 6),
            color: Colors.white),
        subtitle: Container(height: 12, color: Colors.white),
        trailing: trailing
            ? const Icon(Icons.edit, color: Colors.white)
            : const Icon(Icons.arrow_forward_ios, color: Colors.white),
      );

  Widget _buildProfileContent(Size screenSize, bool isDark) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.all(screenSize.width * 0.05),
      children: [
        _buildProfilePicture(scheme),
        const SizedBox(height: 24),
        _buildEditableTile(
          context: context,
          title: "First Name",
          value: _user?.firstName ?? 'Unknown',
          icon: Icons.person_rounded,
          onEdit: () => _navigateToEdit("First Name", _user?.firstName ?? ''),
        ),
        _buildEditableTile(
          context: context,
          title: "Last Name",
          value: _user?.lastName ?? 'Unknown',
          icon: Icons.person_rounded,
          onEdit: () => _navigateToEdit("Last Name", _user?.lastName ?? ''),
        ),
        _buildEditableTile(
          context: context,
          title: "Email",
          value: (_user?.email.isNotEmpty == true)
              ? _user!.email
              : (_authService.currentUser?.email ?? 'Unknown'),
          icon: Icons.email_rounded,
          onEdit: null,
        ),
        _buildEditableTile(
          context: context,
          title: "Phone Number",
          value: _user?.phoneNumber ?? 'Not set',
          icon: Icons.phone_rounded,
          onEdit: () =>
              _navigateToEdit("Phone Number", _user?.phoneNumber ?? ''),
        ),
        Divider(color: Theme.of(context).dividerColor, height: 32),
        _buildSectionHeader(context, "Account Management"),
        _buildDangerTile(context),
      ],
    );
  }

  Widget _buildProfilePicture(ColorScheme scheme) {
    final profilePic = _user?.profilePicture;
    final initials   = _user?.firstName.isNotEmpty == true
        ? _user!.firstName[0].toUpperCase()
        : '?';

    ImageProvider? backgroundImage;
    if (profilePic != null && profilePic.isNotEmpty) {
      if (profilePic.startsWith('http')) {
        backgroundImage = NetworkImage(profilePic);
      } else {
        try {
          backgroundImage = MemoryImage(base64Url.decode(profilePic));
        } catch (_) {}
      }
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppCol.primary, AppCol.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppCol.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: Colors.transparent,
              backgroundImage: backgroundImage,
              child: backgroundImage == null
                  ? Text(initials,
                      style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _updateProfilePicture,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppCol.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppCol.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildEditableTile({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onEdit,
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
        child: Icon(icon, color: AppCol.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      trailing: onEdit != null
          ? IconButton(
              icon: Icon(Icons.edit_rounded,
                  color: AppCol.primary.withValues(alpha: 0.7), size: 20),
              onPressed: onEdit,
            )
          : null,
    );
  }

  Widget _buildDangerTile(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 22),
      ),
      title: const Text("Delete Account",
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.redAccent.withValues(alpha: 0.5), size: 20),
      onTap: _showDeleteAccountDialog,
    );
  }

  Future<void> _updateProfilePicture() async {
    try {
      final picker    = ImagePicker();
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
