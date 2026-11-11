import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

/// The short motion loops bundled in `assets/loops/` (720x720, 3 s, no
/// sound, no lettering). Each one belongs to one moment of the app.
enum FastLoops {
  orderPlaced('order_placed'),
  preparing('preparing'),
  ready('ready'),
  walking('walking'),
  completed('completed'),
  emptyCart('empty_cart'),
  closed('closed'),
  loading('loading'),
  pigeon('pigeon'),
  midnight('midnight'),
  milestone('milestone'),
  clock('clock');

  const FastLoops(this.file);
  final String file;

  String get asset => 'assets/loops/$file.mp4';
}

/// A silent, endlessly looping clip in a circle (or a rounded square
/// when [radius] is set). Shows [fallback] until the first frame is
/// ready, and keeps it when the clip cannot play or the system asks for
/// reduced motion, so the screen never depends on the video.
class FastLoop extends StatefulWidget {
  final FastLoops loop;
  final double size;
  final Widget? fallback;

  /// Null draws a circle.
  final double? radius;

  const FastLoop({
    super.key,
    required this.loop,
    this.size = 132,
    this.fallback,
    this.radius,
  });

  @override
  State<FastLoop> createState() => _FastLoopState();
}

class _FastLoopState extends State<FastLoop> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _start();
  }

  @override
  void didUpdateWidget(FastLoop old) {
    super.didUpdateWidget(old);
    if (old.loop != widget.loop) {
      _stop();
      _ready = false;
      if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
        _start();
      }
    }
  }

  void _start() {
    final controller = VideoPlayerController.asset(
      widget.loop.asset,
      // Never interrupt the music or podcast the customer is playing.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) async {
          if (!mounted || _controller != controller) return;
          await controller.setVolume(0);
          await controller.setLooping(true);
          await controller.play();
          if (!mounted || _controller != controller) return;
          setState(() => _ready = true);
        })
        .catchError((_) {
          // Unplayable here (missing codec, test environment): the
          // fallback stays on screen.
        });
  }

  void _stop() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final radius = BorderRadius.circular(widget.radius ?? widget.size / 2);
    final showVideo = _ready && controller != null;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: showVideo ? Colors.black : null,
        boxShadow: showVideo
            ? [
                BoxShadow(
                  color: FASTBrand.rose.withValues(alpha: 0.18),
                  blurRadius: widget.size * 0.28,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: showVideo
              ? SizedBox.expand(
                  key: ValueKey(widget.loop),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              : Center(
                  key: const ValueKey('fallback'),
                  child: widget.fallback ?? const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}

/// Hidden trigger: [taps] quick taps on [child] open [loop] in a small
/// dismissible popup. Single taps do nothing, so it is safe on a logo.
class FastSecretTap extends StatefulWidget {
  final Widget child;
  final FastLoops loop;
  final int taps;

  const FastSecretTap({
    super.key,
    required this.child,
    required this.loop,
    this.taps = 5,
  });

  @override
  State<FastSecretTap> createState() => _FastSecretTapState();
}

class _FastSecretTapState extends State<FastSecretTap> {
  int _count = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    _count = now.difference(_last) < const Duration(milliseconds: 600)
        ? _count + 1
        : 1;
    _last = now;
    if (_count >= widget.taps) {
      _count = 0;
      showFastLoopPeek(context, widget.loop);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

/// Shows [loop] large in the middle of the screen; a tap anywhere
/// closes it. No text, so nothing to translate.
Future<void> showFastLoopPeek(BuildContext context, FastLoops loop) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).pop(),
      child: Center(
        child: FastLoop(
          loop: loop,
          size: 260,
          radius: 32,
          fallback: const Icon(Icons.bolt, color: FASTBrand.gold, size: 64),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}
