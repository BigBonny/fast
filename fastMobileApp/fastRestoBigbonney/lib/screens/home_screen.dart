// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_glow_background.dart';
import '../widgets/fast_night_surface.dart';
import '../widgets/fast_parts.dart';
import '../widgets/fast_ui.dart';
import '../l10n/tr.dart';
import '../services/restaurant_service.dart';

/// Shell of a promo card: the night surface for the lead card, a plain
/// card with a hairline for the others.
class _PromoShell extends StatelessWidget {
  const _PromoShell({required this.night, required this.child});

  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Container(
      width: 280,
      margin: const EdgeInsetsDirectional.only(end: FASTSpace.s12),
      padding: night ? null : const EdgeInsets.all(FASTSpace.s16),
      decoration: night
          ? null
          : BoxDecoration(
              color: fast.card,
              borderRadius: BorderRadius.circular(FASTRadius.md),
              border: Border.all(color: fast.line),
            ),
      child: night ? FastNightSurface(child: child) : child,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);

    // Sync text controller with search state
    if (provider.searchKeyword != _searchController.text &&
        !_isFocusingSearch) {
      _searchController.text = provider.searchKeyword;
    }

    final filteredRest = provider.getFilteredRestaurants();
    final suggCategories = provider.getAutocompleteCategories();
    final isSearching = provider.searchKeyword.isNotEmpty;

