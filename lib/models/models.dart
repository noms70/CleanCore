import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BinLocation {
  final String id;
  final double lat;
  final double lng;
  final int fullness;
  final bool isCritical;
  final String area;
  final String status;
  final int capacity;

  BinLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.fullness,
    required this.isCritical,
    required this.area,
    required this.status,
    required this.capacity,
  });

  // Factory constructor to create a BinLocation from a Firestore document
  factory BinLocation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    // Firestore's GeoPoint is the preferred way to store coordinates
    GeoPoint location = data['location'] ?? GeoPoint(0, 0);
    return BinLocation(
      id: doc.id,
      lat: location.latitude,
      lng: location.longitude,
      fullness: data['fullness'] ?? 0,
      isCritical: data['isCritical'] ?? false,
      // The model uses 'area', but your database has 'name'. Let's use 'name' for now.
      area: data['name'] ?? '',
      status: data['status'] ?? '',
      capacity: data['capacity'] ?? 0,
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
