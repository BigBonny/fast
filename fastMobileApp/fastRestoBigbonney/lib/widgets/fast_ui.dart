import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme.dart';

// FAST motion system — shared micro-interactions and branded components.
// `FastTap` gives every tappable surface the same springy press feel,
// `FastButton` is the primary CTA (gradient, glow, loading state),
// `FastStagger` animates list entrances, `FastShimmer`/`FastSkeleton`
// cover loading states, `FastGlassCard` and `FastEmpty` round out the
// surfaces. All of them resolve colors from `context.fast`, so they
// follow the active theme automatically.

/// Springy press wrapper — scales its child down while held and
/// releases with a light elastic bounce, like native tappable cards.
class FastTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale while held down. 0.96 is the FAST signature — noticeable
  /// but not cartoonish.
  final double pressedScale;

  const FastTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
  });

  @override
  State<FastTap> createState() => _FastTapState();
}

class _FastTapState extends State<FastTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.pressedScale,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null && widget.onLongPress == null
          ? null
          : (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

enum FastButtonKind { primary, soft, outline, ghost }

/// Primary FAST call-to-action — amber gradient, warm glow, springy
/// press, built-in loading state.
class FastButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final FastButtonKind kind;
  final double height;
  final double? fontSize;

  const FastButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.kind = FastButtonKind.primary,
    this.height = 52,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final enabled = onPressed != null && !loading;

    final (bg, fg, border, glow) = switch (kind) {
      FastButtonKind.primary => (
          FASTBrand.accentGradient,
          FASTBrand.onAmber,
          null,
          FASTBrand.amber.withValues(alpha: enabled ? 0.35 : 0.0),
        ),
      FastButtonKind.soft => (
          null,
          FASTBrand.amberDeep,
          null,
          null,
        ),
      FastButtonKind.outline => (
          null,
          fast.t1,
          Border.all(color: fast.line),
          null,
        ),
      FastButtonKind.ghost => (null, FASTBrand.amberDeep, null, null),
    };

    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize ?? 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          );

    return FastTap(
      onTap: enabled ? onPressed : null,
      pressedScale: 0.97,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1.0 : 0.55,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding:
              expand ? null : const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: bg,
            color: switch (kind) {
              FastButtonKind.soft => fast.amberSoftBg,
              FastButtonKind.primary => FASTBrand.amber,
              _ => Colors.transparent,
            },
            border: border ??
                (kind == FastButtonKind.soft
                    ? Border.all(color: fast.amberSoftBorder)
                    : null),
            borderRadius: BorderRadius.circular(14),
            boxShadow: glow == null
                ? null
                : [
                    BoxShadow(
                      color: glow,
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Staggered entrance — fades and slides a child in, delayed by
/// `index` so list items cascade instead of popping in together.
class FastStagger extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration step;

  const FastStagger({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
  });

  @override
  State<FastStagger> createState() => _FastStaggerState();
}

class _FastStaggerState extends State<FastStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.step * widget.index.clamp(0, 12);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Shimmer sweep laid over any placeholder subtree — drives
/// [FastSkeleton] shapes while content loads.
class FastShimmer extends StatefulWidget {
  final Widget child;
  const FastShimmer({super.key, required this.child});

  @override
  State<FastShimmer> createState() => _FastShimmerState();
}

class _FastShimmerState extends State<FastShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF222227) : const Color(0xFFE9E6E0);
    final shine =
        isDark ? const Color(0xFF34343B) : const Color(0xFFFBFAF7);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final slide = _controller.value * 2 - 0.5;
            return LinearGradient(
              colors: [base, shine, base],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(slide),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double slide;
  const _SlideGradient(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}

/// Placeholder shapes for loading states, wrapped in [FastShimmer].
class FastSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final bool shimmer;

  const FastSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 8,
    this.shimmer = true,
  });

  /// Mimics the home-screen restaurant card while it loads.
  static Widget restaurantCard(BuildContext context) {
    final fast = context.fast;
    return FastShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: fast.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fast.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 140, color: fast.cardHigh),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: fast.cardHigh,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 10,
                    width: 240,
                    decoration: BoxDecoration(
                      color: fast.cardHigh,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.fast.cardHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return shimmer ? FastShimmer(child: box) : box;
  }
}

/// Frosted card for content that floats over imagery or gradients.
class FastGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const FastGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: isDark ? 0.42 : 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Branded empty state — haloed icon, title, subtitle, optional CTA.
class FastEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? accent;

  const FastEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final accent = this.accent ?? FASTBrand.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fast.t1,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: fast.t3, fontSize: 12, height: 1.4),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
