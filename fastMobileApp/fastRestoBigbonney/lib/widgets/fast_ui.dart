import 'dart:math' as math;
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

// ---------------------------------------------------------------------------
// SynapsisUI ports — their signature interactions rebuilt in Flutter and
// tuned to FAST tokens: floating glass nav, oversize-thumb switch,
// swipe-to-delete rows, scroll parallax and error shake.
// ---------------------------------------------------------------------------

/// One destination in a [FastNavBar].
class FastNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Count badge (0 hides it) — cart items.
  final int badge;

  /// Small activity dot — pending orders.
  final bool dot;

  /// Replaces the [icon] entirely — used by Pro's RUSH action tab so the
  /// glossy dome can live inside the bar at tab level.
  final Widget? customIcon;

  const FastNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge = 0,
    this.dot = false,
    this.customIcon,
  });
}

/// Frosted floating bottom bar — a springing amber indicator pill slides
/// between tabs while icons scale up and brighten the closer the indicator
/// gets (Flutter port of SynapsisUI's BottomTab).
class FastNavBar extends StatefulWidget {
  final int currentIndex;
  final List<FastNavItem> items;
  final ValueChanged<int> onTap;

  /// Indicator/active color — amber on the client side, teal for Pro.
  final Color accent;

  /// Pill surface — defaults to the theme card color.
  final Color? surface;

  /// Pill border — defaults to the theme line color.
  final Color? line;

  /// Inactive icon/label color — defaults to the theme t3 color.
  final Color? inactive;

  /// Optional keys per tab — the Pro spotlight tutorial targets nav items.
  final List<Key?>? itemKeys;

  const FastNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.accent = const Color(0xFFF59E0B),
    this.surface,
    this.line,
    this.inactive,
    this.itemKeys,
  });

  @override
  State<FastNavBar> createState() => _FastNavBarState();
}

