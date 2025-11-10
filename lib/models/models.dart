import 'package:flutter/material.dart';

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
