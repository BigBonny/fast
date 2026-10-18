import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/tr.dart';

/// FAST Pro intro carousel — four full-screen branded slides. The
/// artwork already contains the Retour / Passer / Suivant buttons and
/// the page dots, so transparent hit zones are laid exactly over the
/// baked controls: the visuals stay pixel-perfect while the buttons
/// actually do something.
///
/// Also used for the client intro — pass different [images] and
/// [dismissedPrefKey]. A "Ne plus afficher" toggle at the bottom-left
/// persists the user's choice so the carousel stops auto-playing.
class ProIntroSlides extends StatefulWidget {
  /// Called when the user finishes the last slide (Suivant) or skips
  /// (Passer) at any point.
  final VoidCallback onDone;

  /// Called when Retour is tapped on the first slide — there is no
  /// earlier slide to go back to. Optional; when null the tap is a
  /// no-op pop attempt.
  final VoidCallback? onBack;

  /// Full-bleed slide artwork, in order.
  final List<String> images;

  /// SharedPreferences key that suppresses the carousel once the user
  /// ticks "don't show again".
  final String dismissedPrefKey;

  static const String proDismissedKey = 'fast_pro_intro_dismissed';
  static const String clientDismissedKey = 'fast_client_intro_dismissed';

  const ProIntroSlides({
    super.key,
    required this.onDone,
    this.onBack,
    this.images = const [
      'assets/images/pro_tuto_1.jpg',
      'assets/images/pro_tuto_2.jpg',
      'assets/images/pro_tuto_3.jpg',
      'assets/images/pro_tuto_4.jpg',
    ],
    this.dismissedPrefKey = proDismissedKey,
  });

  /// True when the user previously ticked "don't show again".
  static Future<bool> isDismissed([
    String prefKey = proDismissedKey,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  /// Clears the dismissal flag — e.g. "Revoir le tutoriel" should be
  /// able to bring the carousel back.
  static Future<void> resetDismissed([
    String prefKey = proDismissedKey,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
  }

  @override
  State<ProIntroSlides> createState() => _ProIntroSlidesState();
}

class _ProIntroSlidesState extends State<ProIntroSlides> {
  final PageController _page = PageController();
  int _index = 0;
  bool _dontShowAgain = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _toggleDontShowAgain() async {
    final next = !_dontShowAgain;
    setState(() => _dontShowAgain = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.dismissedPrefKey, next);
  }

  void _retour() {
    if (_index > 0) {
      _page.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onBack?.call();
    }
  }

  void _suivant() {
    if (_index < widget.images.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0416),
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return Stack(
            children: [
              PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.images.length,
                itemBuilder: (_, i) => Image.asset(
                  widget.images[i],
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              // Retour — baked top-left in the artwork
              Positioned(
                left: 0,
                top: 0,
                width: w * 0.36,
                height: h * 0.085,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _retour,
                ),
              ),
              // Passer — baked top-right
              Positioned(
                right: 0,
                top: 0,
                width: w * 0.32,
                height: h * 0.085,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDone,
                ),
              ),
              // Suivant — baked bottom pill (last slide completes)
              Positioned(
                left: w * 0.055,
                right: w * 0.055,
                top: h * 0.888,
                height: h * 0.068,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _suivant,
                ),
              ),
              // "Ne plus afficher" — the artwork has no such control, so
              // this one is rendered live, tucked into the bottom-left
              // corner where every slide has empty space.
              Positioned(
                left: w * 0.04,
                top: h * 0.948,
                height: h * 0.045,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleDontShowAgain,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _dontShowAgain
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 14,
                          color: _dontShowAgain
                              ? const Color(0xFFF59E0B)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr(context, 'dont_show_again'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
