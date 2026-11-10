// lib/screens/restaurant_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:url_launcher/url_launcher.dart';
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';
import '../theme.dart';
import 'story_viewer_screen.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_parts.dart';
import '../widgets/fast_ui.dart';
import 'product_sheet.dart';
import '../l10n/tr.dart';
import '../services/reservation_service.dart';
import '../services/review_service.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  // Sticky category bar — a horizontal chip row pinned to the top
  // once the menu scrolls under it; tapping a chip jumps straight
  // to that section (cahier des charges: barre transversale).
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _catKeys = {};
  // Per-chip keys let the horizontal bar auto-scroll so the active
  // category always stays on screen while the menu scrolls.
  final Map<String, GlobalKey> _chipKeys = {};
  List<String> _catOrder = [];
  String? _activeCat;
  DateTime _spyLockUntil = DateTime.fromMillisecondsSinceEpoch(0);

  static const double _barHeight = 46;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Fresh menu on every open — the list cache can lag behind Pro edits.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<FASTProvider>();
      final id = prov.selectedRestaurant?.id;
      if (id != null) prov.refreshRestaurant(id);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _barTopInset => MediaQuery.of(context).padding.top + 6;

  double _docOffsetOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return double.nan;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return double.nan;
    return ro.localToGlobal(Offset.zero).dy + _scroll.offset;
  }

  void _onScroll() {
    if (!_scroll.hasClients || _catOrder.isEmpty) return;
    final threshold = _scroll.offset + _barTopInset + _barHeight + 12;
    String? active;
    for (final cat in _catOrder) {
      final doc = _docOffsetOf(_catKeys[cat]!);
      if (doc.isNaN) continue;
      if (doc <= threshold) active = cat;
    }
    final next = active ?? _catOrder.first;
    final catChanged = next != _activeCat;
    // While a chip tap animates the scroll, the tapped category owns the
    // highlight — the spy takes over again once it lands.
    final spyLocked = DateTime.now().isBefore(_spyLockUntil);
    if (catChanged && !spyLocked) {
      setState(() => _activeCat = next);
      _revealChip(next);
    }
  }

  /// Slides the active chip into view inside the horizontal bar —
  /// centred when possible so the user sees the neighbours too.
  /// Scrolls ONLY the chip row's own ScrollPosition: ensureVisible()
  /// would also move the outer CustomScrollView to centre the pinned
  /// bar, bouncing the user back to the first section.
  void _revealChip(String cat) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[cat]?.currentContext;
      if (ctx == null || !mounted) return;
      final object = ctx.findRenderObject();
      final state = Scrollable.maybeOf(ctx);
      if (object == null || state == null) return;
      state.position.ensureVisible(
        object,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  void _scrollToCategory(String cat) {
    final key = _catKeys[cat];
    if (key == null || !_scroll.hasClients) return;
    // Optimistic activation — on short menus the section can never reach
    // the scroll-spy threshold, so the tap drives the state, not the spy.
    _spyLockUntil = DateTime.now().add(const Duration(milliseconds: 700));
    if (_activeCat != cat) {
      setState(() => _activeCat = cat);
    }
    _revealChip(cat);
    final doc = _docOffsetOf(key);
    if (doc.isNaN) return;
    final target = (doc - _barTopInset - _barHeight - 6).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _categoryChip(BuildContext context, String cat, bool active) {
    // Selected state is ink (near-black in light mode, near-white in
    // dark), not the accent — amber is kept for the pickup code and tags.
    final ink = context.fast.ink;
    final onInk = context.fast.onInk;
    return Padding(
      key: _chipKeys[cat],
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FastTap(
        onTap: () {
          HapticFeedback.selectionClick();
          _scrollToCategory(cat);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? ink : context.fast.card,
            borderRadius: BorderRadius.circular(FASTRadius.pill),
            border: Border.all(color: active ? ink : context.fast.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _categoryIcon(cat),
                size: 13,
                color: active ? onInk : context.fast.t3,
              ),
              const SizedBox(width: 6),
              Text(
                cat.isEmpty
                    ? Provider.of<FASTProvider>(
                        context,
                        listen: false,
                      ).tr('menu_other')
                    : cat,
                style: FASTText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active ? onInk : context.fast.t2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The category bar lives inside the scroll flow — it sits right above
  /// the menu and pins under the status bar once the menu reaches it.
  /// [pinned] is true while it's stuck; the back arrow only appears then,
  /// since the banner's own back button has scrolled away by that point.
  Widget _catBarContent(BuildContext context, {required bool pinned}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        FASTSpace.s16,
        _barTopInset,
        FASTSpace.s16,
        8,
      ),
      decoration: BoxDecoration(
        color: context.fast.bg,
        border: Border(
          bottom: BorderSide(
            color: pinned ? context.fast.line : Colors.transparent,
          ),
        ),
        boxShadow: pinned
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (pinned) ...[
            GestureDetector(
              onTap: () {
                final provider = Provider.of<FASTProvider>(
                  context,
                  listen: false,
                );
                provider.selectRestaurant(null);
                provider.navigateToScreen('home');
              },
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(
                  color: context.fast.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.fast.line),
                ),
                child: Icon(Icons.arrow_back, size: 16, color: context.fast.t1),
              ),
            ),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in _catOrder)
                    _categoryChip(context, cat, cat == _activeCat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final rest = provider.selectedRestaurant;

    if (rest == null) {
      return Center(child: Text(provider.tr('no_resto')));
    }

    // Categories are computed up front — the pinned sliver needs to
    // know whether the bar exists before the menu sections build.
    final cats = _categoriesOf(rest);

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner: the photo carries only the round buttons and the
              // Stories pill — name, address and facts sit under it.
              Stack(
                children: [
                  FastImage(
                    rest.image,
                    height: 180,
                    width: double.infinity,
                    cacheWidth: 900,
                    placeholder: Container(
                      height: 180,
                      color: context.fast.cardHigh,
                    ),
                  ),
                  // Back Button
                  PositionedDirectional(
                    top: FASTSpace.s12,
                    start: FASTSpace.s12,
                    child: _roundButton(
                      context,
                      icon: Icons.arrow_back,
                      label: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onTap: () {
                        provider.selectRestaurant(null);
                        provider.navigateToScreen('home');
                      },
                    ),
                  ),
                  // Favorite heart
                  PositionedDirectional(
                    top: FASTSpace.s12,
                    end: FASTSpace.s12,
                    child: _roundButton(
                      context,
                      icon: provider.isFavorite(rest.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: provider.isFavorite(rest.id)
                          ? FASTBrand.error
                          : context.fast.t1,
                      onTap: () => provider.toggleFavorite(rest.id),
                    ),
                  ),
                  // Stories entry — Snapchat-style menu viewer
                  if (rest.menu.any(
                    (m) =>
                        m.available &&
                        (m.image.isNotEmpty || m.videoUrl.isNotEmpty),
                  ))
                    PositionedDirectional(
                      top: 64,
                      end: FASTSpace.s12,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoryViewerScreen(restaurant: rest),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FASTSpace.s12,
                            vertical: 6,
                          ),
                          // Sits on the photo: a dark scrim with white
                          // text reads in both themes.
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(
                              FASTRadius.pill,
                            ),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: FASTSpace.s4),
                              Text(
                                provider.tr('stories'),
                                style: FASTText.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Name, address, facts, actions
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FASTSpace.s16,
                  FASTSpace.s16,
                  FASTSpace.s16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FastTag(
                      'Click & Collect',
                      kind: FastTagKind.accent,
                      icon: Icons.bolt,
                    ),
                    const SizedBox(height: FASTSpace.s8),
                    Text(
                      rest.name,
                      style: FASTText.display.copyWith(color: context.fast.t1),
                    ),
                    if (rest.address.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s4),
                      Text(
                        rest.address,
                        style: FASTText.body.copyWith(color: context.fast.t2),
                      ),
                    ],
                    const SizedBox(height: FASTSpace.s8),
                    // One line of facts: rating, reviews, prep time, distance.
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(end: 2),
                              child: Icon(
                                Icons.star_rounded,
                                color: FASTBrand.amber,
                                size: 18,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: '${rest.rating}',
                            style: FASTText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.fast.t1,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' (${provider.tr('reviews').replaceAll('{n}', '${rest.reviewsCount}')})'
                                '  ·  ${provider.tr('prep_time').replaceAll('{n}', '${rest.pickupPrepTime}')}'
                                '  ·  ${provider.getRealDistance(rest).toStringAsFixed(1)} km',
                          ),
                        ],
                      ),
                      style: FASTText.body.copyWith(color: context.fast.t2),
                    ),
                    if (!rest.paymentsReady) ...[
                      const SizedBox(height: FASTSpace.s12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(FASTSpace.s12),
                        decoration: BoxDecoration(
                          color: context.fast.cardHigh,
                          borderRadius: BorderRadius.circular(FASTRadius.sm),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: context.fast.t2,
                              size: 16,
                            ),
                            const SizedBox(width: FASTSpace.s8),
                            Expanded(
                              child: Text(
                                provider.tr('restaurant_not_connected'),
                                style: FASTText.caption.copyWith(
                                  color: context.fast.t1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: FASTSpace.s16),
                    ..._buildActions(context, provider, rest),
                    if (rest.description.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s16),
                      Text(
                        rest.description,
                        style: FASTText.body.copyWith(color: context.fast.t2),
                      ),
                    ],
                    // Food truck — weekly stops so customers can follow the truck
                    if (rest.isFoodTruck) ...[
                      const SizedBox(height: FASTSpace.s16),
                      _buildTruckSchedule(context, rest),
                    ],
                  ],
                ),
              ),

              // Menu title
              // No "menu" label here: the category bar below already
              // carries the status-bar inset as top padding (it needs it
              // once pinned), and that inset doubles as the section gap.
              const SizedBox(height: FASTSpace.s8),
            ],
          ),
        ),

        // Sticky category bar — pins at the top while the menu scrolls
        if (cats.length > 1)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyCatBarDelegate(
              height: _barTopInset + _barHeight,
              builder: (ctx, pinned) => _catBarContent(ctx, pinned: pinned),
            ),
          ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menu — grouped under clean category sections
              if (rest.menu.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      provider.tr('no_items'),
                      style: FASTText.body.copyWith(color: context.fast.t3),
                    ),
                  ),
                )
              else
                ..._buildMenuSections(context, provider, rest),

              // Where to find the restaurant. The address and map sit under
              // the menu so the dishes start higher on the page; the
              // itinerary button stays at the top with the other actions.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FASTSpace.s16,
                  FASTSpace.s24,
                  FASTSpace.s16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: context.fast.line, height: 1, thickness: 1),
                    const SizedBox(height: FASTSpace.s24),
                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: context.fast.t2,
                          size: 20,
                        ),
                        const SizedBox(width: FASTSpace.s8),
                        Expanded(
                          child: Text(
                            rest.address,
                            style: FASTText.body.copyWith(
                              color: context.fast.t1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FASTSpace.s12),

                    // Mini Map (MapLibre GL + OpenFreeMap)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FASTRadius.md),
                      child: SizedBox(
                        height: 180,
                        child: debugSkipMaps
                            ? ColoredBox(color: context.fast.cardHigh)
                            : MapLibreMap(
                                // Claim drags before the page scroll does.
                                gestureRecognizers: {
                                  Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer(),
                                  ),
                                },
                                options: MapOptions(
                                  initStyle: openFreeMapStyle,
                                  initCenter: geo(
                                    rest.latitude,
                                    rest.longitude,
                                  ),
                                  initZoom: 15.0,
                                  gestures: const MapGestures(
                                    rotate: false,
                                    pan: true,
                                    zoom: true,
                                    pitch: false,
                                  ),
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
                                        geometry: Point(
                                          geo(rest.latitude, rest.longitude),
                                        ),
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
                  ],
                ),
              ),

              // Reviews — each comment is reportable (F09 moderation)
              if (rest.reviews.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FASTSpace.s16,
                    FASTSpace.s24,
                    FASTSpace.s16,
                    FASTSpace.s4,
                  ),
                  child: Text(
                    provider
                        .tr('reviews')
                        .replaceAll('{n}', '${rest.reviewsCount}'),
                    style: FASTText.title.copyWith(color: context.fast.t1),
                  ),
                ),
                for (var i = 0; i < rest.reviews.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: FASTSpace.s16,
                      endIndent: FASTSpace.s16,
                      color: context.fast.line,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s16,
                      vertical: FASTSpace.s12,
                    ),
                    child: _buildReviewCard(context, provider, rest.reviews[i]),
                  ),
                ],
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ],
    );
  }

  /// Group menu items under category headers, ordered by meal flow:
  /// starters → mains → desserts → drinks, custom labels alphabetically,
  /// uncategorized last.
  /// Ordered category keys for this menu — computed once per build and
  /// registered with the spy keys so the pinned bar can exist before the
  /// lazily-built sections are laid out.
  List<String> _categoriesOf(Restaurant rest) {
    final keys = <String>{};
    for (final item in rest.menu) {
      keys.add(_normalizedCategory(item.category));
    }
    final ordered = keys.toList()
      ..sort((a, b) {
        final ia = _categoryOrder(a);
        final ib = _categoryOrder(b);
        if (ia != ib) return ia.compareTo(ib);
        return a.compareTo(b);
      });

    _catOrder = ordered;
    _activeCat ??= ordered.isNotEmpty ? ordered.first : null;
    if (_activeCat != null && !ordered.contains(_activeCat)) {
      _activeCat = ordered.isNotEmpty ? ordered.first : null;
    }
    for (final k in ordered) {
      _catKeys.putIfAbsent(k, () => GlobalKey());
      _chipKeys.putIfAbsent(k, () => GlobalKey());
    }
    _catKeys.removeWhere((k, _) => !ordered.contains(k));
    _chipKeys.removeWhere((k, _) => !ordered.contains(k));
    return ordered;
  }

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

    final keys = _catOrder;
    return [
      for (final key in keys) ...[
        Padding(
          key: _catKeys[key],
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s24,
            FASTSpace.s16,
            FASTSpace.s4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  key.isEmpty ? provider.tr('menu_other') : key,
                  style: FASTText.title.copyWith(color: context.fast.t1),
                ),
              ),
              Text(
                '${groups[key]!.length}',
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ],
          ),
        ),
        // One column of rows separated by hairlines: long dish names get
        // two lines and a missing photo no longer leaves a blank tile.
        for (var i = 0; i < groups[key]!.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: FASTSpace.s16,
              endIndent: FASTSpace.s16,
              color: context.fast.line,
            ),
          _buildMenuItemRow(context, provider, groups[key]![i]),
        ],
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
    if (c.contains('boisson') ||
        c.contains('drink') ||
        c.contains('beverage')) {
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
    // Apple Maps on iOS (native, no browser hop), Google elsewhere.
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.https('maps.apple.com', '/', {
            'daddr': destination,
            'dirflg': 'w',
          })
        : Uri.https('www.google.com', '/maps/dir/', {
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

  /// 40 circle on the card colour — back and heart on the banner, same
  /// as the heart on the home restaurant card.
  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    String? label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: FastTap(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.fast.card,
            shape: BoxShape.circle,
            boxShadow: FASTShadow.card(context),
          ),
          child: Icon(icon, size: 20, color: color ?? context.fast.t1),
        ),
      ),
    );
  }

  /// Secondary action: outlined pill in the text colour.
  Widget _outlineAction(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final fast = context.fast;
    return FastTap(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FASTRadius.pill),
          border: Border.all(color: fast.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fast.t1),
              const SizedBox(width: FASTSpace.s8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.body.copyWith(
                  color: fast.t1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Itinerary, reserve (when the restaurant takes reservations) and leave
  /// a review. One ink pill, the others outlined: reserving leads on a
  /// reservation-only restaurant, the itinerary everywhere else.
  List<Widget> _buildActions(
    BuildContext context,
    FASTProvider provider,
    Restaurant rest,
  ) {
    final reserveLeads = rest.reservationsEnabled && rest.reservationOnly;
    void reserve() => _showReservationSheet(context, rest);
    void itinerary() => _openGoogleMapsDirections(context, rest);
    // F08 — anyone can tap; the backend only accepts the review once the
    // user has a completed order here. The sheet surfaces that message
    // instead of failing silently.
    void review() => _showReviewSheet(context, provider, rest);

    final hasSecondOutline = rest.reservationsEnabled;
    return [
      if (reserveLeads)
        FastButton(
          label: provider.tr('reserve_table'),
          icon: Icons.event_seat_outlined,
          kind: FastButtonKind.ink,
          height: 48,
          onPressed: reserve,
        )
      else
        Semantics(
          button: true,
          label: provider.tr('gmaps'),
          child: FastButton(
            label: tr(context, 'itinerary'),
            icon: Icons.directions_walk,
            kind: FastButtonKind.ink,
            height: 48,
            onPressed: itinerary,
          ),
        ),
      const SizedBox(height: FASTSpace.s8),
      Row(
        children: [
          if (reserveLeads) ...[
            Expanded(
              child: Semantics(
                button: true,
                label: provider.tr('gmaps'),
                child: _outlineAction(
                  context,
                  label: tr(context, 'itinerary'),
                  onTap: itinerary,
                ),
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
          ] else if (rest.reservationsEnabled) ...[
            Expanded(
              child: _outlineAction(
                context,
                label: provider.tr('reserve_table'),
                onTap: reserve,
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
          ],
          Expanded(
            child: _outlineAction(
              context,
              label: provider.tr('leave_review'),
              // Two pills share the row: no icon so the labels fit.
              icon: hasSecondOutline ? null : Icons.star_outline_rounded,
              onTap: review,
            ),
          ),
        ],
      ),
    ];
  }

  /// Review dates arrive as strings; ISO dates are shown as dd/mm/yyyy,
  /// anything else as received.
  String _reviewDate(String raw) {
    final t = raw.trim();
    final d = DateTime.tryParse(t)?.toLocal();
    if (d == null) return t;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// F09 — a single review with its report (moderation) action.
  Widget _buildReviewCard(
    BuildContext context,
    FASTProvider provider,
    Review r,
  ) {
    final fast = context.fast;
    final date = _reviewDate(r.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.body.copyWith(
                  color: fast.t1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...List.generate(
              5,
              (i) => Icon(
                i < r.rating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 16,
                color: FASTBrand.amber,
              ),
            ),
            const SizedBox(width: FASTSpace.s4),
            InkWell(
              onTap: () => _reportReview(context, provider, r),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(FASTSpace.s4),
                child: Icon(Icons.flag_outlined, size: 18, color: fast.t3),
              ),
            ),
          ],
        ),
        if (date.isNotEmpty)
          Text(date, style: FASTText.caption.copyWith(color: fast.t3)),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: FASTSpace.s4),
          Text(r.comment, style: FASTText.body.copyWith(color: fast.t2)),
        ],
      ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.tr('report_sent'))));
      }
    } catch (_) {
      // Duplicate reports return 409 — treat as already sent.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.tr('report_sent'))));
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

  /// One menu item as a full-width row: name, description, price, and a
  /// square photo with a "+" in its corner.
  Widget _buildMenuItemRow(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    final rest = provider.selectedRestaurant;
    final reservationOnly = rest != null && rest.reservationOnly;
    return FastMenuRow(
      name: item.name,
      description: item.description,
      price: item.price,
      image: item.image,
      available: item.available,
      prepMinutes: item.prepTime,
      unavailableLabel: provider.tr('sold_out'),
      showAdd: !reservationOnly,
      // Reservation-only restaurants don't sell à-la-carte — the tap
      // opens the booking sheet instead of the product sheet.
      onTap: () {
        if (rest != null && rest.reservationOnly) {
          _showReservationSheet(context, rest);
        } else {
          _showAddToCartDialog(context, provider, item);
        }
      },
    );
  }

  // Product sheet: photo, options, supplements, notes, quantity.
  void _showAddToCartDialog(
    BuildContext context,
    FASTProvider provider,
    MenuItem item,
  ) {
    showProductSheet(context, provider, item);
  }

  // Food truck — emplacements programmés par jour pour suivre le camion.
  Widget _buildTruckSchedule(BuildContext context, Restaurant rest) {
    final fast = context.fast;
    final today = DateTime.now().weekday; // 1 = lundi … 7 = dimanche
    final byDay = {for (final s in rest.truckStops) s.weekday: s};
    return Container(
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 20, color: fast.t1),
              const SizedBox(width: FASTSpace.s8),
              Expanded(
                child: Text(
                  tr(context, 'food_truck'),
                  style: FASTText.item.copyWith(color: fast.t1),
                ),
              ),
              if (rest.todayStop == null)
                Flexible(
                  child: Text(
                    tr(context, 'truck_not_today'),
                    textAlign: TextAlign.end,
                    style: FASTText.caption.copyWith(color: fast.t3),
                  ),
                ),
            ],
          ),
          if (rest.todayStop != null) ...[
            const SizedBox(height: FASTSpace.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: fast.t1),
                const SizedBox(width: FASTSpace.s8),
                Expanded(
                  child: Text(
                    '${tr(context, 'truck_today')} ${[rest.todayStop!.label, rest.todayStop!.address, rest.todayStop!.city].where((p) => p.isNotEmpty).join(', ')}',
                    style: FASTText.body.copyWith(
                      color: fast.t1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: FASTSpace.s12),
          Wrap(
            spacing: FASTSpace.s8,
            runSpacing: FASTSpace.s8,
            children: [
              for (var d = 1; d <= 7; d++)
                if (byDay.containsKey(d))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: d == today ? fast.ink : fast.cardHigh,
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                    ),
                    child: Text(
                      '${tr(context, 'day_$d')} • ${byDay[d]!.label.isNotEmpty ? byDay[d]!.label : (byDay[d]!.city.isNotEmpty ? byDay[d]!.city : byDay[d]!.address)}',
                      style: FASTText.caption.copyWith(
                        color: d == today ? fast.onInk : fast.t2,
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
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
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
    final fast = context.fast;
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final pickStyle = OutlinedButton.styleFrom(
      foregroundColor: fast.t1,
      backgroundColor: fast.cardHigh,
      side: BorderSide(color: fast.line),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FASTRadius.sm),
      ),
      textStyle: FASTText.body.copyWith(fontWeight: FontWeight.w700),
    );
    final media = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: fast.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
        boxShadow: FASTShadow.sheet(context),
      ),
      padding: EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        FASTSpace.s16 + media.viewInsets.bottom + media.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'reserve_table'),
            style: FASTText.title.copyWith(color: fast.t1),
          ),
          const SizedBox(height: FASTSpace.s16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(dateLabel),
                  style: pickStyle,
                ),
              ),
              const SizedBox(width: FASTSpace.s8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(timeLabel),
                  style: pickStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'party_size'),
                      style: FASTText.body.copyWith(
                        color: fast.t1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.restaurant.seatingCapacity > 0)
                      Text(
                        tr(context, 'seating_cap_hint').replaceAll(
                          '{n}',
                          '${widget.restaurant.seatingCapacity}',
                        ),
                        style: FASTText.caption.copyWith(color: fast.t3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              FastStepper(
                value: _partySize,
                min: 1,
                max: _maxParty,
                onChanged: (v) => setState(() => _partySize = v),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          if (_error != null) ...[
            _SheetError(_error!),
            const SizedBox(height: FASTSpace.s8),
          ],
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            cursorColor: fast.ink,
            style: FASTText.body.copyWith(color: fast.t1),
            decoration: _sheetInput(context, tr(context, 'allergy_note')),
          ),
          const SizedBox(height: FASTSpace.s24),
          FastButton(
            label: tr(context, 'reserve_table'),
            onPressed: _submit,
            loading: _sending,
            kind: FastButtonKind.ink,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'review_sent_ok'))));
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
    final fast = context.fast;
    final media = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: fast.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
        boxShadow: FASTShadow.sheet(context),
      ),
      padding: EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        FASTSpace.s16 + media.viewInsets.bottom + media.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'leave_review'),
            style: FASTText.title.copyWith(color: fast.t1),
          ),
          const SizedBox(height: FASTSpace.s4),
          Text(
            widget.restaurant.name,
            style: FASTText.body.copyWith(color: fast.t3),
          ),
          const SizedBox(height: FASTSpace.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final lit = i < _rating;
              return IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = i + 1.0);
                },
                icon: Icon(
                  lit ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: lit ? FASTBrand.amber : fast.faint,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: FASTSpace.s12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            cursorColor: fast.ink,
            style: FASTText.body.copyWith(color: fast.t1),
            decoration: _sheetInput(context, tr(context, 'review_ph')),
          ),
          if (_error != null) ...[
            const SizedBox(height: FASTSpace.s12),
            _SheetError(_error!),
          ],
          const SizedBox(height: FASTSpace.s24),
          FastButton(
            label: tr(context, 'submit_review'),
            onPressed: _submit,
            loading: _sending,
            kind: FastButtonKind.ink,
          ),
        ],
      ),
    );
  }
}

