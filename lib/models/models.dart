import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BinLocation {
  final String id;
  final double lat;
  final double lng;
  final int fullness;   // fill percentage 0-100; internally named 'fullness'
  final bool isCritical;
  final String area;    // human-readable label (wasteType or sector)
  final String status;
  final int capacity;
  final String wasteType; // from backend 'wasteType' field

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

    return BinLocation(
      id: doc.id,
      lat: lat,
      lng: lng,
      fullness: fill,
      isCritical: critical,
      // area label: prefer sector, fall back to wasteType or legacy 'name'
      area: (data['sector'] ?? wt.isNotEmpty ? wt : data['name'] ?? 'Unknown').toString(),
      status: rawStatus.isEmpty ? 'normal' : rawStatus,
      capacity: ((data['capacity'] ?? 240) as num).toInt(),
      wasteType: wt,
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

/// Lightweight representation of an active route document from Firestore.
class ActiveRoute {
  final String routeId;
  final String driverId;
  final int totalStops;
  final int completedStops;
  final String status;
  final double estimatedFuel;
  final double totalDistanceKm;

  ActiveRoute({
    required this.routeId,
    required this.driverId,
    required this.totalStops,
    required this.completedStops,
    required this.status,
    required this.estimatedFuel,
    required this.totalDistanceKm,
  });

  factory ActiveRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActiveRoute(
      routeId: d['routeId'] as String? ?? doc.id,
      driverId: d['driverId'] as String? ?? '',
      totalStops: ((d['totalStops'] ?? 0) as num).toInt(),
      completedStops: ((d['completedStops'] ?? 0) as num).toInt(),
      status: d['status'] as String? ?? 'active',
      estimatedFuel: ((d['estimatedFuel'] ?? 0.0) as num).toDouble(),
      totalDistanceKm: ((d['totalDistanceKm'] ?? 0.0) as num).toDouble(),
    );
  }

  double get progressFraction =>
      totalStops == 0 ? 0.0 : completedStops / totalStops;
}
