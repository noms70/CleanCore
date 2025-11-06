import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cc/utils/colors.dart';
import '../widgets/navbar.dart';
import './settings_page.dart';

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
    ),
    BinLocation(
      id: 'BIN_002',
      lat: 40.7150,
      lng: -74.0050,
      fullness: 45,
      isCritical: false,
    ),
    BinLocation(
      id: 'BIN_003',
      lat: 40.7160,
      lng: -74.0040,
      fullness: 98,
      isCritical: true,
    ),
    BinLocation(
      id: 'BIN_004',
      lat: 40.7140,
      lng: -74.0070,
      fullness: 35,
      isCritical: false,
    ),
    BinLocation(
      id: 'BIN_005',
      lat: 40.7135,
      lng: -74.0045,
      fullness: 92,
      isCritical: true,
    ),
  ];

  Set<Marker> _markers = {};

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

  @override
  void initState() {
    super.initState();
    _generateMarkers();
  }

  void _generateMarkers() {
    Set<Marker> markers = {};

    for (var bin in binLocations) {
      markers.add(
        Marker(
          markerId: MarkerId(bin.id),
          position: LatLng(bin.lat, bin.lng),
          icon: bin.isCritical
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
          infoWindow: InfoWindow(
            title: bin.id,
            snippet: '${bin.fullness}% Full',
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartEnds Driver Dashboard'),
        elevation: 0,
        backgroundColor: AppCol.btnbacks,
        foregroundColor: AppCol.btnbacke,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome & Status Banner
            _buildWelcomeBanner(),

            // Quick Start Button
            _buildQuickStartButton(),

            // Google Maps Section - added interactive map with bin locations
            _buildMapSection(),

            // Route Summary
            _buildRouteSummary(),

            // Alerts & Notifications
            _buildAlerts(),

            // Performance Metrics KPIs
            _buildKPIs(),

            const SizedBox(height: 20),
          ],
        ),
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

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
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
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(40.7145, -74.0055),
                  zoom: 15.5,
                ),
                markers: _markers,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppCol.btnbacks,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Route Map Overview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppCol.btntext,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$criticalBinsNearby Critical',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Critical Bins (95%+)',
                        style: TextStyle(fontSize: 11, color: AppCol.textGrey),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Standard Bins',
                        style: TextStyle(fontSize: 11, color: AppCol.textGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      decoration: BoxDecoration(gradient: AppCol.headerback),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${getGreeting()}, $driverName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppCol.btntext,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: getStatusColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      currentStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateTime.now().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: AppCol.btntext),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppCol.btncol,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppCol.btnbacks.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                currentStatus = 'On Route';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Route started! Safe travels.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    currentStatus == 'Offline'
                        ? 'Start Today\'s Route'
                        : 'Route in Progress',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppCol.btntext,
            ),
          ),
          const SizedBox(height: 12),
          Row(
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
                  'Distance Saved',
                  '${distanceSaved}km',
                  Icons.directions_car,
                  AppCol.btnbacks,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'Truck Capacity',
            '$capacityUsage%',
            Icons.local_shipping,
            Colors.orange,
            isFullWidth: true,
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

  BinLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.fullness,
    required this.isCritical,
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
