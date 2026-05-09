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
import 'package:url_launcher/url_launcher.dart';

import 'package:cc/utils/colors.dart';
import '../models/models.dart';
import '../widgets/navbar.dart';
import './route_job_screen.dart';

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

  // ── Bin data (live from Firestore — filtered by worker assignment) ───────
  List<BinLocation> _bins = [];
  BinLocation? _selectedBin;

  // Raw Firestore docs — stored so any position update can re-filter without
  // waiting for a new Firestore snapshot.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rawBinDocs = [];

  // Workers within 10 km see bins when no assignedArea is set.
  static const double _proximityRadiusM = 10000;

  // Worker assignment — loaded once from Firestore so the bin query can filter
  String _assignedArea = '';
  String _assignedWasteType = '';

  // ── Active route (live from Firestore 'routes' collection) ────────────────
  ActiveRoute? _activeRoute;

  // ── Urgent bin alert ──────────────────────────────────────────────────────
  // Tracks bins we've already shown an alert for (prevents repeat alerts)
  final Set<String> _notifiedUrgentBins = {};
  BinLocation? _urgentAlertBin; // currently shown alert, null = no alert
  bool _reoptimizing = false;

  // ── Reverse-geocoded display names for bin tiles ──────────────────────────
  final Map<String, String> _binLocationNames = {};

  // ── Services ─────────────────────────────────────────────────────────────
  final _api = ApiService();
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _binsSub;
  StreamSubscription<QuerySnapshot>? _routeSub;
  StreamSubscription<QuerySnapshot>? _urgentSub;
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
    _bins = List.from(widget.binLocations);
    _setupMap();
    _loadProfileThenSubscribeToBins(); // loads assignment filters first
    _subscribeToActiveRoute();
    _subscribeToUrgentBins();
  }

  @override
  void dispose() {
    _binsSub?.cancel();
    _routeSub?.cancel();
    _urgentSub?.cancel();
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
      // Bins may have loaded before GPS was ready — re-filter now that we
      // have a position, but only when there is no explicit area assignment.
      if (_assignedArea.isEmpty && _rawBinDocs.isNotEmpty) {
        _applyBinFilter();
      }
    } catch (_) {
      _initialPosition = CameraPosition(
        target: LatLng(widget.driverLat, widget.driverLng),
        zoom: 11.5,
      );
    }
    _generateMarkers();
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Firestore: load worker profile then subscribe to filtered bins ────────
  // Workers only see bins in their assignedArea + assignedWasteType so they
  // are not overwhelmed with irrelevant stops on the map.
  Future<void> _loadProfileThenSubscribeToBins() async {
    if (_uid != null) {
      try {
        final doc = await _db.collection('users').doc(_uid).get();
        if (doc.exists) {
          final d = doc.data()!;
          _assignedArea      = (d['assignedArea']      as String? ?? '').trim();
          _assignedWasteType = (d['assignedWasteType'] as String? ?? '').trim();
        }
      } catch (_) {}
    }
    _subscribeToBins();
  }

  // ── Firestore: live bin updates (filtered by worker assignment) ───────────
  void _subscribeToBins() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      _rawBinDocs = snap.docs;
      _applyBinFilter();
    });
  }

  // Re-applies the current filter against the cached raw docs and updates state.
  // Called on every new Firestore snapshot AND on significant GPS movement.
  void _applyBinFilter() {
    final filtered = _buildFilteredBins(_rawBinDocs);
    if (mounted) {
      setState(() {
        _bins = filtered;
        _generateMarkers();
      });
      _fetchBinNamesForNewBins(filtered);
    }
  }

  // Reverse-geocodes each bin that isn't already in the cache, 250 ms apart
  // to stay within Nominatim's 1-req/sec policy.
  Future<void> _fetchBinNamesForNewBins(List<BinLocation> bins) async {
    final newBins = bins.where((b) => !_binLocationNames.containsKey(b.id)).toList();
    for (final bin in newBins) {
      if (!mounted) return;
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${bin.lat}&lon=${bin.lng}',
        );
        final resp = await http.get(uri, headers: {'User-Agent': 'CleanCore/1.0'});
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          final topName = (data['name'] as String?)?.trim() ?? '';
          final name = topName.isNotEmpty
              ? topName
              : (addr['amenity'] as String?)?.trim() ??
                (addr['shop'] as String?)?.trim() ??
                (addr['building'] as String?)?.trim() ??
                (addr['road'] as String?)?.trim() ??
                (addr['suburb'] as String?)?.trim();
          if (name != null && name.isNotEmpty && mounted) {
            setState(() => _binLocationNames[bin.id] = name);
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  // Returns the subset of raw docs visible to this worker.
  // • Assigned workers  → strict area + waste-type match (existing behaviour).
  // • Unassigned workers → bins within _proximityRadiusM of current GPS.
  // • No GPS yet         → show everything so the map isn't empty on first load.
  List<BinLocation> _buildFilteredBins(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((d) {
      final data = d.data();

      final binLat = _getBinLat(data);
      final binLng = _getBinLng(data);
      if (binLat == null || binLng == null) return false;

      if (_assignedArea.isNotEmpty) {
        final binArea = (data['area'] ?? data['sector'] ?? '').toString().trim();
        if (binArea != _assignedArea) return false;
      } else if (_currentPosition != null) {
        final distM = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          binLat,
          binLng,
        );
        if (distM > _proximityRadiusM) return false;
      }

      if (_assignedWasteType.isNotEmpty) {
        final binWaste =
            (data['wasteType'] ?? data['waste_type'] ?? data['type'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        if (binWaste != _assignedWasteType.toLowerCase()) return false;
      }

      return true;
    }).map((d) => BinLocation.fromFirestore(d)).toList();
  }

  double? _getBinLat(Map<String, dynamic> data) {
    if (data['lat'] != null) return (data['lat'] as num).toDouble();
    if (data['location'] is GeoPoint) {
      return (data['location'] as GeoPoint).latitude;
    }
    return null;
  }

  double? _getBinLng(Map<String, dynamic> data) {
    if (data['lng'] != null) return (data['lng'] as num).toDouble();
    if (data['location'] is GeoPoint) {
      return (data['location'] as GeoPoint).longitude;
    }
    return null;
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
      if (!mounted) return;
      setState(() {
        _activeRoute = snap.docs.isNotEmpty
            ? ActiveRoute.fromFirestore(snap.docs.first)
            : null;
        if (_activeRoute == null) _polylines.clear();
      });
      if (_activeRoute != null) _fetchAndDrawRoutePolyline();
    });
  }

  // ── OSRM road-based polyline ──────────────────────────────────────────────
  // Fetches the actual road route from the worker's current position through
  // every pending stop in order. Re-called whenever the route changes or the
  // driver moves (50 m trigger in _startLocationStream).
  Future<void> _fetchAndDrawRoutePolyline() async {
    if (_activeRoute == null) return;

    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : LatLng(widget.driverLat, widget.driverLng);

    final pending = _activeRoute!.stops.where((s) => !s.completed).toList();
    if (pending.isEmpty) {
      if (mounted) setState(() => _polylines.clear());
      return;
    }

    final waypoints = [origin, ...pending.map((s) => LatLng(s.lat, s.lng))];
    final coordStr =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url =
        'http://router.project-osrm.org/route/v1/driving/$coordStr'
        '?overview=full&geometries=polyline';

    var coords = <LatLng>[];
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok' && (body['routes'] as List).isNotEmpty) {
          final encoded = (body['routes'] as List)[0]['geometry'] as String;
          coords = PolylinePoints.decodePolyline(encoded)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback: straight lines when OSRM is unreachable
    if (coords.isEmpty) coords = waypoints;

    if (!mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('active_route'),
          points: coords,
          color: AppCol.btnbacks,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });
  }

  // ── Urgent bin real-time alert ─────────────────────────────────────────────
  // Listens for bins with fillLevel >= 90 that are not yet locked to a route.
  // When a new one appears in the worker's area, shows an alert banner.
  void _subscribeToUrgentBins() {
    if (_uid == null) return;
    _urgentSub = _db
        .collection('bins')
        .where('fillLevel', isGreaterThanOrEqualTo: 90)
        .where('isLocked', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docChanges) {
        // Only react to newly added or modified-to-urgent bins
        if (doc.type == DocumentChangeType.added ||
            doc.type == DocumentChangeType.modified) {
          final binId = doc.doc.id;
          if (_notifiedUrgentBins.contains(binId)) continue;

          final data = doc.doc.data() as Map<String, dynamic>;
          final binArea = (data['area'] ?? data['sector'] ?? '').toString().trim();
          if (_assignedArea.isNotEmpty) {
            if (binArea.isNotEmpty && binArea != _assignedArea) continue;
          } else if (_currentPosition != null) {
            final binLat = _getBinLat(data);
            final binLng = _getBinLng(data);
            if (binLat != null && binLng != null) {
              final distM = Geolocator.distanceBetween(
                _currentPosition!.latitude, _currentPosition!.longitude,
                binLat, binLng,
              );
              if (distM > _proximityRadiusM) continue;
            }
          }

          _notifiedUrgentBins.add(binId);
          final urgent = BinLocation.fromFirestore(doc.doc);
          setState(() => _urgentAlertBin = urgent);
          // Auto-dismiss after 10 seconds
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted && _urgentAlertBin?.id == binId) {
              setState(() => _urgentAlertBin = null);
            }
          });
          break; // show one at a time
        }
      }
    });
  }

  // ── Insert an urgent bin as the next stop in the existing active route ─────
  // Does NOT call optimizeRoute() — that would replace the whole route because
  // the original bins are isLocked=true and the backend ignores them.
  Future<void> _addBinToRoute(BinLocation bin) async {
    final route = _activeRoute;
    if (route == null || _uid == null) return;

    setState(() { _reoptimizing = true; _urgentAlertBin = null; });

    try {
      // Serialize current stops back to maps (preserving completed flags)
      final updatedStops = route.stops.map((s) => <String, dynamic>{
        'binId':     s.binId,
        'lat':       s.lat,
        'lng':       s.lng,
        'fillLevel': s.fillLevel,
        'wasteType': s.wasteType,
        'area':      s.area,
        'completed': s.completed,
      }).toList();

      // Guard: don't add if already present
      if (updatedStops.any((s) => s['binId'] == bin.id)) {
        if (mounted) setState(() => _reoptimizing = false);
        return;
      }

      final newStop = <String, dynamic>{
        'binId':     bin.id,
        'lat':       bin.lat,
        'lng':       bin.lng,
        'fillLevel': bin.fullness,
        'wasteType': bin.wasteType,
        'area':      bin.area,
        'completed': false,
      };

      // Insert right before the first pending stop so it becomes the next pickup
      final firstPendingIdx = updatedStops.indexWhere((s) => s['completed'] == false);
      if (firstPendingIdx >= 0) {
        updatedStops.insert(firstPendingIdx, newStop);
      } else {
        updatedStops.add(newStop);
      }

      // Patch the route document — _subscribeToActiveRoute will redraw the polyline
      await _db.collection('routes').doc(route.routeId).update({
        'stops':      updatedStops,
        'totalStops': route.totalStops + 1,
      });

      // Lock the bin so other routes don't claim it
      await _db.collection('bins').doc(bin.id).update({'isLocked': true});
    } catch (_) {
      // Firestore write failed — route is unchanged, no action needed
    }

    if (mounted) setState(() => _reoptimizing = false);
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
      // For unassigned workers the visible bins depend on position —
      // re-filter so the map reflects their latest location.
      if (_assignedArea.isEmpty && _rawBinDocs.isNotEmpty) {
        _applyBinFilter();
      }
      // Re-draw the road polyline from the driver's new position.
      if (_activeRoute != null) _fetchAndDrawRoutePolyline();
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

  // ── Dark map style ────────────────────────────────────────────────────────
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#64779e"}]},
  {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
  {"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3C7680"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
  {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023e58"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"transit","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit.line","elementType":"geometry.fill","stylers":[{"color":"#283d6a"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      c.setMapStyle(_darkMapStyle);
    }
  }

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

  // ── Open stop in Google Maps via geo: deep link ───────────────────────────
  Future<void> _openInGoogleMaps(BinLocation bin) async {
    final uri      = Uri.parse('geo:${bin.lat},${bin.lng}?q=${bin.lat},${bin.lng}');
    final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${bin.lat},${bin.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  // ── Mark bin as collected ─────────────────────────────────────────────────
  // Calls POST /complete-stop with route_id and bin_id.
  // Backend increments completedStops and resets fillLevel to 0.
  Future<void> _markCollected(BinLocation bin) async {
    if (_activeRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active route. Tap "My Route" to generate one first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await _api.completeStop(
      routeId:  _activeRoute!.routeId,
      binId:    bin.id,
      workerId: _uid ?? '',
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
  Future<void> _viewBinImage(BinLocation bin) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Bin ${bin.id.length > 14 ? '${bin.id.substring(0, 14)}…' : bin.id}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        content: FutureBuilder<DocumentSnapshot>(
          future: _db.collection('bins').doc(bin.id).get(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: AppCol.btnbacks)),
              );
            }
            final data = snap.data?.data() as Map<String, dynamic>?;
            final preview = data?['imagePreview'] as String? ?? '';
            if (preview.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'No image available.\nScan this bin with AI to capture one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(preview),
                fit: BoxFit.contain,
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppCol.btnbacks)),
          ),
        ],
      ),
    );
  }

  // ── Image source picker (camera or gallery) ──────────────────────────────
  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Image Source',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Scan bin with AI → POST /analyze/ ────────────────────────────────────
  Future<void> _scanBin(BinLocation bin) async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _scanning = true);
    Navigator.pop(context); // close bottom sheet while scanning

    // Read image bytes (works on both web and mobile)
    final bytes = await picked.readAsBytes();

    final result = await _api.analyzeBin(
      imageBytes: bytes,
      imageName: picked.name,
      binId: bin.id,                  // updates existing Firestore doc
      area: _assignedArea.isNotEmpty  // keeps bin in the worker's routing pool
          ? _assignedArea
          : bin.area,
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

  // ── Report anomaly with type picker ─────────────────────────────────────
  Future<void> _reportAnomaly(BinLocation bin) async {
    if (_uid == null) return;
    Navigator.pop(context); // close bin sheet first

    const types = [
      {'key': 'broken_bin',   'label': 'Broken Bin',      'priority': 'high'},
      {'key': 'blocked_road', 'label': 'Blocked Road',     'priority': 'high'},
      {'key': 'overflowing',  'label': 'Overflowing',      'priority': 'high'},
      {'key': 'inaccessible', 'label': 'Inaccessible',     'priority': 'medium'},
      {'key': 'vandalism',    'label': 'Vandalism/Damage', 'priority': 'medium'},
      {'key': 'other',        'label': 'Other Issue',      'priority': 'low'},
    ];

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Report Issue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              'Bin ${bin.id.length > 12 ? '${bin.id.substring(0, 12)}…' : bin.id}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...types.map((t) => ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: t['priority'] == 'high'
                    ? Colors.red
                    : t['priority'] == 'medium'
                        ? Colors.orange
                        : Colors.grey,
              ),
              title: Text(t['label'] as String),
              dense: true,
              onTap: () => Navigator.pop(ctx, t),
            )),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final success = await _api.reportAnomaly(
      binId:       bin.id,
      anomalyType: selected['key'] as String,
      reportedBy:  _uid!,
      sector:      bin.area,
      priority:    selected['priority'] as String,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Issue reported: ${selected['label']}'
            : 'Failed to report issue.'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  // ── Check if a bin is a completed stop on the active route ──────────────
  bool _isBinCompleted(String binId) {
    if (_activeRoute == null) return false;
    return _activeRoute!.stops.any(
      (s) => s.binId == binId && s.completed,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppCol.primaryDark : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Bin Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppCol.btntext,
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
            _detailRow(
              'Status',
              _isBinCompleted(bin.id) ? 'COMPLETED' : _getStatusText(bin.fullness),
            ),
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

            // Completed badge — shown when this bin is a done stop on the active route
            if (_isBinCompleted(bin.id)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Collected — this stop is done',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_activeRoute != null) ...[
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
                  // Show Route Plan on Map
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _focusOnRoute();
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Show Route Plan on Map'),
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
                  OutlinedButton.icon(
                    onPressed: () => _viewBinImage(bin),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('View Bin'),
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
                  // Mark Complete (disabled if already done)
                  ElevatedButton.icon(
                    onPressed: _isBinCompleted(bin.id) ? null : () => _markCollected(bin),
                    icon: Icon(
                      _isBinCompleted(bin.id)
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      _isBinCompleted(bin.id) ? 'Already Completed' : 'Mark Complete',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBinCompleted(bin.id)
                          ? Colors.grey.shade300
                          : Colors.green,
                      foregroundColor: _isBinCompleted(bin.id)
                          ? Colors.grey.shade600
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Report Issue
                  OutlinedButton.icon(
                    onPressed: () => _reportAnomaly(bin),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    label: const Text('Report Issue',
                        style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: isDark ? Colors.grey.shade400 : AppCol.textGrey,
          fontSize: 14,
        )),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppCol.btntext,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText(int fullness) {
    if (fullness <= 30) return 'EMPTY';
    if (fullness <= 70) return 'NORMAL';
    if (fullness < 90) return 'FULL';
    return 'OVERFLOW';
  }

  void _focusOnRoute() {
    if (_activeRoute == null || _activeRoute!.stops.isEmpty) return;
    
    final points = _activeRoute!.stops.map((s) => LatLng(s.lat, s.lng)).toList();
    if (_currentPosition != null) {
      points.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_bounds(points), 50),
    );
  }

  Widget _buildBinTile(BinLocation bin) {
    final isSelected = _selectedBin?.id == bin.id;
    final tileColor = bin.isCritical ? Colors.red : Colors.green;

    // Determine status label & color based on fill level
    final String statusLabel;
    final Color statusColor;
    if (bin.fullness >= 90) {
      statusLabel = 'CRITICAL';
      statusColor = Colors.red;
    } else if (bin.fullness > 70) {
      statusLabel = 'HIGH';
      statusColor = Colors.orange;
    } else if (bin.fullness > 30) {
      statusLabel = 'NORMAL';
      statusColor = Colors.green;
    } else {
      statusLabel = 'LOW';
      statusColor = const Color(0xFF0BBFC9);
    }

    // Gradient for the accent strip at top
    final List<Color> accentGradient = bin.isCritical
        ? [Colors.red.shade400, Colors.red.shade700]
        : bin.fullness > 70
            ? [Colors.orange.shade300, Colors.orange.shade600]
            : [const Color(0xFF0BBFC9), const Color(0xFF048A7E)];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(bin.lat, bin.lng), zoom: 17),
          ),
        );
        _showBinDetails(bin);
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppCol.card : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppCol.btnbacks
                : isDark ? AppCol.secondary : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: (bin.isCritical
                      ? Colors.red
                      : isSelected
                          ? AppCol.btnbacks
                          : Colors.black)
                  .withOpacity(bin.isCritical ? 0.18 : 0.08),
              blurRadius: bin.isCritical ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient accent strip ──
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: accentGradient),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Radial fill gauge ──
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: bin.fullness / 100,
                              strokeWidth: 3.5,
                              backgroundColor: isDark ? AppCol.secondary : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor),
                            ),
                          ),
                          Icon(Icons.delete_outline,
                              color: statusColor, size: 18),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ── Location name (resolved via reverse geocoding, else bin ID) ──
                    Text(
                      _binLocationNames[bin.id] ?? bin.id,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppCol.btntext,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),

                    const SizedBox(height: 4),

                    // ── Status chip with percentage ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${bin.fullness}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: statusColor.withOpacity(0.7),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppCol.card : Colors.white,
                        mini: true,
                        child: Icon(Icons.my_location, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppCol.btntext),
                      ),
                    ),

                    // My Route — opens RouteJobScreen
                    Positioned(
                      left: 16,
                      bottom: 250,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RouteJobScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? AppCol.card : Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: AppCol.btncol,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.route_rounded, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'My Route',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppCol.btntext,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            color: Theme.of(context).brightness == Brightness.dark ? AppCol.card : Colors.white,
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
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppCol.btntext),
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

                    // Urgent bin alert banner (slides in below route banner)
                    if (_urgentAlertBin != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top +
                            (_activeRoute != null ? 72 : 8),
                        left: 16,
                        right: 16,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Urgent Pickup Needed!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Bin ${_urgentAlertBin!.id.length > 14 ? '${_urgentAlertBin!.id.substring(0, 14)}…' : _urgentAlertBin!.id} '
                                        'is overflowing (${_urgentAlertBin!.fullness}%). '
                                        'Ready to collect!',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Re-route button — only shown when a route is already active
                                    if (_activeRoute != null)
                                      GestureDetector(
                                        onTap: _reoptimizing ? null : () => _addBinToRoute(_urgentAlertBin!),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: _reoptimizing
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: Colors.white),
                                                )
                                              : const Text(
                                                  'Re-route',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                        ),
                                      ),
                                    if (_activeRoute != null)
                                      const SizedBox(height: 4),
                                    // Navigate to bin on map
                                    GestureDetector(
                                      onTap: () {
                                        final bin = _urgentAlertBin!;
                                        setState(() => _urgentAlertBin = null);
                                        _mapController?.animateCamera(
                                          CameraUpdate.newCameraPosition(
                                            CameraPosition(
                                              target: LatLng(bin.lat, bin.lng),
                                              zoom: 16,
                                            ),
                                          ),
                                        );
                                        _showBinDetails(bin);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'View',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                // Dismiss
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _urgentAlertBin = null),
                                  child: const Icon(Icons.close,
                                      color: Colors.white70, size: 18),
                                ),
                              ],
                            ),
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
                          child: Builder(builder: (context) {
                            final sorted = [..._bins]
                              ..sort((a, b) => b.fullness.compareTo(a.fullness));
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              itemCount: sorted.length,
                              itemBuilder: (_, i) => _buildBinTile(sorted[i]),
                            );
                          }),
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