    return GestureDetector(
      // Tap anywhere outside the search field dismisses the keyboard —
      // the only dismissal route on iOS, which has no back button.
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Stack(
        children: [
          Container(color: context.fast.bg),
          LayoutBuilder(
            builder: (context, viewport) => ListView(
              // Dragging the list dismisses the keyboard too.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                // Branded hero — dark glow background, headline + search pill
                FastGlowBackground(
                  arcs: false,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // The hero extends under the floating AppBar; the brand
                      // mark sits level with the nav icons, like the reference.
                      final statusBar = MediaQuery.of(context).padding.top;
                      const heroBody = 276.0;
                      final heroHeight = statusBar + heroBody;
                      // The photo owns the lower-right; measured from the
                      // reference it spans ~60% of the width at natural aspect.
                      final photoW = box.maxWidth * 0.58;
                      // Asset is 323x312 → natural height for this width.
                      final photoH = photoW * 312 / 323;
                      // Where the photo's left edge and top edge sit in hero
                      // coordinates — the streak painter needs these to draw
                      // the diagonal slash continuing into the purple.
                      final photoLeft = box.maxWidth - photoW;
                      final photoTop = heroHeight - photoH;
                      return SizedBox(
                        height: heroHeight,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              bottom: 0,
                              width: photoW,
                              height: photoH,
                              child: ClipPath(
                                // Cuts the top-left corner along the line the
                                // baked fiery streak travels — purple above,
                                // food below, just like the reference.
                                clipper: const _HeroPhotoClip(),
                                child: ShaderMask(
                                  blendMode: BlendMode.dstIn,
                                  shaderCallback: (rect) =>
                                      const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          Colors.white,
                                          Colors.white,
                                        ],
                                        stops: [0.0, 0.16, 1.0],
                                      ).createShader(rect),
                                  child: Image.asset(
                                    'assets/images/hero_food.png',
                                    width: photoW,
                                    height: photoH,
                                    fit: BoxFit.fill,
                                    alignment: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                            // The diagonal neon slash — continues the streak
                            // baked into the photo across the purple toward
                            // the top-right corner, the reference's signature.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _HeroStreakPainter(
                                    photoLeft: photoLeft,
                                    photoTop: photoTop,
                                    photoW: photoW,
                                    photoH: photoH,
                                  ),
                                ),
                              ),
                            ),
                            // Soft dark veil on the left so the headline stays
                            // crisp where it meets the photo
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        FastGlowBackground.topColor.withValues(
                                          alpha: 0.70,
                                        ),
                                        FastGlowBackground.topColor.withValues(
                                          alpha: 0.42,
                                        ),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.34, 0.54],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Brand mark + tagline — centered between the
                            // nav icons like the reference, but as one tight
                            // lockup: bolt inside a gradient badge, wordmark
                            // burning amber→ember, tagline breathing below.
                            Positioned(
                              top: statusBar * 0.4,
                              left: 0,
                              right: 0,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.bolt,
                                        color: Color(0xFFFBBF24),
                                        size: 30,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x99F59E0B),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 2),
                                      Builder(
                                        builder: (context) {
                                          // Still amber gradient with one
                                          // fixed highlight — the endless
                                          // shine sweep was decoration.
                                          return ShaderMask(
                                            blendMode: BlendMode.srcIn,
                                            shaderCallback: (rect) =>
                                                const LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    FASTBrand.gold,
                                                    FASTBrand.neonOrange,
                                                    FASTBrand.neonPink,
                                                    FASTBrand.neonMagenta,
                                                  ],
                                                  stops: [0.0, 0.38, 0.74, 1.0],
                                                ).createShader(rect),
                                            child: const Text(
                                              'FAST',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontStyle: FontStyle.italic,
                                                fontSize: 38,
                                                letterSpacing: 1.2,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                    color: Color(0x80F59E0B),
                                                    blurRadius: 22,
                                                    offset: Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.bolt,
                                        color: Color(0xFFFBBF24),
                                        size: 30,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x99F59E0B),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'CHAQUE MINUTE COMPTE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2.6,
                                      color: Color(0xB3FBBF24),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Headline block — left of the photo, tilted a touch
                            // so the sentence feels like it lifts as it goes.
                            // The column's right edge is capped just inside the
                            // photo's faded left margin so no line can ever
                            // overlap the bowl, whatever the screen width.
                            Positioned(
                              left: 20,
                              right: 0,
                              // +56 clears the wordmark and its 12 pt
                              // tagline even under a short status bar.
                              top: statusBar + 56,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (((photoLeft + photoW * 0.10) - 20) /
                                            box.maxWidth)
                                        .clamp(0.38, 0.62),
                                // Level headline: the tilt and the painted
                                // swoosh under it were removed so the hero
                                // holds fewer competing shapes.
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // scaleDown keeps every locale on one
                                    // line instead of wrapping into the photo
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        tr(context, 'hero_order'),
                                        style: _heroHeadline,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      // Amber→ember gradient "Fast." — the
                                      // brand accent line, on its own row.
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (rect) =>
                                              const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  FASTBrand.gold,
                                                  FASTBrand.neonOrange,
                                                  FASTBrand.neonPink,
                                                  FASTBrand.neonMagenta,
                                                ],
                                              ).createShader(rect),
                                          // Side padding gives the italic's overhang room
                                          // inside the gradient mask so it is not clipped.
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Fast.',
                                              style: TextStyle(
                                                fontFamily:
                                                    FASTText.displayFamily,
                                                fontVariations: [
                                                  FontVariation('wght', 900),
                                                ],
                                                fontSize: 36,
                                                fontWeight: FontWeight.w900,
                                                fontStyle: FontStyle.italic,
                                                letterSpacing: -0.4,
                                                color: Colors.white,
                                                height: 1.05,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black54,
                                                    blurRadius: 12,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // The sub wraps inside the safe column —
                                    // no fixed width, so it never rides over
                                    // the photo edge.
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        tr(context, 'hero_sub'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFBBF24),
                                          height: 1.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 10,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Search pill pinned to the bottom of the hero
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Search Bar — white pill on the dark hero
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      18,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x59000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: Color(0x14F59E0B),
                                            blurRadius: 30,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Focus(
                                        onFocusChange: (focus) {
                                          setState(() {
                                            _isFocusingSearch = focus;
                                          });
                                        },
                                        child: TextField(
                                          controller: _searchController,
                                          // Shows a "Search" key on the
                                          // keyboard — submitting dismisses
                                          // it (vital on iOS).
                                          textInputAction:
                                              TextInputAction.search,
                                          onSubmitted: (_) => FocusManager
                                              .instance
                                              .primaryFocus
                                              ?.unfocus(),
                                          onChanged: (val) =>
                                              provider.setKeyword(val),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1A1425),
                                          ),
                                          decoration: InputDecoration(
                                            hintText: provider.tr(
                                              'search_hint',
                                            ),
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF8A8496),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Color(0xFF8A8496),
                                              size: 18,
                                            ),
                                            suffixIcon:
                                                provider
                                                    .searchKeyword
                                                    .isNotEmpty
                                                ? IconButton(
                                                    onPressed: () {
                                                      provider.setKeyword('');
                                                      _searchController.clear();
                                                      FocusManager
                                                          .instance
                                                          .primaryFocus
                                                          ?.unfocus();
                                                    },
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Color(0xFF8A8496),
                                                      size: 16,
                                                    ),
                                                  )
                                                : null,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 0,
                                                ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              borderSide: const BorderSide(
                                                color: FASTBrand.gold,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Autocomplete Suggestions Panel OR Main Page Content — both
                // scroll together with the hero above them
                if (isSearching)
                  SizedBox(
                    height:
                        (viewport.maxHeight -
                                252 -
                                MediaQuery.of(context).padding.top) <
                            240
                        ? 240.0
                        : viewport.maxHeight -
                              252 -
                              MediaQuery.of(context).padding.top,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.fast.bg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: _buildSuggestionsPanel(
                        context,
                        provider,
                        suggCategories,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: context.fast.bg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: _buildMainContent(context, provider, filteredRest),
                  ),
              ],
            ),
          ),

