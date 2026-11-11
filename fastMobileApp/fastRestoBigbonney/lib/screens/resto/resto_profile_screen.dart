import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../theme.dart';
import '../../widgets/fast_image.dart';
import '../../widgets/fast_night_surface.dart';
import '../../l10n/tr.dart';

class RestoProfileScreen extends StatelessWidget {
  const RestoProfileScreen({super.key});

  Widget _placeholderImage(BuildContext context) => Container(
    color: context.fast.cardHigh,
    alignment: Alignment.center,
    child: Icon(Icons.storefront_outlined, color: context.fast.t3, size: 64),
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestoProvider>(context);
    final settings = provider.settings;
    final fast = context.fast;

    return Scaffold(
      backgroundColor: fast.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: false,
            backgroundColor: fast.card,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  settings?.image != null && settings!.image.isNotEmpty
                      ? FastImage(
                          settings.image,
                          fit: BoxFit.cover,
                          placeholder: _placeholderImage(context),
                        )
                      : _placeholderImage(context),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          fast.bg.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FASTSpace.s16,
                0,
                FASTSpace.s16,
                FASTSpace.s40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header card: the restaurant as customers see it ───
                  SizedBox(
                    width: double.infinity,
                    child: FastNightSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  fastLabelCase(
                                    context,
                                    settings?.cuisineType ?? 'CUISINE',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FASTText.label.copyWith(
                                    color: FastNightSurface.onNightMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: FASTSpace.s12),
                              const Icon(
                                Icons.star_rounded,
                                color: FASTBrand.gold,
                                size: 18,
                              ),
                              const SizedBox(width: FASTSpace.s4),
                              Text(
                                '4.8',
                                style: FASTText.price.copyWith(
                                  fontSize: 14,
                                  color: FastNightSurface.onNight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: FASTSpace.s8),
                          Text(
                            settings?.name ?? tr(context, 'my_restaurant'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FASTText.title.copyWith(
                              color: FastNightSurface.onNight,
                            ),
                          ),
                          const SizedBox(height: FASTSpace.s8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: FastNightSurface.onNightMuted,
                                size: 16,
                              ),
                              const SizedBox(width: FASTSpace.s4),
                              Expanded(
                                child: Text(
                                  '${settings?.city ?? tr(context, 'city')} • ${tr(context, 'at_km').replaceAll('{n}', '2.4')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FASTText.body.copyWith(
                                    color: FastNightSurface.onNightMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FASTSpace.s40),
                  Text(
                    tr(context, 'public_preview'),
                    style: FASTText.title.copyWith(color: fast.t1),
                  ),
                  const SizedBox(height: FASTSpace.s8),
                  Divider(height: 1, thickness: 1, color: fast.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FASTSpace.s16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: fast.t2,
                          size: 22,
                        ),
                        const SizedBox(width: FASTSpace.s12),
                        Expanded(
                          child: Text(
                            tr(context, 'preview_notice'),
                            style: FASTText.body.copyWith(
                              color: fast.t2,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: fast.line),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
