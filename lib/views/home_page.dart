import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cc/models/user_model.dart';
import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cc/utils/colors.dart';
import '../models/models.dart';
import '../widgets/alert_card.dart';
import '../widgets/navbar.dart';
import './map_page.dart';
import './settings_page.dart';

// =========================================================================
// 1. **FIXED ERROR:** ProgressPainter must be a top-level class.
// =========================================================================

/// Custom Painter for the Circular Progress Bar for route completion.
class ProgressPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color progressColor;
  final double strokeWidth;

  ProgressPainter({
    required this.progress,
    required this.baseColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;

    // Base circle (unfilled part)
    final basePaint = Paint()
      ..color = baseColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, basePaint);

    // Progress arc (filled part)
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from the top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  // Corrected the covariant type and condition check.
  bool shouldRepaint(covariant ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =========================================================================
// 2. HomePage Implementation
// =========================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserModel? _user;

  // Driver information
  String currentStatus = 'Offline';

  // Route data — populated from Firestore 'routes' collection
  int completedBins = 0;
  int totalBins = 0;
  String routeId = '—';
  String estimatedTime = '—';
  int criticalBinsNearby = 0;
  double estimatedFuel = 0.0;

  // Firestore subscriptions
  StreamSubscription<QuerySnapshot>? _routeSub;
  StreamSubscription<QuerySnapshot>? _binsSub;

  // Map markers and locations
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

  // Map-related state
  double driverLat = 33.7077; // Centered at Centaurus
  double driverLng = 73.0499;

  // Alerts - **REMOVED from UI, kept for data structure**
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
    _subscribeToRouteData();
    _subscribeToBinStats();
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _binsSub?.cancel();
    super.dispose();
  }

  /// Listen to the driver's active route in Firestore.
  /// Field 'driverId' matches what the backend writes (not 'workerId').
  void _subscribeToRouteData() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _routeSub = _db
        .collection('routes')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() {
          completedBins = 0;
          totalBins = 0;
          routeId = 'No active route';
          estimatedFuel = 0.0;
          currentStatus = 'Idle';
        });
        return;
      }
      final route = ActiveRoute.fromFirestore(snap.docs.first);
      setState(() {
        completedBins = route.completedStops;
        totalBins = route.totalStops;
        routeId = route.routeId.length > 12
            ? route.routeId.substring(0, 12) + '…'
            : route.routeId;
        estimatedFuel = route.estimatedFuel;
        currentStatus = 'On Route';
        // Rough ETA: assume 2 min per remaining stop
        final remaining = route.totalStops - route.completedStops;
        final mins = remaining * 2;
        estimatedTime = mins >= 60
            ? '${mins ~/ 60}h ${mins % 60}m'
            : '${mins}m';
      });
    });
  }

  /// Count critical bins from Firestore (fillLevel > 89 or status critical/full).
  void _subscribeToBinStats() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      if (!mounted) return;
      final critical = snap.docs.where((d) {
        final data = d.data();
        final fill = (data['fillLevel'] ?? data['fill_level'] ?? 0) as num;
        final status = (data['status'] ?? '').toString().toLowerCase();
        return fill >= 90 || status == 'critical' || status == 'full';
      }).length;
      setState(() => criticalBinsNearby = critical);
    });
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
          // It's generally better to use a logger, but keeping print for now to match style
          // ignore: avoid_print
          backgroundImage = MemoryImage(base64Url.decode(profilePic));
        } catch (e) {
          // ignore: avoid_print
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
                  // Use the user's name
                  '${_user!.firstName} ${_user!.lastName}',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenSize.width * 0.01),
                Text(
                  'Welcome back! Ready for a Drive?',
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

  // --- MODIFIED METHOD TO BUILD JUST THE HOME PAGE'S CONTENT ---
  Widget _buildHomePageContent(Size screenSize) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildUserInfo(context, screenSize),
          const SizedBox(height: 20),
          _buildCircularProgressSection(screenSize), // NEW SECTION
          const SizedBox(height: 30),
          _buildKeyRouteMetricsGrid(screenSize), // NEW SECTION
          const SizedBox(height: 100), // Extra space for NavBar clearance
        ],
      ),
    );
  }

  // --- NEW: Circular Progress Bar for Route Completion ---
  Widget _buildCircularProgressSection(Size screenSize) {
    final progress = completedBins / totalBins;
    final progressPercentage = (progress * 100).toStringAsFixed(0);

    return Center(
      child: SizedBox(
        width: screenSize.width * 0.5,
        height: screenSize.width * 0.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // **FIXED ERROR:** ProgressPainter is now a top-level class and is used correctly.
            CustomPaint(
              size: Size(screenSize.width * 0.5, screenSize.width * 0.5),
              painter: ProgressPainter(
                progress: progress,
                baseColor: AppCol.btnbacks.withOpacity(0.2),
                progressColor: AppCol.btnbacks,
                strokeWidth: 12.0,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_sweep_sharp, // Bin/Sweep Icon
                  size: screenSize.width * 0.1,
                  color: AppCol.btnbacks,
                ),
                const SizedBox(height: 8),
                Text(
                  '$progressPercentage%',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.1,
                    fontWeight: FontWeight.bold,
                    color: AppCol.btntext,
                  ),
                ),
                Text(
                  'Route Progress',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                    color: AppCol.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Grid of 4 Key Route Metrics Cards ---
  Widget _buildKeyRouteMetricsGrid(Size screenSize) {
    final double cardWidth =
        (screenSize.width - 50) / 2; // Adjusted calculation for padding/spacing

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 10),
            child: Text(
              'Route Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppCol.btntext,
              ),
            ),
          ),
          GridView.count(
            physics:
                const NeverScrollableScrollPhysics(), // Important for SingleChildScrollView
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: cardWidth /
                (cardWidth * 0.6), // Adjust to make cards wider than tall
            children: [
              _buildMetricCard(
                'Route ID',
                routeId,
                Icons.alt_route,
                AppCol.btnbacks,
              ),
              _buildMetricCard(
                'Est. Remaining',
                estimatedTime,
                Icons.schedule,
                Colors.orange,
              ),
              _buildMetricCard(
                'Critical Bins',
                '$criticalBinsNearby Bins',
                Icons.crisis_alert,
                Colors.red,
              ),
              _buildMetricCard(
                'Fuel Est.',
                '${estimatedFuel.toStringAsFixed(1)} L',
                Icons.local_gas_station,
                AppCol.ngt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppCol.btntext,
            ),
          ),
        ],
      ),
    );
  }
}