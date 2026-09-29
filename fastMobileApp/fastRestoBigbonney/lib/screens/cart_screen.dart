// lib/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import '../provider.dart';
import '../models.dart';
import '../services/payment_service.dart';
import '../services/group_service.dart';
import '../theme.dart';

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
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ Text('🛒', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12), Text(
                'Votre panier est vide',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.fast.t1),
              ),
                    SizedBox(height: 6), Text(
                'Ajoutez de bons plats d\'un restaurant local pour passer commande !',
                style: TextStyle(fontSize: 11, color: context.fast.t2),
                textAlign: TextAlign.center,
              ),
                    SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.navigateToScreen('home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: FASTBrand.onAmber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Parcourir les restaurants', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.activeGroupId != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [ Icon(Icons.groups_outlined, color: Color(0xFFF59E0B)),
                        SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Part individuelle du groupe ${provider.activeGroupCode ?? ''}\nVous paierez uniquement vos articles.',
                      style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Order list Card
 Text(
            'PANIER DE ${rest.name.toUpperCase()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: context.fast.t3,
            ),
          ),
                SizedBox(height: 12),
          _buildCartItemsCard(context, provider, cart),
          
                SizedBox(height: 20),

          if (provider.activeGroupId == null && rest.deliveryEnabled)
            _buildFulfillmentSelector(provider),

          if (provider.fulfillmentType == FulfillmentType.delivery) ...[
            const SizedBox(height: 16),
            _buildDeliveryAddressSection(provider),
          ] else ...[
                  SizedBox(height: 20), Text(
              'CHOISIR LE TEMPS DE MARCHE ESTIMÉ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: context.fast.t3,
              ),
            ),
            const SizedBox(height: 12),
            _buildWalkTimeSelector(context, rest.pickupPrepTime),
          ],

          const SizedBox(height: 20),

          // Secure payment Form and receipt breakdown
          _isProcessing
              ? _buildProcessingCard()
              : _buildCheckoutFormCard(context, provider),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCartItemsCard(BuildContext context, FASTProvider provider, List<CartItem> cart) {
    return Container(
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fast.line),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics:       NeverScrollableScrollPhysics(),
        itemCount: cart.length,
        separatorBuilder: (context, index) =>       Divider(color: context.fast.line, height: 1),
        itemBuilder: (context, index) {
          final item = cart[index];
          return Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [ Text(
                        item.menuItem.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.fast.t1),
                      ),
                      if (item.selectedOptions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.selectedOptions.map((opt) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                            ),
                            child: Text(opt, style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B))),
                          )).toList(),
                        ),
                      ],
                      if (item.allergyNotes.isNotEmpty) ...[
                              SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.fast.amberSoftBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.fast.amberSoftBorder),
                          ),
                          child: Text(
                            '« ${item.allergyNotes} »',
                            style: const TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                            SizedBox(height: 6), Text(
                        '${item.menuItem.price.toStringAsFixed(2)} € chacun',
                        style: TextStyle(fontSize: 11, color: context.fast.t2),
                      ),
                    ],
                  ),
                ),
                      SizedBox(width: 12),
                Row(
                  children: [
                    // quantity adjustments
                    Container(
                      decoration: BoxDecoration(
                        color: FASTBrand.onAmber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => provider.updateCartQuantity(item.menuItem.id, item.quantity - 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ), Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                          ),
                          GestureDetector(
                            onTap: () => provider.updateCartQuantity(item.menuItem.id, item.quantity + 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text('+', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8), IconButton(
                      onPressed: () => provider.removeFromCart(item.menuItem.id),
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalkTimeSelector(BuildContext context, int minPrepTime) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Text(
                      'Temps de trajet à pied',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.fast.t1),
                    ),
                    const SizedBox(height: 2), Text(
                      'Préparation synchronisée basée sur votre rythme de marche.',
                      style: TextStyle(fontSize: 10, color: const Color(0xFFF59E0B).withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⚡ $_selectedWalkTime MIN',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Choice chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWalkChip('DÈS QUE POSS. (${minPrepTime}m)', minPrepTime),
                const SizedBox(width: 8),
                _buildWalkChip('+10 min', minPrepTime + 10),
                const SizedBox(width: 8),
                _buildWalkChip('+20 min', minPrepTime + 20),
                const SizedBox(width: 8),
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
      children: [ Text(
          'MODE DE RÉCUPÉRATION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: context.fast.t3),
        ),
              SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text('Click & Collect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                selected: provider.fulfillmentType == FulfillmentType.pickup,
                selectedColor: Color(0xFFF59E0B),
                backgroundColor: context.fast.card,
                labelStyle: TextStyle(
                  color: provider.fulfillmentType == FulfillmentType.pickup ? FASTBrand.onAmber : context.fast.t1,
                ),
                onSelected: (_) => provider.setFulfillmentType(FulfillmentType.pickup),
              ),
            ),
                  SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text('Livraison', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                selected: provider.fulfillmentType == FulfillmentType.delivery,
                selectedColor: Color(0xFF10B981),
                backgroundColor: context.fast.card,
                labelStyle: TextStyle(
                  color: provider.fulfillmentType == FulfillmentType.delivery ? Colors.white : context.fast.t1,
                ),
                onSelected: (_) => provider.setFulfillmentType(FulfillmentType.delivery),
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
      children: [ Text(
          'ADRESSE DE LIVRAISON',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: context.fast.t3),
        ),
              SizedBox(height: 10), TextField(
          controller: _deliveryAddressCtrl,
          style: TextStyle(color: context.fast.t1, fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: '12 rue Example, 75001 Paris',
            hintStyle: TextStyle(color: context.fast.t3),
            filled: true,
            fillColor: context.fast.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.fast.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.fast.line)),
          ),
          onChanged: (v) => provider.setDeliveryAddress(v),
        ),
              SizedBox(height: 8),
        Row(
          children: [ TextButton.icon(
              onPressed: _geocodingAddress ? null : () => _useCurrentLocation(provider),
              icon: const Icon(Icons.my_location, size: 16, color: Color(0xFF10B981)),
              label: Text(
                _geocodingAddress ? 'Localisation…' : 'Ma position',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
              ),
            ),
                  Spacer(), Text(
              'Zone ${provider.selectedRestaurant?.deliveryRadiusKm.toStringAsFixed(0) ?? '5'} km',
              style: TextStyle(fontSize: 10, color: context.fast.t3),
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
      final loc = provider.userLocation;
      if (loc == null) {
        provider.showToast('GPS', 'Impossible d\'obtenir votre position.');
        return;
      }
      final places = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (places.isEmpty) return;
      final p = places.first;
      final addr = [p.street, p.postalCode, p.locality].where((e) => e != null && e.isNotEmpty).join(', ');
      _deliveryAddressCtrl.text = addr;
      provider.setDeliveryAddress(addr, latitude: loc.latitude, longitude: loc.longitude);
    } catch (e) {
      provider.showToast('Adresse', 'Erreur de géolocalisation.');
    } finally {
      if (mounted) setState(() => _geocodingAddress = false);
    }
  }

  Widget _buildWalkChip(String label, int minutes) {
    final isSelected = _selectedWalkTime == minutes;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      selected: isSelected,
      backgroundColor: context.fast.card,
      selectedColor: Color(0xFFF59E0B),
      checkmarkColor: FASTBrand.onAmber,
      labelStyle: TextStyle(color: isSelected ? FASTBrand.onAmber : context.fast.t1),
      side: BorderSide(color: isSelected ?       Color(0xFFF59E0B) : context.fast.line),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedWalkTime = minutes;
          });
        }
      },
    );
  }

  // Secure checkout fields card
  Widget _buildCheckoutFormCard(BuildContext context, FASTProvider provider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ Text(
              'DÉTAILS DU PAIEMENT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: context.fast.t3,
              ),
            ),
                  SizedBox(height: 12),
            
            // Receipt breakdown
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.fast.cardHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [ Text('Sous-total du panier', style: TextStyle(fontSize: 12, color: context.fast.t2)), Text('${provider.cartSubtotal.toStringAsFixed(2)} €', style: TextStyle(fontSize: 12, color: context.fast.t1, fontFamily: 'monospace')),
                    ],
                  ),
                        SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [ Text(
                        provider.fulfillmentType == FulfillmentType.delivery
                            ? 'Frais de livraison'
                            : 'Frais de retrait',
                        style: TextStyle(fontSize: 12, color: context.fast.t2),
                      ),
                      if (provider.fulfillmentType == FulfillmentType.delivery)
 Text(
                          '${provider.cartDeliveryFee.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 12, color: context.fast.t1, fontFamily: 'monospace'),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('GRATUIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ),
                    ],
                  ),
                        SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [ Text('Frais de service fixes', style: TextStyle(fontSize: 12, color: context.fast.t2)), Text('${provider.flatServiceFee.toStringAsFixed(2)} €', style: TextStyle(fontSize: 12, color: context.fast.t1, fontFamily: 'monospace')),
                    ],
                  ),
                        Divider(color: context.fast.line, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [ Text('Montant total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.fast.t1)), Text('${provider.cartTotal.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B), fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
            ),
                  SizedBox(height: 16),
            
            // Stripe Checkout
 Text(
              'PAIEMENT SÉCURISÉ STRIPE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: context.fast.t3,
              ),
            ),
                  SizedBox(height: 12), Text(
              'Les informations bancaires sont saisies directement chez Stripe. FAST ne stocke jamais les numéros de carte.',
              style: TextStyle(fontSize: 11, color: context.fast.t2, height: 1.35),
            ),
                  SizedBox(height: 20),

            // Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startStripeCheckout(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: FASTBrand.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield, size: 16),
                    const SizedBox(width: 8), Text(
                      'Payer ${provider.cartTotal.toStringAsFixed(2)} € avec Stripe',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            if (_pendingStripeSessionId != null) ...[
                    SizedBox(height: 8), TextButton(
                onPressed: () => _confirmStripeCheckout(provider),
                child: Text(
                  'Paiement non détecté ? Confirmer manuellement',
                  style: TextStyle(color: context.fast.t3, fontSize: 11),
                ),
              ),
            ],
                  SizedBox(height: 10),
                  Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Icon(Icons.lock_outline, size: 12, color: context.fast.t3),
                  SizedBox(width: 4), Text(
                    'Connexion sécurisée PCI-DSS active',
                    style: TextStyle(fontSize: 9, color: context.fast.t3, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
                SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
                SizedBox(height: 20), Text(
            _processStep,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: context.fast.t1, fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
                SizedBox(height: 6), Text(
            'Sécurisation des jetons d\'autorisation...',
            style: TextStyle(fontSize: 10, color: context.fast.t3),
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
        provider.showToast('Adresse requise', 'Saisissez une adresse de livraison.');
        return;
      }
      if (provider.deliveryLatitude == null || provider.deliveryLongitude == null) {
        setState(() => _geocodingAddress = true);
        try {
          final locations = await locationFromAddress(addr);
          if (locations.isEmpty) {
            provider.showToast('Adresse', 'Adresse introuvable — précisez ville et code postal.');
            return;
          }
          provider.setDeliveryAddress(addr, latitude: locations.first.latitude, longitude: locations.first.longitude);
        } catch (_) {
          provider.showToast('Adresse', 'Impossible de géolocaliser cette adresse.');
          return;
        } finally {
          if (mounted) setState(() => _geocodingAddress = false);
        }
      }
    }

    setState(() {
      _isProcessing = true;
      _processStep = 'CRÉATION DU PAIEMENT STRIPE...';
    });

    try {
      final rest = provider.selectedRestaurant!;
      final items = provider.cart
          .map((c) => {
                'menuItemId': c.menuItem.id,
                'quantity': c.quantity,
                'selectedOptions': c.selectedOptions,
                'allergyNotes': c.allergyNotes,
              })
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
        provider.showToast('Stripe', 'Impossible d’ouvrir la page de paiement.');
      }
    } catch (e) {
      if (mounted) provider.showToast('Paiement impossible', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStep = '';
        });
      }
    }
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
        setState(() {
          _pendingStripeSessionId = null;
        });
      }
    } catch (e) {
      if (mounted) provider.showToast('Paiement non confirmé', 'Terminez le paiement Stripe puis réessayez.');
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
