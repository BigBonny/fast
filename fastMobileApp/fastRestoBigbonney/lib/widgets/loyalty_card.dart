import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models.dart';
import '../theme.dart';
import 'fast_night_surface.dart';
import 'fast_parts.dart';
import 'fast_ui.dart';

/// "Encore 3 commandes avant votre récompense !" / "Votre récompense vous
/// attend !" — the one line under the stamps.
String loyaltyProgressLine(BuildContext context, LoyaltyCard card) {
  if (card.rewardAvailable) return tr(context, 'loy_ready');
  if (card.remaining == 1) return tr(context, 'loy_remaining_one');
  return tr(context, 'loy_remaining').replaceAll('{n}', '${card.remaining}');
}

/// The stamp card: restaurant, "7 / 10", one dot per order and the reward
/// waiting at the end. On the night surface, like the membership card.
class LoyaltyCardView extends StatelessWidget {
  const LoyaltyCardView({
    super.key,
    required this.card,
    this.onUse,
    this.onTap,
  });

  final LoyaltyCard card;

  /// Shown as "Use my reward" once the card is complete.
  final VoidCallback? onUse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const fg = FastNightSurface.onNight;
    const muted = FastNightSurface.onNightMuted;
    final content = FastNightSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.title.copyWith(color: fg),
                ),
              ),
              const SizedBox(width: FASTSpace.s8),
              FastTag(
                tr(context, 'loy_tag'),
                kind: FastTagKind.accent,
                icon: Icons.card_giftcard,
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${card.stamps}',
                  style: FASTText.display.copyWith(color: FASTBrand.gold),
                ),
                TextSpan(
                  text: ' / ${card.threshold}',
                  style: FASTText.title.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: FASTSpace.s12),
          Wrap(
            spacing: FASTSpace.s8,
            runSpacing: FASTSpace.s8,
            children: [
              for (var i = 1; i <= card.threshold; i++)
                _Stamp(
                  number: i,
                  filled: i <= card.stamps,
                  isReward: i == card.threshold,
                ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          Text(
            loyaltyProgressLine(context, card),
            style: FASTText.body.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FASTSpace.s12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(FASTSpace.s12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              border: Border.all(color: FASTBrand.gold.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.redeem, color: FASTBrand.gold, size: 22),
                const SizedBox(width: FASTSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'loy_your_reward'),
                        style: FASTText.caption.copyWith(color: muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.reward,
                        style: FASTText.item.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (card.rewardAvailable && onUse != null) ...[
            const SizedBox(height: FASTSpace.s12),
            FastButton(
              label: tr(context, 'loy_use'),
              icon: Icons.redeem,
              onPressed: onUse,
              height: 48,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return FastTap(onTap: onTap, child: content);
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.number,
    required this.filled,
    required this.isReward,
  });

  final int number;
  final bool filled;
  final bool isReward;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled ? FASTBrand.neonGradient : null,
        border: filled
            ? null
            : Border.all(
                color: isReward
                    ? FASTBrand.gold
                    : FastNightSurface.onNightMuted.withValues(alpha: 0.45),
                width: isReward ? 1.5 : 1,
              ),
      ),
      child: isReward
          ? Icon(
              Icons.card_giftcard,
              size: 16,
              color: filled ? FASTBrand.onAmber : FASTBrand.gold,
            )
          : filled
          ? const Icon(Icons.check, size: 16, color: FASTBrand.onAmber)
          : Text(
              '$number',
              style: FASTText.caption.copyWith(
                color: FastNightSurface.onNightMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// The small bubble on a restaurant page: this restaurant has a loyalty
/// card, here is the goal and the reward — both set by the restaurateur.
class LoyaltyBubble extends StatelessWidget {
  const LoyaltyBubble({
    super.key,
    required this.restaurant,
    this.card,
    this.onTap,
  });

  final Restaurant restaurant;

  /// The client's progress here, if they have any.
  final LoyaltyCard? card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final c = card;
    final threshold = c?.threshold ?? restaurant.loyaltyThreshold;
    final reward = c?.reward ?? restaurant.loyaltyReward;
    final stamps = c?.stamps ?? 0;
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FASTSpace.s12),
      decoration: BoxDecoration(
        color: fast.amberSoftBg,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: fast.amberSoftBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: FASTBrand.neonGradient,
            ),
            child: const Icon(
              Icons.card_giftcard,
              size: 18,
              color: FASTBrand.onAmber,
            ),
          ),
          const SizedBox(width: FASTSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c != null && c.rewardAvailable
                      ? tr(context, 'loy_ready')
                      : tr(context, 'loy_bubble_t'),
                  style: FASTText.body.copyWith(
                    color: fast.t1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tr(context, 'loy_bubble_s')} '
                  '${tr(context, 'loy_bubble_goal').replaceAll('{n}', '$threshold').replaceAll('{r}', reward)}',
                  style: FASTText.caption.copyWith(
                    color: fast.t2,
                    height: 1.35,
                  ),
                ),
                if (c != null) ...[
                  const SizedBox(height: FASTSpace.s8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          child: LinearProgressIndicator(
                            value: threshold == 0 ? 0 : stamps / threshold,
                            minHeight: 6,
                            backgroundColor: fast.line,
                            valueColor: const AlwaysStoppedAnimation(
                              FASTBrand.rose,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Text(
                        '$stamps / $threshold',
                        style: FASTText.price.copyWith(
                          fontSize: 13,
                          color: fast.t1,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    tr(context, 'loy_bubble_end'),
                    style: FASTText.caption.copyWith(
                      color: fast.t1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: FASTSpace.s4),
            Icon(Icons.chevron_right, size: 20, color: fast.t3),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return FastTap(onTap: onTap, child: body);
  }
}
