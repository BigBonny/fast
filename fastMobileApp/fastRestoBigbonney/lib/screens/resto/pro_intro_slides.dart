import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/tr.dart';

/// FAST Pro intro carousel — three full-screen branded slides. The
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

  /// Where the baked Suivant / Commencer pill sits on each slide, as
  /// fractions of the artwork (0..1 in both axes). The pill was drawn
  /// at a slightly different height on every slide, so one rect per
  /// image; a shorter list falls back to its last entry.
  final List<Rect> nextButtonRects;

  static const String proDismissedKey = 'fast_pro_intro_dismissed';
  static const String clientDismissedKey = 'fast_client_intro_dismissed';

  /// All artwork is 576x1024 — the hit zones below are measured on it.
  static const double artAspect = 576 / 1024;

  /// Three slides, in the baked dot order: visibilité → menu IA →
  /// gain de temps.
  static const List<String> proImages = [
    'assets/images/pro_intro_1.jpg',
    'assets/images/pro_intro_2.jpg',
    'assets/images/pro_intro_3.jpg',
  ];
  static const List<Rect> proNextRects = [
    Rect.fromLTRB(0.06, 0.82, 0.94, 0.91), // visibilité / clients
    Rect.fromLTRB(0.05, 0.845, 0.95, 0.935), // menu en quelques secondes
    Rect.fromLTRB(0.05, 0.84, 0.95, 0.925), // gagnez du temps
  ];
  static const List<String> clientImages = [
    'assets/images/client_tuto_1.jpg',
    'assets/images/client_tuto_2.jpg',
    'assets/images/client_tuto_3.jpg',
    'assets/images/client_tuto_4.jpg',
  ];
  static const List<Rect> clientNextRects = [
    Rect.fromLTRB(0.08, 0.836, 0.92, 0.936), // Commencer
    Rect.fromLTRB(0.08, 0.816, 0.92, 0.916), // GPS
    Rect.fromLTRB(0.08, 0.816, 0.92, 0.916), // proximité
    Rect.fromLTRB(0.06, 0.860, 0.94, 0.952), // C'est parti
  ];
  static const Rect _retourRect = Rect.fromLTRB(0.0, 0.0, 0.28, 0.075);
  static const Rect _passerRect = Rect.fromLTRB(0.76, 0.0, 1.0, 0.075);

  const ProIntroSlides({
    super.key,
    required this.onDone,
    this.onBack,
    this.images = proImages,
    this.dismissedPrefKey = proDismissedKey,
    this.nextButtonRects = proNextRects,
  });

  Rect nextRectFor(int index) =>
      nextButtonRects[index.clamp(0, nextButtonRects.length - 1)];

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

  /// Maps an artwork-fraction rect onto the on-screen fitted image.
  Positioned _zone(Rect art, Rect frac, VoidCallback onTap) {
    return Positioned(
      left: art.left + frac.left * art.width,
      top: art.top + frac.top * art.height,
      width: frac.width * art.width,
      height: frac.height * art.height,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0416),
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          // Letterbox the 9:16 artwork instead of cropping it — the baked
          // buttons must stay visible and sit exactly under the hit zones
          // on every screen ratio.
          final fitted = applyBoxFit(
            BoxFit.contain,
            const Size(576, 1024),
            Size(w, h),
          ).destination;
          final art = Rect.fromLTWH(
            (w - fitted.width) / 2,
            (h - fitted.height) / 2,
            fitted.width,
            fitted.height,
          );
          final padding = MediaQuery.paddingOf(context);
          final spareBottom = h - art.bottom;
          final chipBottom = spareBottom >= 44
              ? (spareBottom - 32) / 2
              : padding.bottom + 6;
          return Stack(
            children: [
              PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.images.length,
                itemBuilder: (_, i) => Image.asset(
                  widget.images[i],
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              // Retour — baked top-left in the artwork
              _zone(art, ProIntroSlides._retourRect, _retour),
              // Passer — baked top-right
              _zone(art, ProIntroSlides._passerRect, widget.onDone),
              // Suivant / Commencer — baked bottom pill (last slide completes)
              _zone(art, widget.nextRectFor(_index), _suivant),
              // "Ne plus afficher" — the artwork has no such control, so
              // this one is rendered live. It sits in the letterbox band
              // under the artwork when there is one, otherwise in the
              // bottom-right corner, clear of the page dots and counter.
              Positioned(
                right: 12,
                bottom: chipBottom,
                height: 32,
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
