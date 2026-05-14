import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// ── BACKEND URL CONFIG ────────────────────────────────────────────────────────
// Change _deviceBase before running on a physical device.
//   Android emulator → '10.0.2.2'   (maps to host machine localhost)
//   Physical device  → your PC's LAN IP (run `ipconfig` on Windows / `ifconfig` on Mac)
//   Example: 'http://192.168.1.67:8000'
//const String _deviceBase = 'http://192.168.1.67:8000';
const String _deviceBase = 'https://scribe-childlike-earshot.ngrok-free.dev';
// ─────────────────────────────────────────────────────────────────────────────

/// Central service for all calls to the FastAPI backend.
class ApiService {
  static const String _base = kIsWeb
      ? 'http://localhost:8000'
      : _deviceBase;

  // Prevents ngrok's browser-warning page from being returned instead of JSON.
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
  static const Map<String, String> _baseHeaders = {
    'ngrok-skip-browser-warning': 'true',
  };

  // ── 1. Analyze bin image ──────────────────────────────────────────────────
  // Field name MUST be "image_file" — matches FastAPI's parameter name exactly.
  // binId: if given, backend UPDATES that existing doc (preserves isLocked/routeId).
  // area:  worker's assignedArea, so scanned bins stay in the right routing pool.
  Future<Map<String, dynamic>?> analyzeBin({
    List<int>? imageBytes,
    String? imageName,
    File? imageFile,    // legacy mobile-only param
    String? binId,      // existing Firestore bin ID to update (not create)
    String? area,       // worker's assignedArea
    required double lat,
    required double lng,
  }) async {
    try {
      final params = <String, String>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        if (binId != null && binId.isNotEmpty) 'bin_id': binId,
        if (area != null && area.isNotEmpty) 'area': area,
      };
      final uri = Uri.parse('$_base/analyze/').replace(queryParameters: params);

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_baseHeaders);

      if (imageBytes != null) {
        // Works on both web and mobile
        request.files.add(http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: imageName ?? 'capture.jpg',
        ));
      } else if (!kIsWeb && imageFile != null) {
        // Mobile-only fallback
        request.files.add(
          await http.MultipartFile.fromPath('image_file', imageFile.path),
        );
      } else {
        _log('analyzeBin', 0, 'No image provided');
        return null;
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('analyzeBin', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('analyzeBin', 0, e.toString());
      return null;
    }
  }

  // ── 1b. Re-scan an existing bin (updates fill/waste/image, preserves lat/lng/area) ──
  Future<Map<String, dynamic>?> rescanBin({
    required String binId,
    required List<int> imageBytes,
    String imageName = 'capture.jpg',
  }) async {
    try {
      final uri = Uri.parse('$_base/rescan-bin/$binId');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_baseHeaders)
        ..files.add(http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: imageName,
        ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('rescanBin', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('rescanBin', 0, e.toString());
      return null;
    }
  }

  // ── 2. Update driver GPS ──────────────────────────────────────────────────
  // Field name: driver_id (NOT worker_id). Backend merges lat/lng into the
  // 'users' document so the Admin Panel map shows live driver positions.
  Future<bool> updateWorkerLocation({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/update-worker-location'),
        headers: _jsonHeaders,
        body: json.encode({
          'driver_id': driverId,
          'lat': lat,
          'lng': lng,
        }),
      );
      if (response.statusCode == 200) return true;
      _log('updateWorkerLocation', response.statusCode, response.body);
      return false;
    } catch (e) {
      _log('updateWorkerLocation', 0, e.toString());
      return false;
    }
  }

  // ── 3. Complete a collection stop ─────────────────────────────────────────
  // Backend increments completedStops, marks stop completed, resets bin, and
  // writes a pickupLog document for analytics.
  Future<Map<String, dynamic>?> completeStop({
    required String routeId,
    required String binId,
    String workerId = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/complete-stop'),
        headers: _jsonHeaders,
        body: json.encode({
          'route_id':  routeId,
          'bin_id':    binId,
          'worker_id': workerId,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 409) {
        return {'error': 'already_completed'};
      }
      _log('completeStop', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('completeStop', 0, e.toString());
      return null;
    }
  }

  // ── 3b. Skip a stop with an exception reason ────────────────────────────
  Future<Map<String, dynamic>?> skipStop({
    required String routeId,
    required String binId,
    required String workerId,
    required String exceptionType,
    String note = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/skip-stop'),
        headers: _jsonHeaders,
        body: json.encode({
          'route_id':       routeId,
          'bin_id':         binId,
          'worker_id':      workerId,
          'exception_type': exceptionType,
          'exception_note': note,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 409) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return {'error': body['detail'] ?? 'conflict'};
      }
      _log('skipStop', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('skipStop', 0, e.toString());
      return null;
    }
  }

  // ── 3c. Clock in / out shift management ─────────────────────────────────
  Future<Map<String, dynamic>?> clockIn({required String workerId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/clock-in'),
        headers: _jsonHeaders,
        body: json.encode({'worker_id': workerId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 409) {
        return {'error': 'already_clocked_in'};
      }
      _log('clockIn', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('clockIn', 0, e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> clockOut({required String workerId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/clock-out'),
        headers: _jsonHeaders,
        body: json.encode({'worker_id': workerId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 409) {
        return {'error': 'not_clocked_in'};
      }
      _log('clockOut', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('clockOut', 0, e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> getShiftStatus(String workerId) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/worker/shift-status/$workerId'),
        headers: _jsonHeaders,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('getShiftStatus', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('getShiftStatus', 0, e.toString());
      return null;
    }
  }

  // ── 4. Generate optimized route for worker ───────────────────────────────
  // Calls POST /optimize-route. Backend loads worker's assignedArea +
  // assignedWasteType from Firestore and runs the VRP algorithm.
  // depot_lat/lng should be the worker's current GPS so the first stop is
  // ordered from their actual position.
  Future<Map<String, dynamic>?> optimizeRoute({
    required String workerId,
    double depotLat = 0.0,
    double depotLng = 0.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/optimize-route'),
        headers: _jsonHeaders,
        body: json.encode({
          'worker_id': workerId,
          'depot_lat': depotLat,
          'depot_lng': depotLng,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('optimizeRoute', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('optimizeRoute', 0, e.toString());
      return null;
    }
  }

  // ── 5. Fetch worker's current active route ────────────────────────────────
  // Calls GET /worker/my-route/{worker_id}
  // Returns the full route document including ordered stops list.
  Future<Map<String, dynamic>?> getMyRoute({required String workerId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/worker/my-route/$workerId'),
        headers: _baseHeaders,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('getMyRoute', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('getMyRoute', 0, e.toString());
      return null;
    }
  }

  // ── 5. Report anomaly (broken bin / blocked road) ─────────────────────────
  Future<bool> reportAnomaly({
    required String binId,
    required String anomalyType,
    required String reportedBy,
    String sector = '',
    String priority = 'medium',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/report-anomaly'),
        headers: _jsonHeaders,
        body: json.encode({
          'bin_id': binId,
          'anomaly_type': anomalyType,
          'reported_by': reportedBy,
          'sector': sector,
          'priority': priority,
        }),
      );
      if (response.statusCode == 200) return true;
      _log('reportAnomaly', response.statusCode, response.body);
      return false;
    } catch (e) {
      _log('reportAnomaly', 0, e.toString());
      return false;
    }
  }

  void _log(String method, int code, String body) {
    // ignore: avoid_print
    print('[ApiService] $method → $code: $body');
  }
}
