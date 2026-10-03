// lib/screens/restaurant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:url_launcher/url_launcher.dart';
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';
import '../theme.dart';
import 'story_viewer_screen.dart';
import '../widgets/fast_image.dart';
import '../l10n/tr.dart';

class RestaurantScreen extends StatelessWidget {
        const RestaurantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final rest = provider.selectedRestaurant;

    if (rest == null) {
      return Center(child: Text(provider.tr('no_resto')));
    }

    return ListView(
      children: [
        // Restaurant Banner Header
        Stack(
          children: [
            FastImage(
              rest.image,
              height: 160,
              width: double.infinity,
              cacheWidth: 500,
              placeholder: Container(height: 160, color: context.fast.cardHigh),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ Colors.black54, Colors.transparent, Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Back Button
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: context.fast.bg.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    provider.selectRestaurant(null);
                    provider.navigateToScreen('home');
                  },
                  icon: Icon( Icons.arrow_back,
                    color: context.fast.t1,
                    size: 20,
                  ),
                ),
              ),
            ),
            // Favorite heart
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: context.fast.bg.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => provider.toggleFavorite(rest.id),
                  icon: Icon(
                    provider.isFavorite(rest.id) ? Icons.favorite : Icons.favorite_border,
                    color: provider.isFavorite(rest.id) ? const Color(0xFFEF4444) : context.fast.t1,
                    size: 20,
                  ),
                ),
              ),
            ),
            // Stories entry — Snapchat-style menu viewer
            if (rest.menu.any((m) => m.available && (m.image.isNotEmpty || m.videoUrl.isNotEmpty)))
              Positioned(
                top: 64,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StoryViewerScreen(restaurant: rest)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(provider.tr('stories'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            // Title & Info
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚡ CLICK & COLLECT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: FASTBrand.onAmber,
                      ),
                    ),
                  ),
                        SizedBox(height: 6), Text(
                    rest.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Restaurant Meta Info Section
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta chips
              Row(
                children: [ Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                        SizedBox(width: 4), Text(
                    '${rest.rating} (${provider.tr('reviews').replaceAll('{n}', '${rest.reviewsCount}')})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t1,
                    ),
                  ),
                        SizedBox(width: 12), Icon( Icons.access_time_filled,
                    color: context.fast.t2,
                    size: 14,
                  ),
                        SizedBox(width: 4), Text(
                    provider.tr('prep_time').replaceAll('{n}', '${rest.pickupPrepTime}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t2,
                    ),
                  ),
                        SizedBox(width: 12), Icon( Icons.location_on,
                    color: context.fast.t2,
                    size: 14,
                  ),
                        SizedBox(width: 4), Text(
                    '${rest.distance} km',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t2,
                    ),
                  ),
                ],
              ),
                    SizedBox(height: 12),
              // Description
 Text(
                rest.description,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fast.t2,
                  height: 1.4,
                ),
              ),
                    SizedBox(height: 8),
              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [ Icon(Icons.map, color: context.fast.t3, size: 14),
                        SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rest.address,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fast.t3,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
                    SizedBox(height: 12),

              // Mini Map (MapLibre GL + OpenFreeMap)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 130,
                  child: MapLibreMap(
                    options: MapOptions(
                      initStyle: openFreeMapStyle,
                      initCenter: geo(rest.latitude, rest.longitude),
                      initZoom: 15.0,
                      gestures: const MapGestures.none(),
                    ),
                    onEvent: (event) async {
                      if (event case MapEventStyleLoaded()) {
                        await registerMapMarkers(event.style);
                      }
                    },
                    layers: [
                      MarkerLayer(
                        points: [
                          Feature(
                            geometry: Point(geo(rest.latitude, rest.longitude)),
                          ),
                        ],
                        iconImage: 'marker_restaurant',
                        iconSize: 0.2,
                        iconAnchor: IconAnchor.center,
                      ),
                    ],
                  ),
                ),
              ),
                    SizedBox(height: 12),
              Semantics(
                button: true,
                label: provider.tr('gmaps'),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMapsDirections(context, rest),
                    icon: Icon(Icons.directions_walk, size: 20),
                    label: Text(tr(context, 'itinerary')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF59E0B),
                      foregroundColor: FASTBrand.onAmber,
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

              Divider(color: context.fast.line, height: 1),

        // Menu title
              Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            provider.tr('menu_items'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: context.fast.t3,
            ),
          ),
        ),

        // Menu list items
        if (rest.menu.isEmpty)
                Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                provider.tr('no_items'),
                style: TextStyle(color: context.fast.t3),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics:       NeverScrollableScrollPhysics(),
            itemCount: rest.menu.length,
            separatorBuilder: (context, index) =>
                      Divider(color: context.fast.line, height: 1),
            itemBuilder: (context, index) {
              final item = rest.menu[index];
              return _buildMenuItemTile(context, provider, item);
            },
          ),
        const SizedBox(height: 120),
      ],
    );
  }

  Future<void> _openGoogleMapsDirections(
    BuildContext context,
    Restaurant restaurant,
  ) async {
    final latitude = restaurant.latitude;
    final longitude = restaurant.longitude;
    final hasValidCoordinates =
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    final address = restaurant.address.trim();

    if (!hasValidCoordinates && address.isEmpty) {
      _showDirectionsError(
        context,
        tr(context, 'route_fail'),
      );
      return;
    }

    final destination = hasValidCoordinates ? '$latitude,$longitude' : address;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'walking',
    });

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && context.mounted) {
        _showDirectionsError(
          context,
          tr(context, 'gmaps_unavailable'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showDirectionsError(
          context,
          tr(context, 'gmaps_fail'),
        );
      }
    }
  }

  void _showDirectionsError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.fast.line,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    return InkWell(
      onTap: () => _showAddToCartDialog(context, provider, item),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [ Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.fast.t1,
                    ),
                  ),
                        SizedBox(height: 4), Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fast.t2,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8), Row(
                    children: [ Text(
                        '€${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      if (item.prepTime > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.fast.cardHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 10, color: context.fast.t3),
                              const SizedBox(width: 3),
                              Text('~${item.prepTime} min',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.fast.t3)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
                  SizedBox(width: 16),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FastImage(
                    item.image,
                    width: 72,
                    height: 72,
                    cacheWidth: 72,
                    placeholder: Container(
                      width: 72,
                      height: 72,
                      color: context.fast.line,
                    ),
                  ),
                ),
                      Positioned(
                  bottom: -6,
                  right: -6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: FASTBrand.onAmber, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Cart customization popup dialog
  void _showAddToCartDialog(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    final textController = TextEditingController();

    // Free options — no extra charge
    final List<String> freeOptions = [
      provider.tr('opt_no_onions'),
      provider.tr('opt_no_cheese'),
      provider.tr('opt_gluten'),
      provider.tr('opt_spicy'),
      provider.tr('opt_well'),
      provider.tr('opt_rare'),
    ];
    final List<String> selectedFree = [];

    // Paid extras from the menu item's supplements (set by restaurant owner)
    final List<String> selectedPaid = [];

    int qty = 1; // quantity counter declared outside builder to persist state

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 8,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Item Name & Description
 Text(
                            item.name,
                            style:       TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.fast.t1,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 6), Text(
                              item.description,
                              style:       TextStyle(
                                fontSize: 12,
                                color: context.fast.t2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                                Divider(color: context.fast.line, height: 1),
                          const SizedBox(height: 16),

                          // Free options — no extra charge
                                Text(
                            provider.tr('options'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.fast.t1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: freeOptions
                                .map(
                                  (option) => FilterChip(
                                    label: Text(
                                      option,
                                      style:       TextStyle(
                                        fontSize: 12,
                                        color: context.fast.t1,
                                      ),
                                    ),
                                    selected: selectedFree.contains(option),
                                    onSelected: (val) {
                                      setModalState(() {
                                        if (val) {
                                          selectedFree.add(option);
                                        } else {
                                          selectedFree.remove(option);
                                        }
                                      });
                                    },
                                    backgroundColor: context.fast.bg,
                                    side: BorderSide(
                                      color: selectedFree.contains(option)
                                          ? const Color(0xFFF59E0B)
                                          : context.fast.faint,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),

                          // Paid supplements — from item.supplements
                          if (item.supplements.isNotEmpty) ...[
                                  Text(
                              provider.tr('extras'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: context.fast.t1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.supplements
                                  .map(
                                    (s) => FilterChip(
                                      label: Text(
                                        '${s.name} (+${s.price.toStringAsFixed(2)}€)',
                                        style:       TextStyle(
                                          fontSize: 12,
                                          color: context.fast.t1,
                                        ),
                                      ),
                                      selected: selectedPaid.contains(s.id),
                                      onSelected: (val) {
                                        setModalState(() {
                                          if (val) {
                                            selectedPaid.add(s.id);
                                          } else {
                                            selectedPaid.remove(s.id);
                                          }
                                        });
                                      },
                                      backgroundColor: context.fast.bg,
                                      side: BorderSide(
                                        color: selectedPaid.contains(s.id)
                                            ? const Color(0xFFF59E0B)
                                            : context.fast.faint,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Allergy notes multiline field
                                Text(
                            'ALLERGIES / NOTES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: context.fast.t3,
                            ),
                          ),
                          const SizedBox(height: 8), TextField(
                            controller: textController,
                            maxLines: 3,
                            style:       TextStyle(
                              fontSize: 12,
                              color: context.fast.t1,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  tr(context, 'allergy_hint'),
                              hintStyle:       TextStyle(
                                color: context.fast.t3,
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: context.fast.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:       BorderSide(
                                  color: context.fast.line,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:       BorderSide(
                                  color: context.fast.line,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity picker & Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Qty Counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FASTBrand.onAmber,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.fast.line),
                        ),
                        child: Row(
                          children: [ IconButton(
                              onPressed: () {
                                if (qty > 1) {
                                  setModalState(() {
                                    qty--;
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove, size: 16),
                            ), Text(
                              '$qty',
                              style:       TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: context.fast.t1,
                              ),
                            ), IconButton(
                              onPressed: () {
                                setModalState(() {
                                  qty++;
                                });
                              },
                              icon: const Icon(Icons.add, size: 16),
                            ),
                          ],
                        ),
                      ),
                      // Add Button
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Builder(
                            builder: (ctx) {
                              final extrasTotal = selectedPaid.fold(0.0, (
                                sum,
                                id,
                              ) {
                                final s = item.supplements.firstWhere(
                                  (s) => s.id == id,
                                  orElse: () => MenuItemSupplement(
                                    id: '',
                                    name: '',
                                    price: 0,
                                  ),
                                );
                                return sum + s.price;
                              });
                              final total = (item.price + extrasTotal) * qty;
                              final allSelected = [
                                ...selectedFree,
                                ...selectedPaid,
                              ];
                              return ElevatedButton(
                                onPressed: () {
                                  provider.addToCart(
                                    item,
                                    qty,
                                    allSelected,
                                    textController.text.trim(),
                                  );
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: FASTBrand.onAmber,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  tr(context, 'add_cart_price').replaceAll('{n}', total.toStringAsFixed(2)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
