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
import '../widgets/navbar.dart';
import './map_page.dart';
import './settings_page.dart';
import '../widgets/inactivity_wrapper.dart';

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
// 2. Animated Metric Card
// =========================================================================

class _AnimatedMetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;
  final bool isDark;

  const _AnimatedMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    required this.isDark,
  });

  @override
  State<_AnimatedMetricCard> createState() => _AnimatedMetricCardState();
}

class _AnimatedMetricCardState extends State<_AnimatedMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [
                      widget.gradient[0].withValues(alpha: 0.20),
                      widget.gradient[1].withValues(alpha: 0.10),
                    ]
                  : [
                      widget.gradient[0].withValues(alpha: 0.12),
                      widget.gradient[1].withValues(alpha: 0.06),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: widget.isDark ? 0.30 : 0.20),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: widget.isDark ? 0.18 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon + title row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.accentColor,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Value
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 3. HomePage Implementation
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

  // Bins are loaded live from Firestore inside MapPage — no hardcoded data here.
  final List<BinLocation> binLocations = [];

  // Driver position — updated by live GPS stream in MapPage.
  double driverLat = 33.6938; // G-9 Islamabad fallback
  double driverLng = 73.0651;

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
            ? '${route.routeId.substring(0, 12)}…'
            : route.routeId;
        estimatedFuel = route.estimatedFuel;
        currentStatus = 'On Route';
        // ETA = remaining travel time + collection time per stop.
        // Travel: scale total route km by fraction of stops remaining,
        //         then divide by 25 km/h average city speed.
        // Collection: 5 min per remaining stop (bin swap + loading).
        final remaining = route.totalStops - route.completedStops;
        final fraction  = route.totalStops > 0 ? remaining / route.totalStops : 0.0;
        final remKm     = route.totalDistanceKm * fraction;
        final travelMins = (remKm / 25.0 * 60).round();
        final collectMins = remaining * 5;
        final mins = travelMins + collectMins;
        estimatedTime = mins >= 60
            ? '${mins ~/ 60}h ${mins % 60}m'
            : '${mins}m';
      });
    });
  }

  /// Count critical bins visible to this worker (area-scoped).
  bool _criticalAreaMatches(String binArea, String workerArea) {
    final b = binArea.toLowerCase();
    final w = workerArea.toLowerCase();
    return b == w || b.endsWith(', $w');
  }

  void _subscribeToBinStats() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      if (!mounted) return;
      // Don't count until the user profile is loaded — first snapshot fires
      // before _user is set, which would use empty area and count everything.
      if (_isLoadingUserData) return;

      final workerArea  = (_user?.assignedArea ?? '').trim();
      final workerWaste = (_user?.assignedWasteType ?? '').toLowerCase().trim();

      // No assigned area → show 0. Proximity is too broad for a dashboard
      // count — a worker should only see bins they're responsible for.
      if (workerArea.isEmpty) {
        setState(() => criticalBinsNearby = 0);
        return;
      }

      final critical = snap.docs.where((d) {
        final data    = d.data();
        final fill    = (data['fillLevel'] ?? data['fill_level'] ?? 0) as num;
        final binArea = (data['area'] ?? data['sector'] ?? '').toString().trim();

        if (!_criticalAreaMatches(binArea, workerArea)) return false;

        if (workerWaste.isNotEmpty) {
          final binWaste =
              (data['wasteType'] ?? data['type'] ?? '').toString().toLowerCase();
          if (binWaste != workerWaste) return false;
        }

        return fill >= 90;
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
        // Re-subscribe now that we have the worker's area — the first snapshot
        // fired before user loaded used an empty area and counted all nearby bins.
        _binsSub?.cancel();
        _subscribeToBinStats();
      }
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
      _sunIcon = Icons.wb_sunny_rounded;
      _gradientColors = [AppCol.success, AppCol.primary]; // fresh teal-green
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
      _sunIcon = Icons.wb_sunny_rounded;
      _gradientColors = [AppCol.primary, AppCol.card];    // teal → card navy
    } else {
      _greeting = 'Good Evening';
      _sunIcon = Icons.nights_stay_rounded;
      _gradientColors = [AppCol.card, AppCol.primaryDark]; // deep navy evening
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

    final firstName  = _capitalize(_user!.firstName);
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
            color: Colors.black.withValues(alpha: 0.3),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimBase = isDark ? AppCol.secondary : Colors.grey.withValues(alpha: 0.2);
    final shimShine = isDark ? AppCol.card : Colors.grey.withValues(alpha: 0.1);

    return Container(
      margin: EdgeInsets.all(screenSize.width * 0.04),
      padding: EdgeInsets.all(screenSize.width * 0.04),
      decoration: BoxDecoration(
        color: shimBase,
        borderRadius: BorderRadius.circular(screenSize.width * 0.04),
      ),
      child: Row(
        children: [
          Container(
            width: screenSize.width * 0.16,
            height: screenSize.width * 0.16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shimShine,
            ),
          ),
          SizedBox(width: screenSize.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  color: shimShine,
                  margin: EdgeInsets.only(bottom: screenSize.width * 0.02),
                ),
                Container(height: 12, color: shimShine),
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
      return InactivityWrapper(
        child: SettingsPage(
          onNavigate: (page) {
            setState(() {
              currentPage = page;
            });
          },
        ),
      );
    }

    if (currentPage == 'Map') {
      return InactivityWrapper(
        child: MapPage(
          binLocations: binLocations,
          driverLat: driverLat,
          driverLng: driverLng,
          currentPage: currentPage,
          onNavigate: (page) {
            setState(() {
              currentPage = page;
            });
          },
        ),
      );
    }

    // --- ELSE, SHOW THE HOME PAGE ---
    final screenSize = MediaQuery.of(context).size;

    return InactivityWrapper(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
          backgroundColor: AppCol.primaryDark,
          elevation: 0,
          toolbarHeight: 80,
          title: Center(
            child: Image.asset(
              'assets/app_logo_2.png',
              height: 72,
              fit: BoxFit.contain,
            ),
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
    final progress           = totalBins == 0 ? 0.0 : completedBins / totalBins;
    final progressPercentage = (progress * 100).toStringAsFixed(0);
    final scheme             = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: screenSize.width * 0.5,
        height: screenSize.width * 0.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(screenSize.width * 0.5, screenSize.width * 0.5),
              painter: ProgressPainter(
                progress: progress,
                baseColor: AppCol.primary.withValues(alpha: 0.15),
                progressColor: AppCol.primary,
                strokeWidth: 12.0,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_sweep_rounded,
                  size: screenSize.width * 0.1,
                  color: AppCol.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  '$progressPercentage%',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.1,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'Route Progress',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Route Metrics Grid ---
  Widget _buildKeyRouteMetricsGrid(Size screenSize) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppCol.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Route Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _buildMetricCard(
                title: 'Route ID',
                value: routeId,
                icon: Icons.alt_route_rounded,
                accentColor: AppCol.primary,
                gradient: const [Color(0xFF0BBFC9), Color(0xFF048A7E)],
              ),
              _buildMetricCard(
                title: 'Est. Time',
                value: estimatedTime,
                icon: Icons.schedule_rounded,
                accentColor: const Color(0xFF7C6FED),
                gradient: const [Color(0xFF7C6FED), Color(0xFF4F46B8)],
              ),
              _buildMetricCard(
                title: 'Critical Bins',
                value: '$criticalBinsNearby',
                icon: Icons.crisis_alert_rounded,
                accentColor: const Color(0xFFE05C6A),
                gradient: const [Color(0xFFE05C6A), Color(0xFFA8293A)],
              ),
              _buildMetricCard(
                title: 'Fuel Est.',
                value: '${estimatedFuel.toStringAsFixed(1)} L',
                icon: Icons.local_gas_station_rounded,
                accentColor: AppCol.success,
                gradient: const [Color(0xFF1DD1A1), Color(0xFF0E9B77)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradient,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _AnimatedMetricCard(
      title: title,
      value: value,
      icon: icon,
      accentColor: accentColor,
      gradient: gradient,
      isDark: isDark,
    );
  }
}