// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';

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
    if (provider.searchKeyword != _searchController.text && !_isFocusingSearch) {
      _searchController.text = provider.searchKeyword;
    }

    final filteredRest = provider.getFilteredRestaurants();
    final suggCategories = provider.getAutocompleteCategories();
    final isSearching = provider.searchKeyword.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // Search Bar (full width — no ASAP pill)
            Container(
              color: context.fast.bg,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search field — full width
                      Expanded(
                        child: Focus(
                          onFocusChange: (focus) {
                            setState(() {
                              _isFocusingSearch = focus;
                            });
                          },
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => provider.setKeyword(val),
                            style: TextStyle(fontSize: 13, color: context.fast.t1),
                            decoration: InputDecoration(
                              hintText: 'Rechercher des cuisines, des plats, des spécialités...',
                              hintStyle: TextStyle(color: context.fast.t3),
                              prefixIcon: Icon(Icons.search, color: context.fast.t3, size: 18),
                              suffixIcon: provider.searchKeyword.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        provider.setKeyword('');
                                        _searchController.clear();
                                      },
                                      icon: Icon(Icons.close, color: context.fast.t3, size: 16),
                                    )
                                  : null,
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                              filled: true,
                              fillColor: context.fast.cardHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.fast.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.fast.line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Autocomplete Suggestions Panel OR Main Page Content
            Expanded(
              child: isSearching
                  ? _buildSuggestionsPanel(context, provider, suggCategories)
                  : Container(
                      decoration: BoxDecoration(
                        color: context.fast.bg,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: _buildMainContent(context, provider, filteredRest),
                    ),
            ),
          ],
        ),

        // Slot Machine Selection Overlay
        if (provider.isSurpriseMeRolling)
          _buildSlotsOverlay(context, provider),
      ],
    );
  }

  bool _isFocusingSearch = false;

  // Split suggestion layout
  Widget _buildSuggestionsPanel(
      BuildContext context, FASTProvider provider, List<CategoryItem> suggCategories) {
    final kw = provider.searchKeyword.toLowerCase();
    
    // Find matching dishes
    final List<Map<String, dynamic>> matchingDishes = [];
    final List<Restaurant> matchingRestaurants = [];

    for (var r in provider.restaurants) {
      bool matchedRest = r.name.toLowerCase().contains(kw) || r.description.toLowerCase().contains(kw);
      if (matchedRest) {
        matchingRestaurants.add(r);
      }
      for (var d in r.menu) {
        if (d.name.toLowerCase().contains(kw) || d.description.toLowerCase().contains(kw)) {
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
          if (suggCategories.isNotEmpty) ...[ Text(
              'CATÉGORIES CORRESPONDANTES',
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
                        cat.name,
                        style: TextStyle(
                          color: context.fast.t1,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        provider.setCategory(cat.id);
                        provider.setKeyword(''); // Clear search to reveal category list
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
            'CUISINES & PLATS CORRESPONDANTS',
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
                      children: [ Text(
                          '🥙',
                          style: TextStyle(fontSize: 32),
                        ),
                              SizedBox(height: 12), Text(
                          'Aucun article trouvé',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: context.fast.t3,
                          ),
                        ),
                              SizedBox(height: 4), Text(
                          'Essayez de rechercher burger, pizza, wrap, salade, etc.',
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
                        ...matchingRestaurants.map((r) => ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: FastImage(
                                  r.image,
                                  width: 40,
                                  height: 40,
                                  placeholder: Container(color: context.fast.faint, width: 40, height: 40),
                                ),
                              ),
                              title: Text(
                                r.name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.fast.t1),
                              ),
                              subtitle: Text(
                                '${r.pickupPrepTime} min prép • ${provider.getRealDistance(r).toStringAsFixed(1)} km',
                                style: TextStyle(fontSize: 11, color: context.fast.t3),
                              ),
                              trailing: Icon(Icons.chevron_right, size: 16, color: context.fast.t3),
                              onTap: () {
                                provider.selectRestaurant(r.id);
                                provider.navigateToScreen('restaurant');
                              },
                            )),
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
                                placeholder: Container(color: context.fast.faint, width: 40, height: 40),
                              ),
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.fast.t1),
                              ),
                              subtitle: Text(
                                'De : ${r.name} • ${item.price.toStringAsFixed(2)} €',
                                style: TextStyle(fontSize: 11, color: context.fast.t3),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Commander',
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
      BuildContext context, FASTProvider provider, List<Restaurant> filteredRest) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      children: [
        // Hero headline (matches website homepage)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHAQUE MINUTE COMPTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  color: context.fast.t3,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: context.fast.t1,
                    height: 1.15,
                  ),
                  children: const [
                    TextSpan(text: 'Commandez. '),
                    TextSpan(
                      text: 'Vite.',
                      style: TextStyle(color: Color(0xFFF59E0B)),
                    ),
                    TextSpan(text: ' Maintenant.'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vos restaurants préférés, sans attendre.',
                style: TextStyle(fontSize: 12, color: context.fast.t2),
              ),
            ],
          ),
        ),
        // Bento/Actionable Carousel Banners
        _buildActionableBanners(context, provider),
        
              SizedBox(height: 16),
        
        // Category Browsing Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [ Text(
                'PARCOURIR PAR CATÉGORIE',
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
                  child: const Text(
                    'Effacer le filtre',
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

        // Kitchen list section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [ Text(
                'CUISINES À PROXIMITÉ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: context.fast.t3,
                ),
              ), Text(
                '${filteredRest.length} établissements disponibles',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: context.fast.t3,
                ),
              ),
            ],
          ),
        ),
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
      height: 140,
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
            tag: 'FOOD DROP',
            tagColor: const Color(0xFFFBBF24),
            title: 'Envie de burgers ? Économisez 5 € !',
            subtitle: 'Code : VELVET5',
            cta: 'Profiter',
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
            tag: 'AVEC MES AMIS',
            tagColor: const Color(0xFFC4B5FD),
            title: 'Commande de groupe, chacun paie sa part.',
            subtitle: 'Partagez un code, commandez ensemble',
            cta: 'Créer un groupe',
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
            tag: 'SURPRISE ME',
            tagColor: const Color(0xFFF59E0B),
            title: 'Indécis ? Laissez-nous choisir votre repas.',
            subtitle: 'Découverte aléatoire',
            cta: 'Surprenez-moi',
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
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.15,
                child: Text(emoji, style: const TextStyle(fontSize: 64)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          Icon(ctaIcon, size: 12, color: const Color(0xFF17171B)),
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

  // Categories horizontal scrolling band
  Widget _buildCategoryStrip(BuildContext context, FASTProvider provider) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.categories.length,
        separatorBuilder: (context, index) =>       SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = provider.categories[index];
          final isActive = provider.selectedCategory == cat.id;
          return GestureDetector(
            onTap: () => provider.setCategory(cat.id),
            child: AnimatedContainer(
              duration:       Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFF59E0B)
                    : context.fast.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFF59E0B)
                      : context.fast.line,
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
                children: [ Text(
                    cat.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                        SizedBox(height: 4), Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? FASTBrand.onAmber
                          : context.fast.t2,
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
  Widget _buildRestaurantCard(BuildContext context, FASTProvider provider, Restaurant rest) {
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
                  placeholder: Container(
                    height: 140,
                    color: context.fast.cardHigh,
                    child: Icon(Icons.restaurant, color: context.fast.faint, size: 40),
                  ),
                ),
                // Top gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [ Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                              SizedBox(width: 4), Text(
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
                      '⚡ ${rest.pickupPrepTime} min prép • ${provider.getRealDistance(rest).toStringAsFixed(1)} km',
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
                children: [ Text(
                    rest.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: context.fast.t1,
                    ),
                  ),
                        SizedBox(height: 4), Text(
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
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.fast.cardHigh,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.fast.line),
                        ),
                        child: Text(
                          tag.label,
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

  Widget _buildNoKitchens(BuildContext context, FASTProvider provider) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [ Text('🥙', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12), Text(
              'Aucune cuisine trouvée',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.fast.t1),
            ),
                  SizedBox(height: 6), Text(
              'Essayez de supprimer les restrictions alimentaires ou de modifier les filtres.',
              style: TextStyle(fontSize: 11, color: context.fast.t3),
              textAlign: TextAlign.center,
            ),
                  SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.resetFilters(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF59E0B),
                foregroundColor: FASTBrand.onAmber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Réinitialiser les filtres', style: TextStyle(fontWeight: FontWeight.bold)),
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
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [ Text(
                '🎯',
                style: TextStyle(fontSize: 40),
              ),
                    SizedBox(height: 12), Text(
                'CHOIX DE VOTRE REPAS',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
                    SizedBox(height: 6), Text(
                'Lancement de la machine à sous...',
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
                    ?       Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FastImage(
                              randRest.image,
                              width: 80,
                              height: 80,
                              placeholder: Container(color: context.fast.cardHigh, width: 80, height: 80),
                            ),
                          ),
                                SizedBox(height: 12), Text(
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
