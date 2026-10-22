import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import '../l10n/tr.dart';
import '../widgets/intro_carousel.dart';

/// First-launch onboarding — dark branded glow stage, one accent color per
/// slide (amber / teal / magenta). The carousel itself lives in
/// [FastIntroCarousel]; this screen only supplies the slides and the
/// completion flow.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback? onDone;
  const OnboardingScreen({super.key, this.onDone});

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_onboarding_done', true);
    if (!context.mounted) return;
    if (onDone != null) {
      onDone!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FastIntroCarousel(
      slides: [
        FastIntroSlide(
          icon: Icons.shopping_bag_outlined,
          title: tr(context, 'ob1_title'),
          description: tr(context, 'ob1_d'),
          accent: const Color(0xFFF59E0B),
          glow: const Color(0xFFF97316),
        ),
        FastIntroSlide(
          icon: Icons.explore_outlined,
          title: tr(context, 'ob2_title'),
          description: tr(context, 'ob2_d'),
          accent: const Color(0xFF00C8B3),
          glow: const Color(0xFF0EA5E9),
        ),
        FastIntroSlide(
          icon: Icons.emoji_events_outlined,
          title: tr(context, 'ob3_title'),
          description: tr(context, 'ob3_d'),
          accent: const Color(0xFFFF0066),
          glow: const Color(0xFFEC4899),
        ),
      ],
      onDone: () => _finishOnboarding(context),
    );
  }
}
