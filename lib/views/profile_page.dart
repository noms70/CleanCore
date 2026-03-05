import 'dart:convert';
import 'dart:io';
import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
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

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final user = await _firestoreService.getUser(currentUser.uid);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _formatFieldKey(String label) {
    final words = label.split(' ');
    return words.asMap().entries.map((e) {
      return e.key == 0
          ? e.value.toLowerCase()
          : e.value[0].toUpperCase() + e.value.substring(1).toLowerCase();
    }).join('');
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────

  void _showEditDialog(String field, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $field',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppCol.btnbacke)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: field,
            labelStyle: const TextStyle(color: AppCol.btnbacks),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppCol.btnbacks.withOpacity(0.4))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppCol.btnbacks, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppCol.textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppCol.btnbacks,
                foregroundColor: AppCol.btnbacke,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty && val != current) {
                await _firestoreService
                    .updateUser(_user!.uid, {_formatFieldKey(field): val});
                showToast('Profile updated');
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

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppCol.btnbacke)),
        content: const Text(
            'This will permanently delete your account and all data. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppCol.textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              if (_user == null) return;
              try {
                await _firestoreService.deleteUserDocument(_user!.uid);
                final err = await _authService.deleteAccount();
                if (!mounted) return;
                if (err != null) {
                  showToast(err, isError: true);
                  await _authService.signOut();
                }
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const AuthLandingScreen()),
                    (_) => false);
              } catch (_) {
                showToast('Deletion failed. Please try again.', isError: true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppCol.btnbacke),
        title: const Text(
          'Personal Profile',
          style: TextStyle(
            color: AppCol.btnbacke,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading ? _buildShimmer() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          _buildAvatar(),
          const SizedBox(height: 32),

          // ── Info fields ───────────────────────────────────────────────
          _buildFieldCard(
            icon: Icons.person_rounded,
            label: 'First Name',
            value: _user?.firstName ?? '—',
            onEdit: () =>
                _showEditDialog('First Name', _user?.firstName ?? ''),
          ),
          const SizedBox(height: 12),
          _buildFieldCard(
            icon: Icons.person_outline_rounded,
            label: 'Last Name',
            value: _user?.lastName ?? '—',
            onEdit: () =>
                _showEditDialog('Last Name', _user?.lastName ?? ''),
          ),
          const SizedBox(height: 12),
          _buildFieldCard(
            icon: Icons.email_rounded,
            label: 'Email',
            value: _user?.email ?? '—',
          ),
          const SizedBox(height: 12),
          _buildFieldCard(
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            value: _user?.phoneNumber?.isNotEmpty == true
                ? _user!.phoneNumber!
                : 'Not set',
            valueFaded: _user?.phoneNumber?.isEmpty != false,
            onEdit: () =>
                _showEditDialog('Phone Number', _user?.phoneNumber ?? ''),
          ),

          const SizedBox(height: 32),

          // ── Section header ────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACCOUNT MANAGEMENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                color: AppCol.btnbacks,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Action tiles ──────────────────────────────────────────────
          _buildActionCard(
            icon: Icons.delete_rounded,
            label: 'Delete Account',
            iconColor: Colors.red,
            onTap: _showDeleteDialog,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            iconColor: AppCol.btnbacks,
            onTap: () async {
              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const AuthLandingScreen()),
                  (_) => false);
            },
          ),
        ],
      ),
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    final profilePic = _user?.profilePicture ?? '';
    final initial =
        (_user?.firstName.isNotEmpty == true) ? _user!.firstName[0].toUpperCase() : '?';

    ImageProvider? bg;
    if (profilePic.startsWith('http')) {
      bg = NetworkImage(profilePic);
    } else if (profilePic.isNotEmpty) {
      try {
        bg = MemoryImage(base64Url.decode(profilePic));
      } catch (_) {}
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppCol.btnbacks, width: 3),
          ),
        ),
        // Avatar
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFFE8F4FD),
          backgroundImage: bg,
          child: bg == null
              ? Text(initial,
                  style: const TextStyle(
                      fontSize: 38,
                      color: AppCol.btnbacks,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        // Edit button
        Positioned(
          bottom: 2,
          right: -2,
          child: GestureDetector(
            onTap: _pickProfilePicture,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppCol.btnbacks,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded,
                  color: AppCol.btnbacke, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard({
    required IconData icon,
    required String label,
    required String value,
    bool valueFaded = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500])),
        subtitle: Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueFaded
                    ? Colors.grey[400]
                    : AppCol.btnbacke,
                fontStyle:
                    valueFaded ? FontStyle.italic : FontStyle.normal)),
        trailing: onEdit != null
            ? Icon(Icons.edit_rounded,
                color: AppCol.btnbacks.withOpacity(0.7), size: 18)
            : null,
        onTap: onEdit,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: iconColor)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: iconColor.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }

  // ─── Shimmer ─────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Column(
          children: [
            const CircleAvatar(radius: 55, backgroundColor: Colors.white),
            const SizedBox(height: 32),
            for (int i = 0; i < 4; i++) ...[
              Container(
                  height: 72,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _pickProfilePicture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        await _firestoreService.uploadProfilePicture(
            _user!.uid, File(picked.path));
        showToast('Profile picture updated');
        _loadUserData();
      }
    } catch (_) {
      showToast('Failed to update picture', isError: true);
    }
  }
}
