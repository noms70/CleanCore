import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cc/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:cc/utils/colors.dart';
import '../widgets/navbar.dart';
import './settings_page.dart';
import '../widgets/alert_card.dart';
import './map_page.dart'; // <-- IMPORT NEW MAP PAGE
import '../models/models.dart'; // <-- IMPORT NEW MODELS
import 'dart:io';
import 'dart:convert';

import 'package:cc/models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _user;

  // Driver information
  String driverName = 'Ayesha Noman';
  String currentStatus = 'Offline'; // Offline, On Route, Break

  // Route data
  int completedBins = 12;
  int totalBins = 45;
  String routeId = 'Route 4B - Downtown';
  String estimatedTime = '2h 35m';
  int criticalBinsNearby = 3;

  // Performance metrics
  double efficiencyScore = 87.5;
  double distanceSaved = 24.3; // km
  double capacityUsage = 68; // percentage

  // --- MODIFICATION: NEW ISLAMABAD LOCATIONS ---
  // Map markers and locations
  // THIS DATA IS STILL THE "SOURCE OF TRUTH"
  final List<BinLocation> binLocations = [
    BinLocation(
      id: 'BIN_ISB_001',
      lat: 33.72962, // Faisal Mosque
      lng: 73.03702,
      fullness: 92,
      isCritical: true,
      area: 'Faisal Mosque Area',
      status: 'Critical',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_ISB_002',
      lat: 33.69333, // Pakistan Monument
      lng: 73.06822,
      fullness: 45,
      isCritical: false,
      area: 'Pakistan Monument',
      status: 'Normal',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_ISB_003',
      lat: 33.7400, // Daman-e-Koh
      lng: 73.0600,
      fullness: 98,
      isCritical: true,
      area: 'Daman-e-Koh Viewpoint',
      status: 'Critical',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_ISB_004',
      lat: 33.7077, // Centaurus Mall
      lng: 73.0499,
      fullness: 35,
      isCritical: false,
      area: 'Centaurus Mall',
      status: 'Normal',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_ISB_005',
      lat: 33.70293, // Rawal Lake
      lng: 73.12771,
      fullness: 88,
      isCritical: true,
      area: 'Rawal Lake Park',
      status: 'Critical',
      capacity: 240,
    ),
  ];

  // Map-related state is MOVED to MapPage
  // --- MODIFICATION: NEW DRIVER STARTING LOCATION ---
  double driverLat = 33.7077; // Centered at Centaurus
  double driverLng = 73.0499;
  // --- END MODIFICATION ---

  // Alerts
  List<Alert> alerts = [
    Alert(
      title: 'New Bin Urgency Detected',
      message: 'Route recalculated for better efficiency',
      type: 'info',
      icon: Icons.route,
    ),
    Alert(
      title: 'Anomaly #123 Resolved',
      message: 'Admin confirmed issue closure',
      type: 'success',
      icon: Icons.check_circle,
    ),
  ];

  String currentPage = 'home';

  // User data variables for user info widget
  bool _isLoadingUserData = true;
  late List<Color> _gradientColors;
  late IconData _sunIcon;
  late String _greeting;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  void _initializeUserData() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final user = await _firestoreService.getUser(currentUser.uid);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoadingUserData = false;
          _updateGreeting();
        });
      }
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
      _sunIcon = Icons.wb_sunny;
      _gradientColors = [const Color(0xFFFDB750), const Color(0xFFF77F00)];
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
      _sunIcon = Icons.wb_sunny;
      _gradientColors = [const Color(0xFF00D9D9), const Color(0xFF0A8E8B)];
    } else {
      _greeting = 'Good Evening';
      _sunIcon = Icons.nights_stay;
      _gradientColors = [const Color(0xFF2D3E50), const Color(0xFF1A1F36)];
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildUserInfo(BuildContext context, Size screenSize) {
    if (_isLoadingUserData || _user == null) {
      return _buildUserInfoSkeleton(screenSize);
    }

    final firstName = _capitalize(_user!.firstName);
    final lastName = _capitalize(_user!.lastName);
    final profilePic = _user!.profilePicture;

    ImageProvider? backgroundImage;
    if (profilePic.isNotEmpty) {
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
      margin: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.width * 0.04,
      ),
      padding: EdgeInsets.all(screenSize.width * 0.03),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _gradientColors),
        borderRadius: BorderRadius.circular(screenSize.width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: screenSize.width * 0.065,
            backgroundImage: backgroundImage,
            child: (backgroundImage == null)
                ? Text(
                    firstName.isNotEmpty ? firstName[0] : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenSize.width * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: screenSize.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _sunIcon,
                      color: Colors.white,
                      size: screenSize.width * 0.06,
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: screenSize.width * 0.03,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenSize.width * 0.01),
                Text(
                  '$firstName $lastName',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenSize.width * 0.01),
                Text(
                  'Welcome back! Ready for a Ride?',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSkeleton(Size screenSize) {
    return Container(
      margin: EdgeInsets.all(screenSize.width * 0.04),
      padding: EdgeInsets.all(screenSize.width * 0.04),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(screenSize.width * 0.04),
      ),
      child: Row(
        children: [
          Container(
            width: screenSize.width * 0.16,
            height: screenSize.width * 0.16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
          SizedBox(width: screenSize.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  color: Colors.grey.withOpacity(0.3),
                  margin: EdgeInsets.only(bottom: screenSize.width * 0.02),
                ),
                Container(height: 12, color: Colors.grey.withOpacity(0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Color getStatusColor() {
    switch (currentStatus) {
      case 'On Route':
        return Colors.green;
      case 'Break':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- THIS IS NOW THE MAIN PAGE ROUTER ---

    if (currentPage == 'settings') {
      return SettingsPage(
        onNavigate: (page) {
          setState(() {
            currentPage = page;
          });
        },
      );
    }

    if (currentPage == 'Map') {
      return MapPage(
        binLocations: binLocations,
        driverLat: driverLat,
        driverLng: driverLng,
        currentPage: currentPage,
        onNavigate: (page) {
          setState(() {
            currentPage = page;
          });
        },
      );
    }

    // --- ELSE, SHOW THE HOME PAGE ---
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        ),
        backgroundColor: AppCol.btnbacks,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 50, bottom: 10),
                child: Center(
                  child: Image.asset(
                    'assets/cc_logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // Spacer to balance the layout
          ],
        ),
      ),
      body: _buildHomePageContent(
        screenSize,
      ), // <-- USE NEW HOME CONTENT METHOD
      bottomNavigationBar: NavBar(
        currentPage: currentPage,
        onNavigate: (page) {
          setState(() {
            currentPage = page;
          });
        },
      ),
    );
  }

  // --- NEW METHOD TO BUILD JUST THE HOME PAGE'S CONTENT ---
  Widget _buildHomePageContent(Size screenSize) {
    return Stack(
      children: [
        Column(
          children: [
            _buildUserInfo(context, screenSize),
            // GoogleMap WIDGET REMOVED
            // _buildBinTile ListView REMOVED
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRouteSummary(),
                    const SizedBox(height: 16),
                    //_buildKPIs(), // <-- UNCOMMENTED
                    const SizedBox(height: 20),
                    _buildAlerts(), // <-- MOVED HERE FOR LAYOUT
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppCol.btnbacks.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: AppCol.btnbacks, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Today\'s Route',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppCol.btntext,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRouteSummaryRow('Route ID', routeId),
            const SizedBox(height: 12),
            _buildRouteSummaryRow('Total Bins', '$totalBins Bins'),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppCol.btntext,
                      ),
                    ),
                    Text(
                      '$completedBins / $totalBins Collected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppCol.textGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completedBins / totalBins,
                    minHeight: 8,
                    backgroundColor: AppCol.btnbacks.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppCol.btnbacks),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRouteSummaryRow('Est. Completion', estimatedTime),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '$criticalBinsNearby Critical Bins Nearby (95%+ Full)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppCol.btntext,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppCol.ngt,
          ),
        ),
      ],
    );
  }

  Widget _buildAlerts() {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: AppCol.btnbacks),
              const SizedBox(width: 8),
              const Text(
                'Alerts & Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btntext,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppCol.btnbacks.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${alerts.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppCol.btnbacks,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((alert) => AlertCard(alert: alert)),
        ],
      ),
    );
  }
}