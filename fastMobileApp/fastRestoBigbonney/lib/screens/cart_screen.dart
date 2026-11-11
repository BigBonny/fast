// lib/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show
        Stripe,
        StripeException,
        FailureCode,
        SetupPaymentSheetParameters,
        PaymentSheetApplePay,
        PaymentSheetGooglePay;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import '../provider.dart';
import '../models.dart';
import '../services/payment_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_parts.dart';
import '../widgets/fast_ui.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final PaymentService _paymentService = PaymentService();
  final GroupService _groupService = GroupService();

  int _selectedWalkTime = 12; // default walking ETA in minutes
  bool _isProcessing = false;
  String _processStep = '';
  String? _pendingStripeSessionId;
  final _deliveryAddressCtrl = TextEditingController();
  bool _geocodingAddress = false;

  @override
  void initState() {
    super.initState();
    _loadPendingSession();
  }

  Future<void> _loadPendingSession() async {
    final id = await FASTProvider.loadPendingStripeSession();
    if (id != null && mounted) setState(() => _pendingStripeSessionId = id);
  }

  @override
  void dispose() {
    _deliveryAddressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final cart = provider.cart;
    final rest = provider.selectedRestaurant;

    if (cart.isEmpty || rest == null) {
      return Center(
        child: FastEmpty(
          icon: Icons.shopping_bag_outlined,
          title: provider.tr('cart_empty'),
          subtitle: tr(context, 'cart_empty_hint'),
          action: FastButton(
            label: provider.tr('browse'),
            onPressed: () => provider.navigateToScreen('home'),
            expand: false,
            height: 46,
            kind: FastButtonKind.ink,
          ),
        ),
      );
    }

    // Default selected walk time to restaurant prep time if not initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedWalkTime < rest.pickupPrepTime) {
        setState(() {
          _selectedWalkTime = rest.pickupPrepTime;
        });
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(FASTSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.activeGroupId != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FASTSpace.s16),
              decoration: BoxDecoration(
                color: context.fast.amberSoftBg,
                borderRadius: BorderRadius.circular(FASTRadius.md),
                border: Border.all(color: context.fast.amberSoftBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_outlined, color: context.fast.t1),
                  const SizedBox(width: FASTSpace.s12),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'group_share',
                      ).replaceAll('{n}', provider.activeGroupCode ?? ''),
                      style: FASTText.body.copyWith(
                        color: context.fast.t1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FASTSpace.s24),
          ],
          // Order list Card
          _sectionLabel(tr(context, 'cart_of').replaceAll('{n}', rest.name)),
          const SizedBox(height: FASTSpace.s12),
          _buildCartItemsCard(context, provider, cart),

          const SizedBox(height: FASTSpace.s24),

          if (provider.activeGroupId == null && rest.deliveryEnabled)
            _buildFulfillmentSelector(provider),

          if (provider.fulfillmentType == FulfillmentType.delivery) ...[
            const SizedBox(height: FASTSpace.s24),
            _buildDeliveryAddressSection(provider),
          ] else ...[
            const SizedBox(height: FASTSpace.s24),
            _sectionLabel(tr(context, 'walk_time_title')),
            const SizedBox(height: FASTSpace.s12),
            _buildWalkTimeSelector(context, rest.pickupPrepTime),
          ],

          const SizedBox(height: FASTSpace.s40),

          // Secure payment Form and receipt breakdown
          _isProcessing
              ? _buildProcessingCard()
              : _buildCheckoutFormCard(context, provider),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Small bold section label in the label voice.
  Widget _sectionLabel(String text) {
    return Text(
      fastLabelCase(context, text),
      style: FASTText.label.copyWith(color: context.fast.t3),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: context.fast.card,
      borderRadius: BorderRadius.circular(FASTRadius.md),
      border: Border.all(color: context.fast.line),
    );
  }

  /// Pill chip, ink when selected. Keeps `ChoiceChip` so tap semantics
  /// stay exactly what they were.
  Widget _inkChip({
    required String label,
    required bool selected,
    required ValueChanged<bool>? onSelected,
  }) {
    final fast = context.fast;
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      showCheckmark: false,
      backgroundColor: fast.card,
      selectedColor: fast.ink,
      disabledColor: fast.card,
      labelStyle: FASTText.label.copyWith(
        letterSpacing: 0,
        color: selected ? fast.onInk : fast.t1,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: FASTSpace.s4),
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s8,
        vertical: FASTSpace.s8,
      ),
      shape: const StadiumBorder(),
      side: BorderSide(color: selected ? fast.ink : fast.line),
      onSelected: onSelected,
    );
  }

  Widget _buildCartItemsCard(
    BuildContext context,
    FASTProvider provider,
    List<CartItem> cart,
  ) {
    return Container(
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FASTRadius.md),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cart.length,
          separatorBuilder: (context, index) =>
              Divider(color: context.fast.line, height: 1),
          itemBuilder: (context, index) {
            final item = cart[index];
            return FastSwipeDelete(
              onDelete: () => provider.removeFromCart(item),
              child: Container(
                color: context.fast.card,
                padding: const EdgeInsets.all(FASTSpace.s16),
                child: _buildCartRow(context, provider, item),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartRow(
    BuildContext context,
    FASTProvider provider,
    CartItem item,
  ) {
    final fast = context.fast;
    final image = item.menuItem.image;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            child: FastImage(
              image,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              cacheWidth: 180,
              placeholder: Container(
                width: 56,
                height: 56,
                color: fast.cardHigh,
                alignment: Alignment.center,
                child: Icon(Icons.restaurant, size: 20, color: fast.faint),
              ),
            ),
          ),
          const SizedBox(width: FASTSpace.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.menuItem.name,
                      style: FASTText.item.copyWith(color: fast.t1),
                    ),
                  ),
                  const SizedBox(width: FASTSpace.s12),
                  FastPrice(item.menuItem.price * item.quantity),
                ],
              ),
              if (item.selectedOptions.isNotEmpty) ...[
                const SizedBox(height: FASTSpace.s8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Paid supplements are stored by id; show their name.
                    for (final opt in item.selectedOptions)
                      FastTag(
                        item.menuItem.supplements
                            .where((s) => s.id == opt)
                            .map((s) => s.name)
                            .firstWhere((_) => true, orElse: () => opt),
                      ),
                  ],
                ),
              ],
              if (item.allergyNotes.isNotEmpty) ...[
                const SizedBox(height: FASTSpace.s8),
                Container(
                  padding: const EdgeInsets.all(FASTSpace.s8),
                  decoration: BoxDecoration(
                    color: fast.amberSoftBg,
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    border: Border.all(color: fast.amberSoftBorder),
                  ),
                  child: Text(
                    '« ${item.allergyNotes} »',
                    style: FASTText.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: fast.t1,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: FASTSpace.s4),
              Text(
                tr(
                  context,
                  'each_price',
                ).replaceAll('{n}', item.menuItem.price.toStringAsFixed(2)),
                style: FASTText.caption.copyWith(color: fast.t2),
              ),
              const SizedBox(height: FASTSpace.s12),
              Row(
                children: [
                  // quantity adjustments — min 0 so "minus" at 1 still
                  // goes through updateCartQuantity(item, 0), which
                  // removes the line exactly as before.
                  FastStepper(
                    value: item.quantity,
                    min: 0,
                    max: 1 << 30,
                    size: 36,
                    onChanged: (q) => provider.updateCartQuantity(item, q),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => provider.removeFromCart(item),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: fast.t3, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkTimeSelector(BuildContext context, int minPrepTime) {
    return Container(
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.read<FASTProvider>().tr('walk_time'),
                      style: FASTText.item.copyWith(color: context.fast.t1),
                    ),
                    const SizedBox(height: FASTSpace.s4),
                    Text(
                      context.read<FASTProvider>().tr('walk_sub'),
                      style: FASTText.caption.copyWith(color: context.fast.t2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              FastTag(
                '$_selectedWalkTime MIN',
                kind: FastTagKind.accent,
                icon: Icons.bolt,
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          // Choice chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWalkChip(
                  tr(context, 'asap').replaceAll('{n}', '$minPrepTime'),
                  minPrepTime,
                ),
                const SizedBox(width: FASTSpace.s8),
                _buildWalkChip('+10 min', minPrepTime + 10),
                const SizedBox(width: FASTSpace.s8),
                _buildWalkChip('+20 min', minPrepTime + 20),
                const SizedBox(width: FASTSpace.s8),
                _buildWalkChip('+30 min', minPrepTime + 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentSelector(FASTProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(tr(context, 'pickup_mode_title')),
        const SizedBox(height: FASTSpace.s12),
        Row(
          children: [
            Expanded(
              child: _inkChip(
                label: provider.tr('click_collect'),
                selected: provider.fulfillmentType == FulfillmentType.pickup,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  provider.setFulfillmentType(FulfillmentType.pickup);
                },
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            Expanded(
              // Spec: unavailable choices are disabled, not hidden, so
              // the customer sees the option exists but can't pick it.
              child: Opacity(
                opacity: (provider.selectedRestaurant?.allowDineIn ?? false)
                    ? 1.0
                    : 0.4,
                child: _inkChip(
                  label: provider.tr('dine_in'),
                  selected: provider.fulfillmentType == FulfillmentType.dineIn,
                  onSelected:
                      (provider.selectedRestaurant?.allowDineIn ?? false)
                      ? (_) {
                          HapticFeedback.selectionClick();
                          provider.setFulfillmentType(FulfillmentType.dineIn);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            Expanded(
              child: _inkChip(
                label: provider.tr('delivery'),
                selected: provider.fulfillmentType == FulfillmentType.delivery,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  provider.setFulfillmentType(FulfillmentType.delivery);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveryAddressSection(FASTProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(tr(context, 'delivery_addr_title')),
        const SizedBox(height: FASTSpace.s12),
        TextField(
          controller: _deliveryAddressCtrl,
          style: FASTText.body.copyWith(color: context.fast.t1),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: tr(context, 'addr_example'),
            hintStyle: FASTText.body.copyWith(color: context.fast.t3),
            filled: true,
            fillColor: context.fast.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              borderSide: BorderSide(color: context.fast.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              borderSide: BorderSide(color: context.fast.line),
            ),
          ),
          onChanged: (v) => provider.setDeliveryAddress(v),
        ),
        const SizedBox(height: FASTSpace.s8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _geocodingAddress
                  ? null
                  : () => _useCurrentLocation(provider),
              icon: Icon(Icons.my_location, size: 16, color: context.fast.t1),
              label: Text(
                provider.tr(_geocodingAddress ? 'locating' : 'my_position'),
                style: FASTText.caption.copyWith(
                  color: context.fast.t1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            Expanded(
              child: Text(
                provider
                    .tr('delivery_zone')
                    .replaceAll(
                      '{n}',
                      provider.selectedRestaurant?.deliveryRadiusKm
                              .toStringAsFixed(0) ??
                          '5',
                    ),
                textAlign: TextAlign.end,
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _useCurrentLocation(FASTProvider provider) async {
    setState(() => _geocodingAddress = true);
    try {
      await provider.fetchUserLocation();
      if (!mounted) return;
      final loc = provider.userLocation;
      if (loc == null) {
        provider.showToast('GPS', tr(context, 'no_position'));
        return;
      }
      final places = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (!mounted || places.isEmpty) return;
      final p = places.first;
      final addr = [
        p.street,
        p.postalCode,
        p.locality,
      ].where((e) => e != null && e.isNotEmpty).join(', ');
      _deliveryAddressCtrl.text = addr;
      provider.setDeliveryAddress(
        addr,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
    } catch (e) {
      provider.showToast(tr(context, 'address_lbl'), tr(context, 'geo_error'));
    } finally {
      if (mounted) setState(() => _geocodingAddress = false);
    }
  }

  Widget _buildWalkChip(String label, int minutes) {
    final isSelected = _selectedWalkTime == minutes;
    return _inkChip(
      label: label,
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedWalkTime = minutes;
          });
        }
      },
    );
  }

  Widget _receiptRow(String label, Widget trailing) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: FASTText.body.copyWith(color: context.fast.t2),
          ),
        ),
        const SizedBox(width: FASTSpace.s12),
        trailing,
      ],
    );
  }

  // Secure checkout fields card
  Widget _buildCheckoutFormCard(BuildContext context, FASTProvider provider) {
    final amountStyle = FASTText.price.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: context.fast.t1,
    );
    return Container(
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(tr(context, 'payment_details')),
          const SizedBox(height: FASTSpace.s16),

          // Receipt breakdown
          _receiptRow(
            provider.tr('subtotal'),
            Text(
              '${provider.cartSubtotal.toStringAsFixed(2)} €',
              style: amountStyle,
            ),
          ),
          const SizedBox(height: FASTSpace.s8),
          _receiptRow(
            provider.fulfillmentType == FulfillmentType.delivery
                ? provider.tr('fee_delivery')
                : provider.tr('fee_pickup'),
            provider.fulfillmentType == FulfillmentType.delivery
                ? Text(
                    '${provider.cartDeliveryFee.toStringAsFixed(2)} €',
                    style: amountStyle,
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FASTBrand.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                    ),
                    child: Text(
                      tr(context, 'free_upper'),
                      style: FASTText.label.copyWith(color: FASTBrand.success),
                    ),
                  ),
          ),
          Divider(color: context.fast.line, height: FASTSpace.s24),
          Row(
            children: [
              Expanded(
                child: Text(
                  provider.tr('total'),
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Text(
                '${provider.cartTotal.toStringAsFixed(2)} €',
                style: FASTText.price.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.fast.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s24),

          // Stripe Checkout
          _sectionLabel(tr(context, 'stripe_secure_title')),
          const SizedBox(height: FASTSpace.s8),
          Text(
            tr(context, 'bank_info'),
            style: FASTText.caption.copyWith(color: context.fast.t2),
          ),
          const SizedBox(height: FASTSpace.s24),

          // Place Order Button
          FastButton(
            label: provider
                .tr('pay_stripe')
                .replaceAll('{n}', provider.cartTotal.toStringAsFixed(2)),
            onPressed: () => _startStripeCheckout(provider),
            icon: Icons.shield,
            kind: FastButtonKind.ink,
            fontSize: 14,
          ),
          if (_pendingStripeSessionId != null) ...[
            const SizedBox(height: FASTSpace.s8),
            Center(
              child: TextButton(
                onPressed: () => _confirmStripeCheckout(provider),
                child: Text(
                  provider.tr('confirm_payment'),
                  style: FASTText.caption.copyWith(color: context.fast.t2),
                ),
              ),
            ),
          ],
          const SizedBox(height: FASTSpace.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: context.fast.t3),
              const SizedBox(width: FASTSpace.s4),
              Flexible(
                child: Text(
                  provider.tr('pci'),
                  textAlign: TextAlign.center,
                  style: FASTText.caption.copyWith(color: context.fast.t3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s24,
        vertical: FASTSpace.s40,
      ),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(FASTBrand.gold),
            ),
          ),
          const SizedBox(height: FASTSpace.s24),
          Text(
            _processStep,
            style: FASTText.label.copyWith(color: context.fast.t1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FASTSpace.s8),
          Text(
            tr(context, 'securing_tokens'),
            style: FASTText.caption.copyWith(color: context.fast.t3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _startStripeCheckout(FASTProvider provider) async {
    if (provider.fulfillmentType == FulfillmentType.delivery) {
      final addr = provider.deliveryAddress.trim();
      if (addr.isEmpty) {
        provider.showToast(
          tr(context, 'addr_required'),
          tr(context, 'addr_enter'),
        );
        return;
      }
      if (provider.deliveryLatitude == null ||
          provider.deliveryLongitude == null) {
        setState(() => _geocodingAddress = true);
        try {
          final locations = await locationFromAddress(addr);
          if (!mounted) return;
          if (locations.isEmpty) {
            provider.showToast(
              tr(context, 'address_lbl'),
              tr(context, 'addr_notfound'),
            );
            return;
          }
          provider.setDeliveryAddress(
            addr,
            latitude: locations.first.latitude,
            longitude: locations.first.longitude,
          );
        } catch (_) {
          provider.showToast(
            tr(context, 'address_lbl'),
            tr(context, 'addr_nolocate'),
          );
          return;
        } finally {
          if (mounted) setState(() => _geocodingAddress = false);
        }
      }
    }

    setState(() {
      _isProcessing = true;
      _processStep = tr(context, 'creating_payment');
    });

    try {
      final rest = provider.selectedRestaurant!;
      if (!rest.paymentsReady) {
        provider.showToast(
          tr(context, 'payment_fail'),
          tr(context, 'restaurant_not_connected'),
        );
        return;
      }
      final items = provider.cart
          .map(
            (c) => {
              'menuItemId': c.menuItem.id,
              'quantity': c.quantity,
              'selectedOptions': c.selectedOptions,
              'allergyNotes': c.allergyNotes,
            },
          )
          .toList();
      if (provider.activeGroupId != null) {
        await provider.syncGroupCartToServer();
        await _groupService.updateMyPart(
          provider.activeGroupId!,
          itemsCount: provider.cartCount,
          total: provider.cartTotal,
          isReady: true,
        );
      }
      // Native PaymentSheet first — returns false when the native SDK
      // isn't usable (no publishable key / old backend), keeping the
      // hosted Checkout page as the automatic fallback.
      if (await _payWithPaymentSheet(provider, rest, items)) return;
      final session = await _paymentService.createCheckoutSession(
        restaurantId: rest.id,
        items: items,
        userWalkTimeMin: _selectedWalkTime,
        groupId: provider.activeGroupId,
        fulfillmentType: provider.fulfillmentType,
        deliveryAddress: provider.deliveryAddress,
        deliveryLatitude: provider.deliveryLatitude,
        deliveryLongitude: provider.deliveryLongitude,
      );
      _pendingStripeSessionId = session.sessionId;
      await FASTProvider.savePendingStripeSession(session.sessionId);
      if (mounted) setState(() {});
      final launched = await launchUrl(
        Uri.parse(session.url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        provider.showToast('Stripe', tr(context, 'stripe_open_fail'));
      }
    } catch (e) {
      if (mounted) {
        provider.showToast(tr(context, 'payment_fail'), e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStep = '';
        });
      }
    }
  }

  /// Native Stripe PaymentSheet — the whole payment stays inside the
  /// app. Returns false only when native payment can't run at all, so
  /// the caller can fall back to the hosted Checkout session.
  Future<bool> _payWithPaymentSheet(
    FASTProvider provider,
    Restaurant rest,
    List<Map<String, dynamic>> items,
  ) async {
    StripePaymentConfig config;
    try {
      config = await _paymentService.getPaymentConfig();
    } catch (_) {
      return false;
    }
    if (config.publishableKey.isEmpty) return false;
    Stripe.publishableKey = config.publishableKey;
    if (config.applePayMerchantId != null) {
      Stripe.merchantIdentifier = config.applePayMerchantId!;
    }

    StripePaymentIntent intent;
    try {
      intent = await _paymentService.createPaymentIntent(
        restaurantId: rest.id,
        items: items,
        userWalkTimeMin: _selectedWalkTime,
        groupId: provider.activeGroupId,
        fulfillmentType: provider.fulfillmentType,
        deliveryAddress: provider.deliveryAddress,
        deliveryLatitude: provider.deliveryLatitude,
        deliveryLongitude: provider.deliveryLongitude,
      );
    } on PaymentSheetUnavailable {
      return false;
    }
    // Persisted so an app-kill mid-sheet still creates the order on the
    // next resume (the payment_intent.succeeded webhook is the durable
    // path — this only makes recovery instant).
    await FASTProvider.savePendingStripeIntent(intent.paymentIntentId);

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          customerId: intent.customerId,
          customerEphemeralKeySecret: intent.ephemeralKeySecret,
          merchantDisplayName: 'FAST',
          applePay: config.applePayMerchantId != null
              ? PaymentSheetApplePay(
                  merchantCountryCode: config.merchantCountryCode,
                )
              : null,
          googlePay: config.googlePayEnabled
              ? PaymentSheetGooglePay(
                  merchantCountryCode: config.merchantCountryCode,
                  testEnv: config.googlePayTestEnv,
                )
              : null,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return true;
      if (mounted) {
        provider.showToast(
          tr(context, 'payment_fail'),
          e.error.localizedMessage ?? e.error.message ?? e.toString(),
        );
      }
      return true;
    } catch (_) {
      return false; // native SDK failure — fall back to the web session
    }
    if (!mounted) return true;
    final ok = await provider.confirmStripeIntent(intent.paymentIntentId);
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      provider.navigateToScreen('commandes');
    }
    return true;
  }

  Future<void> _confirmStripeCheckout(FASTProvider provider) async {
    final sessionId = _pendingStripeSessionId;
    if (sessionId == null) return;
    setState(() {
      _isProcessing = true;
      _processStep = 'CONFIRMATION DU PAIEMENT...';
    });

    try {
      final ok = await provider.confirmStripeCheckout(sessionId);
      if (ok && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _pendingStripeSessionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        provider.showToast(
          tr(context, 'payment_unconfirmed'),
          tr(context, 'finish_stripe'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStep = '';
        });
      }
    }
  }
}
