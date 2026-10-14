// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_glow_background.dart';
import '../l10n/tr.dart';

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

    return Stack(
      children: [
        Container(color: context.fast.bg),
        LayoutBuilder(
          builder: (context, viewport) => ListView(
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
                    const heroBody = 292.0;
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
                                shaderCallback: (rect) => const LinearGradient(
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
                          // Brand mark + tagline — centered, slightly above
                          // the nav icon row like the reference
                          Positioned(
                            top: statusBar * 0.4,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      color: FASTBrand.amber,
                                      size: 34,
                                    ),
                                    Text(
                                      'FAST',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 34,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Icon(
                                      Icons.bolt,
                                      color: FASTBrand.amber,
                                      size: 34,
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Chaque minute compte',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Headline block — left of the photo, tilted a touch
                          // so the sentence feels like it lifts as it goes
                          Positioned(
                            left: 20,
                            right: 0,
                            top: statusBar + 78,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.66,
                              child: Transform.rotate(
                                angle: -0.028,
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Three stacked lines, each stepping a
                                    // bit further right — the cascade that
                                    // makes the sentence feel like it's
                                    // moving away, like the reference.
                                    Text(
                                      tr(context, 'hero_order'),
                                      style: _heroHeadline,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Text(
                                        'Fast.',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                          color: Color(0xFFF59E0B),
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
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        tr(context, 'hero_now').trim(),
                                        style: _heroHeadline,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Fixed width so the sub wraps before the
                                    // bowl's edge instead of riding over it
                                    SizedBox(
                                      width: 185,
                                      child: Text(
                                        tr(context, 'hero_sub'),
                                        style: const TextStyle(
                                          fontSize: 14,
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
                                    const SizedBox(height: 2),
                                    // Curved orange swoosh under the last
                                    // line, like the reference's hand-drawn
                                    // highlight beneath "votre arrivée."
                                    SizedBox(
                                      width: 150,
                                      height: 10,
                                      child: CustomPaint(
                                        painter: _HeroUnderlinePainter(),
                                      ),
                                    ),
                                  ],
                                ),
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
                                  child: Focus(
                                    onFocusChange: (focus) {
                                      setState(() {
                                        _isFocusingSearch = focus;
                                      });
                                    },
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) =>
                                          provider.setKeyword(val),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1A1425),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: provider.tr('search_hint'),
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF8A8496),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Color(0xFF8A8496),
                                          size: 18,
                                        ),
                                        suffixIcon:
                                            provider.searchKeyword.isNotEmpty
                                            ? IconButton(
                                                onPressed: () {
                                                  provider.setKeyword('');
                                                  _searchController.clear();
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
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFF59E0B),
                                            width: 1.5,
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
                              268 -
                              MediaQuery.of(context).padding.top) <
                          240
                      ? 240.0
                      : viewport.maxHeight -
                            268 -
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
        if (provider.isSurpriseMeRolling) _buildSlotsOverlay(context, provider),
      ],
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

    return Container(
      color: context.fast.bg,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Categories Autocomplete Suggestions
          if (suggCategories.isNotEmpty) ...[
            Text(
              tr(context, 'matching_cats'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: context.fast.t3,
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggCategories.length,
                itemBuilder: (context, index) {
                  final cat = suggCategories[index];
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: context.fast.card,
                      side: BorderSide(color: context.fast.line),
                      avatar: Text(cat.icon),
                      label: Text(
                        catLabel(context, cat.id),
                        style: TextStyle(
                          color: context.fast.t1,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        provider.setCategory(cat.id);
                        provider.setKeyword(
                          '',
                        ); // Clear search to reveal category list
                        _searchController.clear();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 2: Matching Kitchens & Dishes List
          Text(
            provider.tr('matching'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: context.fast.t3,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: (matchingRestaurants.isEmpty && matchingDishes.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🥙', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 12),
                        Text(
                          tr(context, 'no_items'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: context.fast.t3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr(context, 'search_suggest'),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.fast.t3,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      // Restaurants results
                      if (matchingRestaurants.isNotEmpty) ...[
                        ...matchingRestaurants.map(
                          (r) => ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FastImage(
                                r.image,
                                width: 40,
                                height: 40,
                                placeholder: Container(
                                  color: context.fast.faint,
                                  width: 40,
                                  height: 40,
                                ),
                              ),
                            ),
                            title: Text(
                              r.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: context.fast.t1,
                              ),
                            ),
                            subtitle: Text(
                              '${r.pickupPrepTime} ${tr(context, 'min_prep')} • ${provider.getRealDistance(r).toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.fast.t3,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: context.fast.t3,
                            ),
                            onTap: () {
                              provider.selectRestaurant(r.id);
                              provider.navigateToScreen('restaurant');
                            },
                          ),
                        ),
                      ],
                      // Dishes results
                      if (matchingDishes.isNotEmpty) ...[
                        ...matchingDishes.map((data) {
                          final Restaurant r = data['restaurant'];
                          final MenuItem item = data['item'];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FastImage(
                                item.image,
                                width: 40,
                                height: 40,
                                placeholder: Container(
                                  color: context.fast.faint,
                                  width: 40,
                                  height: 40,
                                ),
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: context.fast.t1,
                              ),
                            ),
                            subtitle: Text(
                              '${tr(context, 'from_resto').replaceAll('{n}', r.name)} • ${item.price.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.fast.t3,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr(context, 'order_btn'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            onTap: () {
                              provider.selectRestaurant(r.id);
                              provider.navigateToScreen('restaurant');
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Normal landing page contents
  Widget _buildMainContent(
    BuildContext context,
    FASTProvider provider,
    List<Restaurant> filteredRest,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Bento/Actionable Carousel Banners
        _buildActionableBanners(context, provider),

        SizedBox(height: 16),

        // Category Browsing Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(context, 'browse_by_cat'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: context.fast.t3,
                ),
              ),
              if (provider.selectedCategory != 'all')
                GestureDetector(
                  onTap: () => provider.resetFilters(),
                  child: Text(
                    tr(context, 'clear_filter'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildCategoryStrip(context, provider),

        SizedBox(height: 20),

        // Favorites — synced with website "Mes favoris"
        if (provider.favorites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 14),
                const SizedBox(width: 6),
                Text(
                  tr(context, 'favorites').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: context.fast.t3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: provider.favorites.length,
              itemBuilder: (context, index) {
                final rest = provider.favorites[index];
                return GestureDetector(
                  onTap: () {
                    provider.selectRestaurant(rest.id);
                    provider.navigateToScreen('restaurant');
                  },
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.fast.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.fast.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FastImage(
                          rest.image,
                          height: 84,
                          width: double.infinity,
                          placeholder: Container(
                            height: 84,
                            color: context.fast.cardHigh,
                            child: Icon(
                              Icons.restaurant,
                              color: context.fast.faint,
                              size: 28,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rest.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: context.fast.t1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFF59E0B),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${rest.rating} • ${rest.pickupPrepTime} min',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.fast.t3,
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
          const SizedBox(height: 20),
        ],

        // Kitchen list section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.tr('cuisines_near'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: context.fast.t3,
                ),
              ),
              Text(
                provider
                    .tr('restaurants_available')
                    .replaceAll('{n}', '${filteredRest.length}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: context.fast.t3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildRadiusFilter(context, provider),
        const SizedBox(height: 12),

        // List of Restaurants
        filteredRest.isEmpty
            ? _buildNoKitchens(context, provider)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRest.length,
                  itemBuilder: (context, index) {
                    final rest = filteredRest[index];
                    return _buildRestaurantCard(context, provider, rest);
                  },
                ),
              ),

        const SizedBox(height: 80), // bottom offset for basket
      ],
    );
  }

  // Actionable Banners — synced with website quick categories
  Widget _buildActionableBanners(BuildContext context, FASTProvider provider) {
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _promoBanner(
            context: context,
            onTap: () {
              provider.setKeyword('burger');
              provider.setCategory('burger');
            },
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            emoji: '🍔',
            tag: tr(context, 'express_offer'),
            tagColor: const Color(0xFFFBBF24),
            title: tr(context, 'promo_burger_t'),
            subtitle: tr(context, 'promo_velvet'),
            cta: tr(context, 'cta_enjoy'),
          ),
          _promoBanner(
            context: context,
            onTap: () => provider.navigateToScreen('group'),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            emoji: '👥',
            tag: tr(context, 'with_friends'),
            tagColor: const Color(0xFFC4B5FD),
            title: tr(context, 'group_tagline'),
            subtitle: tr(context, 'promo_group_s'),
            cta: tr(context, 'cta_group'),
            ctaIcon: Icons.group_add,
          ),
          _promoBanner(
            context: context,
            onTap: () => provider.triggerSurpriseMe(context),
            gradient: const LinearGradient(
              colors: [Color(0xFF374151), Color(0xFF1A1F2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            emoji: '🎯',
            tag: tr(context, 'cta_surprise'),
            tagColor: const Color(0xFFF59E0B),
            title: tr(context, 'promo_surprise_t2'),
            subtitle: tr(context, 'promo_surprise_s2'),
            cta: tr(context, 'cta_surprise'),
            ctaIcon: Icons.shuffle,
          ),
        ],
      ),
    );
  }

  Widget _promoBanner({
    required BuildContext context,
    required VoidCallback onTap,
    required LinearGradient gradient,
    required String emoji,
    required String tag,
    required Color tagColor,
    required String title,
    required String subtitle,
    required String cta,
    IconData ctaIcon = Icons.chevron_right,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(right: -10, bottom: -10, child: _PulsingEmoji(emoji)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FASTBrand.onAmber.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tagColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            cta,
                            style: const TextStyle(
                              color: Color(0xFF17171B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            ctaIcon,
                            size: 12,
                            color: const Color(0xFF17171B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Animated light sweep across the card
            Positioned.fill(
              child: IgnorePointer(
                child: _LightSweep(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Categories horizontal scrolling band
  Widget _buildCategoryStrip(BuildContext context, FASTProvider provider) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = provider.categories[index];
          final isActive = provider.selectedCategory == cat.id;
          return GestureDetector(
            onTap: () => provider.setCategory(cat.id),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFF59E0B) : context.fast.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? const Color(0xFFF59E0B) : context.fast.line,
                  width: isActive ? 1.8 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 22)),
                  SizedBox(height: 4),
                  Text(
                    catLabel(context, cat.id),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? FASTBrand.onAmber : context.fast.t2,
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
  ) {
    return GestureDetector(
      onTap: () {
        provider.selectRestaurant(rest.id);
        provider.navigateToScreen('restaurant');
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.fast.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.fast.line),
          boxShadow: [
            BoxShadow(
              color: context.fast.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Image
            Stack(
              children: [
                FastImage(
                  rest.image,
                  height: 140,
                  width: double.infinity,
                  cacheWidth: 800,
                  placeholder: Container(
                    height: 140,
                    color: context.fast.cardHigh,
                    child: Icon(
                      Icons.restaurant,
                      color: context.fast.faint,
                      size: 40,
                    ),
                  ),
                ),
                // Top gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Favorite heart
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => provider.toggleFavorite(rest.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.fast.bg.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        provider.isFavorite(rest.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: provider.isFavorite(rest.id)
                            ? const Color(0xFFEF4444)
                            : context.fast.t2,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Details badges
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.fast.bg.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        SizedBox(width: 4),
                        Text(
                          '${rest.rating}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.fast.t1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Distance badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚡ ${rest.pickupPrepTime} ${tr(context, 'min_prep')} • ${provider.getRealDistance(rest).toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: FASTBrand.onAmber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Text info
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rest.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: context.fast.t1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    rest.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fast.t3,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  // Dietary preference tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rest.dietaryOptions.map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.fast.cardHigh,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.fast.line),
                        ),
                        child: Text(
                          dietLabel(context, tag),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: context.fast.t2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  // Website-style status row: teal FAST indicator + prep time
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C8B3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'FAST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF00C8B3),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule, size: 12, color: context.fast.t3),
                      const SizedBox(width: 3),
                      Text(
                        '${rest.pickupPrepTime} min',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.fast.t3,
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
  }

  // Max search radius picker — 1 / 3 / 5 / 10 km or unlimited
  Widget _buildRadiusFilter(BuildContext context, FASTProvider provider) {
    final options = <(double?, String)>[
      (null, provider.tr('radius_all')),
      (1, '1 km'),
      (3, '3 km'),
      (5, '5 km'),
      (10, '10 km'),
    ];
    final hasGps = provider.userLocation != null;
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (km, label) = options[i];
          final active = provider.searchRadiusKm == km;
          return GestureDetector(
            onTap: () => provider.setSearchRadius(km),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF00C8B3) : context.fast.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF00C8B3) : context.fast.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    km == null ? Icons.all_inclusive : Icons.near_me,
                    size: 11,
                    color: active ? Colors.white : context.fast.t3,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    km != null && !hasGps ? '$label (GPS…)' : label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : context.fast.t2,
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
    return Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text('🥙', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              tr(context, 'no_cuisine'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: context.fast.t1,
              ),
            ),
            SizedBox(height: 6),
            Text(
              tr(context, 'widen_radius'),
              style: TextStyle(fontSize: 11, color: context.fast.t3),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.resetFilters(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF59E0B),
                foregroundColor: FASTBrand.onAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                tr(context, 'reset_filters'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slots Reveal animation modal overlay
  Widget _buildSlotsOverlay(BuildContext context, FASTProvider provider) {
    final randRest = provider.surpriseMeRolledRestaurant;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.fast.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                tr(context, 'choose_meal'),
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                tr(context, 'slot_launch'),
                style: TextStyle(color: context.fast.t2, fontSize: 11),
              ),
              SizedBox(height: 24),
              // Surprise-me revolving screen card
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.fast.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.fast.line),
                ),
                child: randRest == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF59E0B),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FastImage(
                              randRest.image,
                              width: 80,
                              height: 80,
                              placeholder: Container(
                                color: context.fast.cardHigh,
                                width: 80,
                                height: 80,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            randRest.name,
                            style: TextStyle(
                              color: context.fast.t1,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diagonal light band sweeping across a promo card, forever looping.
class _LightSweep extends StatefulWidget {
  final BorderRadius borderRadius;
  const _LightSweep({required this.borderRadius});

  @override
  State<_LightSweep> createState() => _LightSweepState();
}

class _LightSweepState extends State<_LightSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Sweep position: -1.4 → 1.4 (off-left to off-right)
          final t = _ctrl.value * 2.8 - 1.4;
          return FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 1.6,
            alignment: Alignment(t, 0),
            child: Transform.rotate(
              angle: -0.35,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.20),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Softly pulsing decorative emoji with a light glow.
class _PulsingEmoji extends StatefulWidget {
  final String emoji;
  const _PulsingEmoji(this.emoji);

  @override
  State<_PulsingEmoji> createState() => _PulsingEmojiState();
}

class _PulsingEmojiState extends State<_PulsingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_ctrl.value);
        return Transform.scale(
          scale: 1 + v * 0.18,
          child: Opacity(
            opacity: 0.15 + v * 0.15,
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: 64,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.35 + v * 0.3),
                    blurRadius: 18 + v * 14,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

/// The hand-drawn orange swoosh under the hero's last line — a bezier
/// that dips slightly then sweeps up to the right, tapering at both
/// ends like a marker underline.
class _HeroUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.45, size.height * 1.15, size.width, 0);
    for (final (w, alpha, blur) in const [(5.0, 0.35, 4.0), (2.4, 1.0, 0.0)]) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: alpha),
            const Color(0xFFFBBF24).withValues(alpha: alpha),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round;
      if (blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared white headline style for the stacked hero lines
/// ("Commandez." / "Maintenant.") — "Fast." has its own amber variant.
const _heroHeadline = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w900,
  letterSpacing: -0.8,
  color: Colors.white,
  height: 1.05,
  shadows: [
    Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
  ],
);
