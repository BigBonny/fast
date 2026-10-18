import 'package:flutter/material.dart';
import 'resto/pro_intro_slides.dart';
import '../theme.dart';

/// Gate in front of the client app — plays the branded client intro
/// slides on every entry (login, cold start) until the user ticks
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
    ProIntroSlides.isDismissed(ProIntroSlides.clientDismissedKey).then((v) {
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
    return ProIntroSlides(
      images: ProIntroSlides.clientImages,
      dismissedPrefKey: ProIntroSlides.clientDismissedKey,
      nextButtonRects: ProIntroSlides.clientNextRects,
      onDone: () => setState(() => _done = true),
    );
  }
}
