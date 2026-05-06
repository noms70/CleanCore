import 'package:cc/utils/colors.dart';
import 'package:flutter/material.dart';

/// Programmatic CleanCore logo — a teal truck carrying a recycling bin.
/// [size] controls the overall scale. [showText] adds the brand name below.
/// [darkBackground] switches text to white (for use on dark/gradient backgrounds).
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool darkBackground;

  const AppLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: size),
        if (showText) ...[
          SizedBox(height: size * 0.14),
          _buildBrandName(),
        ],
      ],
    );
  }

  Widget _buildBrandName() {
    final textColor = darkBackground ? Colors.white : AppCol.primaryDark;
    final accentColor = AppCol.primary;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Clean',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: size * 0.30,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: 'Core',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: size * 0.30,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shared paints ────────────────────────────────────────────────────────
    final tealFill = Paint()
      ..shader = LinearGradient(
        colors: [AppCol.primary, AppCol.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final darkFill = Paint()
      ..color = AppCol.primaryDark
      ..style = PaintingStyle.fill;

    final whiteFaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // ── Truck body ───────────────────────────────────────────────────────────
    // Main body rectangle — occupies left 72% of canvas
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.10, w * 0.72, h * 0.60),
      topLeft: const Radius.circular(6),
      bottomLeft: const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, tealFill);

    // ── Cab (driver compartment) — right side ────────────────────────────────
    final cabPath = Path()
      ..moveTo(w * 0.72, h * 0.10)
      ..lineTo(w * 0.95, h * 0.10)
      ..lineTo(w * 1.00, h * 0.26)
      ..lineTo(w * 1.00, h * 0.70)
      ..lineTo(w * 0.72, h * 0.70)
      ..close();

    final cabPaint = Paint()
      ..color = AppCol.primaryDark
      ..style = PaintingStyle.fill;
    canvas.drawPath(cabPath, cabPaint);

    // Cab window
    final windowPath = Path()
      ..moveTo(w * 0.74, h * 0.14)
      ..lineTo(w * 0.93, h * 0.14)
      ..lineTo(w * 0.97, h * 0.28)
      ..lineTo(w * 0.97, h * 0.48)
      ..lineTo(w * 0.74, h * 0.48)
      ..close();
    canvas.drawPath(windowPath, whiteFaint);

    // ── Recycling bin on truck bed ────────────────────────────────────────────
    // Bin body
    final binRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.12, h * 0.00, w * 0.44, h * 0.10),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    canvas.drawRRect(binRect, darkFill);

    // Bin opening indicator (lighter strip)
    final binOpenRect = Rect.fromLTWH(w * 0.24, h * 0.01, w * 0.20, h * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(binOpenRect, const Radius.circular(2)),
      whiteFaint,
    );

    // ── Chassis / underbody ──────────────────────────────────────────────────
    final chassisRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.70, w * 1.00, h * 0.06),
      bottomLeft: const Radius.circular(3),
    );
    canvas.drawRRect(chassisRect, darkFill);

    // ── Wheels ───────────────────────────────────────────────────────────────
    final rimPaint  = Paint()..color = AppCol.primary;
    final tirePaint  = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;

    void drawWheel(double cx, double cy) {
      final r      = w * 0.095;
      final center = Offset(cx, cy);
      canvas.drawCircle(center, r,         tirePaint);
      canvas.drawCircle(center, r * 0.55,  rimPaint);
      canvas.drawCircle(center, r * 0.28,  tirePaint);
    }

    drawWheel(w * 0.18, h * 0.88); // rear wheel
    drawWheel(w * 0.88, h * 0.88); // front wheel

    // ── Recycling arrows (small emblem on body) ──────────────────────────────
    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    final cx = w * 0.36;
    final cy = h * 0.40;
    final ar = w * 0.10;

    // Three rotating arrows (simplified arcs)
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * 2.094); // 120° apart
      final arcRect = Rect.fromCircle(center: Offset(0, -ar * 0.6), radius: ar * 0.5);
      canvas.drawArc(arcRect, -0.5, 2.8, false, arrowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
