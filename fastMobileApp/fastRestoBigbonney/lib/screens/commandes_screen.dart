// lib/screens/commandes_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart' as geo_loc;
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';
import '../services/location_service.dart';
import '../services/delivery_service.dart';
import 'qr_screen.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_parts.dart';
import '../widgets/fast_ui.dart';
import '../l10n/tr.dart';
import '../services/reservation_service.dart';
import '../api/api_exceptions.dart';

/// Status pill at the label size. [color] null gives a quiet grey pill;
/// amber is drawn as a solid fill with dark text (amber text fails
/// contrast on light surfaces); other status colours are tinted.
Widget _statusPill(BuildContext context, String label, Color? color) {
  final fast = context.fast;
  final Color bg;
  final Color fg;
  if (color == null) {
    bg = fast.cardHigh;
    fg = fast.t2;
  } else if (color == FASTBrand.gold) {
    bg = FASTBrand.gold;
    fg = FASTBrand.onAmber;
  } else {
    bg = color.withValues(alpha: 0.15);
    fg = color;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(FASTRadius.pill),
    ),
    child: Text(
      fastLabelCase(context, label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: FASTText.label.copyWith(color: fg),
    ),
  );
}

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _deliveryService = DeliveryService();

  // Delivery tracking
  Timer? _deliveryPollTimer;
  String? _deliveryStatusLabel;
  String? _deliveryDriverName;
  String? _deliveryPollingOrderId;

  // Active order tracking
  int _selectedActiveIndex = 0;
  List<LatLng> _routePolyline = [];
  double _walkProgress = 0;
  StreamSubscription<geo_loc.Position>? _locationSub;
  String? _trackingOrderId;
  DateTime? _lastTrackingPatch;

  // Active Order (Suivi) Animations
  late AnimationController _confettiController;
  bool _ratingSubmitted = false;
  double _pendingRating = 0;
  final TextEditingController _commentController = TextEditingController();
  String? _lastCompletedId;

  // Order History States
  final Map<String, double> _orderRatings = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Default to History if no active orders exist, otherwise default to Tracking
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final hasActiveOrder = provider.orders.any(
      (o) =>
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled,
    );
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: hasActiveOrder ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _deliveryPollTimer?.cancel();
    _tabController.dispose();
    _confettiController.dispose();
    _commentController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getHistoryController(String orderId) {
    if (!_controllers.containsKey(orderId)) {
      _controllers[orderId] = TextEditingController();
    }
    return _controllers[orderId]!;
  }

  Widget _sectionLabel(String text) => Text(
    fastLabelCase(context, text),
    style: FASTText.label.copyWith(color: context.fast.t3),
  );

  InputDecoration _reviewFieldDecoration(String hint) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: FASTText.body.copyWith(color: context.fast.t3),
      filled: true,
      fillColor: context.fast.bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s16,
        vertical: FASTSpace.s12,
      ),
      border: border(context.fast.line),
      enabledBorder: border(context.fast.line),
      focusedBorder: border(context.fast.ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);

    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          provider.tr('nav_orders'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => HapticFeedback.selectionClick(),
          indicatorColor: context.fast.ink,
          indicatorWeight: 2,
          dividerColor: context.fast.line,
          labelColor: context.fast.ink,
          unselectedLabelColor: context.fast.t3,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(text: provider.tr('tracking_tab')),
            Tab(text: provider.tr('history_tab')),
            Tab(text: provider.tr('reservations_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuiviTab(provider),
          _buildHistoriqueTab(provider),
          const _MyReservationsTab(),
        ],
      ),
    );
  }

  // ─── SUIVI TAB ─────────────────────────────────────────────────────────────
  Widget _buildSuiviTab(FASTProvider provider) {
    final activeOrders = provider.orders
        .where(
          (o) =>
              o.status != OrderStatus.completed &&
              o.status != OrderStatus.cancelled,
        )
        .toList();

    if (activeOrders.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _stopLocationTracking(),
      );
      return Center(
        child: FastEmpty(
          icon: Icons.directions_walk,
          loop: FastLoops.walking,
          title: provider.tr('no_tracking'),
          subtitle: provider.tr('no_tracking_sub'),
          action: FastButton(
            label: provider.tr('discover'),
            kind: FastButtonKind.ink,
            expand: false,
            height: 48,
            onPressed: () => provider.navigateToScreen('home'),
          ),
        ),
      );
    }

    if (_selectedActiveIndex >= activeOrders.length) {
      _selectedActiveIndex = 0;
    }
    final activeOrder = activeOrders[_selectedActiveIndex];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTrackingForOrder(provider, activeOrder);
    });

    final isCompleted = activeOrder.status == OrderStatus.completed;
    final isCancelled = activeOrder.status == OrderStatus.cancelled;
    final walkProgress = isCompleted
        ? 1.0
        : isCancelled
        ? 0.0
        : _walkProgress.clamp(0.0, 1.0);

    // Trigger confetti when a new completion is detected
    if (isCompleted && _lastCompletedId != activeOrder.id) {
      _lastCompletedId = activeOrder.id;
      _ratingSubmitted = activeOrder.userRatingSubmitted;
      _pendingRating = 0;
      _confettiController.forward(from: 0);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeOrders.length > 1) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeOrders.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final o = activeOrders[index];
                      final selected = index == _selectedActiveIndex;
                      return FastTap(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedActiveIndex = index);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: FASTSpace.s16,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.fast.ink
                                : context.fast.card,
                            borderRadius: BorderRadius.circular(
                              FASTRadius.pill,
                            ),
                            border: Border.all(
                              color: selected
                                  ? context.fast.ink
                                  : context.fast.line,
                            ),
                          ),
                          child: Text(
                            o.restaurantName,
                            style: FASTText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? context.fast.onInk
                                  : context.fast.t1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildTrackerHeader(
                context,
                activeOrder,
                isCompleted,
                isCancelled,
              ),
              SizedBox(height: 16),
              // The pickup code is the first thing under the order header:
              // every payment path lands here, and it is what the customer
              // shows at the counter. Same conditions as before — never
              // for delivery or cancelled orders.
              if (!activeOrder.isDelivery &&
                  activeOrder.status != OrderStatus.cancelled &&
                  activeOrder.pickupToken != null) ...[
                FastPickupCode(
                  code: pickupCodeFromToken(activeOrder.pickupToken!),
                  label: provider.tr('pickup_code_lbl'),
                  hint: provider.tr('pickup_code_hint'),
                ),
                const SizedBox(height: 16),
              ],
              if (!isCancelled) ...[
                if (activeOrder.isDelivery) ...[
                  _sectionLabel(provider.tr('tracking_delivery')),
                  const SizedBox(height: 8),
                  _buildDeliveryTrackingCard(activeOrder),
                ] else ...[
                  _sectionLabel(provider.tr('tracking_walk')),
                  const SizedBox(height: 8),
                  _buildVectorMapCard(context, walkProgress, activeOrder),
                ],
                const SizedBox(height: 16),
              ],

              // Contextual status text card
              _buildStatusDescriptionCard(
                context,
                activeOrder,
                isCompleted,
                isCancelled,
              ),
              const SizedBox(height: 20),

              // Pickup code/QR — visible from the moment the order is
              // placed so the client always has it when they arrive.
              if (!activeOrder.isDelivery &&
                  activeOrder.status != OrderStatus.cancelled) ...[
                if (!isCompleted &&
                    activeOrder.gpsProgress <= 0 &&
                    (activeOrder.status == OrderStatus.preparing ||
                        activeOrder.status == OrderStatus.readyForPickup))
                  _buildDepartCard(context, provider, activeOrder),
                _buildQRButton(context, activeOrder),
              ],

              // Cancellation trigger
              if (!isCompleted && !isCancelled)
                _buildCancelAction(context, provider, activeOrder),

              const SizedBox(height: 80),
            ],
          ),
        ),

        // Confetti + Rating overlay when completed
        if (isCompleted)
          _buildCompletionOverlay(context, provider, activeOrder),
      ],
    );
  }

  Widget _buildTrackerHeader(
    BuildContext context,
    Order order,
    bool isCompleted,
    bool isCancelled,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            child: FastImage(
              order.restaurantImage,
              width: 56,
              height: 56,
              placeholder: Container(
                color: context.fast.cardHigh,
                width: 56,
                height: 56,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        order.restaurantName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.item.copyWith(color: context.fast.t1),
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    _buildStatusBadge(order.status),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${tr(context, 'active_tracking')} • ${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.caption.copyWith(color: context.fast.t3),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: context.fast.t2,
                    ),
                    SizedBox(width: 4),
                    Text(
                      isCompleted
                          ? context.read<FASTProvider>().tr('order_picked')
                          : isCancelled
                          ? context.read<FASTProvider>().tr(
                              'order_cancelled_lbl',
                            )
                          : context
                                .read<FASTProvider>()
                                .tr('eta_in')
                                .replaceAll('{n}', '${_liveEtaMinutes(order)}'),
                      style: FASTText.caption.copyWith(
                        color: context.fast.t2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // Live proximity chip — syncs with actual GPS progress:
                // green = still far, orange ≈ 3 min out, red = at the door.
                if (!isCompleted && !isCancelled) ...[
                  const SizedBox(height: 8),
                  _buildProximityChip(order),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live ETA in minutes — counts down with real GPS progress along the
  /// walking route; falls back to the walk time declared at order time.
  int _liveEtaMinutes(Order order) {
    if (_trackingOrderId == order.id && _walkProgress > 0) {
      return (order.userWalkTimeMinutes * (1 - _walkProgress)).ceil();
    }
    return order.userWalkTimeMinutes;
  }

  /// green = still far (kitchen has time), orange ≈ 3 min out,
  /// red = right at the restaurant.
  Widget _buildProximityChip(Order order) {
    final eta = _liveEtaMinutes(order);
    final atDoor = _walkProgress >= 0.92 || eta <= 1;

    final Color c;
    final String label;
    final IconData icon;
    final fast = context.read<FASTProvider>();
    if (atDoor) {
      c = FASTBrand.error;
      label = fast.tr('at_door');
      icon = Icons.storefront;
    } else if (eta <= 3) {
      c = FASTBrand.gold;
      label = fast.tr('almost').replaceAll('{n}', '$eta');
      icon = Icons.near_me;
    } else {
      c = FASTBrand.success;
      label = fast.tr('en_route');
      icon = Icons.directions_walk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FASTRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: FASTText.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: c,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color? color;
    String label;
    final fast = context.read<FASTProvider>();
    switch (status) {
      case OrderStatus.placed:
        color = FASTBrand.info;
        label = fast.tr('st_ordered');
        break;
      case OrderStatus.preparing:
        color = FASTBrand.gold;
        label = fast.tr('st_preparing');
        break;
      case OrderStatus.readyForPickup:
        color = FASTBrand.success;
        label = fast.tr('st_ready');
        break;
      case OrderStatus.completed:
        color = null;
        label = fast.tr('st_picked');
        break;
      case OrderStatus.cancelled:
        color = FASTBrand.error;
        label = fast.tr('st_cancelled');
        break;
    }
    return _statusPill(context, label, color);
  }

  Widget _buildVectorMapCard(
    BuildContext context,
    double progress,
    Order order,
  ) {
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final rest = provider.restaurants
        .where((r) => r.id == order.restaurantId)
        .firstOrNull;
    final restLat = rest?.latitude ?? 48.8566;
    final restLon = rest?.longitude ?? 2.3522;

    final userLoc = provider.userLocation;
    final userLat = userLoc?.latitude ?? 48.8566;
    final userLon = userLoc?.longitude ?? 2.3476;

    final midLat = (userLat + restLat) / 2;
    final midLon = (userLon + restLon) / 2;

    final routePoints = _routePolyline.isNotEmpty
        ? _routePolyline
        : [LatLng(userLat, userLon), LatLng(restLat, restLon)];

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapLibreMap(
            // Claim drags before the surrounding scroll view does —
            // otherwise the map is visible but can't be panned/zoomed.
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            options: MapOptions(
              initStyle: openFreeMapStyle,
              initCenter: geo(midLat, midLon),
              initZoom: 14.0,
              gestures: const MapGestures.all(),
            ),
            onEvent: (event) async {
              if (event case MapEventStyleLoaded()) {
                await registerMapMarkers(event.style);
              }
            },
            layers: [
              PolylineLayer(
                polylines: [
                  Feature(
                    geometry: LineString.from(
                      routePoints
                          .map((p) => geo(p.latitude, p.longitude))
                          .toList(),
                    ),
                  ),
                ],
                color: FASTBrand.gold.withValues(alpha: 0.6),
                width: 3,
              ),
              MarkerLayer(
                points: [Feature(geometry: Point(geo(userLat, userLon)))],
                iconImage: 'marker_user',
                iconSize: 0.2,
                iconAnchor: IconAnchor.center,
              ),
              MarkerLayer(
                points: [Feature(geometry: Point(geo(restLat, restLon)))],
                iconImage: 'marker_restaurant',
                iconSize: 0.2,
                iconAnchor: IconAnchor.center,
              ),
            ],
          ),
          PositionedDirectional(
            start: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(FASTRadius.pill),
              ),
              child: Text(
                context
                    .read<FASTProvider>()
                    .tr('pct_route')
                    .replaceAll('{n}', '${(progress * 100).round()}'),
                style: FASTText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureTrackingForOrder(FASTProvider provider, Order order) {
    if (order.isDelivery) {
      if (_deliveryPollingOrderId == order.id) return;
      _stopLocationTracking();
      _stopDeliveryPolling();
      _deliveryPollingOrderId = order.id;
      _fetchDeliveryStatus(order.id);
      _deliveryPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchDeliveryStatus(order.id);
      });
      return;
    }
    if (_trackingOrderId == order.id) return;
    _stopDeliveryPolling();
    _stopLocationTracking();
    _trackingOrderId = order.id;
    _routePolyline = [];
    _walkProgress = (order.gpsProgress / 100).clamp(0.0, 1.0);
    _startLocationTracking(provider, order);
  }

  void _stopDeliveryPolling() {
    _deliveryPollTimer?.cancel();
    _deliveryPollTimer = null;
    _deliveryPollingOrderId = null;
    _deliveryStatusLabel = null;
    _deliveryDriverName = null;
  }

  Future<void> _fetchDeliveryStatus(String orderId) async {
    try {
      final data = await _deliveryService.getOrderDelivery(orderId);
      final delivery = data['delivery'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _deliveryStatusLabel = _deliveryStatusToLabel(
          delivery?['status'] as String?,
        );
        final driver = delivery?['driver'] as Map<String, dynamic>?;
        _deliveryDriverName = driver?['name'] as String?;
      });
    } catch (_) {}
  }

  String _deliveryStatusToLabel(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return context.read<FASTProvider>().tr('drv_search');
      case 'ACCEPTED':
        return context.read<FASTProvider>().tr('drv_assigned');
      case 'AT_RESTAURANT':
        return context.read<FASTProvider>().tr('drv_at_resto');
      case 'PICKED_UP':
        return context.read<FASTProvider>().tr('drv_coming');
      case 'DELIVERED':
        return context.read<FASTProvider>().tr('drv_delivered');
      default:
        return context.read<FASTProvider>().tr('drv_preparing');
    }
  }

  Widget _buildDeliveryTrackingCard(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.fast.cardHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delivery_dining_outlined,
                  color: context.fast.t1,
                  size: 20,
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Expanded(
                child: Text(
                  _deliveryStatusLabel ??
                      _deliveryStatusToLabel(order.deliveryStatus),
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
              ),
            ],
          ),
          if (_deliveryDriverName != null) ...[
            const SizedBox(height: FASTSpace.s12),
            Text(
              context
                  .read<FASTProvider>()
                  .tr('driver_lbl')
                  .replaceAll('{n}', '$_deliveryDriverName'),
              style: FASTText.body.copyWith(color: context.fast.t2),
            ),
          ],
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: FASTSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: context.fast.t2,
                  ),
                ),
                const SizedBox(width: FASTSpace.s4),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: FASTText.body.copyWith(color: context.fast.t2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _stopLocationTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    _trackingOrderId = null;
  }

  Future<void> _startLocationTracking(
    FASTProvider provider,
    Order order,
  ) async {
    final rest = provider.restaurants
        .where((r) => r.id == order.restaurantId)
        .firstOrNull;
    if (rest == null) return;

    final restPoint = LatLng(rest.latitude, rest.longitude);
    final start = await LocationService.instance.getCurrentLocation(
      forceRefresh: true,
    );
    if (start != null) {
      _routePolyline = await LocationService.instance.getWalkingRoute(
        start,
        restPoint,
      );
      if (mounted) setState(() {});
    }

    const settings = geo_loc.LocationSettings(
      accuracy: geo_loc.LocationAccuracy.high,
      distanceFilter: 15,
    );

    _locationSub =
        geo_loc.Geolocator.getPositionStream(locationSettings: settings).listen(
          (pos) async {
            if (!mounted || _trackingOrderId != order.id) return;
            final current = LatLng(pos.latitude, pos.longitude);

            if (_routePolyline.isEmpty) {
              _routePolyline = await LocationService.instance.getWalkingRoute(
                current,
                restPoint,
              );
            }

            final progress = LocationService.instance.progressAlongRoute(
              current,
              _routePolyline,
            );
            _walkProgress = progress;

            final now = DateTime.now();
            if (_lastTrackingPatch == null ||
                now.difference(_lastTrackingPatch!) >
                    const Duration(seconds: 20)) {
              _lastTrackingPatch = now;
              // Map/user-dot refresh only. The restaurant uplink lives in
              // ProximityService (single source, keeps working when the
              // app is backgrounded) — two uploaders would fight.
              provider.fetchUserLocation();
            }

            if (mounted) setState(() {});
          },
        );
  }

  Widget _buildStatusDescriptionCard(
    BuildContext context,
    Order order,
    bool isCompleted,
    bool isCancelled,
  ) {
    String title = '';
    String desc = '';
    IconData icon = Icons.info;
    Color iconColor = FASTBrand.gold;

    // Motion loop for the moment; cancelled orders keep the plain icon.
    FastLoops? loop;

    final fast = context.read<FASTProvider>();
    if (isCancelled) {
      title = fast.tr('cancelled_title');
      desc = fast.tr('cancelled_desc');
      icon = Icons.cancel_outlined;
      iconColor = FASTBrand.error;
    } else if (isCompleted) {
      title = fast.tr('picked_title');
      desc = fast.tr('picked_desc');
      icon = Icons.handshake_outlined;
      iconColor = FASTBrand.success;
      // Easter egg: every 10th picked-up order gets the sparkler.
      final picked = fast.orders
          .where((o) => o.status == OrderStatus.completed)
          .length;
      loop = picked > 0 && picked % 10 == 0
          ? FastLoops.milestone
          : FastLoops.completed;
    } else {
      switch (order.status) {
        case OrderStatus.placed:
          title = fast.tr('ordered_title');
          desc = fast.tr('ordered_desc');
          icon = Icons.receipt_long_outlined;
          iconColor = FASTBrand.info;
          loop = FastLoops.orderPlaced;
          break;
        case OrderStatus.preparing:
          title = fast.tr('cooking_title');
          desc = fast.tr('cooking_desc');
          icon = Icons.restaurant_menu;
          iconColor = FASTBrand.gold;
          loop = FastLoops.preparing;
          break;
        case OrderStatus.readyForPickup:
          title = fast.tr('ready_title');
          desc = fast.tr('ready_desc');
          icon = Icons.shopping_bag_outlined;
          iconColor = FASTBrand.success;
          loop = FastLoops.ready;
          break;
        default:
          break;
      }
    }

    // Amber is drawn as a fill with a dark icon; the other status
    // colours as a tint with the icon in the status colour.
    final amberIcon = iconColor == FASTBrand.gold;

    final iconBadge = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: amberIcon ? FASTBrand.gold : iconColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: amberIcon ? FASTBrand.onAmber : iconColor,
        size: 20,
      ),
    );

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loop != null)
            FastLoop(loop: loop, size: 64, fallback: iconBadge)
          else
            iconBadge,
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
                SizedBox(height: 4),
                Text(
                  desc,
                  style: FASTText.body.copyWith(color: context.fast.t2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _departing = false;

  /// "Je pars" — tells the restaurant the client is leaving now, so the
  /// kitchen can time the order. Hidden once the order is en route.
  Widget _buildDepartCard(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk, color: context.fast.t1),
          const SizedBox(width: FASTSpace.s12),
          Expanded(
            child: Text(
              provider.tr('depart_prompt'),
              style: FASTText.body.copyWith(
                color: context.fast.t1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: FASTSpace.s12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: FastButton(
              label: provider.tr('je_parts'),
              kind: FastButtonKind.ink,
              expand: false,
              height: 44,
              fontSize: 14,
              loading: _departing,
              onPressed: _departing
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final fast = context.read<FASTProvider>();
                      setState(() => _departing = true);
                      final ok = await provider.departForOrder(
                        order.id,
                        navigate: false,
                      );
                      if (!mounted) return;
                      setState(() => _departing = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            fast.tr(ok ? 'depart_ok' : 'depart_fail'),
                          ),
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRButton(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: FastButton(
        label: context.read<FASTProvider>().tr('show_qr'),
        icon: Icons.qr_code,
        kind: FastButtonKind.ink,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QRVerificationScreen(order: order),
              fullscreenDialog: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCancelAction(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: TextButton(
          onPressed: () =>
              _showHonestCancellationSheet(context, provider, order),
          child: Text(
            provider.tr('cancel_order'),
            style: FASTText.caption.copyWith(
              color: FASTBrand.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showHonestCancellationSheet(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    final bool prepStarted = order.status != OrderStatus.placed;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.fast.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: FASTBrand.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(context, 'cancel_policy'),
                      style: FASTText.item.copyWith(color: context.fast.t1),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                tr(context, 'cancel_policy_intro'),
                style: FASTText.caption.copyWith(color: context.fast.t2),
              ),
              SizedBox(height: 16),

              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: !prepStarted
                      ? Color(0xFF10B981).withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.12
                              : 0.08,
                        )
                      : context.fast.bg,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  border: Border.all(
                    color: !prepStarted
                        ? Color(0xFF10B981).withValues(alpha: 0.3)
                        : context.fast.line,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      !prepStarted
                          ? Icons.check_circle
                          : Icons.radio_button_off,
                      color: !prepStarted ? Color(0xFF10B981) : context.fast.t3,
                      size: 16,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'cancel_case1'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: context.fast.t1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            tr(context, 'cancel_case1_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fast.t2,
                              height: 1.3,
                            ),
                          ),
                          if (!prepStarted) ...[
                            const SizedBox(height: 6),
                            Text(
                              tr(context, 'refund_active').replaceAll(
                                '{n}',
                                order.subtotal.toStringAsFixed(2),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: FASTBrand.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: prepStarted
                      ? Color(0xFFEF4444).withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.14
                              : 0.08,
                        )
                      : context.fast.bg,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  border: Border.all(
                    color: prepStarted
                        ? Color(0xFFEF4444).withValues(alpha: 0.3)
                        : context.fast.line,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      prepStarted ? Icons.error : Icons.radio_button_off,
                      color: prepStarted ? Color(0xFFEF4444) : context.fast.t3,
                      size: 16,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'cancel_case2'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: context.fast.t1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            tr(context, 'cancel_case2_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fast.t2,
                              height: 1.3,
                            ),
                          ),
                          if (prepStarted) ...[
                            const SizedBox(height: 6),
                            Text(
                              tr(context, 'active_debit').replaceAll(
                                '{n}',
                                order.total.toStringAsFixed(2),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: FASTBrand.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.fast.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        tr(context, 'keep_order'),
                        style: TextStyle(
                          color: context.fast.t1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.cancelOrder(order.id);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FASTBrand.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        tr(context, 'confirm_cancel'),
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildCompletionOverlay(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    if (_ratingSubmitted && _confettiController.isCompleted) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          final confettiFade = _confettiController.value < 0.7
              ? 1.0
              : (1.0 - (_confettiController.value - 0.7) / 0.3);
          return Stack(
            children: [
              if (_confettiController.value < 0.9)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: confettiFade.clamp(0.0, 1.0),
                      child: CustomPaint(
                        painter: _ConfettiPainter(
                          progress: _confettiController.value,
                          seed: order.id.hashCode,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_ratingSubmitted)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildRatingCard(context, provider, order),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingCard(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
        border: Border(
          top: BorderSide(color: context.fast.line),
          left: BorderSide(color: context.fast.line),
          right: BorderSide(color: context.fast.line),
        ),
        boxShadow: FASTShadow.sheet(context),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.fast.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 24,
                color: context.fast.t1,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'picked_up_excl'),
                      style: FASTText.item.copyWith(color: context.fast.t1),
                    ),
                    Text(
                      order.restaurantName,
                      style: FASTText.caption.copyWith(color: context.fast.t2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            tr(context, 'review_prompt'),
            style: FASTText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: context.fast.t1,
            ),
          ),
          SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setInnerState) {
              return Row(
                children: List.generate(5, (i) {
                  final filled = i < _pendingRating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _pendingRating = (i + 1).toDouble());
                    },
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: 6),
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: filled ? FASTBrand.gold : context.fast.faint,
                        size: 32,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 2,
            style: FASTText.body.copyWith(color: context.fast.t1),
            decoration: _reviewFieldDecoration(tr(context, 'comment_ph')),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _ratingSubmitted = true),
                  child: Text(
                    tr(context, 'skip_tuto'),
                    style: FASTText.body.copyWith(
                      color: context.fast.t2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FastButton(
                  label: tr(context, 'send_review'),
                  kind: FastButtonKind.ink,
                  onPressed: _pendingRating == 0
                      ? null
                      : () {
                          provider.submitRestaurantRating(
                            order.id,
                            order.restaurantId,
                            _pendingRating,
                            _commentController.text.trim(),
                          );
                          setState(() => _ratingSubmitted = true);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HISTORIQUE TAB ────────────────────────────────────────────────────────
  Widget _buildHistoriqueTab(FASTProvider provider) {
    final orders = provider.orders;

    if (orders.isEmpty) {
      return Center(
        child: FastEmpty(
          icon: Icons.receipt_long_outlined,
          loop: FastLoops.clock,
          title: tr(context, 'no_history'),
          subtitle: tr(context, 'history_hint'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderHistoryCard(context, provider, order);
      },
    );
  }

  Widget _buildOrderHistoryCard(
    BuildContext context,
    FASTProvider provider,
    Order order,
  ) {
    final formattedDate = _parseIsoDate(order.createdAt);
    final isCompleted = order.status == OrderStatus.completed;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fast.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  child: FastImage(
                    order.restaurantImage,
                    width: 48,
                    height: 48,
                    placeholder: Container(
                      color: context.fast.cardHigh,
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              order.restaurantName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: FASTText.item.copyWith(
                                color: context.fast.t1,
                              ),
                            ),
                          ),
                          const SizedBox(width: FASTSpace.s8),
                          _buildStatusLabel(order.status),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        tr(
                          context,
                          'ordered_on',
                        ).replaceAll('{n}', formattedDate),
                        style: FASTText.caption.copyWith(
                          color: context.fast.t2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        order.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.caption.copyWith(
                          color: context.fast.t3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.fast.line, height: 1),

          // Items list
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((cartItem) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${cartItem.quantity}x  ${cartItem.menuItem.name}',
                            style: FASTText.body.copyWith(
                              color: context.fast.t1,
                            ),
                          ),
                        ),
                        const SizedBox(width: FASTSpace.s12),
                        Text(
                          '${(cartItem.menuItem.price * cartItem.quantity).toStringAsFixed(2)} €',
                          style: FASTText.price.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.fast.t2,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                Divider(color: context.fast.line, height: 24),

                // total paid
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'total_paid'),
                        style: FASTText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.fast.t1,
                        ),
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s12),
                    Text(
                      '${order.total.toStringAsFixed(2)} €',
                      style: FASTText.price.copyWith(color: context.fast.t1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rating Feedback panel (only for completed orders)
          if (isCompleted) ...[
            Divider(color: context.fast.line, height: 1),
            Container(
              padding: EdgeInsets.all(16),
              child: order.userRatingSubmitted
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: FASTBrand.success,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tr(context, 'review_sent_ok'),
                            style: FASTText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: FASTBrand.success,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(tr(context, 'rate_venue')),
                        SizedBox(height: 8),

                        // Stars Picker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (starIdx) {
                            final double starValue = starIdx + 1.0;
                            final double currentRating =
                                _orderRatings[order.id] ?? 5.0;
                            final isLit = starValue <= currentRating;
                            return IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _orderRatings[order.id] = starValue;
                                });
                              },
                              icon: Icon(
                                isLit
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: isLit
                                    ? FASTBrand.gold
                                    : context.fast.faint,
                                size: 28,
                              ),
                            );
                          }),
                        ),

                        SizedBox(height: 10),

                        // Comments field
                        TextField(
                          controller: _getHistoryController(order.id),
                          maxLines: 1,
                          style: FASTText.body.copyWith(color: context.fast.t1),
                          decoration: _reviewFieldDecoration(
                            tr(context, 'review_ph'),
                          ),
                        ),

                        SizedBox(height: 12),

                        // Submit button
                        FastButton(
                          label: tr(context, 'submit_review'),
                          kind: FastButtonKind.ink,
                          height: 48,
                          onPressed: () {
                            final text = _getHistoryController(
                              order.id,
                            ).text.trim();
                            // Comment is optional — stars alone count.
                            final rating = _orderRatings[order.id] ?? 5.0;
                            provider.submitRestaurantRating(
                              order.id,
                              order.restaurantId,
                              rating,
                              text,
                            );
                            _getHistoryController(order.id).clear();
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusLabel(OrderStatus status) {
    Color fg;
    switch (status) {
      case OrderStatus.completed:
        fg = FASTBrand.success;
        break;
      case OrderStatus.cancelled:
        fg = FASTBrand.error;
        break;
      default:
        fg = FASTBrand.gold;
        break;
    }
    return _statusPill(context, orderStatusLabel(context, status), fg);
  }

  String _parseIsoDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final monthNames = tr(context, 'months_csv').split('|');
      final m = monthNames[dt.month - 1];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $m ${dt.year} · ${h}h$min';
    } catch (e) {
      return isoString.split('T')[0];
    }
  }
}

// ─── RESERVATIONS TAB (customer side) ────────────────────────────────────────
/// Lists the customer's table reservations — pending ones can be cancelled.
class _MyReservationsTab extends StatefulWidget {
  const _MyReservationsTab();

  @override
  State<_MyReservationsTab> createState() => _MyReservationsTabState();
}

class _MyReservationsTabState extends State<_MyReservationsTab> {
  final _service = ReservationService();
  List<Reservation>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.myReservations();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is ApiException ? e.message : tr(context, 'load_err'),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancel(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'cancel_reservation_q')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(context, 'close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tr(context, 'cancel'),
              style: const TextStyle(color: FASTBrand.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.cancel(r.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : tr(context, 'load_err'),
            ),
          ),
        );
      }
    }
  }

  Color _statusColor(String status) => switch (status) {
    'CONFIRMED' => FASTBrand.success,
    'DECLINED' || 'CANCELLED' => FASTBrand.error,
    _ => FASTBrand.gold,
  };

  String _statusLabel(String status) => switch (status) {
    'CONFIRMED' => tr(context, 'reservation_confirmed'),
    'DECLINED' => tr(context, 'reservation_declined'),
    'CANCELLED' => tr(context, 'reservation_cancelled'),
    _ => tr(context, 'reservation_pending'),
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: FastLoop(
          loop: FastLoops.loading,
          size: 84,
          fallback: CircularProgressIndicator(color: FASTBrand.gold),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: FASTText.body.copyWith(color: context.fast.t2),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: Text(tr(context, 'retry'))),
            ],
          ),
        ),
      );
    }
    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: FastEmpty(
          icon: Icons.event_seat_outlined,
          title: tr(context, 'no_reservations'),
          subtitle: tr(context, 'no_reservations_hint'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(Reservation r) {
    final color = _statusColor(r.status);
    final dt = r.dateTime;
    final dateLabel =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FASTRadius.sm),
                child: FastImage(
                  r.restaurantImage,
                  width: 48,
                  height: 48,
                  placeholder: Container(
                    width: 48,
                    height: 48,
                    color: context.fast.cardHigh,
                  ),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Expanded(
                child: Text(
                  r.restaurantName.isEmpty ? r.customerName : r.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
              ),
              const SizedBox(width: FASTSpace.s8),
              _statusPill(context, _statusLabel(r.status), color),
            ],
          ),
          const SizedBox(height: FASTSpace.s12),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: context.fast.t3),
              const SizedBox(width: 4),
              Text(
                dateLabel,
                style: FASTText.caption.copyWith(color: context.fast.t2),
              ),
              const SizedBox(width: FASTSpace.s16),
              Icon(Icons.people_outline, size: 14, color: context.fast.t3),
              const SizedBox(width: 4),
              Text(
                '${r.partySize}',
                style: FASTText.caption.copyWith(color: context.fast.t2),
              ),
            ],
          ),
          if (r.isPending) ...[
            const SizedBox(height: FASTSpace.s12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancel(r),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FASTBrand.error,
                  side: const BorderSide(color: FASTBrand.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  tr(context, 'cancel_reservation'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Confetti CustomPainter ────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final int seed;

  _ConfettiPainter({required this.progress, required this.seed});

  static const int _count = 80;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final colors = [
      FASTBrand.gold,
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFA855F7),
      const Color(0xFFEF4444),
      Colors.white,
    ];

    for (int i = 0; i < _count; i++) {
      final startX = random.nextDouble() * size.width;
      final speed = 0.4 + random.nextDouble() * 0.6;
      final y =
          (progress * speed * size.height * 1.6) -
          (random.nextDouble() * size.height * 0.2);
      final x = startX + sin(progress * 6 + i) * 30;

      if (y < 0 || y > size.height) continue;

      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()
        ..color = color.withValues(
          alpha: (1.0 - progress * 0.8).clamp(0.0, 1.0),
        );
      final w = 6.0 + random.nextDouble() * 6;
      final h = 3.0 + random.nextDouble() * 4;
      final angle = progress * 8 + random.nextDouble() * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// Custom Painter drawing the stylized vector roadmap
class MapRoadmapPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final OrderStatus orderStatus;

  MapRoadmapPainter({
    required this.progress,
    required this.pulse,
    required this.orderStatus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF0A0A0C)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF27272A).withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final path = Path();
    final startPt = Offset(40, size.height - 40);
    final controlPt1 = Offset(size.width * 0.3, size.height * 0.85);
    final controlPt2 = Offset(size.width * 0.2, size.height * 0.3);
    final midPt = Offset(size.width * 0.5, size.height * 0.45);
    final controlPt3 = Offset(size.width * 0.8, size.height * 0.6);
    final endPt = Offset(size.width - 40, 40);

    path.moveTo(startPt.dx, startPt.dy);
    path.cubicTo(
      controlPt1.dx,
      controlPt1.dy,
      controlPt2.dx,
      controlPt2.dy,
      midPt.dx,
      midPt.dy,
    );
    path.quadraticBezierTo(controlPt3.dx, controlPt3.dy, endPt.dx, endPt.dy);

    final roadPaint = Paint()
      ..color = const Color(0xFF18181B)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, roadPaint);

    final roadBorderPaint = Paint()
      ..color = const Color(0xFF27272A)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, roadBorderPaint);
    canvas.drawPath(path, roadPaint);

    final neonPaint = Paint()
      ..color = FASTBrand.gold.withValues(alpha: 0.4)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, neonPaint);

    final Offset progressPt = _getPositionOnCubicPath(
      startPt,
      controlPt1,
      controlPt2,
      midPt,
      controlPt3,
      endPt,
      progress,
    );

    final radarPaint = Paint()
      ..color = FASTBrand.gold.withValues(alpha: 0.15 + (pulse * 0.15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(progressPt, 12 + (pulse * 8), radarPaint);

    final dotPaint = Paint()
      ..color = FASTBrand.gold
      ..style = PaintingStyle.fill;
    canvas.drawCircle(progressPt, 5.0, dotPaint);

    final startDotPaint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPt, 4.0, startDotPaint);

    final endDotPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPt, 5.0, endDotPaint);

    if (orderStatus == OrderStatus.readyForPickup) {
      final kitchenRadarPaint = Paint()
        ..color = const Color(
          0xFF10B981,
        ).withValues(alpha: 0.1 + (pulse * 0.15))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPt, 10 + (pulse * 10), kitchenRadarPaint);
    }
  }

  Offset _getPositionOnCubicPath(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
    Offset p5,
    double t,
  ) {
    if (t < 0.5) {
      final double localT = t * 2.0;
      final double u = 1.0 - localT;
      final double tt = localT * localT;
      final double uu = u * u;
      final double uuu = uu * u;
      final double ttt = tt * localT;

      final double x =
          uuu * p0.dx +
          3.0 * uu * localT * p1.dx +
          3.0 * u * tt * p2.dx +
          ttt * p3.dx;
      final double y =
          uuu * p0.dy +
          3.0 * uu * localT * p1.dy +
          3.0 * u * tt * p2.dy +
          ttt * p3.dy;
      return Offset(x, y);
    } else {
      final double localT = (t - 0.5) * 2.0;
      final double u = 1.0 - localT;
      final double tt = localT * localT;
      final double uu = u * u;

      final double x = uu * p3.dx + 2.0 * u * localT * p4.dx + tt * p5.dx;
      final double y = uu * p3.dy + 2.0 * u * localT * p4.dy + tt * p5.dy;
      return Offset(x, y);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
