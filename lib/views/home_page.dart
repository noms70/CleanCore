import 'dart:async';
import 'dart:convert';
import 'dart:math';


import 'package:cc/models/user_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cc/services/auth_service.dart';
import 'package:cc/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/utils/area_match.dart';
import '../models/models.dart';
import '../widgets/navbar.dart';
import './map_page.dart';
import './settings_page.dart';
import '../widgets/inactivity_wrapper.dart';
import '../services/api_service.dart';

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
  final ApiService _api = ApiService();
  UserModel? _user;

  // Shift management state
  bool _isClockedIn = false;
  String? _currentShiftId;
  DateTime? _clockInTime;
  Timer? _shiftTimer;
  int _shiftElapsedSeconds = 0;
  Map<String, dynamic>? _scheduledShift;
  StreamSubscription<QuerySnapshot>? _scheduleSub;
  DateTime? _shiftStartTime;     // parsed from scheduledShift.startTime
  int _secondsUntilShift = 0;    // live countdown
  Timer? _countdownTimer;

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;

  // Live thresholds from settings/main — kept in sync with map_page so the
  // Critical Bins tile recounts the moment admin moves the slider.
  int _criticalThreshold = 90;

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
    _subscribeToSettings();
    _subscribeToBinStats();
    _loadShiftStatus();
    _subscribeToSchedule();
  }

  // Live admin thresholds — keeps the Critical Bins count consistent with
  // the map markers (both read settings/main, see map_page.dart).
  void _subscribeToSettings() {
    _settingsSub = _db
        .collection('settings')
        .doc('main')
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final newCritical = (data['criticalThreshold'] as num?)?.toInt() ?? 90;
      if (newCritical != _criticalThreshold) {
        _criticalThreshold = newCritical;
        _recountCriticalBins();
      }
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _binsSub?.cancel();
    _settingsSub?.cancel();
    _shiftTimer?.cancel();
    _scheduleSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _subscribeToSchedule() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _scheduleSub = _db
        .collection('shiftSchedules')
        .where('workerId', isEqualTo: uid)
        .where('scheduledDate', isEqualTo: dateStr)
        .where('status', isEqualTo: 'scheduled')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!mounted) return;
      final data = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
      setState(() {
        _scheduledShift = data;
        _shiftStartTime = data != null ? _parseShiftStart(data['startTime'] as String? ?? '') : null;
      });
      _restartCountdown();
    });
  }

  DateTime? _parseShiftStart(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  bool get _isShiftStarted {
    if (_shiftStartTime == null) return true; // no schedule = no restriction
    return DateTime.now().isAfter(_shiftStartTime!.subtract(const Duration(minutes: 5)));
  }

  void _restartCountdown() {
    _countdownTimer?.cancel();
    if (_isClockedIn || _shiftStartTime == null || _isShiftStarted) return;
    _secondsUntilShift = _shiftStartTime!.difference(DateTime.now()).inSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) { _countdownTimer?.cancel(); return; }
      final remaining = _shiftStartTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _countdownTimer?.cancel();
        setState(() => _secondsUntilShift = 0);
      } else {
        setState(() => _secondsUntilShift = remaining);
      }
    });
  }

  Future<void> _loadShiftStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final result = await _api.getShiftStatus(uid);
    if (!mounted || result == null) return;
    final clocked = result['is_clocked_in'] as bool? ?? false;
    setState(() {
      _isClockedIn    = clocked;
      _currentShiftId = result['shift_id'] as String?;
      final raw = result['clock_in_time'] as String?;
      _clockInTime    = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
      if (clocked && _clockInTime != null) {
        _shiftElapsedSeconds = DateTime.now().difference(_clockInTime!).inSeconds;
      }
    });
    if (clocked) _startShiftTimer();
    if (!clocked) _restartCountdown();
  }

  void _startShiftTimer() {
    _shiftTimer?.cancel();
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _shiftElapsedSeconds++);
    });
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onClockIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Block clock-in if no shift is scheduled for today
    if (_scheduledShift == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No shift scheduled for today. Contact your admin.'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    // Block clock-in if scheduled shift exists but hasn't started yet
    if (!_isShiftStarted && _shiftStartTime != null) {
      final start = _shiftStartTime!;
      final timeStr =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Your shift starts at $timeStr. Please wait.'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Shift'),
        content: Text('Clock in at ${TimeOfDay.now().format(context)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clock In')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _api.clockIn(workerId: uid);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      setState(() {
        _isClockedIn         = true;
        _currentShiftId      = result['shift_id'] as String?;
        _clockInTime         = DateTime.now();
        _shiftElapsedSeconds = 0;
      });
      _countdownTimer?.cancel();
      _startShiftTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift started'), backgroundColor: Colors.green),
      );
      // Auto-generate the route the moment the worker clocks in — same call
      // as the My Route button, just triggered automatically so the worker
      // doesn't have to tap a second button to start their shift.
      _autoGenerateRouteOnClockIn(uid);
    } else if (result?['error'] == 'already_clocked_in') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already clocked in'), backgroundColor: Colors.orange),
      );
    } else if (result?['error'] == 'no_shift_scheduled') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No shift scheduled for today. Contact your admin.'),
        backgroundColor: Colors.red.shade700,
      ));
    } else if (result?['error'] == 'shift_not_started') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_shiftStartTime != null
              ? 'Shift starts at ${_shiftStartTime!.hour.toString().padLeft(2, '0')}:${_shiftStartTime!.minute.toString().padLeft(2, '0')}'
              : 'Shift has not started yet'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  // Generates the worker's route silently after a successful clock-in.
  // Mirrors the depot-resolution priority used in route_job_screen.dart:
  // live GPS → last known GPS → worker's Firestore lat/lng. Failures are
  // surfaced as a passive snackbar so the shift itself still starts cleanly
  // even when no qualifying bins exist yet.
  Future<void> _autoGenerateRouteOnClockIn(String uid) async {
    double depotLat = 0.0, depotLng = 0.0;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
      if (!(pos.latitude == 0.0 && pos.longitude == 0.0)) {
        depotLat = pos.latitude;
        depotLng = pos.longitude;
      }
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && !(last.latitude == 0.0 && last.longitude == 0.0)) {
        depotLat = last.latitude;
        depotLng = last.longitude;
      }
    }
    if (depotLat == 0.0 && depotLng == 0.0) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data() ?? <String, dynamic>{};
        depotLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
        depotLng = (data['lng'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }
    if (depotLat == 0.0 && depotLng == 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Clocked in, but location unavailable — open My Route to retry.'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    final routeResult = await _api.optimizeRoute(
      workerId: uid,
      depotLat: depotLat,
      depotLng: depotLng,
    );
    if (!mounted) return;
    if (routeResult != null && routeResult['success'] == true) {
      final stops = (routeResult['route']?['totalStops'] ?? 0) as int;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Route ready — $stops stop${stops == 1 ? '' : 's'} in your area.'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Clocked in. No bins are critical right now — your route will appear when bins fill up.'),
        backgroundColor: Colors.blueGrey.shade700,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _onClockOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Shift'),
        content: const Text('Are you sure you want to clock out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clock Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _api.clockOut(workerId: uid);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      _shiftTimer?.cancel();
      setState(() {
        _isClockedIn         = false;
        _currentShiftId      = null;
        _clockInTime         = null;
        _shiftElapsedSeconds = 0;
      });
      final mins    = result['duration_minutes'] as int? ?? 0;
      final routes  = result['routes_completed'] as int? ?? 0;
      final colls   = result['collections_completed'] as int? ?? 0;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Shift Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Duration: ${mins ~/ 60}h ${mins % 60}m'),
                Text('Routes completed: $routes'),
                Text('Collections: $colls'),
              ],
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        );
      }
    }
  }

  Widget _buildShiftBanner() {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final hasSchedule = _scheduledShift != null;
    // waiting = has schedule but not started yet (shows countdown)
    // noShift = no schedule at all (shows lock)
    final waiting = hasSchedule && !_isClockedIn && !_isShiftStarted;
    final noShift = !hasSchedule && !_isClockedIn;

    // Colour: amber = on shift, orange = waiting, grey = no schedule, teal = ready
    final bannerColor = _isClockedIn
        ? Colors.amber.shade700
        : waiting
            ? Colors.orange.shade700
            : noShift
                ? Colors.grey.shade500
                : Colors.teal.shade600;
    final bannerAlpha = isDark ? 0.25 : 0.12;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: bannerAlpha),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bannerColor.withValues(alpha: isDark ? 0.5 : 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isClockedIn
                ? Icons.access_time_filled
                : waiting
                    ? Icons.hourglass_top_rounded
                    : noShift
                        ? Icons.event_busy
                        : Icons.event_available,
            color: bannerColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isClockedIn
                      ? 'On Shift'
                      : hasSchedule
                          ? 'Shift Today: ${_scheduledShift!['startTime']} – ${_scheduledShift!['endTime']}'
                          : 'No Shift Scheduled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: bannerColor,
                  ),
                ),
                if (_isClockedIn)
                  Text(
                    _formatElapsed(_shiftElapsedSeconds),
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                  )
                else if (waiting)
                  Text(
                    'Starts in ${_formatElapsed(_secondsUntilShift)}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600),
                  )
                else if (hasSchedule && (_scheduledShift!['note'] as String?)?.isNotEmpty == true)
                  Text(
                    _scheduledShift!['note'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.teal.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          ElevatedButton(
            // Disabled when no schedule or shift hasn't started yet
            onPressed: _isClockedIn
                ? _onClockOut
                : (waiting || noShift)
                    ? null
                    : _onClockIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isClockedIn
                  ? Colors.red
                  : (waiting || noShift)
                      ? Colors.grey.shade400
                      : bannerColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: Text(_isClockedIn ? 'Clock Out' : 'Clock In'),
          ),
        ],
      ),
    );
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
        .listen((snap) async {
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

      // Count all routes this driver has made for the same area to derive
      // an incremental route number (e.g. "Wah · 3").
      int routeNumber = 1;
      if (route.assignedArea.isNotEmpty) {
        final countSnap = await _db
            .collection('routes')
            .where('driverId', isEqualTo: uid)
            .where('assignedArea', isEqualTo: route.assignedArea)
            .get();
        routeNumber = countSnap.docs.length;
      }

      if (!mounted) return;
      setState(() {
        completedBins = route.completedStops;
        totalBins = route.totalStops;
        routeId = route.assignedArea.isNotEmpty
            ? '${route.assignedArea} · $routeNumber'
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

  static const double _proximityRadiusM = 10000; // must match map_page

  // Cache the last snapshot so we can recount once _user finishes loading
  // (the user doc is fetched async — without this, the first count fires
  // before assignedArea is known and the stat stays wrong until a bin changes).
  QuerySnapshot<Map<String, dynamic>>? _lastBinsSnapshot;

  /// Re-runs the critical-bin count using the current _user assignment.
  /// Safe to call any time _user changes.
  void _recountCriticalBins() {
    final snap = _lastBinsSnapshot;
    if (snap == null || !mounted) return;
    _applyCriticalBinsCount(snap);
  }

  /// Count critical bins visible to this worker (area-scoped or proximity-based).
  void _subscribeToBinStats() {
    _binsSub = _db.collection('bins').snapshots().listen((snap) {
      if (!mounted) return;
      _lastBinsSnapshot = snap;
      _applyCriticalBinsCount(snap);
    });
  }

  void _applyCriticalBinsCount(QuerySnapshot<Map<String, dynamic>> snap) {
    final workerArea  = _user?.assignedArea ?? '';
    final workerWaste = (_user?.assignedWasteType ?? '').toLowerCase();
    final userLat     = _user?.lat ?? 0.0;
    final userLng     = _user?.lng ?? 0.0;

    final critical = snap.docs.where((d) {
      final data   = d.data();
      final fill   = (data['fillLevel'] ?? data['fill_level'] ?? 0) as num;
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (workerArea.isNotEmpty) {
        // Canonical match — see utils/area_match.dart. Rejects bins with
        // no area set, and handles case/whitespace/hierarchy uniformly.
        final binArea = readBinArea(data);
        if (!areaMatches(binArea, workerArea)) return false;
      } else if (userLat != 0.0 && userLng != 0.0) {
        // No area assigned — fall back to proximity using stored coordinates.
        final binLat = (data['lat'] as num?)?.toDouble()
            ?? (data['location'] is GeoPoint
                ? (data['location'] as GeoPoint).latitude
                : null);
        final binLng = (data['lng'] as num?)?.toDouble()
            ?? (data['location'] is GeoPoint
                ? (data['location'] as GeoPoint).longitude
                : null);
        if (binLat != null && binLng != null) {
          final distM = Geolocator.distanceBetween(
              userLat, userLng, binLat, binLng);
          if (distM > _proximityRadiusM) return false;
        }
      }

      // Wildcard waste types — "Mixed"/"All"/"Any"/"General" mean the worker
      // collects every category. Mirrors map_page.dart so the home stat
      // matches what's actually visible on the map.
      const wildcardWaste = {'mixed', 'all', 'any', 'general'};
      if (workerWaste.isNotEmpty && !wildcardWaste.contains(workerWaste)) {
        final binWaste =
            (data['wasteType'] ?? data['type'] ?? '').toString().toLowerCase();
        if (binWaste != workerWaste) return false;
      }

      // Critical = fill exceeds the LIVE admin threshold (settings/main) OR
      // backend/admin already tagged the status as critical/full/overflowing.
      // Using the live threshold makes the count update instantly when the
      // admin slides the threshold lower — no need to wait for the backend
      // to finish its batch reclassification.
      const criticalStatuses = {'critical', 'full', 'overflowing'};
      return fill >= _criticalThreshold || criticalStatuses.contains(status);
    }).length;
    debugPrint(
      '[HomeStats] criticalBinsNearby=$critical '
      'workerArea="$workerArea" workerWaste="$workerWaste" '
      'totalBins=${snap.docs.length}',
    );
    setState(() => criticalBinsNearby = critical);
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
        // The bin-stats subscription starts in initState before the user
        // doc has loaded, so the first snapshot's count is computed with
        // assignedArea = ''. Recount now that we know the worker's area.
        _recountCriticalBins();
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
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppCol.primaryDark
              : AppCol.primary.withValues(alpha: 0.5),
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
          const SizedBox(height: 12),
          _buildShiftBanner(),
          const SizedBox(height: 16),
          _buildCircularProgressSection(screenSize),
          const SizedBox(height: 30),
          _buildKeyRouteMetricsGrid(screenSize),
          const SizedBox(height: 100),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_sweep_rounded,
                    size: screenSize.width * 0.1,
                    color: AppCol.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$progressPercentage%',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Route Progress',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.032,
                      color: scheme.onSurface.withValues(alpha: 0.5),
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
                title: 'Route',
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