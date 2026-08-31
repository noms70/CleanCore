import 'dart:async';
import 'dart:convert';

import 'package:cc/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:cc/utils/colors.dart';
import 'package:cc/utils/area_match.dart';
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
  // â”€â”€ Map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _initialPosition;
  bool _isLoading = true;

  // â”€â”€ Bin data (live from Firestore â€” filtered by worker assignment) â”€â”€â”€â”€â”€â”€â”€
  List<BinLocation> _bins = [];
  BinLocation? _selectedBin;

  // Raw Firestore docs â€” stored so any position update can re-filter without
  // waiting for a new Firestore snapshot.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rawBinDocs = [];

  // Workers within 10 km see bins when no assignedArea is set.
  static const double _proximityRadiusM = 10000;

  // Worker assignment â€” loaded once from Firestore so the bin query can filter
  String _assignedArea = '';
  String _assignedWasteType = '';

  // Live shift status — gates the My Route button. Worker can only open the
  // route screen once they've clocked in (which itself requires a scheduled
  // shift for today, enforced backend-side at /clock-in).
  bool _isClockedIn = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shiftStatusSub;

  // â”€â”€ Active route (live from Firestore 'routes' collection) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Urgent critical bins are auto-attached server-side by /analyze/ and surface
  // here as new stops in _subscribeToActiveRoute (passive toast, no banner).
  ActiveRoute? _activeRoute;

  // â”€â”€ Reverse-geocoded display names for bin tiles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final Map<String, String> _binLocationNames = {};

  // â”€â”€ Services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _api = ApiService();
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // â”€â”€ Subscriptions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  StreamSubscription<QuerySnapshot>? _binsSub;
  StreamSubscription<QuerySnapshot>? _routeSub;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;

  // Live thresholds from settings/main — keep markers and "ready for pickup"
  // alerts honest even before the backend's batch reclassification finishes.
  // Defaults match the backend's _get_thresholds() fallback (70/90).
  int _warningThreshold  = 70;
  int _criticalThreshold = 90;
  bool _thresholdsLoaded = false;

  // Bin IDs that were critical at the last snapshot — used to detect "newly
  // critical" transitions and show an in-app pickup alert. Seeded on first
  // snapshot so we don't blast the worker with alerts for bins that were
  // already critical when they opened the app.
  Set<String> _previouslyCriticalIds = {};
  bool _firstSnapshotSeen = false;

  // â”€â”€ Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Position? _currentPosition;

  late PolylinePoints _polylinePoints;

  @override
  void initState() {
    super.initState();
    _polylinePoints = PolylinePoints(apiKey: '');
    _bins = List.from(widget.binLocations);
    _setupMap();
    _subscribeToSettings();            // live warning/critical thresholds
    _subscribeToShiftStatus();         // gates the My Route button
    _loadProfileThenSubscribeToBins(); // loads assignment filters first
    _subscribeToActiveRoute();
  }

  @override
  void dispose() {
    _binsSub?.cancel();
    _routeSub?.cancel();
    _locationSub?.cancel();
    _settingsSub?.cancel();
    _shiftStatusSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Live shift status from the user doc — flips _isClockedIn when the worker
  // clocks in/out anywhere in the app. Backend writes shiftStatus
  // ("clocked_in" / "clocked_out") on /clock-in and /clock-out so we just
  // mirror it here.
  void _subscribeToShiftStatus() {
    if (_uid == null) return;
    _shiftStatusSub = _db
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final clockedIn = data['shiftStatus'] == 'clocked_in';
      if (clockedIn != _isClockedIn) {
        setState(() => _isClockedIn = clockedIn);
      }
    });
  }

  // Live settings/main subscription — admin slider changes propagate here
  // within ~50 ms and trigger a marker re-color + alert sweep so the worker
  // sees the new severity without waiting for the next bin update.
  void _subscribeToSettings() {
    _settingsSub = _db
        .collection('settings')
        .doc('main')
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final newWarning  = (data['warningThreshold']  as num?)?.toInt() ?? 70;
      final newCritical = (data['criticalThreshold'] as num?)?.toInt() ?? 90;
      final changed = !_thresholdsLoaded
          || newWarning  != _warningThreshold
          || newCritical != _criticalThreshold;
      _warningThreshold  = newWarning;
      _criticalThreshold = newCritical;
      _thresholdsLoaded  = true;
      debugPrint('[MapPage] thresholds updated: warning=$_warningThreshold critical=$_criticalThreshold');
      // Re-evaluate bins so markers re-color immediately. The first load
      // here just primes the state — no alerts yet because _firstSnapshotSeen
      // is still false until the bins listener has fired at least once.
      if (changed && _rawBinDocs.isNotEmpty) _applyBinFilter();
    });
  }

  // Live critical check — uses current threshold instead of the model's
  // hardcoded 90 % so admin slider changes take effect instantly. Backend
  // also writes status='critical' after recompute, so either signal flips
  // the bin red.
  bool _isCriticalNow(BinLocation bin) {
    if (bin.fullness >= _criticalThreshold) return true;
    final s = bin.status.toLowerCase();
    return s == 'critical' || s == 'full' || s == 'overflowing';
  }

  // â”€â”€ Setup â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _setupMap() async {
    try {
      _currentPosition = await _determinePosition();
      _initialPosition = CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14.5,
      );
      _startLocationStream();
      // Bins may have loaded before GPS was ready â€” re-filter now that we
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

  // â”€â”€ Firestore: load worker profile then subscribe to filtered bins â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Firestore: live bin updates (filtered by worker assignment) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _subscribeToBins() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      _rawBinDocs = snap.docs;
      _applyBinFilter();
    });
  }

  // Re-applies the current filter against the cached raw docs and updates state.
  // Called on every new Firestore snapshot AND on significant GPS movement.
  void _applyBinFilter() {
    debugPrint(
      '[MapPage] applyBinFilter: rawDocs=${_rawBinDocs.length} '
      'assignedArea="$_assignedArea" assignedWasteType="$_assignedWasteType" '
      'gps=${_currentPosition == null ? "null" : "${_currentPosition!.latitude.toStringAsFixed(4)},${_currentPosition!.longitude.toStringAsFixed(4)}"}',
    );
    final filtered = _buildFilteredBins(_rawBinDocs);
    debugPrint('[MapPage] applyBinFilter: kept ${filtered.length} of ${_rawBinDocs.length} bins');
    if (mounted) {
      setState(() {
        _bins = filtered;
        _generateMarkers();
      });
      _fitCameraToBins();
      _fetchBinNamesForNewBins(filtered);
      _sweepNewlyCriticalAlerts(filtered);
    }
  }

  // Fires a snackbar for each bin that transitioned to critical since the
  // last filter pass. Skipped on the very first snapshot (workers shouldn't
  // be spammed with alerts for bins that were already red when they opened
  // the app) — those just seed _previouslyCriticalIds.
  void _sweepNewlyCriticalAlerts(List<BinLocation> bins) {
    final currentIds = bins.where(_isCriticalNow).map((b) => b.id).toSet();
    if (!_firstSnapshotSeen) {
      _previouslyCriticalIds = currentIds;
      _firstSnapshotSeen = true;
      return;
    }
    final newlyCritical = currentIds.difference(_previouslyCriticalIds);
    _previouslyCriticalIds = currentIds;
    for (final id in newlyCritical) {
      final bin = bins.firstWhere((b) => b.id == id);
      _showReadyForPickupAlert(bin);
    }
  }

  void _showReadyForPickupAlert(BinLocation bin) {
    if (!mounted) return;
    final areaLabel = bin.area.isNotEmpty ? bin.area : 'your area';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bin in $areaLabel is now ${bin.fullness}% full — ready for pickup',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Animates the map camera so every visible bin (and the worker, if known)
  // fits in the viewport. Avoids the situation where the camera is parked over
  // an Islamabad fallback while pins are actually in Wah.
  void _fitCameraToBins() {
    if (_mapController == null || _bins.isEmpty) return;
    final points = <LatLng>[
      ..._bins.map((b) => LatLng(b.lat, b.lng)),
      if (_currentPosition != null)
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ];
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(_bounds(points), 60),
    );
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
  // â€¢ Assigned workers  â†’ strict area + waste-type match (existing behaviour).
  // â€¢ Unassigned workers â†’ bins within _proximityRadiusM of current GPS.
  // â€¢ No GPS yet         â†’ show everything so the map isn't empty on first load.
  List<BinLocation> _buildFilteredBins(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((d) {
      final data = d.data();

      final binLat = _getBinLat(data);
      final binLng = _getBinLng(data);
      if (binLat == null || binLng == null) {
        debugPrint('[MapPage] reject ${d.id}: no lat/lng');
        return false;
      }
      // Skip legacy bins that were saved with broken (0,0) coordinates —
      // they would otherwise pin in the middle of the Atlantic.
      if (binLat == 0.0 && binLng == 0.0) {
        debugPrint('[MapPage] reject ${d.id}: coords are (0,0)');
        return false;
      }

      if (_assignedArea.isNotEmpty) {
        // Single source of truth for area matching — see utils/area_match.dart.
        final binArea = readBinArea(data);
        if (!areaMatches(binArea, _assignedArea)) {
          debugPrint('[MapPage] reject ${d.id}: area "$binArea" != worker "$_assignedArea"');
          return false;
        }
      } else if (_currentPosition != null) {
        final distM = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          binLat,
          binLng,
        );
        if (distM > _proximityRadiusM) {
          debugPrint('[MapPage] reject ${d.id}: ${(distM/1000).toStringAsFixed(1)}km from worker (limit ${_proximityRadiusM/1000}km)');
          return false;
        }
      }

      // Wildcard waste types — "Mixed", "All", "Any" mean the worker collects
      // every category, so skip the filter entirely.
      final aw = _assignedWasteType.toLowerCase();
      const wildcardWaste = {'mixed', 'all', 'any', 'general'};
      if (_assignedWasteType.isNotEmpty && !wildcardWaste.contains(aw)) {
        final binWaste =
            (data['wasteType'] ?? data['waste_type'] ?? data['type'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        if (binWaste != aw) {
          debugPrint('[MapPage] reject ${d.id}: wasteType "$binWaste" != worker "$_assignedWasteType"');
          return false;
        }
      }

      debugPrint('[MapPage] keep   ${d.id}: ($binLat,$binLng) area="${data['area']}"');
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

  // â”€â”€ Firestore: active route for this driver â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Backend writes driverId (not workerId). Query must match exactly.
  // We also keep track of which bin IDs were on the route last snapshot, so a
  // bin appended by the backend (urgent critical bin auto-attached in
  // /analyze/) surfaces as a passive toast — no banner, no button.
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
      final newRoute = snap.docs.isNotEmpty
          ? ActiveRoute.fromFirestore(snap.docs.first)
          : null;

      // Diff the bin IDs to detect a backend-driven append.
      if (newRoute != null && _activeRoute != null &&
          newRoute.routeId == _activeRoute!.routeId) {
        final oldIds = _activeRoute!.stops.map((s) => s.binId).toSet();
        final addedStops = newRoute.stops.where((s) => !oldIds.contains(s.binId)).toList();
        for (final added in addedStops) {
          final areaLabel = added.area.isNotEmpty ? added.area : 'your area';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Route updated — urgent bin in $areaLabel '
                '(${added.fillLevel}% full) added automatically.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      setState(() {
        _activeRoute = newRoute;
        if (_activeRoute == null) _polylines.clear();
      });
      if (_activeRoute != null) _fetchAndDrawRoutePolyline();
    });
  }

  // â”€â”€ OSRM road-based polyline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Fetches the actual road route from the worker's current position through
  // every pending stop in order. Re-called whenever the route changes or the
  // driver moves (50 m trigger in _startLocationStream).
  Future<void> _fetchAndDrawRoutePolyline() async {
    if (_activeRoute == null) return;

    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : LatLng(widget.driverLat, widget.driverLng);

    final pending = _activeRoute!.stops.where((s) => !s.completed && !s.skipped).toList();
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

  // â”€â”€ GPS: stream location and push to backend â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _startLocationStream() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // call API only after moving 50 m
      ),
    ).listen((pos) {
      _currentPosition = pos;
      if (_uid != null) {
        // POST /update-worker-location â€” field: driver_id (not worker_id)
        _api.updateWorkerLocation(
          driverId: _uid!,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
      // For unassigned workers the visible bins depend on position â€”
      // re-filter so the map reflects their latest location.
      if (_assignedArea.isEmpty && _rawBinDocs.isNotEmpty) {
        _applyBinFilter();
      }
      // Re-draw the road polyline from the driver's new position.
      if (_activeRoute != null) _fetchAndDrawRoutePolyline();
    });
  }

  // â”€â”€ Map helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _generateMarkers() {
    final markers = <Marker>{};
    for (final bin in _bins) {
      // Severity uses live thresholds (settings/main) — so when admin slides
      // the critical threshold from 90 → 40, a 55 % bin flips from green to
      // red immediately without waiting for the backend's status rewrite.
      final hue = _isCriticalNow(bin)
          ? BitmapDescriptor.hueRed
          : bin.fullness >= _warningThreshold
              ? BitmapDescriptor.hueYellow
              : BitmapDescriptor.hueGreen;
      markers.add(Marker(
        markerId: MarkerId(bin.id),
        position: LatLng(bin.lat, bin.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: bin.id,
          snippet: '${bin.fullness}% â€” ${bin.wasteType}',
        ),
        onTap: () => _showBinDetails(bin),
      ));
    }
    setState(() => _markers = markers);
  }

  // â”€â”€ Dark map style â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    // Bins may have already loaded before the GoogleMap widget finished
    // initializing — fit to them now so the camera doesn't sit on a fallback
    // location while pins are off-screen.
    if (_bins.isNotEmpty) _fitCameraToBins();
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

  // â”€â”€ Open stop in Google Maps via geo: deep link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // â”€â”€ Mark bin as collected â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Calls POST /complete-stop with route_id and bin_id.
  // Backend increments completedStops and resets fillLevel to 0.
  Future<void> _markCollected(BinLocation bin) async {
    if (_activeRoute == null) {
      Navigator.of(context).pop();
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
      Navigator.of(context).pop();
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
                'Bin ${bin.id.length > 14 ? '${bin.id.substring(0, 14)}â€¦' : bin.id}',
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
                    'No image available.',
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

  // â”€â”€ Report anomaly with type picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              'Bin ${bin.id.length > 12 ? '${bin.id.substring(0, 12)}â€¦' : bin.id}',
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

  // â”€â”€ Check if a bin is a completed stop on the active route â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isBinCompleted(String binId) {
    if (_activeRoute == null) return false;
    return _activeRoute!.stops.any(
      (s) => s.binId == binId && s.completed,
    );
  }

  // â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showBinDetails(BinLocation bin) {
    setState(() => _selectedBin = bin);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBinSheet(bin),
    );
  }

  Widget _buildBinSheet(BinLocation bin) {
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

            // Fill progress bar — uses live critical threshold so the bar
            // turns red the moment the admin lowers the slider past the bin.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: bin.fullness / 100,
                minHeight: 8,
                backgroundColor: AppCol.btnbacks.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isCriticalNow(bin) ? Colors.red : AppCol.btnbacks,
                ),
              ),
            ),

            // Completed badge â€” shown when this bin is a done stop on the active route
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
                      'Collected â€” this stop is done',
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
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Route active Â· ${_activeRoute!.completedStops}/${_activeRoute!.totalStops} done',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
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
                      side: BorderSide(color: Colors.orange.withValues(alpha: 0.6)),
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

  // Status text mirrors the marker-colour rule so the bin-details modal
  // never disagrees with the live map. Uses the same _warningThreshold /
  // _criticalThreshold maintained by _subscribeToSettings.
  String _getStatusText(int fullness) {
    if (fullness >= _criticalThreshold) return 'CRITICAL';
    if (fullness >= _warningThreshold)  return 'WARNING';
    return 'NORMAL';
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
    // Determine status label & color based on live admin thresholds so the
    // tile chip stays in lockstep with the marker colour and the route-card
    // colour. _isCriticalNow already honours the live critical threshold.
    final bool tileIsCritical = _isCriticalNow(bin);
    final bool tileIsWarning  = !tileIsCritical && bin.fullness >= _warningThreshold;
    final String statusLabel;
    final Color statusColor;
    if (tileIsCritical) {
      statusLabel = 'CRITICAL';
      statusColor = Colors.red;
    } else if (tileIsWarning) {
      statusLabel = 'WARNING';
      statusColor = Colors.orange;
    } else {
      statusLabel = 'NORMAL';
      statusColor = Colors.green;
    }

    // Gradient for the accent strip at top — uses the same live-threshold
    // categories as the status chip above.
    final List<Color> accentGradient = tileIsCritical
        ? [Colors.red.shade400, Colors.red.shade700]
        : tileIsWarning
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
              color: (tileIsCritical
                      ? Colors.red
                      : isSelected
                          ? AppCol.btnbacks
                          : Colors.black)
                  .withValues(alpha: tileIsCritical ? 0.18 : 0.08),
              blurRadius: tileIsCritical ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // â”€â”€ Gradient accent strip â”€â”€
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
                    // â”€â”€ Radial fill gauge â”€â”€
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

                    // â”€â”€ Location name (resolved via reverse geocoding, else bin ID) â”€â”€
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

                    // â”€â”€ Status chip with percentage â”€â”€
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
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
                              color: statusColor.withValues(alpha: 0.7),
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
                      style: Theme.of(context).brightness == Brightness.dark
                          ? _darkMapStyle
                          : null,
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

                    // My Route â€” opens RouteJobScreen (gated by clock-in)
                    Positioned(
                      left: 16,
                      bottom: 250,
                      child: GestureDetector(
                        onTap: _isClockedIn
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RouteJobScreen()),
                                )
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text("Your Shift hasn't started yet"),
                                  backgroundColor: Colors.orange.shade700,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              },
                        child: Opacity(
                          opacity: _isClockedIn ? 1.0 : 0.5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? AppCol.card : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
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
                                  child: Icon(
                                    _isClockedIn ? Icons.route_rounded : Icons.lock_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
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
                                color: Colors.black.withValues(alpha: 0.15),
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
                                      'Active Route â€” ${(_activeRoute!.progressFraction * 100).toStringAsFixed(0)}% complete',
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
                                          AppCol.btnbacks.withValues(alpha: 0.2),
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

