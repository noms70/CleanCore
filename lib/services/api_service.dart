import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Central service for all calls to the FastAPI backend.
///
/// Android emulator: use 10.0.2.2 (maps to the host machine's localhost).
/// Physical device:  replace with your PC's LAN IP, e.g. 192.168.1.5
class ApiService {
  static const String _base = 'http://10.0.2.2:8000';

  // ── 1. Analyze bin image ──────────────────────────────────────────────────
  // Field name MUST be "image_file" — matches FastAPI's parameter name exactly.
  // bin_id, lat, lng are passed as query params so the backend writes them to
  // the Firestore 'bins' document alongside fillLevel and wasteType.
  Future<Map<String, dynamic>?> analyzeBin({
    required File imageFile,
    required String binId,
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.parse('$_base/analyze/').replace(queryParameters: {
        'bin_id': binId,
        'lat': lat.toString(),
        'lng': lng.toString(),
      });

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

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
        headers: {'Content-Type': 'application/json'},
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
  // Field names: route_id and bin_id (match backend exactly).
  // Backend increments completedStops and resets bin fillLevel to 0.
  Future<Map<String, dynamic>?> completeStop({
    required String routeId,
    required String binId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/complete-stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'route_id': routeId,
          'bin_id': binId,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _log('completeStop', response.statusCode, response.body);
      return null;
    } catch (e) {
      _log('completeStop', 0, e.toString());
      return null;
    }
  }

  // ── 4. Report anomaly (broken bin / blocked road) ─────────────────────────
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
        headers: {'Content-Type': 'application/json'},
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
