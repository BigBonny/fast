// lib/widgets/intro_carousel.dart
// Shared intro carousel — dark branded glow stage, one accent color per
// slide, breathing icon medallion with a slow orbiting dashed ring,
// sliding text transitions and a gradient CTA. Used by the first-launch
// onboarding and by the client intro gate.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import 'fast_glow_background.dart';

/// One slide of [FastIntroCarousel].
class FastIntroSlide {
  final IconData icon;

  /// Full slide title, in the user's language. When [accentPart] is set
  /// it must be a substring of [title]; that span is rendered in the
  /// slide's accent color, the rest stays white.
  final String title;
  final String? accentPart;
  final String description;

  /// Primary slide color (title accent, medallion, progress, CTA left).
  final Color accent;

  /// Secondary gradient/glow color (CTA right, halo, satellite dot).
  final Color glow;

  const FastIntroSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.glow,
    this.accentPart,
  });
}

class FastIntroCarousel extends StatefulWidget {
  final List<FastIntroSlide> slides;

  /// Called when the user finishes the last slide or taps Passer.
  final VoidCallback onDone;

  /// Called when Retour is tapped on the first slide. Null hides the
  /// first-slide back affordance entirely.
  final VoidCallback? onBack;

  /// When set, a "don't show again" chip is rendered and the choice is
  /// persisted under this SharedPreferences key.
  final String? dismissedPrefKey;

  const FastIntroCarousel({
    super.key,
    required this.slides,
    required this.onDone,
    this.onBack,
    this.dismissedPrefKey,
  });

  /// True when the user previously ticked "don't show again" for [prefKey].
  static Future<bool> isDismissed(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  /// Clears a dismissal flag — e.g. a "Revoir le tutoriel" action.
  static Future<void> resetDismissed(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
  }

  @override
  State<FastIntroCarousel> createState() => _FastIntroCarouselState();
}

class _FastIntroCarouselState extends State<FastIntroCarousel>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void dispose() {
    _breathe.dispose();
    _orbit.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _retour() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onBack?.call();
    }
  }

  void _suivant() {
    if (_currentPage < widget.slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  Future<void> _toggleDontShowAgain() async {
    final next = !_dontShowAgain;
    setState(() => _dontShowAgain = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.dismissedPrefKey!, next);
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_currentPage];
    final isLast = _currentPage == widget.slides.length - 1;

    return Scaffold(
      backgroundColor: FastGlowBackground.bottomColor,
      body: FastGlowBackground(
        expand: true,
        child: SafeArea(
          child: Column(
            children: [
              // Header — Retour left, brand center, Passer right.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: (_currentPage > 0 || widget.onBack != null)
                            ? _headerPill(
                                onTap: _retour,
                                icon: Icons.arrow_back_rounded,
                                label: tr(context, 'back'),
                              )
                            : const SizedBox(width: 96),
                      ),
                    ),
                    const MiniFastWordmark(),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _headerPill(
                          onTap: widget.onDone,
                          label: tr(context, 'skip_tuto'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemCount: widget.slides.length,
                  itemBuilder: (context, index) =>
                      _buildSlide(widget.slides[index]),
                ),
              ),

              // Don't-show-again chip — only when a pref key is configured.
              if (widget.dismissedPrefKey != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleDontShowAgain,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _dontShowAgain
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 15,
                          color: _dontShowAgain
                              ? slide.accent
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tr(context, 'dont_show_again'),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Progress + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.slides.length, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 34 : 10,
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [slide.accent, slide.glow],
                                  )
                                : null,
                            color: isActive
                                ? null
                                : Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: slide.accent
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _suivant,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [slide.accent, slide.glow],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: slide.accent.withValues(alpha: 0.45),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast
                                  ? tr(context, 'get_started')
                                  : tr(context, 'next'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              isLast
                                  ? Icons.bolt
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerPill({
    required VoidCallback onTap,
    required String label,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(FastIntroSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_breathe, _orbit]),
                builder: (context, _) {
                  final scale = 1 + 0.035 * _breathe.value;
                  final angle = _orbit.value * 2 * math.pi;
                  return SizedBox(
                    width: 270,
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                slide.accent.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: angle,
                          child: CustomPaint(
                            size: const Size(228, 228),
                            painter: DashedRingPainter(
                              color: slide.accent.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(
                            114 * math.cos(angle + math.pi / 3),
                            114 * math.sin(angle + math.pi / 3),
                          ),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: slide.glow,
                              boxShadow: [
                                BoxShadow(
                                  color: slide.glow.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(44),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [slide.accent, slide.glow],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: slide.accent.withValues(alpha: 0.5),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1.4,
                              ),
                            ),
                            child: Icon(
                              slide.icon,
                              size: 68,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.12, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_currentPage),
                children: [
                  Text(
                    '0${_currentPage + 1} — 0${widget.slides.length}',
                    style: TextStyle(
                      color: slide.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTitle(slide),
                  const SizedBox(height: 14),
                  Container(
                    width: 44,
                    height: 3.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [slide.accent, slide.glow],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(FastIntroSlide slide) {
    const white = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.15,
      letterSpacing: -0.4,
    );
    final part = slide.accentPart;
    final split = part == null ? -1 : slide.title.indexOf(part);
    if (part == null || split < 0) {
      return Text(slide.title, textAlign: TextAlign.center, style: white);
    }
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        children: [
          TextSpan(text: slide.title.substring(0, split), style: white),
          TextSpan(text: part, style: white.copyWith(color: slide.accent)),
          TextSpan(
            text: slide.title.substring(split + part.length),
            style: white,
          ),
        ],
      ),
    );
  }
}

/// Compact amber-gradient FAST wordmark used in intro headers.
class MiniFastWordmark extends StatelessWidget {
  const MiniFastWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 20),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFD97706)],
          ).createShader(rect),
          child: const Text(
            'FAST',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 21,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Evenly spaced dashes around a full circle.
class DashedRingPainter extends CustomPainter {
  DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const dashCount = 44;
    const dashSweep = (2 * math.pi / dashCount) * 0.45;
    for (var i = 0; i < dashCount; i++) {
      final start = (i / dashCount) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
