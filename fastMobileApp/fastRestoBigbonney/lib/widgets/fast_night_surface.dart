import 'package:flutter/material.dart';

import '../theme.dart';

/// The FAST night surface — the app icon as a surface: near-black with a
/// neon frame whose light runs gold → orange → pink → magenta, and a
/// little of that light pooling inside. It carries the brand onto a few
/// set pieces (the pickup code, the membership card, the lead promo, the
/// drawer header) and is not meant for ordinary cards.
///
/// It looks the same in light and dark mode.
class FastNightSurface extends StatelessWidget {
  const FastNightSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FASTSpace.s16),
    this.radius = FASTRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Corner radius. 0 makes a full-bleed band (the drawer header): no
  /// frame and no outer glow, since it has no edges to set apart.
  final double radius;

  /// Primary text on the night surface.
  static const Color onNight = Color(0xFFF7F4F8);

  /// Secondary text on the night surface.
  static const Color onNightMuted = Color(0xFFC0B4C8);

  /// Top and bottom of the backdrop.
  static const Color top = Color(0xFF170B16);
  static const Color bottom = Color(0xFF070409);

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final isCard = radius > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: isCard
            ? [
                BoxShadow(
                  color: FASTBrand.neonOrange.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(-6, 8),
                ),
                BoxShadow(
                  color: FASTBrand.neonPink.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(6, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: CustomPaint(
          painter: const _NightPainter(),
          foregroundPainter: isCard ? _NeonFramePainter(radius) : null,
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
          colors: [FastNightSurface.top, FastNightSurface.bottom],
        ).createShader(rect),
    );
    // Light pooling inside the frame: gold low on the leading side, pink
    // and magenta on the trailing side — the same order as the sign.
    _glow(
      canvas,
      Offset(0, size.height * 1.05),
      size.width * 0.55,
      FASTBrand.neonOrange,
      0.26,
    );
    _glow(
      canvas,
      Offset(size.width * 0.72, size.height * 1.15),
      size.width * 0.6,
      FASTBrand.neonPink,
      0.30,
    );
    _glow(
      canvas,
      Offset(size.width * 1.02, -size.height * 0.05),
      size.width * 0.5,
      FASTBrand.neonMagenta,
      0.24,
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

/// The neon tube around the card.
class _NeonFramePainter extends CustomPainter {
  const _NeonFramePainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.6;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular((radius - stroke / 2).clamp(0, double.infinity)),
    );
    final shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        FASTBrand.gold,
        FASTBrand.neonOrange,
        FASTBrand.neonPink,
        FASTBrand.neonMagenta,
      ],
    ).createShader(rect);
    // A soft halo under a crisp line, like a lit tube.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonFramePainter oldDelegate) =>
      oldDelegate.radius != radius;
}
