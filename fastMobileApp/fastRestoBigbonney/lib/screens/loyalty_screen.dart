// lib/screens/loyalty_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models.dart';
import '../provider.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_ui.dart';
import '../widgets/loyalty_card.dart';

/// "Ma fidélité" — every loyalty card the client has started, then the
/// other restaurants that run a programme. Each restaurateur sets their
/// own order count and reward; an order counts once paid and collected.
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  bool _loading = true;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await context.read<FASTProvider>().loadLoyaltyCards();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _use(LoyaltyCard card) async {
    if (_redeeming) return;
    final provider = context.read<FASTProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.fast.card,
        title: Text(
          tr(ctx, 'loy_use_title'),
          style: FASTText.title.copyWith(color: ctx.fast.t1),
        ),
        content: Text(
          '${card.reward}\n\n${tr(ctx, 'loy_use_body')}',
          style: FASTText.body.copyWith(color: ctx.fast.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              tr(ctx, 'cancel'),
              style: TextStyle(color: ctx.fast.t2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              tr(ctx, 'loy_use'),
              style: TextStyle(
                color: ctx.fast.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _redeeming = true);
    final error = await provider.redeemLoyaltyReward(card.restaurantId);
    if (!mounted) return;
    setState(() => _redeeming = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    HapticFeedback.mediumImpact();
    final now = TimeOfDay.now().format(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.fast.card,
        icon: const Icon(Icons.redeem, color: FASTBrand.gold, size: 40),
        title: Text(
          tr(ctx, 'loy_used_title'),
          textAlign: TextAlign.center,
          style: FASTText.title.copyWith(color: ctx.fast.t1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.reward,
              textAlign: TextAlign.center,
              style: FASTText.item.copyWith(
                color: ctx.fast.t1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FASTSpace.s4),
            Text(
              '${card.restaurantName} · $now',
              textAlign: TextAlign.center,
              style: FASTText.caption.copyWith(color: ctx.fast.t2),
            ),
            const SizedBox(height: FASTSpace.s12),
            Text(
              tr(ctx, 'loy_used_body'),
              textAlign: TextAlign.center,
              style: FASTText.body.copyWith(color: ctx.fast.t2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: ctx.fast.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRestaurant(String id) {
    final provider = context.read<FASTProvider>();
    provider.selectRestaurant(id);
    provider.navigateToScreen('restaurant');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FASTProvider>();
    final fast = context.fast;
    final cards = provider.loyaltyCards;
    final started = cards.map((c) => c.restaurantId).toSet();
    final partners = provider.restaurants
        .where((r) => r.hasLoyalty && !started.contains(r.id))
        .toList();

    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        backgroundColor: fast.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: fast.t2),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr(context, 'loy_title'),
          style: FASTText.item.copyWith(
            color: fast.t1,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: fast.ink,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s8,
            FASTSpace.s16,
            FASTSpace.s40,
          ),
          children: [
            if (_loading && cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(FASTSpace.s40),
                child: Center(
                  child: CircularProgressIndicator(color: FASTBrand.gold),
                ),
              )
            else if (cards.isEmpty)
              FastEmpty(
                icon: Icons.card_giftcard,
                title: tr(context, 'loy_empty_t'),
                subtitle: tr(context, 'loy_empty_s'),
              )
            else ...[
              for (final card in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: FASTSpace.s16),
                  child: LoyaltyCardView(
                    card: card,
                    onUse: _redeeming ? null : () => _use(card),
                  ),
                ),
              Text(
                tr(context, 'loy_rule'),
                textAlign: TextAlign.center,
                style: FASTText.caption.copyWith(color: fast.t3),
              ),
            ],
            if (partners.isNotEmpty) ...[
              const SizedBox(height: FASTSpace.s24),
              Text(
                tr(context, 'loy_partners'),
                style: FASTText.title.copyWith(color: fast.t1),
              ),
              const SizedBox(height: FASTSpace.s8),
              for (final r in partners)
                InkWell(
                  onTap: () => _openRestaurant(r.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: FASTSpace.s8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(FASTRadius.sm),
                          child: FastImage(
                            r.image,
                            width: 48,
                            height: 48,
                            placeholder: Container(
                              width: 48,
                              height: 48,
                              color: fast.faint,
                            ),
                          ),
                        ),
                        const SizedBox(width: FASTSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FASTText.body.copyWith(
                                  color: fast.t1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr(context, 'loy_partner_line')
                                    .replaceAll('{n}', '${r.loyaltyThreshold}')
                                    .replaceAll('{r}', r.loyaltyReward),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FASTText.caption.copyWith(
                                  color: fast.t2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: fast.t3),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