/// Pins the category bar to the top of the viewport while the menu
/// sections scroll beneath it. `overlapsContent` tells the bar it's
/// stuck — used to reveal the back button and drop shadow.
class _StickyCatBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyCatBarDelegate({required this.height, required this.builder});

  final double height;
  final Widget Function(BuildContext context, bool pinned) builder;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: builder(context, overlapsContent));
  }

  @override
  bool shouldRebuild(_StickyCatBarDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.builder != builder;
}

/// Text field look shared by the reservation and review sheets: radius
/// 12 on the raised card colour, ink border when focused.
InputDecoration _sheetInput(BuildContext context, String hint) {
  final fast = context.fast;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(FASTRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: FASTText.body.copyWith(color: fast.t3),
    filled: true,
    fillColor: fast.cardHigh,
    contentPadding: const EdgeInsets.all(FASTSpace.s12),
    border: border(fast.line),
    enabledBorder: border(fast.line),
    focusedBorder: border(fast.ink, 1.5),
  );
}

/// Error message shown inside the reservation and review sheets.
class _SheetError extends StatelessWidget {
  const _SheetError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FASTSpace.s12),
      decoration: BoxDecoration(
        color: FASTBrand.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(FASTRadius.sm),
        border: Border.all(color: FASTBrand.error.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: FASTText.caption.copyWith(color: FASTBrand.error),
      ),
    );
  }
}
