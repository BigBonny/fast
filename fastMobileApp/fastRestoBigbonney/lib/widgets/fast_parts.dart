import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'fast_image.dart';
import 'fast_night_surface.dart';
import 'fast_ui.dart';

// Small shared pieces for the customer screens: tag, price, stepper,
// menu row, pickup code. Everything is drawn from the tokens in
// `theme.dart` (FASTSpace, FASTRadius, FASTText, `context.fast`).

/// Formats an amount the way receipts, totals and the translated strings
/// already do: `12.50 €` (amount, space, euro sign).
String fastPriceLabel(double amount) => '${amount.toStringAsFixed(2)} €';

enum FastTagKind {
  /// Quiet grey pill — dietary tags and neutral facts.
  neutral,

  /// Solid ink pill — the strongest tag.
  ink,

  /// Amber fill with dark text — highlights.
  accent,

  /// Muted pill for unavailable items.
  muted,
}

/// Small pill label. Text goes through [fastLabelCase].
class FastTag extends StatelessWidget {
  const FastTag(
    this.label, {
    super.key,
    this.kind = FastTagKind.neutral,
    this.icon,
  });

  final String label;
  final FastTagKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final (bg, fg) = switch (kind) {
      FastTagKind.neutral => (fast.cardHigh, fast.t2),
      FastTagKind.ink => (fast.ink, fast.onInk),
      FastTagKind.accent => (FASTBrand.gold, FASTBrand.onAmber),
      FastTagKind.muted => (fast.faint, fast.t1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FASTRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: FASTSpace.s4),
          ],
          Flexible(
            child: Text(
              fastLabelCase(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FASTText.label.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A price in the text color with digits of equal width.
class FastPrice extends StatelessWidget {
  const FastPrice(this.amount, {super.key, this.style});

  final double amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      fastPriceLabel(amount),
      style: (style ?? FASTText.price).copyWith(color: context.fast.t1),
    );
  }
}

/// Quantity stepper: minus, count, plus as circles. Never goes below
/// [min]. Each accepted tap gives a light haptic tick.
class FastStepper extends StatelessWidget {
  const FastStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double size;

  void _set(int next) {
    if (next < min || next > max || next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final canDec = value > min;
    final canInc = value < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(
          context,
          icon: Icons.remove,
          bg: fast.cardHigh,
          fg: canDec ? fast.t1 : fast.t3,
          border: fast.line,
          onTap: canDec ? () => _set(value - 1) : null,
        ),
        SizedBox(
          width: size,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: FASTText.price.copyWith(color: fast.t1),
          ),
        ),
        _circle(
          context,
          icon: Icons.add,
          bg: fast.ink,
          fg: fast.onInk,
          onTap: canInc ? () => _set(value + 1) : null,
        ),
      ],
    );
  }

  Widget _circle(
    BuildContext context, {
    required IconData icon,
    required Color bg,
    required Color fg,
    Color? border,
    VoidCallback? onTap,
  }) {
    return FastTap(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

/// One menu item as a row: text on the leading side, a square photo
/// with a "+" on the trailing side. With no photo the text takes the
/// full width and the "+" stands alone.
class FastMenuRow extends StatelessWidget {
  const FastMenuRow({
    super.key,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.onTap,
    this.available = true,
    this.prepMinutes = 0,
    this.tags = const [],
    this.unavailableLabel,
    this.showAdd = true,
  });

  final String name;
  final String description;
  final double price;
  final String image;
  final VoidCallback onTap;
  final bool available;
  final int prepMinutes;
  final List<String> tags;

  /// Shown as a tag when the item is not [available].
  final String? unavailableLabel;

  /// Hide the "+" where a tap does not add to the cart (reservation-only
  /// restaurants).
  final bool showAdd;

  static const double photoSize = 96;

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final hasPhoto = image.isNotEmpty;
    final add = available && showAdd ? _addButton(context) : null;

    return Opacity(
      opacity: available ? 1 : 0.5,
      child: FastTap(
        onTap: onTap,
        pressedScale: 0.98,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FASTSpace.s16,
            vertical: FASTSpace.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.item.copyWith(color: fast.t1),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.body.copyWith(color: fast.t2),
                      ),
                    ],
                    if (!available && unavailableLabel != null ||
                        tags.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!available && unavailableLabel != null)
                            FastTag(unavailableLabel!, kind: FastTagKind.muted),
                          for (final t in tags.take(2)) FastTag(t),
                        ],
                      ),
                    ],
                    const SizedBox(height: FASTSpace.s8),
                    Row(
                      children: [
                        FastPrice(price),
                        if (prepMinutes > 0) ...[
                          const SizedBox(width: FASTSpace.s12),
                          Icon(Icons.schedule, size: 14, color: fast.t3),
                          const SizedBox(width: FASTSpace.s4),
                          Text(
                            '~$prepMinutes min',
                            style: FASTText.caption.copyWith(color: fast.t3),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FASTSpace.s16),
              if (hasPhoto)
                SizedBox(
                  width: photoSize,
                  height: photoSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(FASTRadius.sm),
                        child: FastImage(
                          image,
                          width: photoSize,
                          height: photoSize,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          placeholder: Container(
                            width: photoSize,
                            height: photoSize,
                            color: fast.cardHigh,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.restaurant,
                              size: 24,
                              color: fast.faint,
                            ),
                          ),
                        ),
                      ),
                      if (add != null)
                        PositionedDirectional(end: 6, bottom: 6, child: add),
                    ],
                  ),
                )
              else if (add != null)
                Padding(
                  padding: const EdgeInsets.only(top: FASTSpace.s4),
                  child: add,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    final fast = context.fast;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: fast.card,
        shape: BoxShape.circle,
        border: Border.all(color: fast.line),
        boxShadow: FASTShadow.card(context),
      ),
      child: Icon(Icons.add, size: 20, color: fast.t1),
    );
  }
}

/// The pickup code — the one element that belongs to FAST alone. Large
/// amber characters on the night surface, the same wherever a code is
/// shown.
class FastPickupCode extends StatelessWidget {
  const FastPickupCode({
    super.key,
    required this.code,
    required this.label,
    this.hint,
    this.trailing,
  });

  /// The `XXXX-FAST` code, already derived by `pickupCodeFromToken`.
  final String code;

  /// Small label above the code ("Pickup code").
  final String label;

  /// Optional one-line explanation under the code.
  final String? hint;

  /// Optional widget at the trailing edge of the label line (QR button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $code',
      child: FastNightSurface(
        padding: const EdgeInsets.fromLTRB(
          FASTSpace.s16,
          FASTSpace.s16,
          FASTSpace.s16,
          FASTSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: FASTBrand.gold),
                const SizedBox(width: FASTSpace.s4),
                Expanded(
                  child: Text(
                    fastLabelCase(context, label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FASTText.label.copyWith(
                      color: FastNightSurface.onNightMuted,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: FASTSpace.s12),
            // The code is Latin letters and digits in every locale; keep
            // it left-to-right and let it shrink before it wraps.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              // Lit like the sign on the icon: gold to magenta glyphs.
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) =>
                    FASTBrand.neonGradient.createShader(rect),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    code,
                    maxLines: 1,
                    style: FASTText.code.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: FASTSpace.s8),
              Text(
                hint!,
                style: FASTText.caption.copyWith(
                  color: FastNightSurface.onNightMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
