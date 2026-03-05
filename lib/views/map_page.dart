import 'package:cc/services/route_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/widgets/navbar.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/models.dart';

/// MapPage is a purely presentational widget.
/// All routing / sorting logic lives in [RouteService].
class MapPage extends StatefulWidget {
  final String currentPage;
  final Function(String) onNavigate;
  final List<BinLocation> binLocations;
  final double driverLat;
  final double driverLng;

  const MapPage({
    super.key,
    required this.currentPage,
    required this.onNavigate,
    required this.binLocations,
    required this.driverLat,
    required this.driverLng,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // ─── Map & Location ──────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  CameraPosition? _initialPosition;
  Position? _currentPosition;
  bool _isMapLoading = true;

  // ─── Route State ─────────────────────────────────────────────────────────
  /// Bins sorted by priority (critical first, then fullness descending)
  late List<BinLocation> _sortedBins;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isRouteLoading = false;
  bool _routeBuilt = false;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sortedBins = RouteService.sortByPriority(widget.binLocations);
    _setupMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Setup ───────────────────────────────────────────────────────────────

  Future<void> _setupMap() async {
    try {
      _currentPosition = await _determinePosition();
      _initialPosition = CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 13.0,
      );
    } catch (_) {
      _initialPosition = CameraPosition(
        target: LatLng(widget.driverLat, widget.driverLng),
        zoom: 12.0,
      );
    }

    _buildMarkers();
    setState(() => _isMapLoading = false);
  }

  // ─── Markers ─────────────────────────────────────────────────────────────

  void _buildMarkers() {
    final Set<Marker> markers = {};

    // Numbered bin markers
    for (int i = 0; i < _sortedBins.length; i++) {
      final bin = _sortedBins[i];
      final double hue = bin.isCritical
          ? BitmapDescriptor.hueRed
          : bin.fullness > 70
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueGreen;

      markers.add(
        Marker(
          markerId: MarkerId(bin.id),
          position: LatLng(bin.lat, bin.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}: ${bin.id}',
            snippet: '${bin.fullness}% full — ${bin.area}',
          ),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  // ─── Route ───────────────────────────────────────────────────────────────

  Future<void> _buildCollectionRoute() async {
    setState(() => _isRouteLoading = true);

    final LatLng origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : LatLng(widget.driverLat, widget.driverLng);

    final polylinePoints = await RouteService.buildCollectionRoute(
      origin: origin,
      waypoints: _sortedBins,
    );

    final allPoints = [origin, ...polylinePoints];
    final bounds = RouteService.getBounds(allPoints);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('collection_route'),
          points: polylinePoints,
          color: AppCol.btnbacks,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
      _routeBuilt = true;
      _isRouteLoading = false;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 70),
    );
  }

  // ─── Location ────────────────────────────────────────────────────────────

  Future<void> _recenterMap() async {
    try {
      final pos = await _determinePosition();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return Geolocator.getCurrentPosition();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _isMapLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppCol.btnbacks),
            )
          : _initialPosition == null
              ? const Center(
                  child: Text('Error: Could not load map. Location disabled?'),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (c) => _mapController = c,
                      initialCameraPosition: _initialPosition!,
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      style: Theme.of(context).brightness == Brightness.dark
                          ? '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#263c3f"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6b9a76"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#38414e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212a37"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca5b3"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1f2835"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d19c"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2f3948"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#515c6d"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  }
]
'''
                          : null,
                      padding: const EdgeInsets.only(bottom: 10),
                    ),

                    // ── Top header card ──────────────────────────────────
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 16,
                      right: 16,
                      child: _buildRouteHeaderCard(),
                    ),

                    // ── Recenter FAB ─────────────────────────────────────
                    Positioned(
                      right: 16,
                      bottom: 400,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter_btn',
                        onPressed: _recenterMap,
                        backgroundColor: Theme.of(context).cardColor,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppCol.btnbacke,
                        ),
                      ),
                    ),

                    // ── Bottom collection panel ───────────────────────────
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 90, // sits just above the navbar
                      child: _buildCollectionPanel(),
                    ),
                  ],
                ),
      bottomNavigationBar: NavBar(
        currentPage: widget.currentPage,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  // ─── UI Helpers ──────────────────────────────────────────────────────────

  Widget _buildRouteHeaderCard() {
    final criticalCount = _sortedBins.where((b) => b.isCritical).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppCol.btnbacks.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppCol.btnbacks,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection Route',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppCol.btnbacke,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_sortedBins.length} stops · $criticalCount critical',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (criticalCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$criticalCount',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black12,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Start Route button
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isRouteLoading ? null : _buildCollectionRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppCol.btnbacks,
                  foregroundColor: AppCol.btnbacke,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: _isRouteLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppCol.btnbacke,
                        ),
                      )
                    : Icon(
                        _routeBuilt
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded,
                        size: 22,
                      ),
                label: Text(
                  _isRouteLoading
                      ? 'Building Route…'
                      : _routeBuilt
                          ? 'Recalculate Route'
                          : 'Start Collection Route',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),

          // Bin list — plain Column so the panel hugs content with no empty gap
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _sortedBins.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
                  _buildBinListItem(_sortedBins[i], i + 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinListItem(BinLocation bin, int stopNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3D1F23) : const Color(0xFFFEECEE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stopNumber',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bin.id,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppCol.btnbacke,
                  ),
                ),
                Text(
                  bin.area,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3D1F23) : const Color(0xFFFEECEE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${bin.fullness}%',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          if (bin.isCritical) ...[
            const SizedBox(width: 6),
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 16),
          ],
        ],
      ),
    );
  }
}
