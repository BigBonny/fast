// lib/screens/commandes_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart' as geo_loc;
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';
import 'qr_screen.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _orderService = OrderService();
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
  late AnimationController _pulseController;
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Default to History if no active orders exist, otherwise default to Tracking
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final hasActiveOrder = provider.orders.any(
      (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: hasActiveOrder ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _deliveryPollTimer?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
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
          'Commandes',
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFFF59E0B),
          indicatorWeight: 2,
          labelColor: Color(0xFFF59E0B),
          unselectedLabelColor: context.fast.t3,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Suivi en cours'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuiviTab(provider),
          _buildHistoriqueTab(provider),
        ],
      ),
    );
  }

  // ─── SUIVI TAB ─────────────────────────────────────────────────────────────
  Widget _buildSuiviTab(FASTProvider provider) {
    final activeOrders = provider.orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .toList();

    if (activeOrders.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopLocationTracking());
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ Text('🚶', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12), Text(
                'Aucun suivi actif',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.fast.t1),
              ),
                    SizedBox(height: 6), Text(
                'Passez une commande depuis le panier pour activer le suivi de marche !',
                style: TextStyle(fontSize: 11, color: context.fast.t2),
                textAlign: TextAlign.center,
              ),
                    SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.navigateToScreen('home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: FASTBrand.onAmber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Découvrir les restaurants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
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
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeOrders.length,
                    separatorBuilder: (_, __) =>       SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final o = activeOrders[index];
                      final selected = index == _selectedActiveIndex;
                      return ChoiceChip(
                        label: Text(
                          o.restaurantName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected ? FASTBrand.onAmber : context.fast.t1,
                          ),
                        ),
                        selected: selected,
                        selectedColor: Color(0xFFF59E0B),
                        backgroundColor: context.fast.card,
                        onSelected: (_) => setState(() => _selectedActiveIndex = index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildTrackerHeader(context, activeOrder, isCompleted, isCancelled),
                    SizedBox(height: 16),
              if (!isCancelled) ...[
                if (activeOrder.isDelivery) ...[ Text(
                    'SUIVI LIVRAISON',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: context.fast.t3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDeliveryTrackingCard(activeOrder),
                ] else ...[ Text(
                    'SUIVI GPS — TRAJET VERS LE RESTAURANT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: context.fast.t3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildVectorMapCard(context, walkProgress, activeOrder),
                ],
                const SizedBox(height: 16),
              ],

              // Contextual status text card
              _buildStatusDescriptionCard(context, activeOrder, isCompleted, isCancelled),
              const SizedBox(height: 20),

              // QR Verification button — pickup only
              if (!activeOrder.isDelivery &&
                  (activeOrder.status == OrderStatus.readyForPickup || isCompleted))
                _buildQRButton(context, activeOrder),

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

  Widget _buildTrackerHeader(BuildContext context, Order order, bool isCompleted, bool isCancelled) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FastImage(
              order.restaurantImage,
              width: 56,
              height: 56,
              placeholder: Container(color: context.fast.cardHigh, width: 56, height: 56),
            ),
          ),
                SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [ Text(
                      'SUIVI ACTIF • ${order.id}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                      SizedBox(height: 4), Text(
                  order.restaurantName,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.fast.t1),
                ),
                      SizedBox(height: 6),
                Row(
                  children: [ Icon(Icons.directions_walk, size: 12, color: context.fast.t2),
                          SizedBox(width: 4), Text(
                      isCompleted
                          ? 'Récupéré'
                          : isCancelled
                              ? 'Annulé'
                              : 'Arrivée estimée dans : ${_liveEtaMinutes(order)} min',
                      style: TextStyle(fontSize: 11, color: context.fast.t2, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Live proximity chip — syncs with actual GPS progress:
                // green = still far, orange ≈ 3 min out, red = at the door.
                if (!isCompleted && !isCancelled) ...[
                  const SizedBox(height: 6),
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
    if (atDoor) {
      c = const Color(0xFFEF4444);
      label = 'Devant le restaurant — montrez votre QR';
      icon = Icons.storefront;
    } else if (eta <= 3) {
      c = const Color(0xFFF59E0B);
      label = 'Presque arrivé (~$eta min)';
      icon = Icons.near_me;
    } else {
      c = const Color(0xFF10B981);
      label = 'En route — la cuisine a le temps';
      icon = Icons.directions_walk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
 Color bg;
 Color fg;
    String label;
    switch (status) {
      case OrderStatus.placed:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue;
        label = 'COMMANDÉ';
        break;
      case OrderStatus.preparing:
        bg =       Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg =       Color(0xFFF59E0B);
        label = 'EN COURS';
        break;
      case OrderStatus.readyForPickup:
        bg =       Color(0xFF10B981).withValues(alpha: 0.15);
        fg =       Color(0xFF10B981);
        label = 'PRÊT';
        break;
      case OrderStatus.completed:
        bg = context.fast.t3.withValues(alpha: 0.15);
        fg = context.fast.t2;
        label = 'RÉCUPÉRÉ';
        break;
      case OrderStatus.cancelled:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red;
        label = 'ANNULÉ';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildVectorMapCard(BuildContext context, double progress, Order order) {
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final rest = provider.restaurants.where((r) => r.id == order.restaurantId).firstOrNull;
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.fast.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapLibreMap(
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
                      routePoints.map((p) => geo(p.latitude, p.longitude)).toList(),
                    ),
                  ),
                ],
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
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
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(progress * 100).round()} % du trajet',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
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
        _deliveryStatusLabel = _deliveryStatusToLabel(delivery?['status'] as String?);
        final driver = delivery?['driver'] as Map<String, dynamic>?;
        _deliveryDriverName = driver?['name'] as String?;
      });
    } catch (_) {}
  }

  String _deliveryStatusToLabel(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Recherche d\'un livreur…';
      case 'ACCEPTED':
        return 'Livreur assigné — en route vers le restaurant';
      case 'AT_RESTAURANT':
        return 'Livreur au restaurant';
      case 'PICKED_UP':
        return 'En route vers vous !';
      case 'DELIVERED':
        return 'Livré';
      default:
        return 'Commande en cours de préparation';
    }
  }

  Widget _buildDeliveryTrackingCard(Order order) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [ Icon(Icons.delivery_dining, color: Color(0xFF10B981), size: 28),
                    SizedBox(width: 12),
              Expanded(
                child: Text(
                  _deliveryStatusLabel ?? _deliveryStatusToLabel(order.deliveryStatus),
                  style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (_deliveryDriverName != null) ...[
                  SizedBox(height: 10), Text('Livreur : $_deliveryDriverName', style: TextStyle(fontSize: 12, color: context.fast.t2)),
          ],
          if (order.deliveryAddress.isNotEmpty) ...[
                  SizedBox(height: 8), Text('📍 ${order.deliveryAddress}', style: TextStyle(fontSize: 11, color: context.fast.t3)),
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

  Future<void> _startLocationTracking(FASTProvider provider, Order order) async {
    final rest = provider.restaurants.where((r) => r.id == order.restaurantId).firstOrNull;
    if (rest == null) return;

    final restPoint = LatLng(rest.latitude, rest.longitude);
    final start = await LocationService.instance.getCurrentLocation(forceRefresh: true);
    if (start != null) {
      _routePolyline = await LocationService.instance.getWalkingRoute(start, restPoint);
      if (mounted) setState(() {});
    }

    const settings = geo_loc.LocationSettings(
      accuracy: geo_loc.LocationAccuracy.high,
      distanceFilter: 15,
    );

    _locationSub = geo_loc.Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      if (!mounted || _trackingOrderId != order.id) return;
      final current = LatLng(pos.latitude, pos.longitude);

      if (_routePolyline.isEmpty) {
        _routePolyline = await LocationService.instance.getWalkingRoute(current, restPoint);
      }

      final progress = LocationService.instance.progressAlongRoute(current, _routePolyline);
      _walkProgress = progress;

      final now = DateTime.now();
      if (_lastTrackingPatch == null || now.difference(_lastTrackingPatch!) > const Duration(seconds: 20)) {
        _lastTrackingPatch = now;
        provider.fetchUserLocation();
        try {
          await _orderService.updateTracking(
            orderId: order.id,
            gpsProgress: progress * 100,
            latitude: pos.latitude,
            longitude: pos.longitude,
            isReadyAtEntrance: progress >= 0.92,
          );
          provider.updateOrderTrackingLocally(
            order.id,
            gpsProgress: progress * 100,
            isReadyAtEntrance: progress >= 0.92,
          );
        } catch (_) {}
      }

      if (mounted) setState(() {});
    });
  }

  Widget _buildStatusDescriptionCard(BuildContext context, Order order, bool isCompleted, bool isCancelled) {
    String title = '';
    String desc = '';
 IconData icon = Icons.info;
 Color iconColor =       Color(0xFFF59E0B);

    if (isCancelled) {
      title = 'Commande annulée';
      desc = 'Cette commande a été annulée conformément à notre politique d\'annulation transparente. Consultez l\'historique pour les détails de transaction.';
      icon = Icons.cancel;
      iconColor = Colors.red;
    } else if (isCompleted) {
      title = 'Remise effectuée !';
      desc = 'Vous avez récupéré votre commande via FAST Click & Collect. Repas frais et chaud entre vos mains. Bon appétit !';
      icon = Icons.handshake;
      iconColor = const Color(0xFF10B981);
    } else {
      switch (order.status) {
        case OrderStatus.placed:
          title = 'Commande enregistrée !';
          desc = 'La cuisine synchronise les terminaux. Mettez-vous en route maintenant !';
          icon = Icons.receipt_long;
          iconColor = Colors.blue;
          break;
        case OrderStatus.preparing:
          title = 'Vos artisans cuisinent 🍳';
          desc = 'La cuisine a démarré la préparation. Ils ajustent la cuisson dynamiquement selon votre temps de marche.';
          icon = Icons.restaurant_menu;
          iconColor = const Color(0xFFF59E0B);
          break;
        case OrderStatus.readyForPickup:
          title = 'Repas chaud et prêt ! 🔥';
          desc = 'La cuisine a posé votre repas sur le comptoir Click & Collect. Montrez le QR au staff pour confirmer la remise.';
          icon = Icons.backpack;
          iconColor = const Color(0xFF10B981);
          break;
        default:
          break;
      }
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
                SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.fast.t1),
                ),
                      SizedBox(height: 4), Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: context.fast.t2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRButton(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => QRVerificationScreen(order: order),
              fullscreenDialog: true,
            ));
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.qr_code, color: Color(0xFFF59E0B), size: 18),
          label: const Text(
            'Montrer le QR au staff',
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelAction(BuildContext context, FASTProvider provider, Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: TextButton(
          onPressed: () => _showHonestCancellationSheet(context, provider, order),
          child: const Text(
            'Annuler la commande',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _showHonestCancellationSheet(BuildContext context, FASTProvider provider, Order order) {
    final bool prepStarted = order.status != OrderStatus.placed;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.fast.card,
      shape:       RoundedRectangleBorder(
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
                children: [ Icon(Icons.warning, color: Color(0xFFEF4444)),
                  SizedBox(width: 8), Text(
                    'Politique d\'annulation',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.fast.t1),
                  ),
                ],
              ),
                    SizedBox(height: 12), Text(
                'Chez FAST, notre politique d\'annulation est transparente et simple. Pas de petits caractères :',
                style: TextStyle(fontSize: 11, color: context.fast.t2, height: 1.4),
              ),
                    SizedBox(height: 16),

              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: !prepStarted ?       Color(0xFF10B981).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.08) : context.fast.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !prepStarted ?       Color(0xFF10B981).withValues(alpha: 0.3) : context.fast.line,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Icon(
                      !prepStarted ? Icons.check_circle : Icons.radio_button_off,
                      color: !prepStarted ?       Color(0xFF10B981) : context.fast.t3,
                      size: 16,
                    ),
                          SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [ Text(
                            'Cas 1 : Annulation avant préparation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: context.fast.t1),
                          ),
                                SizedBox(height: 2), Text(
                            'Remboursement intégral (hors frais de service 1,50 € utilisés pour le traitement).',
                            style: TextStyle(fontSize: 10, color: context.fast.t2, height: 1.3),
                          ),
                          if (!prepStarted) ...[
                            const SizedBox(height: 6), Text(
                              '👉 ACTIF. Remboursement : ${order.subtotal.toStringAsFixed(2)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF10B981)),
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
                  color: prepStarted ?       Color(0xFFEF4444).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.08) : context.fast.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: prepStarted ?       Color(0xFFEF4444).withValues(alpha: 0.3) : context.fast.line,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Icon(
                      prepStarted ? Icons.error : Icons.radio_button_off,
                      color: prepStarted ?       Color(0xFFEF4444) : context.fast.t3,
                      size: 16,
                    ),
                          SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [ Text(
                            'Cas 2 : Annulation après préparation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: context.fast.t1),
                          ),
                                SizedBox(height: 2), Text(
                            'Débit total appliqué. La cuisine a déjà utilisé les ingrédients frais pour votre repas.',
                            style: TextStyle(fontSize: 10, color: context.fast.t2, height: 1.3),
                          ),
                          if (prepStarted) ...[
                            const SizedBox(height: 6), Text(
                              '👉 ACTIF. Débit : ${order.total.toStringAsFixed(2)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFFEF4444)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Garder la commande', style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold)),
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
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Confirmer l\'annulation', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildCompletionOverlay(BuildContext context, FASTProvider provider, Order order) {
    if (_ratingSubmitted && _confettiController.isCompleted) return const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          final confettiFade = _confettiController.value < 0.7 ? 1.0 : (1.0 - (_confettiController.value - 0.7) / 0.3);
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

  Widget _buildRatingCard(BuildContext context, FASTProvider provider, Order order) {
    return Container(
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: context.fast.line),
          left: BorderSide(color: context.fast.line),
          right: BorderSide(color: context.fast.line),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
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
            children: [ Text('🎉', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Text(
                      'Récupéré !',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.fast.t1,
                      ),
                    ), Text(
                      order.restaurantName,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fast.t2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
                SizedBox(height: 20), Text(
            'Comment s\'est passée votre expérience ?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.fast.t1),
          ),
                SizedBox(height: 10),
          StatefulBuilder(
            builder: (context, setInnerState) {
              return Row(
                children: List.generate(5, (i) {
                  final filled = i < _pendingRating;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _pendingRating = (i + 1).toDouble());
                    },
                    child: Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: filled ?       Color(0xFFF59E0B) : context.fast.faint,
                        size: 32,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
                SizedBox(height: 14), TextField(
            controller: _commentController,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: context.fast.t1),
            decoration: InputDecoration(
              hintText: 'Laissez un commentaire (optionnel)...',
              hintStyle: TextStyle(color: context.fast.faint, fontSize: 12),
              filled: true,
              fillColor: context.fast.bg,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.fast.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.fast.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF59E0B)),
              ),
            ),
          ),
                SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _ratingSubmitted = true),
                  child: Text(
                    'Passer',
                    style: TextStyle(color: context.fast.t3, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
                    SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: FASTBrand.onAmber,
                    disabledBackgroundColor: context.fast.line,
                    disabledForegroundColor: context.fast.faint,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Envoyer l\'avis',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
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
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ Text('📜', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12), Text(
                'Aucun historique de commande',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.fast.t1),
              ),
                    SizedBox(height: 6), Text(
                'Une fois que vous aurez récupéré des commandes Click & Collect, l\'historique apparaîtra ici.',
                style: TextStyle(fontSize: 11, color: context.fast.t2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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

  Widget _buildOrderHistoryCard(BuildContext context, FASTProvider provider, Order order) {
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
          Container(
            padding: EdgeInsets.all(16),
            color: FASTBrand.onAmber,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FastImage(
                    order.restaurantImage,
                    width: 44,
                    height: 44,
                    placeholder: Container(color: context.fast.cardHigh, width: 44, height: 44),
                  ),
                ),
                      SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [ Text(
                            order.id,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: context.fast.t2,
                            ),
                          ),
                          _buildStatusLabel(order.status),
                        ],
                      ),
                            SizedBox(height: 2), Text(
                        order.restaurantName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.fast.t1),
                      ),
                            SizedBox(height: 4), Text(
                        'Commandé le : $formattedDate',
                        style: TextStyle(fontSize: 10, color: context.fast.t3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Items list
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((cartItem) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [ Text(
                          '${cartItem.quantity}x  ${cartItem.menuItem.name}',
                          style: TextStyle(fontSize: 12, color: context.fast.t1),
                        ), Text(
                          '€${(cartItem.menuItem.price * cartItem.quantity).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: context.fast.t2, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }),
                
                      Divider(color: context.fast.line, height: 20),
                
                // commission flat fee
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [ Text('Frais de service FAST', style: TextStyle(fontSize: 11, color: context.fast.t3)), Text('€${order.serviceFee.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: context.fast.t3, fontFamily: 'monospace')),
                  ],
                ),
                      SizedBox(height: 6),
                // total paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [ Text(
                      'Total payé',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.fast.t1),
                    ), Text(
                      '€${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B),
                        fontFamily: 'monospace',
                      ),
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
              color: context.fast.bg.withValues(alpha: 0.3),
              child: order.userRatingSubmitted
                  ?       Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [ Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8), Text(
                          'Avis envoyé avec succès !',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [ Text(
                          'ÉVALUER CE POINT DE VENTE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: context.fast.t3,
                          ),
                        ),
                              SizedBox(height: 8),
                        
                        // Stars Picker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (starIdx) {
                            final double starValue = starIdx + 1.0;
                            final double currentRating = _orderRatings[order.id] ?? 5.0;
                            final isLit = starValue <= currentRating;
                            return IconButton(
                              onPressed: () {
                                setState(() {
                                  _orderRatings[order.id] = starValue;
                                });
                              },
                              icon: Icon(
                                isLit ? Icons.star : Icons.star_border,
                                color: isLit ?       Color(0xFFF59E0B) : context.fast.line,
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
                          style: TextStyle(fontSize: 11, color: context.fast.t1),
                          decoration: InputDecoration(
                            hintText: 'Votre avis sur la température de la nourriture, rapidité...',
                            hintStyle: TextStyle(color: context.fast.t3, fontSize: 10),
                            filled: true,
                            fillColor: context.fast.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: context.fast.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: context.fast.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        
                              SizedBox(height: 12),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final text = _getHistoryController(order.id).text.trim();
                              if (text.isEmpty) return;
                              final rating = _orderRatings[order.id] ?? 5.0;
                              provider.submitRestaurantRating(order.id, order.restaurantId, rating, text);
                              _getHistoryController(order.id).clear();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF59E0B),
                              foregroundColor: FASTBrand.onAmber,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Soumettre mon avis',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusLabel(OrderStatus status) {
 Color fg = Colors.grey;
    switch (status) {
      case OrderStatus.completed:
        fg = const Color(0xFF10B981);
        break;
      case OrderStatus.cancelled:
        fg = Colors.red;
        break;
      default:
        fg = const Color(0xFFF59E0B);
        break;
    }
    return Text(
      status.label.toUpperCase(),
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
    );
  }

  String _parseIsoDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      final m = monthNames[dt.month - 1];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $m, ${dt.year} à ${h}h$min';
    } catch (e) {
      return isoString.split('T')[0];
    }
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
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFA855F7),
      const Color(0xFFEF4444), Colors.white,
    ];

    for (int i = 0; i < _count; i++) {
      final startX = random.nextDouble() * size.width;
      final speed = 0.4 + random.nextDouble() * 0.6;
      final y = (progress * speed * size.height * 1.6) - (random.nextDouble() * size.height * 0.2);
      final x = startX + sin(progress * 6 + i) * 30;

      if (y < 0 || y > size.height) continue;

      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()..color = color.withValues(alpha: (1.0 - progress * 0.8).clamp(0.0, 1.0));
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
      controlPt1.dx, controlPt1.dy,
      controlPt2.dx, controlPt2.dy,
      midPt.dx, midPt.dy,
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
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, neonPaint);

    final Offset progressPt = _getPositionOnCubicPath(startPt, controlPt1, controlPt2, midPt, controlPt3, endPt, progress);

    final radarPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.15 + (pulse * 0.15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(progressPt, 12 + (pulse * 8), radarPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFF59E0B)
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
        ..color = const Color(0xFF10B981).withValues(alpha: 0.1 + (pulse * 0.15))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPt, 10 + (pulse * 10), kitchenRadarPaint);
    }
  }

  Offset _getPositionOnCubicPath(Offset p0, Offset p1, Offset p2, Offset p3, Offset p4, Offset p5, double t) {
    if (t < 0.5) {
      final double localT = t * 2.0;
      final double u = 1.0 - localT;
      final double tt = localT * localT;
      final double uu = u * u;
      final double uuu = uu * u;
      final double ttt = tt * localT;

      final double x = uuu * p0.dx + 3.0 * uu * localT * p1.dx + 3.0 * u * tt * p2.dx + ttt * p3.dx;
      final double y = uuu * p0.dy + 3.0 * uu * localT * p1.dy + 3.0 * u * tt * p2.dy + ttt * p3.dy;
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
