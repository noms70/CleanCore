import 'dart:async';

import 'package:cc/models/models.dart';
import 'package:cc/services/api_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/utils/area_match.dart';
import 'package:cc/widgets/appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays the worker's current active route as an ordered job list.
/// Workers can:
///   • See area, waste type, distance, and CO₂ footprint for the route
///   • Navigate to each stop via Google Maps deep link
///   • Mark each stop as "Complete Collection"
///   • Report an issue on any stop
class RouteJobScreen extends StatefulWidget {
  const RouteJobScreen({super.key});

  @override
  State<RouteJobScreen> createState() => _RouteJobScreenState();
}

class _RouteJobScreenState extends State<RouteJobScreen> {
  final _api = ApiService();
  final _db  = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  ActiveRoute? _route;
  ActiveRoute? _completedRoute;  // most recent completed route for this driver
  bool _loading = true;
  String? _error;

  // Tracks which stops are currently being submitted to avoid double-taps
  final Set<String> _busyBins = {};
  final Set<String> _skippingBins = {};

  bool _generating = false;
  String? _genError;

  // Worker's assigned area — needed to filter orphan critical bins to this
  // worker's district. Loaded once from users/{uid}.
  String _assignedArea = '';

  // Count of bins with status=='critical' AND isLocked==false in the worker's
  // area. These are bins waiting to be picked up by a /optimize-route call.
  int _orphanCriticalCount = 0;

  StreamSubscription<QuerySnapshot>? _routeSub;
  StreamSubscription<QuerySnapshot>? _completedRouteSub;
  StreamSubscription<QuerySnapshot>? _orphanBinsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;

  // Live thresholds from settings/main — mirrors the listener in map_page.dart
  // so stop cards classify fill levels against the same admin-configured
  // boundaries that the map markers use. Defaults match the backend's
  // _get_thresholds() fallback (70/90) until the first snapshot arrives.
  int _warningThreshold  = 70;
  int _criticalThreshold = 90;

