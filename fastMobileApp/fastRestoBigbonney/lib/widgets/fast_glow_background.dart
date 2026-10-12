import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded dark hero background — deep violet-to-black base with neon
/// glow arcs (purple/magenta upper-left, orange sweeping the right),
/// matching the FAST landing/signup visuals.
class FastGlowBackground extends StatelessWidget {
  const FastGlowBackground({
    super.key,
    required this.child,
    this.expand = false,
    this.arcs = true,
  });

  final Widget child;

  /// Fill all available space (full-screen backdrops) instead of
  /// shrinking to [child] (hero bands inside a Column).
  final bool expand;

  /// Paint the thin neon arc lines on top of the diffuse glows. Off for
  /// the home hero, which layers a photo and wants only soft light.
  final bool arcs;

  static const Color topColor = Color(0xFF1B0B33);
  static const Color bottomColor = Color(0xFF0A0416);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: expand ? double.infinity : null,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: CustomPaint(
        painter: _GlowArcsPainter(arcs: arcs),
        child: child,
      ),
    );
  }
}

class _GlowArcsPainter extends CustomPainter {
  _GlowArcsPainter({required this.arcs});

  final bool arcs;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Wide diffuse glows first (cheap radial gradients painted as rects).
    _radialGlow(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.30),
      radius: size.width * 0.75,
      color: const Color(0xFF7C3AED),
      opacity: 0.30,
    );
    _radialGlow(
      canvas,
      center: Offset(size.width * 0.95, size.height * 0.75),
      radius: size.width * 0.85,
      color: const Color(0xFFF97316),
      opacity: 0.32,
    );
    _radialGlow(
      canvas,
      center: Offset(size.width * 0.30, size.height * 0.95),
      radius: size.width * 0.6,
      color: const Color(0xFFEC4899),
      opacity: 0.16,
    );

    if (!arcs) {
      // Photo heroes: a stronger magenta bloom in the top-left corner
      // and warm light pooling bottom-center, like the reference art.
      _radialGlow(
        canvas,
        center: Offset(size.width * 0.0, size.height * 0.05),
        radius: size.width * 0.55,
        color: const Color(0xFFD946EF),
        opacity: 0.28,
      );
      _radialGlow(
        canvas,
        center: Offset(size.width * 0.5, size.height * 1.05),
        radius: size.width * 0.55,
        color: const Color(0xFFF43F5E),
        opacity: 0.22,
      );
      return;
    }

    // Thin neon arcs — blurred halo stroke plus a crisp core line.
    // Orange arc sweeping the right edge.
    _arc(
      canvas,
      rect,
      center: Offset(size.width * 1.12, size.height * 0.78),
      radius: size.width * 0.58,
      startAngle: math.pi * 0.85,
      sweep: math.pi * 0.75,
      color: const Color(0xFFFF7A1A),
    );
    // Purple arc across the upper left.
    _arc(
      canvas,
      rect,
      center: Offset(-size.width * 0.18, size.height * 0.18),
      radius: size.width * 0.62,
      startAngle: -math.pi * 0.15,
      sweep: math.pi * 0.6,
      color: const Color(0xFF9D4EDD),
    );
    // Faint magenta arc along the bottom.
    _arc(
      canvas,
      rect,
      center: Offset(size.width * 0.4, size.height * 1.35),
      radius: size.width * 0.7,
      startAngle: math.pi * 1.15,
      sweep: math.pi * 0.55,
      color: const Color(0xFFEC4899),
    );
  }

  void _radialGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _arc(
    Canvas canvas,
    Rect rect, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweep,
    required Color color,
  }) {
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipRect(rect);

    final halo = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawArc(arcRect, startAngle, sweep, false, halo);

    final core = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, sweep, false, core);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlowArcsPainter oldDelegate) =>
      oldDelegate.arcs != arcs;
}
