import 'dart:async';

import 'package:cc/models/models.dart';
import 'package:cc/services/api_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _loading = true;
  String? _error;

  // Tracks which stops are currently being submitted to avoid double-taps
  final Set<String> _busyBins = {};

  bool _generating = false;
  String? _genError;

  StreamSubscription<QuerySnapshot>? _routeSub;

  @override
  void initState() {
    super.initState();
    _subscribeToRoute();
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
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
      setState(() {
        _route   = ActiveRoute.fromFirestore(snap.docs.first);
        _loading = false;
        _error   = null;
      });
    }, onError: (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  /// Calls POST /optimize-route to generate the worker's route on demand.
  /// The VRP algorithm filters bins by the worker's assignedArea and
  /// assignedWasteType from Firestore, so the worker only gets relevant stops.
  Future<void> _generateRoute() async {
    if (_uid == null) return;
    setState(() { _generating = true; _genError = null; });

    // Use current GPS as depot origin so the nearest stop comes first
    double depotLat = 0.0, depotLng = 0.0;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));
      depotLat = pos.latitude;
      depotLng = pos.longitude;
    } catch (_) {}

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bin ${stop.binId} collected! '
            '${result['completed_stops']}/${result['total_stops']} stops done.',
          ),
          backgroundColor: Colors.green,
        ),
      );
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report Issue'),
        content: Text('Report a problem with bin ${stop.binId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final success = await _api.reportAnomaly(
      binId:       stop.binId,
      anomalyType: 'field_issue',
      reportedBy:  _uid!,
      sector:      stop.area,
      priority:    'high',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Issue reported.' : 'Failed to report issue.'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppCol.btnbacks,
        foregroundColor: Colors.white,
        title: const Text('My Route', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppCol.btnbacks))
          : _error != null
              ? _buildError()
              : _route == null
                  ? _buildNoRoute()
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

  Widget _buildNoRoute() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Active Route',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppCol.btntext),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to generate your optimised route. The system will find '
              'the highest-priority bins in your assigned area and order them '
              'for the shortest drive.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
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
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Stops (in order)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppCol.btntext),
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
    final isBusy = _busyBins.contains(stop.binId);
    final fillColor = stop.fillLevel >= 90
        ? Colors.red
        : stop.fillLevel >= 70
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isDone
            ? Border.all(color: Colors.green.shade200, width: 1.5)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppCol.btntext),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        stop.area.isNotEmpty ? stop.area : stop.wasteType,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              ),
            ),

            if (!isDone) ...[
              const SizedBox(height: 12),

              // Action buttons
              if (isBusy)
                const Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppCol.btnbacks)))
              else
                Row(
                  children: [
                    // Navigate with Google Maps
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openGoogleMaps(stop.lat, stop.lng),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Maps', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppCol.btnbacks,
                          side: BorderSide(color: AppCol.btnbacks.withOpacity(0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Complete collection
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _completeStop(stop),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Complete', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Report issue
                    IconButton(
                      onPressed: () => _reportIssue(stop),
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      tooltip: 'Report issue',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.1),
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
