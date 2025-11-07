import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cc/utils/colors.dart';
import '../widgets/navbar.dart';
import './settings_page.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GoogleMapController mapController;

  // Driver information
  String driverName = 'James Anderson';
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

  // Map markers and locations
  final List<BinLocation> binLocations = [
    BinLocation(
      id: 'BIN_001',
      lat: 40.7128,
      lng: -74.0060,
      fullness: 95,
      isCritical: true,
      area: 'Downtown A',
      status: 'Critical',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_002',
      lat: 40.7150,
      lng: -74.0050,
      fullness: 45,
      isCritical: false,
      area: 'Downtown B',
      status: 'Normal',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_003',
      lat: 40.7160,
      lng: -74.0040,
      fullness: 98,
      isCritical: true,
      area: 'Downtown C',
      status: 'Critical',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_004',
      lat: 40.7140,
      lng: -74.0070,
      fullness: 35,
      isCritical: false,
      area: 'Downtown D',
      status: 'Normal',
      capacity: 240,
    ),
    BinLocation(
      id: 'BIN_005',
      lat: 40.7135,
      lng: -74.0045,
      fullness: 92,
      isCritical: true,
      area: 'Downtown E',
      status: 'Critical',
      capacity: 240,
    ),
  ];

  Set<Marker> _markers = {};
  BinLocation? selectedBin;
  Set<Polyline> _polylines = {};
  double driverLat = 40.7145;
  double driverLng = -74.0055;

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
  Map<String, dynamic>? _cachedUserData;
  late List<Color> _gradientColors;
  late IconData _sunIcon;
  late String _greeting;

  @override
  void initState() {
    super.initState();
    _generateMarkers();
    _initializeUserData();
  }

  void _initializeUserData() {
    // Simulate loading user data (replace with actual data fetch)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _cachedUserData = {
            'firstName': 'James',
            'lastName': 'Anderson',
            'profilePicture': '', // Empty for now, can be populated later
          };
          _isLoadingUserData = false;
          _updateGreeting();
        });
      }
    });
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
    if (_isLoadingUserData && _cachedUserData == null) {
      return _buildUserInfoSkeleton(screenSize);
    }

    final userData = _cachedUserData ?? {};
    final firstName = _capitalize(
      userData['firstName'] ?? userData['name'] ?? '',
    );
    final lastName = _capitalize(userData['lastName'] ?? '');
    final profilePicUrl = userData['profilePicture'] as String? ?? '';

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
          Container(
            width: screenSize.width * 0.13,
            height: screenSize.width * 0.13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF6F8F7), width: 3.0),
            ),
            child: profilePicUrl.isNotEmpty
                ? (profilePicUrl.startsWith('http')
                      ? ClipOval(
                          child: Image.network(
                            profilePicUrl,
                            fit: BoxFit.cover,
                            cacheWidth: (screenSize.width * 0.16).round(),
                            cacheHeight: (screenSize.width * 0.16).round(),
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: const Color(0xFF8DB930),
                                child: Text(
                                  firstName.isNotEmpty ? firstName[0] : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenSize.width * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : ClipOval(
                          child: Image.file(
                            File(profilePicUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: AppCol.btnbacks,
                                child: Text(
                                  firstName.isNotEmpty ? firstName[0] : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenSize.width * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ))
                : CircleAvatar(
                    backgroundColor: AppCol.btnbacks,
                    child: Text(
                      firstName.isNotEmpty ? firstName[0] : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenSize.width * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  void _generateMarkers() {
    Set<Marker> markers = {};

    for (var bin in binLocations) {
      Color markerColor;
      if (bin.isCritical) {
        markerColor = Colors.red;
      } else if (bin.fullness > 70) {
        markerColor = Colors.yellow;
      } else {
        markerColor = Colors.green;
      }

      markers.add(
        Marker(
          markerId: MarkerId(bin.id),
          position: LatLng(bin.lat, bin.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            markerColor == Colors.red
                ? BitmapDescriptor.hueRed
                : markerColor == Colors.yellow
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: bin.id,
            snippet: '${bin.fullness}% Full - ${bin.area}',
          ),
          onTap: () {
            _showBinDetails(bin);
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
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

  void _createRoute(BinLocation bin) {
    List<LatLng> routePoints = [
      LatLng(driverLat, driverLng),
      LatLng(bin.lat, bin.lng),
    ];

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_to_bin'),
          points: routePoints,
          color: AppCol.btnbacks,
          width: 5,
        ),
      };
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(_getBounds(routePoints), 100),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Route created to ${bin.id}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showBinDetails(BinLocation bin) {
    setState(() {
      selectedBin = bin;
    });
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBinDetailsSheet(bin),
    );
  }

  Widget _buildBinDetailsSheet(BinLocation bin) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Bin Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btntext,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow('ID', bin.id),
          const SizedBox(height: 12),
          _buildDetailRow('Area', bin.area),
          const SizedBox(height: 12),
          _buildDetailRow('Status', bin.status),
          const SizedBox(height: 12),
          _buildDetailRow('Fullness', '${bin.fullness}%'),
          const SizedBox(height: 12),
          _buildDetailRow('Capacity', '${bin.capacity}L'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: bin.fullness / 100,
              minHeight: 8,
              backgroundColor: AppCol.btnbacks.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                bin.isCritical ? Colors.red : AppCol.btnbacks,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createRoute(bin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppCol.btnbacks,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Create Route to Bin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btnbacke,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppCol.textGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppCol.btntext,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPage == 'settings') {
      return SettingsPage(
        onNavigate: (page) {
          setState(() {
            currentPage = page;
          });
        },
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true, // <-- ADD THIS LINE
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // IconButton(
            //   icon: const Icon(Icons.menu, color: Colors.black, size: 28),
            //   onPressed: () {
            //     // Hamburger menu action
            //   },
            // ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Center(
                  child: Image.asset(
                    'assets/cc_logo2.png',
                    height: 55,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // Spacer to balance the layout
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildUserInfo(context, screenSize),
              Expanded(
                flex: 2,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(40.7145, -74.0055),
                    zoom: 15.5,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
              Container(
                height: 140,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: binLocations.length,
                  itemBuilder: (context, index) {
                    final bin = binLocations[index];
                    return _buildBinTile(bin);
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildRouteSummary(),
                      const SizedBox(height: 16),
                      _buildKPIs(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildBinTile(BinLocation bin) {
    bool isSelected = selectedBin?.id == bin.id;
    Color tileColor = bin.isCritical ? Colors.red : Colors.green;

    return GestureDetector(
      onTap: () => _showBinDetails(bin),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppCol.btnbacks : tileColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tileColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: tileColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              bin.id,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppCol.btntext,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${bin.fullness}%',
              style: TextStyle(
                fontSize: 11,
                color: tileColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
          ...alerts.map((alert) => _buildAlertCard(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.type == 'success'
            ? Colors.green.withOpacity(0.1)
            : alert.type == 'warning'
            ? Colors.orange.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alert.type == 'success'
              ? Colors.green.withOpacity(0.3)
              : alert.type == 'warning'
              ? Colors.orange.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.icon,
            color: alert.type == 'success'
                ? Colors.green
                : alert.type == 'warning'
                ? Colors.orange
                : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppCol.btntext,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(fontSize: 12, color: AppCol.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildKPICard(
              'Efficiency',
              '$efficiencyScore%',
              Icons.trending_up,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKPICard(
              'Capacity',
              '$capacityUsage%',
              Icons.local_shipping,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(
    String label,
    String value,
    IconData icon,
    Color accentColor, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppCol.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppCol.btntext,
            ),
          ),
        ],
      ),
    );
  }
}

class BinLocation {
  final String id;
  final double lat;
  final double lng;
  final int fullness;
  final bool isCritical;
  final String area;
  final String status;
  final int capacity;

  BinLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.fullness,
    required this.isCritical,
    required this.area,
    required this.status,
    required this.capacity,
  });
}

class Alert {
  final String title;
  final String message;
  final String type; // 'info', 'success', 'warning'
  final IconData icon;

  Alert({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
  });
}
