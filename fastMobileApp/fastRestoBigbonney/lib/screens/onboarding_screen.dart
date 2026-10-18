import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import '../l10n/tr.dart';
import '../widgets/fast_glow_background.dart';

/// First-launch onboarding — dark branded glow stage, one accent color per
/// slide (amber / teal / magenta), breathing icon medallion with a slow
/// orbiting ring, sliding text transitions and a gradient CTA.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const OnboardingScreen({super.key, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  List<_OnboardingSlide> get _slides => [
    _OnboardingSlide(
      icon: Icons.shopping_bag_outlined,
      title: tr(context, 'ob1_title'),
      description: tr(context, 'ob1_d'),
      accent: const Color(0xFFF59E0B),
      glow: const Color(0xFFF97316),
    ),
    _OnboardingSlide(
      icon: Icons.explore_outlined,
      title: tr(context, 'ob2_title'),
      description: tr(context, 'ob2_d'),
      accent: const Color(0xFF00C8B3),
      glow: const Color(0xFF0EA5E9),
    ),
    _OnboardingSlide(
      icon: Icons.emoji_events_outlined,
      title: tr(context, 'ob3_title'),
      description: tr(context, 'ob3_d'),
      accent: const Color(0xFFFF0066),
      glow: const Color(0xFFEC4899),
    ),
  ];

  @override
  void dispose() {
    _breathe.dispose();
    _orbit.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_onboarding_done', true);
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: FastGlowBackground.bottomColor,
      body: FastGlowBackground(
        expand: true,
        child: SafeArea(
          child: Column(
            children: [
              // Header — brand left, skip right
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _MiniWordmark(),
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                      child: Text(
                        tr(context, 'skip_tuto'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
                  itemCount: _slides.length,
                  itemBuilder: (context, index) => _buildSlide(_slides[index]),
                ),
              ),

              // Progress + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                child: Column(
                  children: [
                    // Segmented progress — active segment fills with the
                    // slide's accent and stretches, the rest stay thin.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
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
                                    colors: [
                                      slide.accent,
                                      slide.glow,
                                    ],
                                  )
                                : null,
                            color: isActive
                                ? null
                                : Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: slide.accent.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),

                    // Gradient CTA — color follows the slide accent.
                    GestureDetector(
                      onTap: () {
                        if (!isLast) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
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

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Medallion scene — breathing core, orbiting dashed ring,
          // drifting satellite chips.
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
                        // Diffuse halo behind everything
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
                        // Orbiting dashed ring
                        Transform.rotate(
                          angle: angle,
                          child: CustomPaint(
                            size: const Size(228, 228),
                            painter: _DashedRingPainter(
                              color: slide.accent.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        // Satellite dot on the ring
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
                        // Core medallion
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

          // Copy — slides in from the right on each page change.
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
                  // Kicker — slide number in the accent color
                  Text(
                    '0${_currentPage + 1} — 0${_slides.length}',
                    style: TextStyle(
                      color: slide.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Accent underline
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
}

/// Compact amber-gradient FAST wordmark used in the onboarding header.
class _MiniWordmark extends StatelessWidget {
  const _MiniWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
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
class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});

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
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Color glow;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.glow,
  });
}
