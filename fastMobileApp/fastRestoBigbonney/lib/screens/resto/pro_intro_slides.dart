import 'package:flutter/material.dart';

/// FAST Pro intro carousel — four full-screen branded slides. The
/// artwork already contains the Retour / Passer / Suivant buttons and
/// the page dots, so transparent hit zones are laid exactly over the
/// baked controls: the visuals stay pixel-perfect while the buttons
/// actually do something.
class ProIntroSlides extends StatefulWidget {
  /// Called when the user finishes the last slide (Suivant) or skips
  /// (Passer) at any point.
  final VoidCallback onDone;

  /// Called when Retour is tapped on the first slide — there is no
  /// earlier slide to go back to. Optional; when null the tap is a
  /// no-op pop attempt.
  final VoidCallback? onBack;

  const ProIntroSlides({super.key, required this.onDone, this.onBack});

  @override
  State<ProIntroSlides> createState() => _ProIntroSlidesState();
}

class _ProIntroSlidesState extends State<ProIntroSlides> {
  static const _images = [
    'assets/images/pro_tuto_1.jpg',
    'assets/images/pro_tuto_2.jpg',
    'assets/images/pro_tuto_3.jpg',
    'assets/images/pro_tuto_4.jpg',
  ];

  final PageController _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
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
    if (_index < _images.length - 1) {
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
                itemCount: _images.length,
                itemBuilder: (_, i) => Image.asset(
                  _images[i],
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
            ],
          );
        },
      ),
    );
  }
}
