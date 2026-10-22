import 'package:flutter/material.dart';
import 'resto/pro_intro_slides.dart';
import '../l10n/tr.dart';
import '../theme.dart';
import '../widgets/intro_carousel.dart';

/// Gate in front of the client app — plays the client intro carousel on
/// every entry (login, cold start) until the user ticks
/// "Ne plus afficher", which persists across launches.
class ClientIntroGate extends StatefulWidget {
  final Widget child;
  const ClientIntroGate({super.key, required this.child});

  @override
  State<ClientIntroGate> createState() => _ClientIntroGateState();
}

class _ClientIntroGateState extends State<ClientIntroGate> {
  bool? _dismissed; // null = still reading prefs
  bool _done = false;

  @override
  void initState() {
    super.initState();
    FastIntroCarousel.isDismissed(ProIntroSlides.clientDismissedKey).then((v) {
      if (mounted) setState(() => _dismissed = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done || (_dismissed ?? false)) return widget.child;
    if (_dismissed == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0416),
        body: Center(
          child: CircularProgressIndicator(color: context.fast.line),
        ),
      );
    }
    return FastIntroCarousel(
      slides: [
        FastIntroSlide(
          icon: Icons.restaurant,
          title: tr(context, 'ci1_t'),
          accentPart: tr(context, 'ci1_ta'),
          description: tr(context, 'ci1_d'),
          accent: const Color(0xFFF59E0B),
          glow: const Color(0xFFF97316),
        ),
        FastIntroSlide(
          icon: Icons.location_on_outlined,
          title: tr(context, 'ci2_t'),
          accentPart: tr(context, 'ci2_ta'),
          description: tr(context, 'ci2_d'),
          accent: const Color(0xFFA855F7),
          glow: const Color(0xFF7C3AED),
        ),
        FastIntroSlide(
          icon: Icons.bolt,
          title: tr(context, 'ci3_t'),
          accentPart: tr(context, 'ci3_ta'),
          description: tr(context, 'ci3_d'),
          accent: const Color(0xFFFF0066),
          glow: const Color(0xFFEC4899),
        ),
      ],
      dismissedPrefKey: ProIntroSlides.clientDismissedKey,
      onDone: () => setState(() => _done = true),
    );
  }
}
