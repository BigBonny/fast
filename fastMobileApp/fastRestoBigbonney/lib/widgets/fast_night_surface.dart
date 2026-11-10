import 'package:flutter/material.dart';

import '../theme.dart';
import 'fast_glow_background.dart';

/// The FAST night surface — the same deep violet-black as the home hero
/// with one warm amber light and a faint violet one. It carries the
/// app's atmosphere onto a few set pieces (the pickup code, the hero)
/// and is not meant for ordinary cards.
///
/// It looks the same in light and dark mode. A hairline border keeps it
/// distinct from the page when the page itself is dark.
class FastNightSurface extends StatelessWidget {
  const FastNightSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FASTSpace.s16),
    this.radius = FASTRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Primary text on the night surface.
  static const Color onNight = Color(0xFFF4F4F5);

  /// Secondary text on the night surface.
  static const Color onNightMuted = Color(0xFFB8AECF);

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // A radius of 0 means a full-bleed band (the drawer header): it gets
    // no hairline and no outer glow, since it has no edges to set apart.
    final isCard = radius > 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: isCard
            ? Border.all(color: Colors.white.withValues(alpha: 0.10))
            : null,
        boxShadow: isCard
            ? [
                BoxShadow(
                  color: FASTBrand.amber.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: CustomPaint(
          painter: const _NightPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _NightPainter extends CustomPainter {
  const _NightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FastGlowBackground.topColor, FastGlowBackground.bottomColor],
        ).createShader(rect),
    );
    _glow(
      canvas,
      Offset(size.width * 1.0, size.height * 0.95),
      size.width * 0.8,
      FASTBrand.ember,
      0.38,
    );
    _glow(
      canvas,
      Offset(size.width * 0.75, size.height * 1.1),
      size.width * 0.5,
      FASTBrand.amber,
      0.26,
    );
    _glow(
      canvas,
      Offset(0, 0),
      size.width * 0.6,
      const Color(0xFF7C3AED),
      0.22,
    );
  }

  void _glow(Canvas canvas, Offset c, double r, Color color, double opacity) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _NightPainter oldDelegate) => false;
}
