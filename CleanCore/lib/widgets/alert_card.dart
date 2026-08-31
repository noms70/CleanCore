import 'package:cc/models/models.dart';
import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light-mode pastel backgrounds darken gracefully for dark mode
    Color lightBg;
    Color borderColor;
    Color iconColor;

    switch (alert.type) {
      case 'success':
        lightBg = isDark ? const Color(0xFF1B2E1B) : const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF4CAF50);
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'warning':
        lightBg = isDark ? const Color(0xFF2E2410) : const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFF9800);
        iconColor = const Color(0xFFFF9800);
        break;
      case 'error':
        lightBg = isDark ? const Color(0xFF2E1212) : const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFF44336);
        iconColor = const Color(0xFFF44336);
        break;
      default: // info
        lightBg = isDark ? const Color(0xFF122030) : const Color(0xFFE3F2FD);
        borderColor = AppCol.btnbacks;
        iconColor = AppCol.btnbacks;
    }

    final textColor = isDark ? Colors.white.withOpacity(0.9) : AppCol.btntext;
    final subTextColor = isDark ? Colors.white54 : AppCol.textGrey.withOpacity(0.8);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(isDark ? 0.05 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(alert.icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