class _FastNavBarState extends State<FastNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController(
    vsync: this,
    value: widget.currentIndex.toDouble(),
    lowerBound: -0.35,
    upperBound: widget.items.length - 0.65,
  );

  @override
  void didUpdateWidget(covariant FastNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _pos.animateTo(
        widget.currentIndex.toDouble(),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
      );
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final accent = widget.accent;
    final inactive = widget.inactive ?? fast.t3;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Icon/label color inside the filled indicator — dark on bright
    // accents (teal, amber), white on dark ones.
    final onAccent = accent.computeLuminance() > 0.35
        ? const Color(0xFF10141F)
        : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: (widget.surface ?? fast.card).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: (widget.line ?? Colors.white).withValues(
                    alpha: widget.line != null ? 1 : 0.09,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final tabW = c.maxWidth / widget.items.length;
                  return Stack(
                    children: [
                      // Sliding indicator — filled gradient pill with a
                      // soft accent glow, not a faint outline.
                      AnimatedBuilder(
                        animation: _pos,
                        builder: (ctx, _) => PositionedDirectional(
                          start: _pos.value * tabW + 8,
                          top: 9,
                          width: tabW - 16,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(accent, Colors.white, 0.12)!,
                                  Color.lerp(accent, Colors.black, 0.18)!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < widget.items.length; i++)
                            Expanded(
                              child: KeyedSubtree(
                                key: widget.itemKeys != null &&
                                        i < widget.itemKeys!.length
                                    ? widget.itemKeys![i]
                                    : null,
                                child: _tab(
                                  i,
                                  widget.items[i],
                                  inactive,
                                  onAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, FastNavItem item, Color inactive, Color onAccent) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(i),
      child: AnimatedBuilder(
        animation: _pos,
        builder: (ctx, _) {
          final t = 1 - (_pos.value - i).abs().clamp(0.0, 1.0);
          final color = Color.lerp(inactive, onAccent, t)!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: 1 + 0.18 * t,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    item.customIcon ??
                        Icon(
                          t > 0.5
                              ? (item.activeIcon ?? item.icon)
                              : item.icon,
                          color: color,
                          size: 22,
                        ),
                    if (item.badge > 0)
                      Positioned(
                        right: -11,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    if (item.dot)
                      const Positioned(
                        right: -6,
                        top: -4,
                        child: SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Oversize-thumb toggle — the white knob pokes out of the track and its
/// inner accent ring collapses into a filled dot when on (Flutter port of
/// SynapsisUI's Switch2).
class FastSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color accent;
  final double size;

  const FastSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.accent = const Color(0xFF00C8B3),
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    const dur = Duration(milliseconds: 300);
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: dur,
        curve: Curves.easeInOut,
        width: size * 2.2,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          color: value ? accent : fast.faint,
          boxShadow: [
            BoxShadow(
              color: (value ? accent : Colors.black).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: dur,
          curve: Curves.easeInOut,
          alignment: Alignment(value ? 0.68 : -0.68, 0),
          child: Container(
            width: size * 1.24,
            height: size * 1.24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ring — visible while off.
                  AnimatedScale(
                    scale: value ? 0 : 1,
                    duration: dur,
                    curve: Curves.easeInOut,
                    child: Container(
                      width: size * 0.72,
                      height: size * 0.72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: fast.t3,
                          width: size * 0.14,
                        ),
                      ),
                    ),
                  ),
                  // Filled dot — pops in while on.
                  AnimatedScale(
                    scale: value ? 1 : 0,
                    duration: dur,
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: size * 0.45,
                      height: size * 0.45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drop-in [SwitchListTile] replacement that pairs a title/subtitle with a
/// [FastSwitch] on the trailing edge.
class FastSwitchTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color accent;

  const FastSwitchTile({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.leading,
    this.accent = const Color(0xFF00C8B3),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
          FastSwitch(value: value, onChanged: onChanged, accent: accent),
        ],
      ),
    );
  }
}

/// Swipe-to-delete row — dragging left slides the child aside and reveals
/// a red zone whose trash icon pops bigger once the commit threshold is
/// crossed; releasing past it fires [onDelete], otherwise the row springs
/// back (Flutter port of SynapsisUI's SwipeAnimation).
class FastSwipeDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final Color color;
  final IconData icon;

  const FastSwipeDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.color = const Color(0xFFEF4444),
    this.icon = Icons.delete_outline,
  });

  @override
  State<FastSwipeDelete> createState() => _FastSwipeDeleteState();
}

class _FastSwipeDeleteState extends State<FastSwipeDelete>
    with SingleTickerProviderStateMixin {
  static const _reveal = 110.0;
  static const _commit = -80.0;

  late final AnimationController _dx =
      AnimationController.unbounded(vsync: this, value: 0);

  @override
  void dispose() {
    _dx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) =>
          _dx.value = (_dx.value + d.delta.dx).clamp(-_reveal, 0.0),
      onHorizontalDragEnd: (_) {
        if (_dx.value <= _commit) widget.onDelete();
        _dx.animateTo(
          0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.elasticOut,
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _dx,
              builder: (ctx, _) {
                final hot = _dx.value <= _commit;
                return Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 22),
                  color: widget.color.withValues(alpha: 0.92),
                  child: AnimatedScale(
                    scale: hot ? 1.5 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _dx,
            builder: (ctx, child) => Transform.translate(
              offset: Offset(_dx.value, 0),
              child: child,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Scroll-driven parallax — the child drifts against the scroll direction
/// as it crosses the viewport centre and is slightly oversized so the
/// motion never reveals edges (Flutter port of SynapsisUI's
/// ParallaxCarousel). Works on both axes; drop around a `FastImage`
/// inside any scrolling list.
class FastParallax extends StatelessWidget {
  final Widget child;
  final double maxShift;
  final double scale;

  const FastParallax({
    super.key,
    required this.child,
    this.maxShift = 18,
    this.scale = 1.15,
  });

  @override
  Widget build(BuildContext context) {
    final scaled = Transform.scale(scale: scale, child: child);
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return scaled;
    return AnimatedBuilder(
      animation: position,
      builder: (ctx, _) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || !position.hasPixels) return scaled;
        final screen = MediaQuery.sizeOf(ctx);
        final vertical = position.axis == Axis.vertical;
        final extent = vertical ? screen.height : screen.width;
        final o = box.localToGlobal(Offset.zero);
        final itemCenter = vertical
            ? o.dy + box.size.height / 2
            : o.dx + box.size.width / 2;
        final progress =
            ((itemCenter - extent / 2) / extent).clamp(-1.0, 1.0);
        final shift = -progress * maxShift;
        return Transform.translate(
          offset: vertical ? Offset(0, shift) : Offset(shift, 0),
          child: scaled,
        );
      },
    );
  }
}

/// Error shake — brief decaying horizontal wobble (Flutter port of the
/// OtpBoxes invalid-code shake). Bump [trigger] to replay it.
class FastShake extends StatefulWidget {
  final Widget child;
  final int trigger;

  const FastShake({super.key, required this.child, this.trigger = 0});

  @override
  State<FastShake> createState() => _FastShakeState();
}

class _FastShakeState extends State<FastShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant FastShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final dx =
            math.sin(_ctrl.value * math.pi * 6) * (1 - _ctrl.value) * 10;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
