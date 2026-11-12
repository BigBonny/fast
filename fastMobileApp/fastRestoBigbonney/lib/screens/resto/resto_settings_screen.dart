import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe_connect/flutter_stripe_connect.dart';
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
import '../assistant_screen.dart';
import '../../widgets/address_autocomplete_field.dart';

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

  /// Stripe's onboarding form, rendered natively inside FAST. Returns
  /// false when it couldn't be started (old backend, unsupported
  /// platform, load failure) so the caller opens the hosted page instead.
  Future<bool> _startEmbeddedOnboarding() async {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) return false;
    final title = tr(context, 'stripe_payments');
    try {
      final session = await _paymentService.createConnectAccountSession();
      String? secret = session['clientSecret'] as String?;
      final key = session['publishableKey'] as String?;
      if (secret == null || key == null || key.isEmpty) {
        // No form to show: demo restaurant, or test mode where the
        // backend connected the account through the API.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                session['connected'] == true
                    ? tr(context, 'stripe_active')
                    : tr(context, 'stripe_pending'),
              ),
            ),
          );
        }
        return true;
      }
      await StripeConnect.instance.initialize(
        publishableKey: key,
        // The first call reuses the session just created; Stripe asks
        // again only when that one expires mid-flow.
        clientSecretProvider: () async {
          final ready = secret;
          secret = null;
          if (ready != null) return ready;
          final fresh = await _paymentService.createConnectAccountSession();
          return fresh['clientSecret'] as String? ?? '';
        },
        appearance: const ConnectAppearance(
          colors: ConnectColors(
            primary: '#00C8B3',
            formHighlightBorder: '#00C8B3',
          ),
        ),
      );
      var failed = false;
      await StripeConnect.presentAccountOnboarding(
        title: title,
        // Only what Stripe needs right now — nothing "for later".
        collectionOptions: const AccountCollectionOptions(),
        onExit: () {
          if (mounted) _loadConnectStatus();
        },
        onLoadError: (error) {
          // Can fire more than once — fall back to the hosted page once.
          debugPrint('[Stripe] embedded onboarding failed: $error');
          if (failed || !mounted) return;
          failed = true;
          _openHostedOnboarding();
        },
      );
      return true;
    } catch (e) {
      debugPrint('[Stripe] embedded onboarding unavailable: $e');
      return false;
    }
  }

  Future<void> _configureStripeConnect() async {
    setState(() => _connectLoading = true);
    try {
      if (!await _startEmbeddedOnboarding()) await _openHostedOnboarding();
      await _loadConnectStatus();
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  /// Stripe's hosted onboarding page in an in-app webview — the path used
  /// when the embedded form isn't available.
  Future<void> _openHostedOnboarding() async {
    try {
      final link = await _paymentService.createConnectAccountLink(
        language: context.read<FASTProvider>().appLanguage,
      );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'stripe_err').replaceAll('{n}', '$e')),
          ),
        );
      }
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
        _dineInFeeCtrl.text = ((data['dineInFee'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2);
        _seatingCtrl.text =
            '${(data['seatingCapacity'] as num?)?.toInt() ?? 0}';
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
          backgroundColor: FASTBrand.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FASTRadius.sm),
          ),
          content: Text(
            tr(context, 'profile_updated'),
            style: FASTText.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
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
    final fast = context.fast;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: FASTPro.teal),
      );
    }

    const sectionGap = SizedBox(height: 32);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s16,
        FASTSpace.s16,
        FASTSpace.s40,
      ),
      children: [
        Text(
          tr(context, 'profil_resto'),
          style: FASTText.display.copyWith(color: fast.t1),
        ),
        const SizedBox(height: FASTSpace.s4),
        Text(
          tr(context, 'visible_clients'),
          style: FASTText.body.copyWith(color: fast.t2),
        ),

        if (_error != null) ...[
          const SizedBox(height: FASTSpace.s12),
          Container(
            padding: const EdgeInsets.all(FASTSpace.s12),
            decoration: BoxDecoration(
              color: FASTBrand.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              border: Border.all(color: FASTBrand.error.withValues(alpha: 0.4)),
            ),
            child: Text(
              _error!,
              style: FASTText.body.copyWith(color: FASTBrand.error),
            ),
          ),
        ],

        const SizedBox(height: FASTSpace.s24),
        _section(tr(context, 'customization')),
        _card(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(FASTSpace.s16),
              child: _buildThemePicker(),
            ),
            _hairline(),
            _navRow(
              icon: Icons.auto_awesome_outlined,
              label: tr(context, 'assistant_title'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AssistantScreen(pro: true),
                ),
              ),
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'stripe_payments')),
        _card(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(FASTSpace.s16),
              child: _buildStripeConnectBanner(),
            ),
            _hairline(),
            _navRow(
              icon: Icons.account_balance_outlined,
              label: tr(context, 'stripe_connect'),
              onTap: _connectLoading ? null : _configureStripeConnect,
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'cover_image')),
        _buildImagePicker(),

        sectionGap,
        _section(tr(context, 'identity')),
        _card(
          children: [
            _field(tr(context, 'resto_name_lbl'), _nameCtrl),
            _field(
              tr(context, 'description'),
              _descCtrl,
              maxLines: 3,
              hint: tr(context, 'desc_hint'),
              bottom: 0,
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'contact_bank')),
        _card(
          children: [
            _field(tr(context, 'city'), _cityCtrl),
            Padding(
              padding: const EdgeInsets.only(bottom: FASTSpace.s12),
              child: AddressAutocompleteField(
                controller: _addressCtrl,
                label: tr(context, 'full_address'),
                onSelected: (s) {
                  if (_cityCtrl.text.trim().isEmpty) _cityCtrl.text = s.city;
                },
              ),
            ),
            _field(
              'IBAN',
              _ibanCtrl,
              hint: 'FR76 **** **** **** **** 1234',
              bottom: 0,
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'legal_identity')),
        _card(
          children: [
            Text(
              tr(context, 'identity_help'),
              style: FASTText.caption.copyWith(color: fast.t2, height: 1.4),
            ),
            const SizedBox(height: FASTSpace.s16),
            _field(
              tr(context, 'siret_lbl'),
              _siretCtrl,
              hint: '123 456 789 00012',
            ),
            _field(
              tr(context, 'phone_lbl'),
              _phoneCtrl,
              hint: '06 12 34 56 78',
            ),
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
              bottom: 0,
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'opening_hours')),
        _hoursEditor(),

        sectionGap,
        _section(tr(context, 'cuisine_category')),
        _card(
          children: [
            _field(
              tr(context, 'cuisine_type'),
              _cuisineCtrl,
              hint: tr(context, 'cuisine_example'),
            ),
            const SizedBox(height: FASTSpace.s4),
            Text(
              tr(context, 'categories_multi'),
              style: FASTText.caption.copyWith(
                color: fast.t2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FASTSpace.s8),
            Wrap(
              spacing: FASTSpace.s8,
              runSpacing: FASTSpace.s8,
              children: [
                ..._categories.map((c) {
                  final sel = _selectedCategories.contains(c);
                  return _chip(
                    catLabel(context, c),
                    sel,
                    (v) => setState(() {
                      if (v) {
                        _selectedCategories.add(c);
                      } else {
                        _selectedCategories.remove(c);
                      }
                    }),
                  );
                }),
                // Custom categories saved via the "Autres" bar below.
                ..._selectedCategories
                    .where((c) => !_categories.contains(c))
                    .map(
                      (c) => InputChip(
                        label: Text(
                          c,
                          style: FASTText.caption.copyWith(
                            color: _onTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: true,
                        showCheckmark: false,
                        selectedColor: FASTPro.teal.withValues(alpha: 0.14),
                        backgroundColor: fast.card,
                        deleteIconColor: _onTeal,
                        side: const BorderSide(color: FASTPro.teal),
                        shape: const StadiumBorder(),
                        onDeleted: () =>
                            setState(() => _selectedCategories.remove(c)),
                      ),
                    ),
              ],
            ),
            // La petite barre apparaît quand "Autres" est sélectionné.
            if (_selectedCategories.contains('Autres')) ...[
              const SizedBox(height: FASTSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCategoryCtrl,
                      style: FASTText.body.copyWith(color: fast.t1),
                      cursorColor: FASTPro.teal,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: tr(context, 'custom_category_hint'),
                      ).copyWith(isDense: true),
                      onSubmitted: (_) => _addCustomCategory(),
                    ),
                  ),
                  const SizedBox(width: FASTSpace.s8),
                  OutlinedButton(
                    onPressed: _addCustomCategory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _onTeal,
                      side: const BorderSide(color: FASTPro.teal),
                      padding: const EdgeInsets.symmetric(
                        horizontal: FASTSpace.s16,
                        vertical: FASTSpace.s12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      tr(context, 'add'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        sectionGap,
        _section(tr(context, 'dietary_options')),
        _card(
          children: [
            Wrap(
              spacing: FASTSpace.s8,
              runSpacing: FASTSpace.s8,
              children: _dietaryAll.map((key) {
                final selected = _selectedDietary.contains(key);
                return _chip(
                  tr(context, 'diet_${key.toLowerCase().replaceAll('_', '')}'),
                  selected,
                  (val) {
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
                );
              }).toList(),
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'prep_time_title')),
        _card(
          children: [
            _timeSlider(
              tr(context, 'normal_time'),
              _normalPrepTime,
              5,
              60,
              FASTPro.teal,
              (v) => setState(() => _normalPrepTime = v),
            ),
            const SizedBox(height: FASTSpace.s16),
            _timeSlider(
              tr(context, 'rush_time'),
              _rushPrepTime,
              10,
              90,
              FASTBrand.error,
              (v) => setState(() => _rushPrepTime = v),
            ),
          ],
        ),

        sectionGap,
        _section(tr(context, 'service_modes')),
        _card(
          padding: const EdgeInsets.symmetric(
            horizontal: FASTSpace.s16,
            vertical: FASTSpace.s8,
          ),
          children: [
            FastSwitchTile(
              leading: _rowIcon(Icons.local_shipping_outlined),
              title: _rowTitle(tr(context, 'food_truck')),
              subtitle: _rowCaption(tr(context, 'food_truck_sub')),
              accent: FASTPro.teal,
              value: _isFoodTruck,
              onChanged: (v) => setState(() => _isFoodTruck = v),
            ),
            if (_isFoodTruck) ...[
              const SizedBox(height: FASTSpace.s8),
              Text(
                tr(context, 'truck_schedule_hint'),
                style: FASTText.caption.copyWith(color: fast.t2),
              ),
              const SizedBox(height: FASTSpace.s8),
              for (var d = 1; d <= 7; d++)
                Padding(
                  padding: const EdgeInsets.only(bottom: FASTSpace.s8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          tr(context, 'day_$d'),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: FASTText.caption.copyWith(
                            color: fast.t2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Expanded(
                        child: AddressAutocompleteField(
                          controller: _truckDayCtrls[d]!,
                          label: tr(context, 'truck_stop_hint'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            _hairline(),
            FastSwitchTile(
              leading: _rowIcon(Icons.restaurant_outlined),
              title: _rowTitle(tr(context, 'dine_in')),
              accent: FASTPro.teal,
              value: _allowDineIn,
              onChanged: (v) => setState(() => _allowDineIn = v),
            ),
            if (_allowDineIn)
              _field('Frais sur place (€)', _dineInFeeCtrl, hint: '0.00'),
            _hairline(),
            FastSwitchTile(
              leading: _rowIcon(Icons.event_outlined),
              title: _rowTitle(tr(context, 'reservations')),
              accent: FASTPro.teal,
              value: _reservationsEnabled,
              onChanged: (v) => setState(() {
                _reservationsEnabled = v;
                if (!v) _reservationOnly = false;
              }),
            ),
            if (_reservationsEnabled) ...[
              _field(tr(context, 'seating_capacity'), _seatingCtrl, hint: '40'),
              _hairline(),
              FastSwitchTile(
                leading: _rowIcon(Icons.event_available_outlined),
                title: _rowTitle(tr(context, 'reservation_only')),
                subtitle: _rowCaption(tr(context, 'reservation_only_sub')),
                accent: FASTPro.teal,
                value: _reservationOnly,
                onChanged: (v) => setState(() => _reservationOnly = v),
              ),
            ],
          ],
        ),

        const SizedBox(height: FASTSpace.s40),
        FastButton(
          label: tr(context, 'save'),
          onPressed: _saving ? null : _save,
          loading: _saving,
          kind: FastButtonKind.ink,
        ),

        const SizedBox(height: FASTSpace.s40),
        _hairline(),
        const SizedBox(height: FASTSpace.s24),
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
                foregroundColor: FASTBrand.error,
                side: const BorderSide(color: FASTBrand.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: auth.isLoggingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FASTBrand.error,
                      ),
                    )
                  : Text(
                      tr(context, 'logout'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: FASTSpace.s8),
        // App Store 5.1.1(v): accounts created in the app must be
        // deletable from the app — Pro accounts included.
        TextButton.icon(
          onPressed: _confirmDeleteAccount,
          icon: const Icon(
            Icons.delete_outline,
            color: FASTBrand.error,
            size: 18,
          ),
          label: Text(
            tr(context, 'del_my_account'),
            style: const TextStyle(
              color: FASTBrand.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
          side: BorderSide(color: context.fast.line),
        ),
        title: Text(
          tr(context, 'del_account_q'),
          style: FASTText.item.copyWith(color: FASTBrand.error),
        ),
        content: Text(
          tr(context, 'del_account_warn'),
          style: FASTText.body.copyWith(color: context.fast.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final deleted = await auth.deleteAccount();
              if (!mounted || !ctx.mounted) return;
              if (deleted) {
                context.read<FASTProvider>().deleteAccount();
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(auth.error ?? tr(context, 'del_fail')),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FASTBrand.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: Text(
              tr(context, 'del'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Stripe Connect status: green once charges are enabled, red while the
  /// owner still has something to do.
  Widget _buildStripeConnectBanner() {
    if (_connectLoading && _connectStatus == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(FASTRadius.pill),
        child: LinearProgressIndicator(
          color: FASTPro.teal,
          backgroundColor: context.fast.line,
        ),
      );
    }
    final connected = _connectStatus?['connected'] as bool? ?? false;
    final chargesEnabled = _connectStatus?['chargesEnabled'] as bool? ?? false;
    final ok = connected && chargesEnabled;
    final color = ok ? FASTBrand.success : FASTBrand.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FASTSpace.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FASTRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: FASTSpace.s12),
          Expanded(
            child: Text(
              ok
                  ? tr(context, 'stripe_active')
                  : connected
                  ? tr(context, 'stripe_connected')
                  : tr(context, 'stripe_required'),
              style: FASTText.body.copyWith(
                color: context.fast.t1,
                fontWeight: FontWeight.w600,
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
    final fast = context.fast;
    return _card(
      padding: const EdgeInsets.symmetric(vertical: FASTSpace.s4),
      children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) _hairline(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              FASTSpace.s16,
              FASTSpace.s8,
              FASTSpace.s8,
              FASTSpace.s8,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    tr(context, 'day_$d'),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: FASTText.caption.copyWith(
                      color: fast.t1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: FASTSpace.s8),
                Expanded(child: _hourField(_openCtrls[d]!, d)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: fast.t3)),
                ),
                Expanded(child: _hourField(_closeCtrls[d]!, d)),
                const SizedBox(width: FASTSpace.s4),
                InkWell(
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  onTap: () => setState(() {
                    if (_closedDays.contains(d)) {
                      _closedDays.remove(d);
                    } else {
                      _closedDays.add(d);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s4,
                      vertical: FASTSpace.s8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _closedDays.contains(d)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: _closedDays.contains(d)
                              ? FASTPro.teal
                              : fast.faint,
                        ),
                        const SizedBox(width: FASTSpace.s4),
                        Text(
                          tr(context, 'closed'),
                          style: FASTText.caption.copyWith(color: fast.t2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickHour(TextEditingController ctrl) async {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(ctrl.text.trim());
    final initial = m == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(
            hour: int.parse(m.group(1)!).clamp(0, 23),
            minute: int.parse(m.group(2)!).clamp(0, 59),
          );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Widget _hourField(TextEditingController ctrl, int day) {
    final fast = context.fast;
    final closed = _closedDays.contains(day);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: color),
    );
    // A picker instead of free typing: the server only accepts HH:MM, and
    // auto-accept needs valid hours to know when the restaurant closes.
    return TextField(
      controller: ctrl,
      enabled: !closed,
      readOnly: true,
      showCursor: false,
      onTap: () => _pickHour(ctrl),
      style: FASTText.price.copyWith(
        fontSize: 14,
        color: closed ? fast.faint : fast.t1,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '09:00',
        hintStyle: FASTText.price.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: fast.t3,
        ),
        filled: true,
        fillColor: fast.cardHigh,
        isDense: true,
        border: border(fast.line),
        enabledBorder: border(fast.line),
        disabledBorder: border(fast.line),
        focusedBorder: border(FASTPro.teal),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
    );
  }

  /// Teal that stays readable as text: the bright teal on dark surfaces,
  /// the deeper one on light surfaces.
  Color get _onTeal => Theme.of(context).brightness == Brightness.dark
      ? FASTPro.teal
      : FASTPro.tealDark;

  Widget _section(String title) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: FASTSpace.s4,
      bottom: FASTSpace.s8,
    ),
    child: Text(
      fastLabelCase(context, title),
      style: FASTText.label.copyWith(color: context.fast.t2),
    ),
  );

  /// Section card: radius 20, hairline border, 16 padding by default.
  Widget _card({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(FASTSpace.s16),
  }) {
    final fast = context.fast;
    return Material(
      color: fast.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FASTRadius.md),
        side: BorderSide(color: fast.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _hairline() =>
      Divider(height: 1, thickness: 1, color: context.fast.line);

  Widget _rowIcon(IconData icon) =>
      Icon(icon, color: context.fast.t2, size: 22);

  Widget _rowTitle(String text) => Text(
    text,
    style: FASTText.body.copyWith(
      color: context.fast.t1,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _rowCaption(String text) =>
      Text(text, style: FASTText.caption.copyWith(color: context.fast.t2));

  /// Plain settings row: neutral line icon, label, chevron.
  Widget _navRow({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final fast = context.fast;
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.all(FASTSpace.s16),
          child: Row(
            children: [
              _rowIcon(icon),
              const SizedBox(width: FASTSpace.s12),
              Expanded(child: _rowTitle(label)),
              const SizedBox(width: FASTSpace.s8),
              Icon(Icons.chevron_right, color: fast.t3, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Multi-select pill: teal tint and border when selected.
  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) {
    final fast = context.fast;
    return FilterChip(
      label: Text(
        label,
        style: FASTText.caption.copyWith(
          color: selected ? _onTeal : fast.t2,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onSelected(v);
      },
      selectedColor: FASTPro.teal.withValues(alpha: 0.14),
      backgroundColor: fast.card,
      checkmarkColor: _onTeal,
      side: BorderSide(color: selected ? FASTPro.teal : fast.line),
      shape: const StadiumBorder(),
    );
  }

  Widget _buildThemePicker() {
    final fast = context.watch<FASTProvider>();
    final shades = context.fast;
    Widget option(ThemeMode mode, IconData icon, String label) {
      final selected = fast.themeMode == mode;
      final fg = selected ? _onTeal : shades.t2;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            fast.setThemeMode(mode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? FASTPro.teal.withValues(alpha: 0.14)
                  : shades.cardHigh,
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              border: Border.all(color: selected ? FASTPro.teal : shades.line),
            ),
            child: Column(
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
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
        const SizedBox(width: FASTSpace.s8),
        option(
          ThemeMode.light,
          Icons.wb_sunny_outlined,
          tr(context, 'theme_light'),
        ),
        const SizedBox(width: FASTSpace.s8),
        option(
          ThemeMode.dark,
          Icons.nightlight_outlined,
          tr(context, 'theme_dark'),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final fast = context.fast;
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
          if (!mounted) return;
          setState(() {
            _imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          });
        }
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: fast.card,
          borderRadius: BorderRadius.circular(FASTRadius.md),
          border: Border.all(color: fast.line),
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
                  Icon(Icons.add_a_photo_outlined, color: fast.t2, size: 32),
                  const SizedBox(height: FASTSpace.s8),
                  Text(
                    tr(context, 'add_photo'),
                    style: FASTText.body.copyWith(color: fast.t2),
                  ),
                ],
              )
            : Container(
                alignment: AlignmentDirectional.topEnd,
                padding: const EdgeInsets.all(FASTSpace.s8),
                child: IconButton(
                  onPressed: () => setState(() => _imageBase64 = ''),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
      ),
    );
  }

  /// Inputs: radius 12 on cardHigh, teal focus border.
  InputDecoration _inputDecoration({String? label, String? hint}) {
    final fast = context.fast;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: FASTText.body.copyWith(color: fast.t2),
      floatingLabelStyle: FASTText.body.copyWith(color: _onTeal),
      hintStyle: FASTText.body.copyWith(color: fast.t3),
      filled: true,
      fillColor: fast.cardHigh,
      border: border(fast.line),
      enabledBorder: border(fast.line),
      focusedBorder: border(FASTPro.teal, 1.5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s12,
        vertical: 14,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboard,
    double bottom = FASTSpace.s12,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        cursorColor: FASTPro.teal,
        style: FASTText.body.copyWith(color: context.fast.t1),
        decoration: _inputDecoration(label: label, hint: hint),
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
          children: [
            Expanded(child: _rowTitle(title)),
            const SizedBox(width: FASTSpace.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FASTSpace.s12,
                vertical: FASTSpace.s4,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(FASTRadius.pill),
              ),
              child: Text(
                '${value.round()} min',
                style: FASTText.price.copyWith(fontSize: 14, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: FASTSpace.s4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
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