  @override
  void initState() {
    super.initState();
    _subscribeToRoute();
    _subscribeToCompletedRoute();
    _subscribeToSettings();
    _loadAssignedAreaThenSubscribeOrphans();
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _completedRouteSub?.cancel();
    _orphanBinsSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  // Live settings/main subscription — admin slider changes propagate here
  // within ~50 ms and trigger a card re-color so the worker sees the new
  // severity without waiting for the next route doc update.
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
      if (newWarning != _warningThreshold || newCritical != _criticalThreshold) {
        setState(() {
          _warningThreshold  = newWarning;
          _criticalThreshold = newCritical;
        });
      }
    });
  }

  // ── Orphan critical bins (area-filtered) ──────────────────────────────────
  // Shows the worker how many critical bins are waiting for the next route.
  // Mirrors the area-hierarchy match used elsewhere in the app.
  Future<void> _loadAssignedAreaThenSubscribeOrphans() async {
    if (_uid == null) return;
    try {
      final doc = await _db.collection('users').doc(_uid!).get();
      if (doc.exists) {
        _assignedArea = (doc.data()?['assignedArea'] as String? ?? '').trim();
      }
    } catch (_) {
      // Worker doc unreachable — fall through with empty area filter.
    }
    _subscribeToOrphanBins();
  }

  void _subscribeToOrphanBins() {
    _orphanBinsSub = _db
        .collection('bins')
        .where('status', isEqualTo: 'critical')
        .where('isLocked', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (_assignedArea.isEmpty) { count++; continue; }
        // Canonical match — see utils/area_match.dart.
        if (areaMatches(readBinArea(data), _assignedArea)) count++;
      }
      setState(() => _orphanCriticalCount = count);
    });
  }

  void _subscribeToRoute() {
    if (_uid == null) {
      setState(() { _loading = false; _error = 'Not logged in.'; });
      return;
    }

    _routeSub = _db
        .collection('routes')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() { _route = null; _loading = false; _error = null; });
        return;
      }
      final newRoute = ActiveRoute.fromFirestore(snap.docs.first);

      // Detect backend-driven stop append (urgent critical bin auto-attached
      // by /analyze/). Surface as a passive snackbar — no banner, no button.
      if (_route != null && _route!.routeId == newRoute.routeId) {
        final oldIds = _route!.stops.map((s) => s.binId).toSet();
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
        _route   = newRoute;
        _loading = false;
        _error   = null;
      });
    }, onError: (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  /// Subscribes to the most recent completed route for this driver.
  /// When all stops are done and the route is marked 'completed' by the backend,
  /// this surfaces the completion screen instead of the generic "No Active Route".
  void _subscribeToCompletedRoute() {
    if (_uid == null) return;
    _completedRouteSub = _db
        .collection('routes')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _completedRoute = snap.docs.isNotEmpty
            ? ActiveRoute.fromFirestore(snap.docs.first)
            : null;
      });
    });
  }

  /// Calls POST /optimize-route to generate the worker's route on demand.
  ///
  /// Depot origin priority:
  ///   1. Live GPS (works on Android emulator / physical device)
  ///   2. Last known GPS position (emulator fallback)
  ///   3. Worker's stored lat/lng from Firestore (Chrome / web fallback)
  ///
  /// Area filtering is always done server-side using the worker's assignedArea
  /// field — GPS is only used to order stops nearest-first from the depot.
  Future<void> _generateRoute() async {
    if (_uid == null) return;
    setState(() { _generating = true; _genError = null; });

    double depotLat = 0.0, depotLng = 0.0;

    if (kIsWeb) {
      // ── Web / Chrome: geolocator hangs waiting for browser permission and
      // Dart's timeout does not reliably interrupt it on web. Skip GPS and
      // use the worker's stored depot coordinates from Firestore directly.
      try {
        final workerDoc = await _db.collection('users').doc(_uid!).get();
        if (workerDoc.exists) {
          final data = workerDoc.data() ?? {};
          depotLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          depotLng = (data['lng'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {
        // Firestore read failed — stays (0,0), caught below
      }
    } else {
      // ── Native (Android emulator / physical device): use live GPS ──────────
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null && !(pos.latitude == 0.0 && pos.longitude == 0.0)) {
        depotLat = pos.latitude;
        depotLng = pos.longitude;
      } else {
        // GPS timed out — fall back to Firestore stored coords
        try {
          final workerDoc = await _db.collection('users').doc(_uid!).get();
          if (workerDoc.exists) {
            final data = workerDoc.data() ?? {};
            depotLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
            depotLng = (data['lng'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) {
          // Firestore read failed — stays (0,0), caught below
        }
      }
    }

    // ── Step 3: If both GPS and Firestore coords are (0,0), inform the user ──
    if (depotLat == 0.0 && depotLng == 0.0) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _genError = 'Could not determine your location.\n'
            '• On emulator: open Extended Controls → Location, '
            'set lat=33.6938 lng=73.0651, tap Set Location, then retry.\n'
            '• On Chrome: make sure your worker profile has valid coordinates.';
      });
      return;
    }

    final result = await _api.optimizeRoute(
      workerId: _uid!,
      depotLat: depotLat,
      depotLng: depotLng,
    );

    if (!mounted) return;
    setState(() => _generating = false);

    if (result == null) {
      setState(() => _genError =
          'No qualifying bins found in your assigned area. '
          'Bins must be >70% full and unlocked.');
    } else {
      // On success, go back to the map so the user can see the new route polylines
      Navigator.pop(context);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _completeStop(RouteStop stop) async {
    if (_route == null || _busyBins.contains(stop.binId)) return;
    setState(() => _busyBins.add(stop.binId));

    final result = await _api.completeStop(
      routeId:  _route!.routeId,
      binId:    stop.binId,
      workerId: _uid ?? '',
    );

    if (!mounted) return;
    setState(() => _busyBins.remove(stop.binId));

    if (result != null) {
      if (result['error'] == 'already_completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This stop is already marked as completed.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (result['route_status'] == 'completed') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showCompletionSummary());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bin ${stop.binId} collected! '
              '${result['completed_stops']}/${result['total_stops']} stops done.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark stop. Check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reportIssue(RouteStop stop) async {
    if (_uid == null) return;

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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            const Text('Report Issue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              'Bin ${stop.binId.length > 12 ? '${stop.binId.substring(0, 12)}…' : stop.binId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...types.map((t) => ListTile(
              leading: Icon(Icons.warning_amber_rounded,
                color: t['priority'] == 'high' ? Colors.red : t['priority'] == 'medium' ? Colors.orange : Colors.grey),
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
      binId:       stop.binId,
      anomalyType: selected['key'] as String,
      reportedBy:  _uid!,
      sector:      stop.area,
      priority:    selected['priority'] as String,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Issue reported: ${selected['label']}' : 'Failed to report issue.'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  Future<void> _skipStop(RouteStop stop) async {
    if (_route == null || _busyBins.contains(stop.binId) || _skippingBins.contains(stop.binId)) return;

    const types = [
      {'key': 'bin_inaccessible',   'label': 'Bin Inaccessible',   'icon': Icons.lock_outline},
      {'key': 'bin_damaged',        'label': 'Bin Damaged',         'icon': Icons.construction_outlined},
      {'key': 'hazardous_material', 'label': 'Hazardous Material',  'icon': Icons.warning_amber_rounded},
    ];

    final noteController = TextEditingController();
    Map<String, dynamic>? selected;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: StatefulBuilder(builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            const Text('Skip Stop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              'Bin ${stop.binId.length > 12 ? '${stop.binId.substring(0, 12)}…' : stop.binId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...types.map((t) => ListTile(
              leading: Icon(t['icon'] as IconData, color: Colors.amber.shade700),
              title: Text(t['label'] as String),
              trailing: selected?['key'] == t['key']
                  ? const Icon(Icons.check_circle, color: Colors.amber)
                  : null,
              dense: true,
              onTap: () => setSheet(() => selected = t),
            )),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Optional note (e.g. gate locked, visible damage)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selected == null ? null : () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirm Skip'),
              ),
            ),
          ],
        )),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _skippingBins.add(stop.binId));

    final result = await _api.skipStop(
      routeId:       _route!.routeId,
      binId:         stop.binId,
      workerId:      _uid ?? '',
      exceptionType: selected!['key'] as String,
      note:          noteController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _skippingBins.remove(stop.binId));

    if (result != null && result['success'] == true) {
      if (result['route_status'] == 'completed') _showCompletionSummary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop skipped — exception logged'),
          backgroundColor: Colors.amber,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['error'] == 'already_skipped'
              ? 'Stop already skipped.'
              : 'Failed to skip stop. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompletionSummary() {
    if (_route == null || !mounted) return;
    final route = _route!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 40),
            ),
            const SizedBox(height: 12),
            const Text('Route Complete!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 4),
            Text('Great work today!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 24),
            _summaryRow(Icons.check_circle_outline, 'Stops Collected',   '${route.totalStops}'),
            _summaryRow(Icons.straighten,            'Distance Driven',   '${route.totalDistanceKm} km'),
            _summaryRow(Icons.eco,                   'CO₂ Footprint',     '${route.carbonFootprintKg.toStringAsFixed(2)} kg'),
            _summaryRow(Icons.local_gas_station,     'Fuel Estimated',    '${route.estimatedFuel.toStringAsFixed(1)} L'),
            _summaryRow(Icons.location_city,         'Area',
              route.assignedArea.isNotEmpty ? route.assignedArea : 'All Areas'),
            _summaryRow(Icons.recycling,             'Waste Stream',
              route.assignedWasteType.isNotEmpty ? route.assignedWasteType : 'All Types'),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Great Work!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppCol.btnbacks),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppCol.primaryDark : const Color(0xFFF5F7FA),
      appBar: AppBuild().buildAppBar(
        title: 'My Route',
        icon: Icons.route_rounded,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppCol.btnbacks))
          : _error != null
              ? _buildError()
              : _route == null
                  ? (_completedRoute != null
                      ? _buildAllDoneScreen(_completedRoute!)
                      : _buildNoRoute())
                  : _buildRouteContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Shown when the worker has no active route but has a recently completed one.
  Widget _buildAllDoneScreen(ActiveRoute done) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          // Trophy / checkmark
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade200, width: 2),
            ),
            child: Icon(Icons.check_circle_rounded,
                color: Colors.green.shade500, size: 56),
          ),
          const SizedBox(height: 20),
          const Text(
            'All Stops Completed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppCol.btntext,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Great work today! You have successfully collected all '
            '${done.totalStops} bins on your route.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          _orphanChip(),
          const SizedBox(height: 28),

          // Summary stats card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppCol.btnbacks, Color(0xFF00A896)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppCol.btnbacks.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _doneStatRow(Icons.check_circle_outline,
                    'Bins Collected', '${done.totalStops}'),
                const Divider(color: Colors.white24, height: 20),
                _doneStatRow(Icons.straighten,
                    'Distance Driven', '${done.totalDistanceKm} km'),
                const Divider(color: Colors.white24, height: 20),
                _doneStatRow(Icons.eco,
                    'CO\u2082 Footprint',
                    '${done.carbonFootprintKg.toStringAsFixed(2)} kg'),
                const Divider(color: Colors.white24, height: 20),
                _doneStatRow(Icons.local_gas_station,
                    'Fuel Used', '${done.estimatedFuel.toStringAsFixed(1)} L'),
                if (done.assignedArea.isNotEmpty) ...[
                  const Divider(color: Colors.white24, height: 20),
                  _doneStatRow(Icons.location_city,
                      'Area', done.assignedArea),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Generate new route button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generateRoute,
              icon: _generating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _generating ? 'Checking for new bins\u2026' : 'Check for New Urgent Bins',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppCol.btnbacks,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor:
                    AppCol.btnbacks.withOpacity(0.5),
              ),
            ),
          ),
          if (_genError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                _genError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _doneStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Soft hint chip: shown only when there are orphan critical bins waiting.
  // The user picks them up by tapping the generate/check button below.
  Widget _orphanChip() {
    if (_orphanCriticalCount <= 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final areaLabel = _assignedArea.isNotEmpty ? _assignedArea : 'your area';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$_orphanCriticalCount urgent bin${_orphanCriticalCount == 1 ? '' : 's'} '
              'in $areaLabel waiting for a route',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRoute() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 72, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Active Route',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppCol.btntext),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to generate your optimised route. The system will find '
              'the highest-priority bins in your assigned area and order them '
              'for the shortest drive.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            _orphanChip(),
            if (_genError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _genError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generateRoute,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _generating ? 'Calculating Route…' : 'Generate My Route',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppCol.btnbacks,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppCol.btnbacks.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteContent() {
    final route = _route!;
    final completed = route.completedStops;
    final total     = route.totalStops;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Route header card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppCol.btnbacks, Color(0xFF00A896)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppCol.btnbacks.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.routeId.length > 18
                          ? route.routeId.substring(0, 18) + '…'
                          : route.routeId,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$completed / $total stops',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: route.progressFraction,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _headerStat(Icons.location_city, route.assignedArea.isNotEmpty ? route.assignedArea : 'All Areas'),
                  const SizedBox(width: 20),
                  _headerStat(Icons.recycling, route.assignedWasteType.isNotEmpty ? route.assignedWasteType : 'All Types'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _headerStat(Icons.straighten, '${route.totalDistanceKm} km'),
                  const SizedBox(width: 20),
                  _headerStat(Icons.eco, '${route.carbonFootprintKg.toStringAsFixed(2)} kg CO₂'),
                  const SizedBox(width: 20),
                  _headerStat(Icons.local_gas_station, '${route.estimatedFuel.toStringAsFixed(1)} L'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Stop list ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Stops (in order)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppCol.btntext),
          ),
        ),

        if (route.stops.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No stops found.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...route.stops.asMap().entries.map((entry) {
            final index = entry.key;
            final stop  = entry.value;
            return _buildStopCard(stop, index + 1, stop.completed);
          }),
      ],
    );
  }

  Widget _headerStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildStopCard(RouteStop stop, int stopNumber, bool isDone) {
    final isBusy      = _busyBins.contains(stop.binId);
    final isSkipping  = _skippingBins.contains(stop.binId);
    final isSkipped   = stop.skipped;
    // Severity uses live thresholds (settings/main via _subscribeToSettings)
    // so card colour stays in lockstep with the map markers when admin
    // changes the warning/critical sliders.
    final fillColor = stop.fillLevel >= _criticalThreshold
        ? Colors.red
        : stop.fillLevel >= _warningThreshold
            ? Colors.orange
            : Colors.green;

    final cardIsDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSkipped
            ? (cardIsDark ? Colors.grey.shade900 : Colors.grey.shade50)
            : (cardIsDark ? AppCol.card : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: isDone
            ? Border.all(color: Colors.green.shade200, width: 1.5)
            : isSkipped
                ? Border.all(color: Colors.amber.shade300, width: 1.5)
                : Border.all(color: cardIsDark ? AppCol.secondary : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(cardIsDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop number + bin ID + done badge
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green : AppCol.btnbacks,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '$stopNumber',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.binId,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cardIsDark ? Colors.white : AppCol.btntext),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        stop.area.isNotEmpty ? stop.area : stop.wasteType,
                        style: TextStyle(fontSize: 12, color: cardIsDark ? Colors.grey.shade500 : Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Fill level badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fillColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: fillColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${stop.fillLevel}%',
                    style: TextStyle(color: fillColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Fill progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stop.fillLevel / 100,
                minHeight: 6,
                backgroundColor: cardIsDark ? AppCol.secondary : Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              ),
            ),

            // Status badge — collected or skipped
            if (isDone || isSkipped) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone ? Colors.green.shade300 : Colors.amber.shade400,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.block,
                      color: isDone ? Colors.green.shade600 : Colors.amber.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDone
                          ? 'Collected ✓'
                          : 'SKIPPED — ${stop.exceptionType?.replaceAll('_', ' ') ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons — shown only for pending (not completed, not skipped) stops
            if (!isDone && !isSkipped) ...[
              const SizedBox(height: 12),

              if (isBusy || isSkipping)
                const Center(child: SizedBox(height: 28, width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppCol.btnbacks)))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mark Complete (full width, primary action)
                    ElevatedButton.icon(
                      onPressed: stop.fillLevel == 0 ? null : () => _completeStop(stop),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Complete',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Skip Stop (amber, operational exception)
                    OutlinedButton.icon(
                      onPressed: () => _skipStop(stop),
                      icon: Icon(Icons.block, size: 15, color: Colors.amber.shade700),
                      label: Text('Skip Stop',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade800,
                        side: BorderSide(color: Colors.amber.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Report Issue (secondary, outlined)
                    OutlinedButton.icon(
                      onPressed: () => _reportIssue(stop),
                      icon: const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                      label: const Text('Report Issue',
                          style: TextStyle(fontSize: 12, color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
