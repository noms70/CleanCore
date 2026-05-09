import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BinLocation {
  final String id;
  final double lat;
  final double lng;
  final int fullness;     // fill percentage 0-100
  final bool isCritical;
  final String area;      // district/sector label
  final String status;
  final int capacity;
  final String wasteType;
  final bool isLocked;    // true = bin is already assigned to an active route

  BinLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.fullness,
    required this.isCritical,
    required this.area,
    required this.status,
    required this.capacity,
    this.wasteType = 'Unknown',
    this.isLocked = false,
  });

  /// Build a BinLocation from a Firestore document written by the backend.
  ///
  /// Backend writes:  fillLevel (int), wasteType (string), lat (float), lng (float)
  /// Legacy docs may have: fullness, GeoPoint location, name
  factory BinLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ── Coordinates: prefer flat lat/lng (backend format) ─────────────────
    double lat = 0.0;
    double lng = 0.0;
    if (data['lat'] != null && data['lng'] != null) {
      lat = (data['lat'] as num).toDouble();
      lng = (data['lng'] as num).toDouble();
    } else if (data['location'] is GeoPoint) {
      final gp = data['location'] as GeoPoint;
      lat = gp.latitude;
      lng = gp.longitude;
    }

    // ── Fill level: backend writes 'fillLevel', legacy uses 'fullness' ─────
    final fill = ((data['fillLevel'] ?? data['fill_level'] ?? data['fullness'] ?? 0) as num).toInt();

    // ── Waste type ────────────────────────────────────────────────────────
    final wt = (data['wasteType'] ?? data['waste_type'] ?? data['type'] ?? 'Unknown') as String;

    // ── Status / criticality ──────────────────────────────────────────────
    final rawStatus = (data['status'] ?? '').toString().toLowerCase();
    final critical = fill >= 90 || rawStatus == 'critical' || rawStatus == 'full';

    // ── Area label: backend writes 'area'; legacy docs may use 'sector' ─────
    final rawArea = (data['area'] ?? data['sector'] ?? '').toString().trim();
    final areaLabel = rawArea.isNotEmpty ? rawArea : (data['name'] ?? 'Unknown').toString();

    return BinLocation(
      id:         doc.id,
      lat:        lat,
      lng:        lng,
      fullness:   fill,
      isCritical: critical,
      area:       areaLabel,
      status:     rawStatus.isEmpty ? 'normal' : rawStatus,
      capacity:   ((data['capacity'] ?? 240) as num).toInt(),
      wasteType:  wt,
      isLocked:   data['isLocked'] as bool? ?? false,
    );
  }
}

class Alert {
  final String title;
  final String message;
  final String type; // 'info', 'success', 'warning'
  final IconData icon;

  Alert({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
  });
}

/// A single stop within an active route.
class RouteStop {
  final String binId;
  final double lat;
  final double lng;
  final int fillLevel;
  final String wasteType;
  final String area;
  /// Set to true by the backend when the worker completes this stop.
  final bool completed;

  RouteStop({
    required this.binId,
    required this.lat,
    required this.lng,
    required this.fillLevel,
    required this.wasteType,
    required this.area,
    this.completed = false,
  });

  factory RouteStop.fromMap(Map<String, dynamic> m) {
    return RouteStop(
      binId:     m['binId'] as String? ?? '',
      lat:       ((m['lat'] ?? 0.0) as num).toDouble(),
      lng:       ((m['lng'] ?? 0.0) as num).toDouble(),
      fillLevel: ((m['fillLevel'] ?? 0) as num).toInt(),
      wasteType: m['wasteType'] as String? ?? 'Unknown',
      area:      m['area'] as String? ?? '',
      completed: m['completed'] as bool? ?? false,
    );
  }
}

/// Full route document from the Firestore 'routes' collection.
class ActiveRoute {
  final String routeId;
  final String driverId;
  final int totalStops;
  final int completedStops;
  final String status;
  final double estimatedFuel;
  final double totalDistanceKm;
  final double carbonFootprintKg;
  final String assignedArea;
  final String assignedWasteType;
  final List<RouteStop> stops;

  ActiveRoute({
    required this.routeId,
    required this.driverId,
    required this.totalStops,
    required this.completedStops,
    required this.status,
    required this.estimatedFuel,
    required this.totalDistanceKm,
    this.carbonFootprintKg = 0.0,
    this.assignedArea = '',
    this.assignedWasteType = '',
    this.stops = const [],
  });

  factory ActiveRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawStops = d['stops'] as List<dynamic>? ?? [];
    return ActiveRoute(
      routeId:           d['routeId'] as String? ?? doc.id,
      driverId:          d['driverId'] as String? ?? '',
      totalStops:        ((d['totalStops'] ?? 0) as num).toInt(),
      completedStops:    ((d['completedStops'] ?? 0) as num).toInt(),
      status:            d['status'] as String? ?? 'active',
      estimatedFuel:     ((d['estimatedFuel'] ?? 0.0) as num).toDouble(),
      totalDistanceKm:   ((d['totalDistanceKm'] ?? 0.0) as num).toDouble(),
      carbonFootprintKg: ((d['carbonFootprintKg'] ?? 0.0) as num).toDouble(),
      assignedArea:      d['assignedArea'] as String? ?? '',
      assignedWasteType: d['assignedWasteType'] as String? ?? '',
      stops: rawStops
          .map((s) => RouteStop.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  double get progressFraction =>
      totalStops == 0 ? 0.0 : completedStops / totalStops;
}
