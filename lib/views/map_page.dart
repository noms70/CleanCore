import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cc/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:cc/utils/colors.dart';
import '../models/models.dart';
import '../widgets/navbar.dart';

class MapPage extends StatefulWidget {
  final String currentPage;
  final Function(String) onNavigate;
  /// Fallback static bins shown before Firestore data loads.
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
  // ── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _initialPosition;
  bool _isLoading = true;

  // ── Bin data (live from Firestore) ────────────────────────────────────────
  List<BinLocation> _bins = [];
  BinLocation? _selectedBin;

  // ── Active route (live from Firestore 'routes' collection) ────────────────
  ActiveRoute? _activeRoute;

  // ── Services ─────────────────────────────────────────────────────────────
  final _api = ApiService();
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _binsSub;
  StreamSubscription<QuerySnapshot>? _routeSub;
  StreamSubscription<Position>? _locationSub;

  // ── Location ──────────────────────────────────────────────────────────────
  Position? _currentPosition;

  late PolylinePoints _polylinePoints;

  // ── Image picker (for bin scan) ───────────────────────────────────────────
  final _picker = ImagePicker();
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _polylinePoints = PolylinePoints(apiKey: '');
    _bins = List.from(widget.binLocations); // show static data immediately
    _setupMap();
    _subscribeToBins();
    _subscribeToActiveRoute();
  }

  @override
  void dispose() {
    _binsSub?.cancel();
    _routeSub?.cancel();
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  void _setupMap() async {
    try {
      _currentPosition = await _determinePosition();
      _initialPosition = CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14.5,
      );
      _startLocationStream();
    } catch (_) {
      _initialPosition = CameraPosition(
        target: LatLng(widget.driverLat, widget.driverLng),
        zoom: 11.5,
      );
    }
    _generateMarkers();
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Firestore: live bin updates ───────────────────────────────────────────
  void _subscribeToBins() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      final live = snap.docs
          .where((d) {
            final data = d.data();
            // Only show bins that have GPS coordinates
            return (data['lat'] != null && data['lng'] != null) ||
                data['location'] is GeoPoint;
          })
          .map((d) => BinLocation.fromFirestore(d))
          .toList();

      if (mounted) {
        setState(() {
          _bins = live.isNotEmpty ? live : widget.binLocations;
          _generateMarkers();
        });
      }
    });
  }

  // ── Firestore: active route for this driver ───────────────────────────────
  // Backend writes driverId (not workerId). Query must match exactly.
  void _subscribeToActiveRoute() {
    if (_uid == null) return;
    _routeSub = _db
        .collection('routes')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _activeRoute = snap.docs.isNotEmpty
              ? ActiveRoute.fromFirestore(snap.docs.first)
              : null;
        });
      }
    });
  }

  // ── GPS: stream location and push to backend ──────────────────────────────
  void _startLocationStream() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // call API only after moving 50 m
      ),
    ).listen((pos) {
      _currentPosition = pos;
      if (_uid != null) {
        // POST /update-worker-location — field: driver_id (not worker_id)
        _api.updateWorkerLocation(
          driverId: _uid!,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
    });
  }

  // ── Map helpers ───────────────────────────────────────────────────────────

  void _generateMarkers() {
    final markers = <Marker>{};
    for (final bin in _bins) {
      final hue = bin.isCritical
          ? BitmapDescriptor.hueRed
          : bin.fullness > 70
              ? BitmapDescriptor.hueYellow
              : BitmapDescriptor.hueGreen;
      markers.add(Marker(
        markerId: MarkerId(bin.id),
        position: LatLng(bin.lat, bin.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: bin.id,
          snippet: '${bin.fullness}% — ${bin.wasteType}',
        ),
        onTap: () => _showBinDetails(bin),
      ));
    }
    setState(() => _markers = markers);
  }

  void _onMapCreated(GoogleMapController c) => _mapController = c;

  void _recenterMap() async {
    try {
      final pos = await _determinePosition();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
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

  void _createPolyline(BinLocation bin) async {
    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : LatLng(widget.driverLat, widget.driverLng);
    final dest = LatLng(bin.lat, bin.lng);

    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=polyline';

    var coords = <LatLng>[];
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final encoded = json.decode(res.body)['routes'][0]['geometry'] as String;
        coords = PolylinePoints.decodePolyline(encoded)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }
    } catch (_) {}

    if (coords.isEmpty) coords = [origin, dest];

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_to_bin'),
          points: coords,
          color: AppCol.btnbacks,
          width: 5,
        ),
      };
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_bounds([origin, dest]), 100),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Route to ${bin.id}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLat = pts[0].latitude, maxLat = pts[0].latitude;
    double minLng = pts[0].longitude, maxLng = pts[0].longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ── Mark bin as collected ─────────────────────────────────────────────────
  // Calls POST /complete-stop with route_id and bin_id.
  // Backend increments completedStops and resets fillLevel to 0.
  Future<void> _markCollected(BinLocation bin) async {
    if (_activeRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active route. Ask your admin to generate one first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await _api.completeStop(
      routeId: _activeRoute!.routeId,
      binId: bin.id,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context); // close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bin ${bin.id} collected! '
            '${result['completed_stops']}/${result['total_stops']} stops done.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark stop. Check connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Scan bin with camera → POST /analyze/ ────────────────────────────────
  Future<void> _scanBin(BinLocation bin) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _scanning = true);
    Navigator.pop(context); // close bottom sheet while scanning

    final result = await _api.analyzeBin(
      imageFile: File(picked.path),
      binId: bin.id,
      lat: bin.lat,
      lng: bin.lng,
    );

    if (!mounted) return;
    setState(() => _scanning = false);

    if (result != null) {
      final fill = result['results']?['fill_level']?['value'] ?? 0;
      final waste = result['results']?['fill_level']?['status'] ?? '—';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: $fill% full · $waste'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan failed. Is the backend running?'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Report anomaly ────────────────────────────────────────────────────────
  Future<void> _reportAnomaly(BinLocation bin) async {
    if (_uid == null) return;
    Navigator.pop(context);

    final success = await _api.reportAnomaly(
      binId: bin.id,
      anomalyType: 'broken_bin',
      reportedBy: _uid!,
      sector: bin.area,
      priority: 'high',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Anomaly reported.' : 'Failed to report anomaly.'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  void _showBinDetails(BinLocation bin) {
    setState(() => _selectedBin = bin);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBinSheet(bin),
    );
  }

  Widget _buildBinSheet(BinLocation bin) {
    final bool isBusy = _scanning;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
          const SizedBox(height: 16),

          _detailRow('ID', bin.id),
          const SizedBox(height: 10),
          _detailRow('Area / Type', bin.wasteType),
          const SizedBox(height: 10),
          _detailRow('Status', bin.status.toUpperCase()),
          const SizedBox(height: 10),
          _detailRow('Fill Level', '${bin.fullness}%'),
          const SizedBox(height: 10),

          // Fill progress bar
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

          // Active route badge
          if (_activeRoute != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Route active · ${_activeRoute!.completedStops}/${_activeRoute!.totalStops} done',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action buttons
          if (isBusy)
            const Center(child: CircularProgressIndicator(color: AppCol.btnbacks))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Navigate to bin
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _createPolyline(bin);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate to Bin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCol.btnbacks,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Scan bin (POST /analyze/)
                OutlinedButton.icon(
                  onPressed: () => _scanBin(bin),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan Bin with AI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppCol.btnbacks,
                    side: BorderSide(color: AppCol.btnbacks),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Mark collected (POST /complete-stop)
                ElevatedButton.icon(
                  onPressed: () => _markCollected(bin),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Collected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Report anomaly (POST /report-anomaly)
                TextButton.icon(
                  onPressed: () => _reportAnomaly(bin),
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  label: const Text(
                    'Report Anomaly',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppCol.textGrey)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btntext)),
        ),
      ],
    );
  }

  Widget _buildBinTile(BinLocation bin) {
    final isSelected = _selectedBin?.id == bin.id;
    final tileColor = bin.isCritical ? Colors.red : Colors.green;
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
              bin.id.length > 10 ? bin.id.substring(0, 10) : bin.id,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btntext),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${bin.fullness}%',
              style: TextStyle(
                  fontSize: 11,
                  color: tileColor,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppCol.btnbacks))
          : _initialPosition == null
              ? const Center(
                  child: Text('Error: Could not load map. Location disabled?'))
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: _initialPosition!,
                      markers: _markers,
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      padding: const EdgeInsets.only(bottom: 10),
                    ),

                    // Re-center FAB
                    Positioned(
                      right: 16,
                      bottom: 250,
                      child: FloatingActionButton(
                        heroTag: 'recenter_btn',
                        onPressed: _recenterMap,
                        backgroundColor: Colors.white,
                        mini: true,
                        child: const Icon(Icons.my_location,
                            color: AppCol.btntext),
                      ),
                    ),

                    // Route progress banner (shown when active route exists)
                    if (_activeRoute != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.route,
                                  color: AppCol.btnbacks, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Active Route — ${(_activeRoute!.progressFraction * 100).toStringAsFixed(0)}% complete',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppCol.btntext),
                                    ),
                                    const SizedBox(height: 3),
                                    LinearProgressIndicator(
                                      value: _activeRoute!.progressFraction,
                                      minHeight: 4,
                                      backgroundColor:
                                          AppCol.btnbacks.withOpacity(0.2),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppCol.btnbacks),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_activeRoute!.completedStops}/${_activeRoute!.totalStops}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppCol.btnbacks),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Scanning overlay
                    if (_scanning)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text('Scanning bin…',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),

                    // Bin tile carousel at bottom
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90),
                        child: SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            itemCount: _bins.length,
                            itemBuilder: (_, i) => _buildBinTile(_bins[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: NavBar(
        currentPage: widget.currentPage,
        onNavigate: widget.onNavigate,
      ),
    );
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
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions permanently denied.');
    }
    return await Geolocator.getCurrentPosition();
  }
}
