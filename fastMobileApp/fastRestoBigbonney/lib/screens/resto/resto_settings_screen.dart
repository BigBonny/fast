import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../resto_provider.dart';
import '../../provider.dart';
import '../../models.dart';
import '../../providers/auth_provider.dart';
import '../../services/restaurant_service.dart';
import '../../services/payment_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';
import '../../widgets/fast_ui.dart';

class RestoSettingsScreen extends StatefulWidget {
  const RestoSettingsScreen({super.key});

  @override
  State<RestoSettingsScreen> createState() => _RestoSettingsScreenState();
}

class _RestoSettingsScreenState extends State<RestoSettingsScreen>
    with WidgetsBindingObserver {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ownerDobCtrl = TextEditingController();
  final _ownerAddrCtrl = TextEditingController();
  // Weekly hours — open/close text fields per day; closed days are
  // stored as "closed" so the state survives a save/load round-trip.
  final Map<int, TextEditingController> _openCtrls = {
    for (var d = 1; d <= 7; d++) d: TextEditingController(),
  };
  final Map<int, TextEditingController> _closeCtrls = {
    for (var d = 1; d <= 7; d++) d: TextEditingController(),
  };
  final Set<int> _closedDays = {};

  final ImagePicker _picker = ImagePicker();
  String _imageBase64 = '';

  double _normalPrepTime = 15;
  double _rushPrepTime = 25;
  List<String> _selectedDietary = [];
  bool _allowDineIn = false;
  bool _reservationsEnabled = false;
  bool _reservationOnly = false;
  final _dineInFeeCtrl = TextEditingController(text: '0');
  final _seatingCtrl = TextEditingController(text: '0');

  // Catégories personnalisées ("Autre…") + mode food truck
  final _customCategoryCtrl = TextEditingController();
  bool _isFoodTruck = false;
  // Une adresse par jour de semaine (1 = lundi … 7 = dimanche).
  final Map<int, TextEditingController> _truckDayCtrls = {
    for (var d = 1; d <= 7; d++) d: TextEditingController(),
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _restaurantId;

  final _paymentService = PaymentService();
  Map<String, dynamic>? _connectStatus;
  bool _connectLoading = false;

  static const _dietaryAll = [
    'VEGAN',
    'VEGETARIAN',
    'GLUTEN_FREE',
    'HALAL',
    'KETO',
    'DAIRY_FREE',
  ];

  // Same list as the client app's category strip — multi-select.
  static const _categories = [
    'Burgers',
    'Tacos',
    'Kebab',
    'Pizza',
    'Poulet',
    'Sandwichs',
    'Fast-food',
    'Hot-dogs',
    'Sushi',
    'Poke',
    'Chinois',
    'Vietnamien',
    'Indien',
    'Thaïlandais',
    'Coréen',
    'Mexicain',
    'Italien',
    'Grec',
    'Cuisine du monde',
    'Grillades & Viandes',
    'Poisson & Fruits de mer',
    'Vegan & Végétarien',
    'Halal',
    'Boulangerie',
    'Sandwicherie',
    'Crêpes & Gaufres',
    'Desserts',
    'Glaces',
    'Bubble Tea',
    'Café',
    'Brasserie',
    'Restaurant traditionnel',
    'Restaurant gastronomique',
    'Buffet',
    'Cuisine méditerranéenne',
    'Cuisine africaine',
    'Cuisine antillaise & créole',
    'Autres',
  ];
  Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromBackend();
    _loadConnectStatus();
  }

  /// Returning from the in-app Stripe onboarding webview re-syncs the
  /// Connect status so the badge updates without reopening the screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadConnectStatus();
  }

  Future<void> _loadConnectStatus() async {
    setState(() => _connectLoading = true);
    try {
      final status = await _paymentService.getConnectStatus();
      if (mounted) setState(() => _connectStatus = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _configureStripeConnect() async {
    setState(() => _connectLoading = true);
    try {
      final link = await _paymentService.createConnectAccountLink();
      final url = link['url'] as String?;
      if (url != null) {
        // In-app webview — the owner stays inside FAST while completing
        // Stripe onboarding. On finish, Stripe hits our return page which
        // deep-links back here and the resume hook re-syncs the status.
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
      } else if (mounted) {
        // Test mode: backend connected the account via API — no hosted flow.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              link['connected'] == true
                  ? tr(context, 'stripe_active')
                  : tr(context, 'stripe_pending'),
            ),
          ),
        );
      }
      await _loadConnectStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'stripe_err').replaceAll('{n}', '$e')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _loadFromBackend() async {
    try {
      final svc = RestaurantService();
      final data = await svc.getMyRestaurant();
      if (!mounted) return;
      setState(() {
        _restaurantId = data['id'] as String?;
        _nameCtrl.text = data['name'] as String? ?? '';
        _descCtrl.text = data['description'] as String? ?? '';
        _cuisineCtrl.text = data['cuisineType'] as String? ?? '';
        _categoryCtrl.text = data['category'] as String? ?? '';
        _selectedCategories = (data['category'] as String? ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        _cityCtrl.text = data['city'] as String? ?? '';
        _addressCtrl.text = data['address'] as String? ?? '';
        _ibanCtrl.text = data['managerIban'] as String? ?? '';
        _siretCtrl.text = data['siret'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _ownerDobCtrl.text = data['ownerBirthDate'] as String? ?? '';
        _ownerAddrCtrl.text = data['ownerAddress'] as String? ?? '';
        final hours = data['openingHours'] as Map<String, dynamic>? ?? {};
        for (var d = 1; d <= 7; d++) {
          final s = '${hours['$d'] ?? ''}';
          if (s == 'closed') {
            _closedDays.add(d);
          } else if (s.contains('-')) {
            final parts = s.split('-');
            _openCtrls[d]!.text = parts[0];
            _closeCtrls[d]!.text = parts.length > 1 ? parts[1] : '';
          }
        }
        _imageBase64 = data['image'] as String? ?? '';
        _normalPrepTime = ((data['normalPrepTime'] as num?)?.toDouble()) ?? 15;
        _rushPrepTime = ((data['rushPrepTime'] as num?)?.toDouble()) ?? 25;
        final opts = data['dietaryOptions'] as List<dynamic>? ?? [];
        _selectedDietary = opts
            .map((e) {
              if (e is String) return e;
              if (e is Map<String, dynamic>) {
                return e['option'] as String? ?? '';
              }
              return '';
            })
            .where((s) => s.isNotEmpty)
            .toList();
        _allowDineIn = data['allowDineIn'] as bool? ?? false;
        _reservationsEnabled = data['reservationsEnabled'] as bool? ?? false;
        _reservationOnly = data['reservationOnly'] as bool? ?? false;
        _dineInFeeCtrl.text =
            ((data['dineInFee'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
        _seatingCtrl.text = '${(data['seatingCapacity'] as num?)?.toInt() ?? 0}';
        _isFoodTruck = data['isFoodTruck'] as bool? ?? false;
        final stops = data['truckStops'] as List<dynamic>? ?? [];
        for (final s in stops) {
          final m = s as Map<String, dynamic>;
          final day = (m['dayOfWeek'] as num?)?.toInt() ?? 0;
          if (day >= 1 && day <= 7) {
            final parts = [
              m['label'] as String? ?? '',
              m['address'] as String? ?? '',
              m['city'] as String? ?? '',
            ].where((p) => p.isNotEmpty);
            _truckDayCtrls[day]!.text = parts.join(', ');
          }
        }
        _loading = false;
      });
    } catch (e) {
      // Fall back to locally cached settings
      if (!mounted) return;
      final cached = Provider.of<RestoProvider>(
        context,
        listen: false,
      ).settings;
      setState(() {
        _restaurantId = cached?.id;
        _nameCtrl.text = cached?.name ?? '';
        _descCtrl.text = cached?.description ?? '';
        _cuisineCtrl.text = cached?.cuisineType ?? '';
        _categoryCtrl.text = cached?.category ?? '';
        _selectedCategories = (cached?.category ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        _cityCtrl.text = cached?.city ?? '';
        _addressCtrl.text = cached?.address ?? '';
        _ibanCtrl.text = cached?.managerIban ?? '';
        _imageBase64 = cached?.image ?? '';
        _normalPrepTime = (cached?.normalPrepTime ?? 15).toDouble();
        _rushPrepTime = (cached?.rushPrepTime ?? 25).toDouble();
        _selectedDietary = cached?.dietaryOptions ?? [];
        _loading = false;
        _error = tr(context, 'load_fallback');
      });
    }
  }

  Future<void> _save() async {
    if (_restaurantId == null) {
      setState(() => _error = tr(context, 'no_resto_found'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'cuisineType': _cuisineCtrl.text.trim(),
      'category': _selectedCategories.join(', '),
      'city': _cityCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'managerIban': _ibanCtrl.text.trim(),
      'siret': _siretCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'ownerBirthDate': _ownerDobCtrl.text.trim(),
      'ownerAddress': _ownerAddrCtrl.text.trim(),
      'openingHours': {
        for (var d = 1; d <= 7; d++)
          if (_closedDays.contains(d))
            '$d': 'closed'
          else if (_openCtrls[d]!.text.trim().isNotEmpty &&
              _closeCtrls[d]!.text.trim().isNotEmpty)
            '$d':
                '${_openCtrls[d]!.text.trim()}-${_closeCtrls[d]!.text.trim()}',
      },
      if (_imageBase64.isNotEmpty) 'image': _imageBase64,
      'normalPrepTime': _normalPrepTime.round(),
      'rushPrepTime': _rushPrepTime.round(),
      'dietaryOptions': _selectedDietary,
      'allowDineIn': _allowDineIn,
      'reservationsEnabled': _reservationsEnabled,
      'reservationOnly': _reservationOnly,
      'dineInFee': double.tryParse(_dineInFeeCtrl.text.trim()) ?? 0,
      'seatingCapacity': int.tryParse(_seatingCtrl.text.trim()) ?? 0,
      'isFoodTruck': _isFoodTruck,
      'truckStops': _isFoodTruck
          ? [
              for (var d = 1; d <= 7; d++)
                if (_truckDayCtrls[d]!.text.trim().isNotEmpty)
                  {'dayOfWeek': d, 'address': _truckDayCtrls[d]!.text.trim()},
            ]
          : <Map<String, dynamic>>[],
    };

    try {
      final svc = RestaurantService();
      await svc.updateRestaurant(_restaurantId!, body);

      // Update local cache
      if (!mounted) return;
      final provider = Provider.of<RestoProvider>(context, listen: false);
      await provider.updateSettings(
        RestaurantSettings(
          id: _restaurantId,
          managerFirstName: provider.settings?.managerFirstName ?? '',
          managerPhone: provider.settings?.managerPhone ?? '',
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          cuisineType: _cuisineCtrl.text.trim(),
          category: _selectedCategories.join(', '),
          city: _cityCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          managerIban: _ibanCtrl.text.trim(),
          image: _imageBase64,
          normalPrepTime: _normalPrepTime.round(),
          rushPrepTime: _rushPrepTime.round(),
          dietaryOptions: _selectedDietary,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Text(
            tr(context, 'profile_updated'),
            style: TextStyle(
              color: context.fast.t1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } catch (e) {
      setState(
        () =>
            _error = tr(context, 'error_colon').replaceAll('{n}', e.toString()),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCustomCategory() {
    final v = _customCategoryCtrl.text.trim();
    if (v.isEmpty) return;
    final label = v[0].toUpperCase() + v.substring(1);
    setState(() {
      _selectedCategories.add(label);
      _customCategoryCtrl.clear();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cuisineCtrl.dispose();
    _categoryCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _ibanCtrl.dispose();
    _dineInFeeCtrl.dispose();
    _seatingCtrl.dispose();
    _customCategoryCtrl.dispose();
    for (final c in _truckDayCtrls.values) {
      c.dispose();
    }
    _siretCtrl.dispose();
    _phoneCtrl.dispose();
    _ownerDobCtrl.dispose();
    _ownerAddrCtrl.dispose();
    for (final c in _openCtrls.values) {
      c.dispose();
    }
    for (final c in _closeCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C8B3)),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        Text(
          tr(context, 'profil_resto'),
          style: TextStyle(
            color: context.fast.t1,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          tr(context, 'visible_clients'),
          style: TextStyle(color: context.fast.t2, fontSize: 13),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],

        SizedBox(height: 24),
        _section(tr(context, 'customization')),
        _buildThemePicker(),

        SizedBox(height: 24),
        _section(tr(context, 'stripe_payments')),
        _buildStripeConnectBanner(),
        SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _connectLoading ? null : _configureStripeConnect,
          icon: const Icon(Icons.account_balance),
          label: Text(tr(context, 'stripe_connect')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00C8B3),
            side: const BorderSide(color: Color(0xFF00C8B3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        SizedBox(height: 24),
        _section(tr(context, 'cover_image')),
        _buildImagePicker(),

        SizedBox(height: 24),
        _section(tr(context, 'identity')),
        _field(tr(context, 'resto_name_lbl'), _nameCtrl),
        _field(
          tr(context, 'description'),
          _descCtrl,
          maxLines: 3,
          hint: tr(context, 'desc_hint'),
        ),

        SizedBox(height: 24),
        _section(tr(context, 'contact_bank')),
        _field(tr(context, 'city'), _cityCtrl),
        _field(
          tr(context, 'full_address'),
          _addressCtrl,
          hint: tr(context, 'addr_example'),
        ),
        _field('IBAN', _ibanCtrl, hint: 'FR76 **** **** **** **** 1234'),

        SizedBox(height: 24),
        _section(tr(context, 'legal_identity')),
        Text(
          tr(context, 'identity_help'),
          style: TextStyle(color: context.fast.t3, fontSize: 11, height: 1.4),
        ),
        SizedBox(height: 12),
        _field(tr(context, 'siret_lbl'), _siretCtrl, hint: '123 456 789 00012'),
        _field(tr(context, 'phone_lbl'), _phoneCtrl, hint: '06 12 34 56 78'),
        _field(
          tr(context, 'owner_dob_lbl'),
          _ownerDobCtrl,
          hint: '15/03/1985',
          keyboard: TextInputType.datetime,
        ),
        _field(
          tr(context, 'owner_addr_lbl'),
          _ownerAddrCtrl,
          hint: '10 Rue de la Paix, 75001 Paris',
        ),
        SizedBox(height: 8),
        Text(
          tr(context, 'opening_hours'),
          style: TextStyle(
            color: context.fast.t2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        _hoursEditor(),

        SizedBox(height: 24),
        _section(tr(context, 'cuisine_category')),
        _field(
          tr(context, 'cuisine_type'),
          _cuisineCtrl,
          hint: tr(context, 'cuisine_example'),
        ),
        SizedBox(height: 12),
        Text(
          tr(context, 'categories_multi'),
          style: TextStyle(
            color: context.fast.t2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._categories.map((c) {
              final sel = _selectedCategories.contains(c);
              return FilterChip(
                label: Text(
                  catLabel(context, c),
                  style: TextStyle(
                    fontSize: 12,
                    color: sel ? Colors.white : context.fast.t2,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                selected: sel,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedCategories.add(c);
                  } else {
                    _selectedCategories.remove(c);
                  }
                }),
                selectedColor: const Color(0xFF00C8B3),
                backgroundColor: context.fast.card,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: sel ? const Color(0xFF00C8B3) : context.fast.faint,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
            // Custom categories saved via the "Autres" bar below.
            ..._selectedCategories
                .where((c) => !_categories.contains(c))
                .map(
                  (c) => InputChip(
                    label: Text(
                      c,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    selected: true,
                    selectedColor: const Color(0xFF00C8B3),
                    backgroundColor: context.fast.card,
                    deleteIconColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF00C8B3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onDeleted: () =>
                        setState(() => _selectedCategories.remove(c)),
                  ),
                ),
          ],
        ),
        // La petite barre apparaît quand "Autres" est sélectionné.
        if (_selectedCategories.contains('Autres')) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCategoryCtrl,
                  style: TextStyle(color: context.fast.t1, fontSize: 13),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: tr(context, 'custom_category_hint'),
                    hintStyle: TextStyle(color: context.fast.t3, fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: context.fast.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.fast.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.fast.line),
                    ),
                  ),
                  onSubmitted: (_) => _addCustomCategory(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C8B3),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(tr(context, 'add')),
              ),
            ],
          ),
        ],

        SizedBox(height: 24),
        _section(tr(context, 'dietary_options')),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietaryAll.map((key) {
            final selected = _selectedDietary.contains(key);
            return FilterChip(
              label: Text(
                tr(context, 'diet_${key.toLowerCase().replaceAll('_', '')}'),
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? context.fast.bg : context.fast.t2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedDietary = [..._selectedDietary, key];
                  } else {
                    _selectedDietary = _selectedDietary
                        .where((k) => k != key)
                        .toList();
                  }
                });
              },
              selectedColor: Color(0xFF00C8B3),
              backgroundColor: context.fast.card,
              checkmarkColor: FASTBrand.onAmber,
              side: BorderSide(
                color: selected ? Color(0xFF00C8B3) : context.fast.faint,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 24),
        _section(tr(context, 'prep_time_title')),
        _timeSlider(
          tr(context, 'normal_time'),
          _normalPrepTime,
          5,
          60,
          const Color(0xFF00C8B3),
          (v) => setState(() => _normalPrepTime = v),
        ),
        SizedBox(height: 20),
        _timeSlider(
          tr(context, 'rush_time'),
          _rushPrepTime,
          10,
          90,
          const Color(0xFFEF4444),
          (v) => setState(() => _rushPrepTime = v),
        ),

        SizedBox(height: 24),
        _section(tr(context, 'service_modes')),
        FastSwitchTile(
          title: Text(
            tr(context, 'food_truck'),
            style: TextStyle(color: context.fast.t1, fontSize: 13),
          ),
          subtitle: Text(
            tr(context, 'food_truck_sub'),
            style: TextStyle(color: context.fast.t3, fontSize: 11),
          ),
          value: _isFoodTruck,
          onChanged: (v) => setState(() => _isFoodTruck = v),
        ),
        if (_isFoodTruck) ...[
          const SizedBox(height: 8),
          Text(
            tr(context, 'truck_schedule_hint'),
            style: TextStyle(color: context.fast.t3, fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      tr(context, 'day_$d'),
                      style: TextStyle(
                        color: context.fast.t2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _truckDayCtrls[d],
                      style: TextStyle(color: context.fast.t1, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: tr(context, 'truck_stop_hint'),
                        hintStyle: TextStyle(
                          color: context.fast.t3,
                          fontSize: 12,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: context.fast.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.fast.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.fast.line),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        FastSwitchTile(
          title: Text(
            tr(context, 'dine_in'),
            style: TextStyle(color: context.fast.t1, fontSize: 13),
          ),
          value: _allowDineIn,
          onChanged: (v) => setState(() => _allowDineIn = v),
        ),
        if (_allowDineIn)
          _field(
            'Frais sur place (€)',
            _dineInFeeCtrl,
            hint: '0.00',
          ),
        FastSwitchTile(
          title: Text(
            tr(context, 'reservations'),
            style: TextStyle(color: context.fast.t1, fontSize: 13),
          ),
          value: _reservationsEnabled,
          onChanged: (v) => setState(() {
            _reservationsEnabled = v;
            if (!v) _reservationOnly = false;
          }),
        ),
        if (_reservationsEnabled) ...[
          _field(
            tr(context, 'seating_capacity'),
            _seatingCtrl,
            hint: '40',
          ),
          FastSwitchTile(
            title: Text(
              tr(context, 'reservation_only'),
              style: TextStyle(color: context.fast.t1, fontSize: 13),
            ),
            subtitle: Text(
              tr(context, 'reservation_only_sub'),
              style: TextStyle(color: context.fast.t3, fontSize: 11),
            ),
            value: _reservationOnly,
            onChanged: (v) => setState(() => _reservationOnly = v),
          ),
        ],

        SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C8B3),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(
              0xFF00C8B3,
            ).withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  tr(context, 'save'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),

        SizedBox(height: 32),
        Divider(color: context.fast.line),
        const SizedBox(height: 16),
        // Proper logout button — only signs out, does not reset data
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return OutlinedButton(
              onPressed: auth.isLoggingOut
                  ? null
                  : () async {
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: auth.isLoggingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEF4444),
                      ),
                    )
                  : Text(
                      tr(context, 'logout'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStripeConnectBanner() {
    if (_connectLoading && _connectStatus == null) {
      return const LinearProgressIndicator(color: Color(0xFF00C8B3));
    }
    final connected = _connectStatus?['connected'] as bool? ?? false;
    final chargesEnabled = _connectStatus?['chargesEnabled'] as bool? ?? false;
    final ok = connected && chargesEnabled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFF00C8B3).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? tr(context, 'stripe_active')
                  : connected
                  ? tr(context, 'stripe_connected')
                  : tr(context, 'stripe_required'),
              style: TextStyle(
                color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact weekly hours editor — day row: label · open field · close
  /// field · "Fermé" checkbox. Saved as {day: "HH:MM-HH:MM" | "closed"}.
  Widget _hoursEditor() {
    return Container(
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.fast.faint),
      ),
      child: Column(
        children: [
          for (var d = 1; d <= 7; d++) ...[
            if (d > 1) Divider(height: 1, color: context.fast.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      tr(context, 'day_$d'),
                      style: TextStyle(
                        color: context.fast.t2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _hourField(_openCtrls[d]!, d)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('–', style: TextStyle(color: context.fast.t3)),
                  ),
                  Expanded(child: _hourField(_closeCtrls[d]!, d)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() {
                      if (_closedDays.contains(d)) {
                        _closedDays.remove(d);
                      } else {
                        _closedDays.add(d);
                      }
                    }),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _closedDays.contains(d)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: _closedDays.contains(d)
                              ? const Color(0xFF00C8B3)
                              : context.fast.faint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tr(context, 'closed'),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.fast.t3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hourField(TextEditingController ctrl, int day) {
    final closed = _closedDays.contains(day);
    return TextField(
      controller: ctrl,
      enabled: !closed,
      keyboardType: TextInputType.datetime,
      style: TextStyle(
        color: closed ? context.fast.faint : context.fast.t1,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '09:00',
        hintStyle: TextStyle(color: context.fast.faint, fontSize: 12),
        filled: true,
        fillColor: context.fast.faint.withValues(alpha: 0.25),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.fast.faint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.fast.faint),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00C8B3),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildThemePicker() {
    final fast = context.watch<FASTProvider>();
    Widget option(ThemeMode mode, IconData icon, String label) {
      final selected = fast.themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => fast.setThemeMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF00C8B3) : context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFF00C8B3) : context.fast.line,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? FASTBrand.onAmber : context.fast.t2,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? FASTBrand.onAmber : context.fast.t2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(
          ThemeMode.system,
          Icons.phone_android,
          tr(context, 'theme_auto'),
        ),
        const SizedBox(width: 8),
        option(
          ThemeMode.light,
          Icons.wb_sunny_outlined,
          tr(context, 'theme_light'),
        ),
        const SizedBox(width: 8),
        option(
          ThemeMode.dark,
          Icons.nightlight_outlined,
          tr(context, 'theme_dark'),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () async {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          });
        }
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.fast.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.fast.faint),
          image: _imageBase64.isNotEmpty
              ? DecorationImage(
                  image: _imageBase64.startsWith('http')
                      ? NetworkImage(_imageBase64)
                      : MemoryImage(base64Decode(_imageBase64.split(',').last))
                            as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imageBase64.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: context.fast.t2, size: 40),
                  SizedBox(height: 12),
                  Text(
                    tr(context, 'add_photo'),
                    style: TextStyle(color: context.fast.t2),
                  ),
                ],
              )
            : Container(
                alignment: Alignment.topRight,
                padding: EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => setState(() => _imageBase64 = ''),
                  icon: Icon(Icons.close, color: context.fast.t1),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: TextStyle(color: context.fast.t1, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: context.fast.t2, fontSize: 13),
          hintStyle: TextStyle(color: context.fast.faint, fontSize: 13),
          filled: true,
          fillColor: context.fast.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.fast.faint),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.fast.faint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00C8B3)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _timeSlider(
    String title,
    double value,
    double min,
    double max,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.fast.t1,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${value.round()} min',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 22),
            activeTrackColor: color,
            inactiveTrackColor: context.fast.line,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