          // Slot Machine Selection Overlay
          if (provider.isSurpriseMeRolling)
            _buildSlotsOverlay(context, provider),
        ],
      ),
    );
  }

  bool _isFocusingSearch = false;

  // Split suggestion layout
  Widget _buildSuggestionsPanel(
    BuildContext context,
    FASTProvider provider,
    List<CategoryItem> suggCategories,
  ) {
    final kw = provider.searchKeyword.toLowerCase();

    // Find matching dishes
    final List<Map<String, dynamic>> matchingDishes = [];
    final List<Restaurant> matchingRestaurants = [];

    for (var r in provider.restaurants) {
      bool matchedRest =
          r.name.toLowerCase().contains(kw) ||
          r.description.toLowerCase().contains(kw);
      if (matchedRest) {
        matchingRestaurants.add(r);
      }
      for (var d in r.menu) {
        if (d.name.toLowerCase().contains(kw) ||
            d.description.toLowerCase().contains(kw)) {
          matchingDishes.add({'restaurant': r, 'item': d});
        }
      }
    }

    final fast = context.fast;

    Widget resultRow({
      required String image,
      required String title,
      required String caption,
      required Widget trailing,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FASTSpace.s16,
            vertical: FASTSpace.s12,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FASTRadius.sm),
                child: FastImage(
                  image,
                  width: 48,
                  height: 48,
                  placeholder: Container(
                    color: fast.faint,
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fast.t1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.caption.copyWith(color: fast.t2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FASTSpace.s8),
              trailing,
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[
      // Restaurants results
      ...matchingRestaurants.map(
        (r) => resultRow(
          image: r.image,
          title: r.name,
          caption:
              '${r.pickupPrepTime} ${tr(context, 'min_prep')} • ${provider.getRealDistance(r).toStringAsFixed(1)} km',
          trailing: Icon(Icons.chevron_right, size: 20, color: fast.t3),
          onTap: () {
            provider.selectRestaurant(r.id);
            provider.navigateToScreen('restaurant');
          },
        ),
      ),
      // Dishes results
      ...matchingDishes.map((data) {
        final Restaurant r = data['restaurant'];
        final MenuItem item = data['item'];
        return resultRow(
          image: item.image,
          title: item.name,
          caption:
              '${tr(context, 'from_resto').replaceAll('{n}', r.name)} • ${item.price.toStringAsFixed(2)} €',
          trailing: FastTag(tr(context, 'order_btn')),
          onTap: () {
            provider.selectRestaurant(r.id);
            provider.navigateToScreen('restaurant');
          },
        );
      }),
    ];

    return Container(
      color: fast.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: FASTSpace.s16),
          // Section 1: Categories Autocomplete Suggestions
          if (suggCategories.isNotEmpty) ...[
            _sectionHeader(context, tr(context, 'matching_cats')),
            const SizedBox(height: FASTSpace.s12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
                itemCount: suggCategories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: FASTSpace.s8),
                itemBuilder: (context, index) {
                  final cat = suggCategories[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setCategory(cat.id);
                      provider.setKeyword(
                        '',
                      ); // Clear search to reveal category list
                      _searchController.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fast.card,
                        borderRadius: BorderRadius.circular(FASTRadius.pill),
                        border: Border.all(color: fast.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            cat.id.startsWith('custom:')
                                ? cat.name
                                : catLabel(context, cat.id),
                            style: FASTText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: fast.t1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: FASTSpace.s24),
          ],

          // Section 2: Matching Kitchens & Dishes List
          _sectionHeader(context, provider.tr('matching')),
          const SizedBox(height: FASTSpace.s4),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    // Scrolls rather than overflowing when the keyboard
                    // leaves the panel at its minimum height.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(FASTSpace.s24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: fast.t3),
                          const SizedBox(height: FASTSpace.s12),
                          Text(
                            tr(context, 'no_items'),
                            textAlign: TextAlign.center,
                            style: FASTText.item.copyWith(color: fast.t1),
                          ),
                          const SizedBox(height: FASTSpace.s4),
                          Text(
                            tr(context, 'search_suggest'),
                            textAlign: TextAlign.center,
                            style: FASTText.body.copyWith(color: fast.t2),
                          ),
                          const SizedBox(height: FASTSpace.s12),
                          _requestRestaurantLink(
                            context,
                            () => _showRestaurantRequestSheet(
                              context,
                              provider.searchKeyword,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      indent: FASTSpace.s16,
                      endIndent: FASTSpace.s16,
                      color: fast.line,
                    ),
                    itemBuilder: (_, i) => rows[i],
                  ),
          ),
        ],
      ),
    );
  }

  /// Page section header: sentence-case bold title on the leading side,
  /// optional count / action text on the trailing side.
  Widget _sectionHeader(
    BuildContext context,
    String title, {
    String? trailing,
    VoidCallback? onTrailingTap,
  }) {
    final fast = context.fast;
    Widget? trail;
    if (trailing != null) {
      trail = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          trailing,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FASTText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: fast.t2,
          ),
        ),
      );
      if (onTrailingTap != null) {
        trail = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTrailingTap,
          child: trail,
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
      // A Wrap, not a Row: the title keeps its natural width on one line
      // where it can, and a long trailing text drops under it instead of
      // squeezing the title onto two lines.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: FASTSpace.s12,
          runSpacing: FASTSpace.s4,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FASTText.title.copyWith(color: fast.t1),
            ),
            if (trail != null) trail,
          ],
        ),
      ),
    );
  }

  /// Quiet text link that opens the "suggest a restaurant" sheet.
  Widget _requestRestaurantLink(BuildContext context, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.storefront_outlined, size: 18),
      label: Text(tr(context, 'req_resto_cta')),
      style: TextButton.styleFrom(
        foregroundColor: context.fast.t1,
        textStyle: FASTText.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  // Normal landing page contents
  Widget _buildMainContent(
    BuildContext context,
    FASTProvider provider,
    List<Restaurant> filteredRest,
  ) {
    final fast = context.fast;
    // Favourites row height follows the text scale so the card never clips:
    // photo + padding + name line + caption line.
    final scaler = MediaQuery.textScalerOf(context);
    final favCaption = scaler.scale(12) * 1.3;
    final favRowHeight =
        (100 +
                2 +
                FASTSpace.s12 * 2 +
                scaler.scale(14) * 1.35 +
                FASTSpace.s4 +
                (favCaption < 16 ? 16 : favCaption) +
                2)
            .ceilToDouble();

    return ListView(
      padding: const EdgeInsets.only(top: FASTSpace.s24, bottom: FASTSpace.s8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Bento/Actionable Carousel Banners
        _buildActionableBanners(context, provider),

        const SizedBox(height: FASTSpace.s40),

        // Category Browsing Section
        _sectionHeader(
          context,
          tr(context, 'browse_by_cat'),
          trailing: provider.selectedCategory != 'all'
              ? tr(context, 'clear_filter')
              : null,
          onTrailingTap: () => provider.resetFilters(),
        ),
        const SizedBox(height: FASTSpace.s12),
        _buildCategoryStrip(context, provider),

        const SizedBox(height: FASTSpace.s40),

        // Favorites — synced with website "Mes favoris"
        if (provider.favorites.isNotEmpty) ...[
          _sectionHeader(context, tr(context, 'favorites')),
          const SizedBox(height: FASTSpace.s12),
          SizedBox(
            height: favRowHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
              itemCount: provider.favorites.length,
              itemBuilder: (context, index) {
                final rest = provider.favorites[index];
                return FastTap(
                  onTap: () {
                    provider.selectRestaurant(rest.id);
                    provider.navigateToScreen('restaurant');
                  },
                  child: Container(
                    width: 200,
                    margin: const EdgeInsetsDirectional.only(
                      end: FASTSpace.s12,
                    ),
                    decoration: BoxDecoration(
                      color: fast.card,
                      borderRadius: BorderRadius.circular(FASTRadius.md),
                      border: Border.all(color: fast.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            FastParallax(
                              child: FastImage(
                                rest.image,
                                height: 100,
                                width: double.infinity,
                                placeholder: Container(
                                  height: 100,
                                  color: fast.cardHigh,
                                  child: Icon(
                                    Icons.restaurant,
                                    color: fast.faint,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            // Same heart badge as the restaurant card,
                            // smaller; it marks the card, it is not a button.
                            PositionedDirectional(
                              top: FASTSpace.s8,
                              end: FASTSpace.s8,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: fast.card,
                                  shape: BoxShape.circle,
                                  boxShadow: FASTShadow.card(context),
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: FASTBrand.error,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(FASTSpace.s12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rest.name,
                                style: FASTText.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: fast.t1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: FASTSpace.s4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: FASTBrand.gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: FASTSpace.s4),
                                  Flexible(
                                    child: Text(
                                      '${rest.rating} • ${rest.pickupPrepTime} min',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: FASTText.caption.copyWith(
                                        color: fast.t2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: FASTSpace.s40),
        ],

        // Kitchen list section
        _sectionHeader(
          context,
          provider.tr('cuisines_near'),
          trailing: provider
              .tr('restaurants_available')
              .replaceAll('{n}', '${filteredRest.length}'),
        ),
        const SizedBox(height: FASTSpace.s12),
        _buildRadiusFilter(context, provider),
        const SizedBox(height: FASTSpace.s16),

        // List of Restaurants — skeletons while fetching, staggered
        // cascade when the cards land.
        if (provider.isLoading && filteredRest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
            child: Column(
              children: List.generate(
                3,
                (_) => FastSkeleton.restaurantCard(context),
              ),
            ),
          )
        else if (filteredRest.isEmpty)
          _buildNoKitchens(context, provider)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRest.length,
              itemBuilder: (context, index) {
                final rest = filteredRest[index];
                return _buildRestaurantCard(context, provider, rest, index);
              },
            ),
          ),

        const SizedBox(height: 80), // bottom offset for basket
      ],
    );
  }

  // Actionable Banners — synced with website quick categories
  Widget _buildActionableBanners(BuildContext context, FASTProvider provider) {
    // Tall enough for tag + two title lines + CTA at larger text scales.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return SizedBox(
      height: (168 * (scale < 1 ? 1 : scale)).ceilToDouble(),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
        children: [
          _promoBanner(
            context: context,
            onTap: () {
              provider.setKeyword('burger');
              provider.setCategory('burger');
            },
            onInkCard: true,
            watermark: Icons.lunch_dining_outlined,
            tag: tr(context, 'express_offer'),
            title: tr(context, 'promo_burger_t'),
            subtitle: tr(context, 'promo_velvet'),
            cta: tr(context, 'cta_enjoy'),
          ),
          _promoBanner(
            context: context,
            onTap: () => provider.navigateToScreen('group'),
            watermark: Icons.groups_outlined,
            tag: tr(context, 'with_friends'),
            title: tr(context, 'group_tagline'),
            subtitle: tr(context, 'promo_group_s'),
            cta: tr(context, 'cta_group'),
            ctaIcon: Icons.group_add,
          ),
          _promoBanner(
            context: context,
            onTap: () => provider.triggerSurpriseMe(context),
            watermark: Icons.casino_outlined,
            tag: tr(context, 'cta_surprise'),
            title: tr(context, 'promo_surprise_t2'),
            subtitle: tr(context, 'promo_surprise_s2'),
            cta: tr(context, 'cta_surprise'),
            ctaIcon: Icons.shuffle,
          ),
        ],
      ),
    );
  }

  /// One promo card. Flat surface: ink for the lead card, plain card with
  /// a hairline for the others.
  Widget _promoBanner({
    required BuildContext context,
    required VoidCallback onTap,
    required IconData watermark,
    required String tag,
    required String title,
    required String subtitle,
    required String cta,
    bool onInkCard = false,
    IconData ctaIcon = Icons.chevron_right,
  }) {
    final fast = context.fast;
    // The lead card sits on the night surface — it carries the hero's
    // mood one step down the page and looks the same in both themes.
    // (The flag keeps its name; it now means "the lead, dark card".)
    final fg = onInkCard ? FastNightSurface.onNight : fast.t1;
    final fgMuted = onInkCard ? FastNightSurface.onNightMuted : fast.t2;
    final pillBg = onInkCard ? FastNightSurface.onNight : fast.ink;
    final pillFg = onInkCard ? FASTBrand.onAmber : fast.onInk;
    return FastTap(
      onTap: onTap,
      child: _PromoShell(
        night: onInkCard,
        child: Stack(
          children: [
            // Large, faint line icon in the top corner, clear of the text.
            PositionedDirectional(
              top: -4,
              end: -4,
              child: Icon(
                watermark,
                size: 64,
                color: fg.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FastTag(
                  tag,
                  kind: onInkCard ? FastTagKind.accent : FastTagKind.neutral,
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.item.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: FASTText.caption.copyWith(color: fgMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FASTSpace.s12,
                        vertical: FASTSpace.s8,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(FASTRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cta,
                            style: FASTText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pillFg,
                            ),
                          ),
                          const SizedBox(width: FASTSpace.s4),
                          Icon(ctaIcon, size: 14, color: pillFg),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Categories horizontal scrolling band — fixed list + any custom
  // categories saved by restaurateurs (community cuisines, food trucks…).
  Widget _buildCategoryStrip(BuildContext context, FASTProvider provider) {
    final cats = [...provider.categories, ...provider.customCategoriesInUse];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (context, index) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = cats[index];
          final isActive = provider.selectedCategory == cat.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              provider.setCategory(cat.id);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              // Selected: the CTA gradient (orange → pink → violet).
              decoration: BoxDecoration(
                color: isActive ? null : context.fast.card,
                gradient: isActive ? FASTBrand.ctaGradient : null,
                borderRadius: BorderRadius.circular(FASTRadius.md),
                border: Border.all(
                  color: isActive ? Colors.transparent : context.fast.line,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: FASTBrand.ctaPink.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 22)),
                  SizedBox(height: 4),
                  Text(
                    cat.id.startsWith('custom:')
                        ? cat.name
                        : catLabel(context, cat.id),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? FASTBrand.onCta : context.fast.t2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Restaurant card widget
  Widget _buildRestaurantCard(
    BuildContext context,
    FASTProvider provider,
    Restaurant rest,
    int index,
  ) {
    final fast = context.fast;
    final isFav = provider.isFavorite(rest.id);
    return FastStagger(
      index: index,
      child: FastTap(
        onTap: () {
          provider.selectRestaurant(rest.id);
          provider.navigateToScreen('restaurant');
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: FASTSpace.s24),
          decoration: BoxDecoration(
            color: fast.card,
            borderRadius: BorderRadius.circular(FASTRadius.md),
            border: Border.all(color: fast.line),
            boxShadow: FASTShadow.card(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo at a fixed 16:9 with nothing on it but the heart —
              // rating, prep time and distance moved to one line of facts
              // under the name.
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRect(
                      child: FastParallax(
                        maxShift: 14,
                        child: FastImage(
                          rest.image,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          placeholder: Container(
                            color: fast.cardHigh,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.restaurant,
                              color: fast.faint,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: FASTSpace.s12,
                    end: FASTSpace.s12,
                    child: FastTap(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.toggleFavorite(rest.id);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: fast.card,
                          shape: BoxShape.circle,
                          boxShadow: FASTShadow.card(context),
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? FASTBrand.error : fast.t1,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(FASTSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.item.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fast.t1,
                      ),
                    ),
                    const SizedBox(height: FASTSpace.s4),
                    // One line of facts: rating, prep time, distance.
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: FASTBrand.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${rest.rating}',
                          style: FASTText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: fast.t1,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '  ·  ${rest.pickupPrepTime} ${tr(context, 'min_prep')}'
                            '  ·  ${provider.getRealDistance(rest).toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FASTText.body.copyWith(color: fast.t2),
                          ),
                        ),
                      ],
                    ),
                    if (rest.description.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s8),
                      Text(
                        rest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.body.copyWith(color: fast.t3),
                      ),
                    ],
                    if (rest.dietaryOptions.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in rest.dietaryOptions.take(3))
                            FastTag(dietLabel(context, tag)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Max search radius picker — 1 / 3 / 5 / 10 km or unlimited
  Widget _buildRadiusFilter(BuildContext context, FASTProvider provider) {
    final fast = context.fast;
    final options = <(double?, String)>[
      (null, provider.tr('radius_all')),
      (1, '1 km'),
      (3, '3 km'),
      (5, '5 km'),
      (10, '10 km'),
    ];
    final hasGps = provider.userLocation != null;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      height: (36 * (scale < 1 ? 1 : scale)).ceilToDouble(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: FASTSpace.s8),
        itemBuilder: (context, i) {
          final (km, label) = options[i];
          final active = provider.searchRadiusKm == km;
          final fg = active ? fast.onInk : fast.t2;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              provider.setSearchRadius(km);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? fast.ink : fast.card,
                borderRadius: BorderRadius.circular(FASTRadius.pill),
                border: Border.all(color: active ? fast.ink : fast.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    km == null ? Icons.all_inclusive : Icons.near_me,
                    size: 14,
                    color: fg,
                  ),
                  const SizedBox(width: FASTSpace.s4),
                  Text(
                    km != null && !hasGps ? '$label (GPS…)' : label,
                    style: FASTText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoKitchens(BuildContext context, FASTProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FastEmpty(
          icon: Icons.restaurant_outlined,
          // Easter egg: between midnight and 5 am the closed café gives
          // way to the moon over the rooftops.
          loop: DateTime.now().hour < 5 ? FastLoops.midnight : FastLoops.closed,
          title: tr(context, 'no_cuisine'),
          subtitle: tr(context, 'widen_radius'),
          action: FastButton(
            label: tr(context, 'reset_filters'),
            onPressed: () => provider.resetFilters(),
            kind: FastButtonKind.ink,
            expand: false,
            height: 48,
          ),
        ),
        _requestRestaurantLink(
          context,
          () => _showRestaurantRequestSheet(context, ''),
        ),
      ],
    );
  }

  /// Client suggests a restaurant that isn't on FAST — ops calls it and
  /// onboards it. Name is prefilled with the active search keyword.
  void _showRestaurantRequestSheet(BuildContext context, String keyword) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RestaurantRequestSheet(initialName: keyword),
    );
  }

  // Slots Reveal animation modal overlay
  Widget _buildSlotsOverlay(BuildContext context, FASTProvider provider) {
    final fast = context.fast;
    final randRest = provider.surpriseMeRolledRestaurant;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(FASTSpace.s24),
          decoration: BoxDecoration(
            color: fast.card,
            borderRadius: BorderRadius.circular(FASTRadius.md),
            border: Border.all(color: fast.line),
            boxShadow: FASTShadow.sheet(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, size: 40, color: fast.t1),
              const SizedBox(height: FASTSpace.s12),
              Text(
                tr(context, 'choose_meal'),
                textAlign: TextAlign.center,
                style: FASTText.title.copyWith(color: fast.t1),
              ),
              const SizedBox(height: FASTSpace.s4),
              Text(
                tr(context, 'slot_launch'),
                textAlign: TextAlign.center,
                style: FASTText.body.copyWith(color: fast.t2),
              ),
              const SizedBox(height: FASTSpace.s24),
              // Surprise-me revolving screen card
              Container(
                constraints: const BoxConstraints(minHeight: 160),
                width: double.infinity,
                padding: const EdgeInsets.all(FASTSpace.s16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fast.cardHigh,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                ),
                child: randRest == null
                    ? const CircularProgressIndicator(color: FASTBrand.gold)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(FASTRadius.sm),
                            child: FastImage(
                              randRest.image,
                              width: 80,
                              height: 80,
                              placeholder: Container(
                                color: fast.faint,
                                width: 80,
                                height: 80,
                              ),
                            ),
                          ),
                          const SizedBox(height: FASTSpace.s12),
                          Text(
                            randRest.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FASTText.item.copyWith(color: fast.t1),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: FASTSpace.s24),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(FASTBrand.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuts the food photo's top-left corner along the diagonal line the
/// baked fiery streak travels: it enters the crop's left edge ~22% down
/// and exits the top ~56% across. Everything above-left of that line
/// stays transparent so the purple hero shows through — in the
/// reference the glowing slash is the boundary between text zone and
/// food, not a straight photo edge.
class _HeroPhotoClip extends CustomClipper<Path> {
  const _HeroPhotoClip();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.22)
      ..lineTo(size.width * 0.56, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Paints the neon slash that continues the streak baked into the food
/// photo: from the point it crosses the photo's left edge, along the
/// same diagonal, out to the screen's top-right corner — hot pink at
/// the bowl, burning to orange/amber at the far end, with a halo pass
/// underneath so it reads as light, not a line.
class _HeroStreakPainter extends CustomPainter {
  const _HeroStreakPainter({
    required this.photoLeft,
    required this.photoTop,
    required this.photoW,
    required this.photoH,
  });

  final double photoLeft;
  final double photoTop;
  final double photoW;
  final double photoH;

  @override
  void paint(Canvas canvas, Size size) {
    // Streak's known points in photo space (see _HeroPhotoClip).
    final a = Offset(photoLeft, photoTop + photoH * 0.22);
    final b = Offset(photoLeft + photoW * 0.56, photoTop);
    final dir = (b - a) / (b - a).distance;
    // Extend past the photo's top-right to the screen edge + a bit more
    // so it dies beyond the corner, like the reference's light trail.
    final end = b + dir * (size.width - b.dx) * 1.35;
    final start = a - dir * photoW * 0.06;

    final rect = Rect.fromPoints(start, end);
    // Soft pink wash around the line so the upper-right purple carries
    // the glow like the reference, not just a thread of light.
    final wash = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF2E93).withValues(alpha: 0.28),
          const Color(0xFFF97316).withValues(alpha: 0.16),
          const Color(0xFFFBBF24).withValues(alpha: 0.10),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawLine(start, end, wash);
    // Wide blurred halo passes first, then the bright core on top.
    for (final (w, alpha, blur) in const [
      (12.0, 0.40, 12.0),
      (5.5, 0.62, 6.0),
      (2.6, 1.0, 0.0),
    ]) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFF2E93).withValues(alpha: alpha),
            const Color(0xFFF97316).withValues(alpha: alpha),
            const Color(0xFFFBBF24).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round;
      if (blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      }
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroStreakPainter old) =>
      old.photoLeft != photoLeft || old.photoTop != photoTop;
}

/// Shared white headline style for the stacked hero lines
/// ("Commandez." / "Maintenant.") — "Fast." has its own amber variant.
const _heroHeadline = TextStyle(
  fontFamily: FASTText.displayFamily,
  fontSize: 34,
  fontWeight: FontWeight.w900,
  fontVariations: [FontVariation('wght', 900)],
  letterSpacing: -0.4,
  color: Colors.white,
  height: 1.05,
  shadows: [
    Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
  ],
);

/// Bottom sheet — client suggests a restaurant that isn't on FAST yet.
/// The FAST team calls the restaurant and onboards it; the request keeps
/// the client's identity so they can be told when it goes live.
class _RestaurantRequestSheet extends StatefulWidget {
  final String initialName;
  const _RestaurantRequestSheet({required this.initialName});

  @override
  State<_RestaurantRequestSheet> createState() =>
      _RestaurantRequestSheetState();
}

class _RestaurantRequestSheetState extends State<_RestaurantRequestSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  // Label at 16 so it reads 12 once it floats above the value.
  InputDecoration _fieldStyle(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: context.fast.t3, fontSize: 16),
    floatingLabelStyle: TextStyle(color: context.fast.t2, fontSize: 16),
    filled: true,
    fillColor: context.fast.faint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.ink, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 2 || _sending) return;
    setState(() => _sending = true);
    try {
      await RestaurantService().requestRestaurant(
        name: name,
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'req_resto_done'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'req_resto_err'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final inputStyle = FASTText.body.copyWith(color: fast.t1);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        MediaQuery.viewInsetsOf(context).bottom + FASTSpace.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: fast.t1, size: 24),
              const SizedBox(width: FASTSpace.s8),
              Expanded(
                child: Text(
                  tr(context, 'req_resto_title'),
                  style: FASTText.title.copyWith(color: fast.t1),
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s8),
          Text(
            tr(context, 'req_resto_sub'),
            style: FASTText.body.copyWith(color: fast.t2),
          ),
          const SizedBox(height: FASTSpace.s24),
          TextField(
            controller: _name,
            style: inputStyle,
            decoration: _fieldStyle(tr(context, 'req_resto_name')),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: FASTSpace.s12),
          TextField(
            controller: _city,
            style: inputStyle,
            decoration: _fieldStyle(tr(context, 'req_resto_city')),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: FASTSpace.s12),
          TextField(
            controller: _phone,
            style: inputStyle,
            decoration: _fieldStyle(tr(context, 'req_resto_phone')),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: FASTSpace.s12),
          TextField(
            controller: _note,
            style: inputStyle,
            decoration: _fieldStyle(tr(context, 'req_resto_note')),
            maxLines: 2,
          ),
          const SizedBox(height: FASTSpace.s24),
          FastButton(
            label: tr(context, 'req_resto_submit'),
            onPressed: _sending ? null : _submit,
            kind: FastButtonKind.ink,
            height: 52,
          ),
        ],
      ),
    );
  }
}
