import 'dart:convert';
import 'package:cc/models/models.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Service responsible for building optimized collection routes via OSRM.
///
/// Separation of concern: all routing / polyline logic lives here,
/// keeping [MapPage] purely presentational.
class RouteService {
  static const String _osrmBase = 'http://router.project-osrm.org/route/v1/driving';

  /// Sorts [bins] by collection priority:
  /// 1. Critical bins (isCritical == true) first.
  /// 2. Then by descending fullness percentage.
  static List<BinLocation> sortByPriority(List<BinLocation> bins) {
    final sorted = List<BinLocation>.from(bins);
    sorted.sort((a, b) {
      if (a.isCritical && !b.isCritical) return -1;
      if (!a.isCritical && b.isCritical) return 1;
      return b.fullness.compareTo(a.fullness);
    });
    return sorted;
  }

  /// Fetches a road-following polyline from [origin] through all [waypoints] in order.
  ///
  /// Uses OSRM's multi-stop format:
  ///   /route/v1/driving/{lng0,lat0};{lng1,lat1};...?overview=full&geometries=polyline
  ///
  /// Falls back to straight-line segments if the API call fails.
  static Future<List<LatLng>> buildCollectionRoute({
    required LatLng origin,
    required List<BinLocation> waypoints,
  }) async {
    if (waypoints.isEmpty) return [origin];

    // Build the coordinate string: origin first, then each bin
    final coords = StringBuffer();
    coords.write('${origin.longitude},${origin.latitude}');
    for (final bin in waypoints) {
      coords.write(';${bin.lng},${bin.lat}');
    }

    final url = '$_osrmBase/$coords?overview=full&geometries=polyline';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encodedPolyline = routes[0]['geometry'] as String;
          final decoded = PolylinePoints.decodePolyline(encodedPolyline);
          return decoded
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
      }
    } catch (e) {
      // Silently fall through to straight-line fallback
    }

    // Fallback: straight lines through all stops
    final points = <LatLng>[origin];
    for (final bin in waypoints) {
      points.add(LatLng(bin.lat, bin.lng));
    }
    return points;
  }

  /// Computes the tight [LatLngBounds] enclosing all [points].
  static LatLngBounds getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final p in points) {
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
}
