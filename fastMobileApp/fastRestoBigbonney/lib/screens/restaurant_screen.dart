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
import '../services/reservation_service.dart';
import '../services/review_service.dart';

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
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.black87,
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
                  icon: Icon(
                    Icons.arrow_back,
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
                    provider.isFavorite(rest.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: provider.isFavorite(rest.id)
                        ? const Color(0xFFEF4444)
                        : context.fast.t1,
                    size: 20,
                  ),
                ),
              ),
            ),
            // Stories entry — Snapchat-style menu viewer
            if (rest.menu.any(
              (m) =>
                  m.available && (m.image.isNotEmpty || m.videoUrl.isNotEmpty),
            ))
              Positioned(
                top: 64,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(restaurant: rest),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          provider.tr('stories'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  SizedBox(height: 6),
                  Text(
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
                children: [
                  Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 4),
                  Text(
                    '${rest.rating} (${provider.tr('reviews').replaceAll('{n}', '${rest.reviewsCount}')})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t1,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.access_time_filled,
                    color: context.fast.t2,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    provider
                        .tr('prep_time')
                        .replaceAll('{n}', '${rest.pickupPrepTime}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.location_on, color: context.fast.t2, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '${provider.getRealDistance(rest).toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: context.fast.t2,
                    ),
                  ),
                ],
              ),
              if (rest.reservationsEnabled) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReservationSheet(context, rest),
                    icon: const Icon(Icons.event_seat, size: 18),
                    label: Text(provider.tr('reserve_table')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C8B3),
                      side: const BorderSide(color: Color(0xFF00C8B3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // F08 — anyone can tap; the backend only accepts the review
              // once the user has a completed order here. The sheet surfaces
              // that message instead of failing silently.
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _showReviewSheet(context, provider, rest),
                  icon: const Icon(
                    Icons.star_outline_rounded,
                    size: 18,
                    color: Color(0xFFF59E0B),
                  ),
                  label: Text(provider.tr('leave_review')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!rest.paymentsReady) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          provider.tr('restaurant_not_connected'),
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                children: [
                  Icon(Icons.map, color: context.fast.t3, size: 14),
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
              // Food truck — weekly stops so customers can follow the truck
              if (rest.isFoodTruck) ...[
                SizedBox(height: 10),
                _buildTruckSchedule(context, rest),
              ],
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

        // Menu — grouped under clean category sections
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
          ..._buildMenuSections(context, provider, rest),

        // Reviews — each comment is reportable (F09 moderation)
        if (rest.reviews.isNotEmpty) ...[
          Divider(color: context.fast.line, height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              provider.tr('reviews').replaceAll('{n}', '${rest.reviewsCount}'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: context.fast.t3,
              ),
            ),
          ),
          ...rest.reviews.map(
            (r) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _buildReviewCard(context, provider, r),
            ),
          ),
        ],
        const SizedBox(height: 120),
      ],
    );
  }

  /// Group menu items under category headers, ordered by meal flow:
  /// starters → mains → desserts → drinks, custom labels alphabetically,
  /// uncategorized last.
  List<Widget> _buildMenuSections(
    BuildContext context,
    FASTProvider provider,
    Restaurant rest,
  ) {
    final groups = <String, List<MenuItem>>{};
    for (final item in rest.menu) {
      final key = _normalizedCategory(item.category);
      groups.putIfAbsent(key, () => []).add(item);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ia = _categoryOrder(a);
        final ib = _categoryOrder(b);
        if (ia != ib) return ia.compareTo(ib);
        return a.compareTo(b);
      });

    return [
      for (final key in keys) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Icon(
                _categoryIcon(key),
                size: 15,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  key.isEmpty ? provider.tr('menu_other') : key,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.fast.t1,
                  ),
                ),
              ),
              Text(
                '${groups[key]!.length}',
                style: TextStyle(fontSize: 11, color: context.fast.t3),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.68,
          ),
          itemCount: groups[key]!.length,
          itemBuilder: (context, index) =>
              _buildMenuItemCard(context, provider, groups[key]![index]),
        ),
      ],
    ];
  }

  /// Display label for grouping — trim, drop plural 's', Title-case.
  String _normalizedCategory(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    return t[0].toUpperCase() + t.substring(1);
  }

  int _categoryOrder(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('entr') || c.contains('starter') || c.contains('apero')) {
      return 0;
    }
    if (c.contains('plat') ||
        c.contains('main') ||
        c.contains('burger') ||
        c.contains('pizza')) {
      return 1;
    }
    if (c.contains('dessert') || c.contains('sucr')) return 2;
    if (c.contains('boisson') || c.contains('drink') || c.contains('beverage')) {
      return 3;
    }
    if (c.isEmpty) return 99;
    return 50; // custom categories — alphabetical between mains and leftovers
  }

  IconData _categoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('dessert') || c.contains('sucr')) return Icons.cake_outlined;
    if (c.contains('boisson') || c.contains('drink')) {
      return Icons.local_drink_outlined;
    }
    if (c.contains('entr') || c.contains('apero')) {
      return Icons.tapas_outlined;
    }
    if (c.isEmpty) return Icons.fastfood_outlined;
    return Icons.restaurant_outlined;
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
      _showDirectionsError(context, tr(context, 'route_fail'));
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
        _showDirectionsError(context, tr(context, 'gmaps_unavailable'));
      }
    } catch (_) {
      if (context.mounted) {
        _showDirectionsError(context, tr(context, 'gmaps_fail'));
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

  /// F09 — a single review with its report (moderation) action.
  Widget _buildReviewCard(
    BuildContext context,
    FASTProvider provider,
    Review r,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.fast.t1,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              ...List.generate(
                5,
                (i) => Icon(
                  i < r.rating.round() ? Icons.star : Icons.star_border,
                  size: 12,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _reportReview(context, provider, r),
                child: Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: context.fast.t3,
                ),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.comment,
              style: TextStyle(
                color: context.fast.t2,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reportReview(
    BuildContext context,
    FASTProvider provider,
    Review r,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('report_review')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(provider.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(provider.tr('report_review')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ReviewService().reportReview(r.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.tr('report_sent'))),
        );
      }
    } catch (_) {
      // Duplicate reports return 409 — treat as already sent.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.tr('report_sent'))),
        );
      }
    }
  }

  void _showReservationSheet(BuildContext context, Restaurant rest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationSheet(restaurant: rest),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    FASTProvider provider,
    Restaurant rest,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(restaurant: rest),
    );
  }

  /// F04 — menu card: photo on top, name, short description, final price
  /// and a "+" add button. Two cards per row.
  Widget _buildMenuItemCard(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    final unavailable = !item.available;
    return Opacity(
      opacity: unavailable ? 0.45 : 1,
      child: Material(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Reservation-only restaurants don't sell à-la-carte — the tap
          // opens the booking sheet instead of the cart dialog.
          onTap: () {
            final rest = provider.selectedRestaurant;
            if (rest != null && rest.reservationOnly) {
              _showReservationSheet(context, rest);
            } else {
              _showAddToCartDialog(context, provider, item);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FastImage(
                      item.image,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      placeholder: Container(color: context.fast.cardHigh),
                    ),
                    if (!unavailable)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: FASTBrand.onAmber,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: context.fast.t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.fast.t2,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '€${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          if (item.prepTime > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 10,
                                  color: context.fast.t3,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '~${item.prepTime} min',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: context.fast.t3,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.fast.t1,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: TextStyle(
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
                                      style: TextStyle(
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
                                        style: TextStyle(
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
                          const SizedBox(height: 8),
                          TextField(
                            controller: textController,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fast.t1,
                            ),
                            decoration: InputDecoration(
                              hintText: tr(context, 'allergy_hint'),
                              hintStyle: TextStyle(
                                color: context.fast.t3,
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: context.fast.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.fast.line,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
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
                          children: [
                            IconButton(
                              onPressed: () {
                                if (qty > 1) {
                                  setModalState(() {
                                    qty--;
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove, size: 16),
                            ),
                            Text(
                              '$qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: context.fast.t1,
                              ),
                            ),
                            IconButton(
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
                                  tr(
                                    context,
                                    'add_cart_price',
                                  ).replaceAll('{n}', total.toStringAsFixed(2)),
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

  // Food truck — emplacements programmés par jour pour suivre le camion.
  Widget _buildTruckSchedule(BuildContext context, Restaurant rest) {
    final today = DateTime.now().weekday; // 1 = lundi … 7 = dimanche
    final byDay = {for (final s in rest.truckStops) s.weekday: s};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚚', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                tr(context, 'food_truck'),
                style: TextStyle(
                  color: context.fast.t1,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (rest.todayStop == null)
                Text(
                  tr(context, 'truck_not_today'),
                  style: TextStyle(
                    color: context.fast.t3,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          if (rest.todayStop != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Color(0xFF00C8B3),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tr(context, 'truck_today')} ${[
                      rest.todayStop!.label,
                      rest.todayStop!.address,
                      rest.todayStop!.city,
                    ].where((p) => p.isNotEmpty).join(', ')}',
                    style: const TextStyle(
                      color: Color(0xFF00C8B3),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                if (byDay.containsKey(d))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: d == today
                          ? const Color(0xFF00C8B3).withValues(alpha: 0.15)
                          : context.fast.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: d == today
                            ? const Color(0xFF00C8B3)
                            : context.fast.line,
                      ),
                    ),
                    child: Text(
                      '${tr(context, 'day_$d')} • ${byDay[d]!.label.isNotEmpty ? byDay[d]!.label : (byDay[d]!.city.isNotEmpty ? byDay[d]!.city : byDay[d]!.address)}',
                      style: TextStyle(
                        color: d == today
                            ? const Color(0xFF00C8B3)
                            : context.fast.t2,
                        fontSize: 10,
                        fontWeight: d == today
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// F10 — reservation request sheet: date, time, party size, note.
class _ReservationSheet extends StatefulWidget {
  final Restaurant restaurant;
  const _ReservationSheet({required this.restaurant});

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  final _service = ReservationService();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _partySize = 2;
  bool _sending = false;
  String? _error;

  int get _maxParty {
    final cap = widget.restaurant.seatingCapacity;
    return cap > 0 ? cap.clamp(1, 60) : 20;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final dateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    // The backend requires >= 30 min notice — check locally so the user
    // gets an immediate, readable message instead of a silent failure.
    if (dateTime.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      setState(() => _error = tr(context, 'reservation_too_soon'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.createReservation(
        restaurantId: widget.restaurant.id,
        partySize: _partySize,
        dateTime: dateTime,
        note: _noteCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'reservation_sent'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:?\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: context.fast.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'reserve_table'),
            style: TextStyle(
              color: context.fast.t1,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.fast.t1,
                    side: BorderSide(color: context.fast.line),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(timeLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.fast.t1,
                    side: BorderSide(color: context.fast.line),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                tr(context, 'party_size'),
                style: TextStyle(color: context.fast.t3, fontSize: 11),
              ),
              if (widget.restaurant.seatingCapacity > 0) ...[
                const SizedBox(width: 8),
                Text(
                  tr(context, 'seating_cap_hint').replaceAll(
                    '{n}',
                    '${widget.restaurant.seatingCapacity}',
                  ),
                  style: TextStyle(color: context.fast.t3, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _partySize > 1
                    ? () => setState(() => _partySize--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: context.fast.t2,
              ),
              Text(
                '$_partySize',
                style: TextStyle(
                  color: context.fast.t1,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: _partySize < _maxParty
                    ? () => setState(() => _partySize++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: context.fast.t2,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: TextStyle(color: context.fast.t1, fontSize: 13),
            decoration: InputDecoration(
              hintText: tr(context, 'allergy_note'),
              hintStyle: TextStyle(color: context.fast.t3),
              filled: true,
              fillColor: context.fast.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.fast.line),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C8B3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr(context, 'reserve_table')),
            ),
          ),
        ],
      ),
    );
  }
}

/// F08 — star + comment sheet. The backend requires a completed order at
/// this restaurant; its 403 message is shown to the user verbatim.
class _ReviewSheet extends StatefulWidget {
  final Restaurant restaurant;
  const _ReviewSheet({required this.restaurant});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _commentCtrl = TextEditingController();
  double _rating = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = tr(context, 'pick_stars'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ReviewService().createReview(
        restaurantId: widget.restaurant.id,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'review_sent_ok'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:?\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fast.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'leave_review'),
            style: TextStyle(
              color: context.fast.t1,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.restaurant.name,
            style: TextStyle(color: context.fast.t3, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final lit = i < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1.0),
                icon: Icon(
                  lit ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: lit ? const Color(0xFFF59E0B) : context.fast.faint,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            style: TextStyle(color: context.fast.t1, fontSize: 13),
            decoration: InputDecoration(
              hintText: tr(context, 'review_ph'),
              hintStyle: TextStyle(color: context.fast.t3, fontSize: 12),
              filled: true,
              fillColor: context.fast.card,
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
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: FASTBrand.onAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr(context, 'submit_review')),
            ),
          ),
        ],
      ),
    );
  }
}
