import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';
import '../widgets/fast_image.dart';
import '../theme.dart';
import '../l10n/tr.dart';

/// Snapchat-style fullscreen story viewer for a restaurant's menu items.
/// - Tap right → next, tap left → previous
/// - Long-press → pause (Snapchat behaviour)
/// - Images auto-advance after 5s; videos play to completion
class StoryViewerScreen extends StatefulWidget {
  final Restaurant restaurant;

  const StoryViewerScreen({super.key, required this.restaurant});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _imageDuration = Duration(seconds: 5);

  late List<MenuItem> _slides;
  int _index = 0;
  bool _paused = false;

  // Image slide progress
  late AnimationController _progress;
  VideoPlayerController? _video;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _slides = widget.restaurant.menu
        .where(
          (m) => m.available && (m.image.isNotEmpty || m.videoUrl.isNotEmpty),
        )
        .toList();
    _progress = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _startSlide();
  }

  MenuItem get _current => _slides[_index];
  bool get _isVideo => _current.videoUrl.isNotEmpty;

  void _startSlide() {
    _videoReady = false;
    _disposeVideo();
    _progress.stop();
    _progress.value = 0;

    if (_isVideo) {
      _video = VideoPlayerController.networkUrl(Uri.parse(_current.videoUrl))
        ..initialize()
            .then((_) {
              if (!mounted || _video == null) return;
              setState(() => _videoReady = true);
              _video!
                ..setLooping(false)
                ..play();
              _video!.addListener(_videoListener);
            })
            .catchError((_) {
              // Unplayable video — treat as a static slide
              if (mounted) _progress.forward();
            });
    } else {
      _progress.forward();
    }
  }

  void _videoListener() {
    final v = _video;
    if (v == null || !mounted) return;
    if (v.value.isInitialized &&
        v.value.position >=
            v.value.duration - const Duration(milliseconds: 250)) {
      _next();
    }
  }

  void _disposeVideo() {
    _video?.removeListener(_videoListener);
    _video?.dispose();
    _video = null;
  }

  void _next() {
    if (_index < _slides.length - 1) {
      setState(() => _index++);
      _startSlide();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _startSlide();
    } else {
      _progress.value = 0;
      _progress.forward();
    }
  }

  void _pause(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (value) {
      _progress.stop();
      _video?.pause();
    } else {
      _progress.forward();
      _video?.play();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            tr(context, 'no_visual'),
            style: FASTText.body.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final w = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < w / 3) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _pause(true),
        onLongPressEnd: (_) => _pause(false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            Center(
              child: _isVideo
                  ? (_videoReady
                        ? AspectRatio(
                            aspectRatio: _video!.value.aspectRatio,
                            child: VideoPlayer(_video!),
                          )
                        : const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ))
                  : FastImage(
                      _current.image,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: Container(color: const Color(0xFF18181B)),
                    ),
            ),

            // Bottom scrim + dish info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _current.name,
                      style: FASTText.title.copyWith(color: Colors.white),
                    ),
                    if (_current.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _current.description,
                        style: FASTText.body.copyWith(color: Colors.white70),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              FASTRadius.pill,
                            ),
                          ),
                          child: Text(
                            '${_current.price.toStringAsFixed(2)} €',
                            style: FASTText.price.copyWith(
                              fontSize: 14,
                              color: FASTBrand.onAmber,
                            ),
                          ),
                        ),
                        if (_current.prepTime > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(
                                FASTRadius.pill,
                              ),
                            ),
                            child: Text(
                              '~${_current.prepTime} min',
                              style: FASTText.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Top: progress segments + header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: List.generate(_slides.length, (i) {
                          return Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: i < _index
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    )
                                  : i == _index
                                  ? _isVideo
                                        ? (_videoReady
                                              ? AnimatedBuilder(
                                                  animation: _video!,
                                                  builder: (_, __) {
                                                    final dur = _video!
                                                        .value
                                                        .duration
                                                        .inMilliseconds;
                                                    final pos = _video!
                                                        .value
                                                        .position
                                                        .inMilliseconds;
                                                    return FractionallySizedBox(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      widthFactor: dur > 0
                                                          ? (pos / dur).clamp(
                                                              0.0,
                                                              1.0,
                                                            )
                                                          : 0.0,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                2,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : const SizedBox.shrink())
                                        : AnimatedBuilder(
                                            animation: _progress,
                                            builder: (_, __) =>
                                                FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor: _progress.value,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                          )
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              widget.restaurant.name.isNotEmpty
                                  ? widget.restaurant.name[0]
                                  : 'F',
                              style: FASTText.label.copyWith(
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.restaurant.name,
                              style: FASTText.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_paused)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(end: 8),
                              child: Icon(
                                Icons.pause,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              fixedSize: const Size(40, 40),
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
