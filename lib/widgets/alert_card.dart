import 'package:cc/models/models.dart';
import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';

class AlertCard extends StatelessWidget {
  // 1. Add a field to hold the alert data
  final Alert alert;

  // 2. Require the alert in the constructor
  const AlertCard({
    super.key,
    required this.alert, // <-- This is new
  });

  // 3. This is the correct 'build' method that Flutter calls
  @override
  Widget build(BuildContext context) {
    // Your UI logic goes here
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 4. Access the alert data using 'widget.alert' or just 'alert'
        color: alert.type == 'success'
            ? Colors.green.withOpacity(0.1)
            : alert.type == 'warning'
            ? Colors.orange.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alert.type == 'success'
              ? Colors.green.withOpacity(0.3)
              : alert.type == 'warning'
              ? Colors.orange.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.icon,
            color: alert.type == 'success'
                ? Colors.green
                : alert.type == 'warning'
                ? Colors.orange
                : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppCol.btntext,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(fontSize: 12, color: AppCol.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
