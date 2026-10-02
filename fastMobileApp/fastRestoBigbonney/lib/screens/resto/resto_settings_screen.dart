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

class RestoSettingsScreen extends StatefulWidget {
  const RestoSettingsScreen({super.key});

  @override
  State<RestoSettingsScreen> createState() => _RestoSettingsScreenState();
}

class _RestoSettingsScreenState extends State<RestoSettingsScreen> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String _imageBase64 = '';

  double _normalPrepTime = 15;
  double _rushPrepTime = 25;
  List<String> _selectedDietary = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _restaurantId;

  final _paymentService = PaymentService();
  Map<String, dynamic>? _connectStatus;
  bool _connectLoading = false;

  static const _dietaryAll = [
    'VEGAN', 'VEGETARIAN', 'GLUTEN_FREE', 'HALAL', 'KETO', 'DAIRY_FREE',
  ];
  static const _dietaryLabels = {
    'VEGAN': 'Végétalien',
    'VEGETARIAN': 'Végétarien',
    'GLUTEN_FREE': 'Sans Gluten',
    'HALAL': 'Halal',
    'KETO': 'Céto',
    'DAIRY_FREE': 'Sans Lactose',
  };

  // Same list as the client app's category strip — multi-select.
  static const _categories = [
    'Burger', 'Pizza', 'Sushi', 'Tacos', 'Kebab', 'Sandwich',
    'Mexicain', 'Africain', 'Arabe', 'Indien', 'Chinois', 'Thaï',
    'Poulet', 'Hot-dog', 'Pâtes', 'Salade', 'Fruits de mer',
    'Vegan', 'Dessert', 'Glaces', 'Crêpes', 'Waffle', 'Café',
    'Smoothie', 'Fast-Food', 'Bols/Healthy', 'Autre',
  ];
  Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _loadConnectStatus();
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
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await _loadConnectStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stripe Connect: $e')),
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
        _imageBase64 = data['image'] as String? ?? '';
        _normalPrepTime = ((data['normalPrepTime'] as num?)?.toDouble()) ?? 15;
        _rushPrepTime = ((data['rushPrepTime'] as num?)?.toDouble()) ?? 25;
        final opts = data['dietaryOptions'] as List<dynamic>? ?? [];
        _selectedDietary = opts.map((e) {
          if (e is String) return e;
          if (e is Map<String, dynamic>) return e['option'] as String? ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList();
        _loading = false;
      });
    } catch (e) {
      // Fall back to locally cached settings
      if (!mounted) return;
      final cached = Provider.of<RestoProvider>(context, listen: false).settings;
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
        _error = 'Impossible de charger depuis le serveur. Données locales affichées.';
      });
    }
  }

  Future<void> _save() async {
    if (_restaurantId == null) {
      setState(() => _error = 'Aucun restaurant trouvé.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'cuisineType': _cuisineCtrl.text.trim(),
      'category': _selectedCategories.join(', '),
      'city': _cityCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'managerIban': _ibanCtrl.text.trim(),
      if (_imageBase64.isNotEmpty) 'image': _imageBase64,
      'normalPrepTime': _normalPrepTime.round(),
      'rushPrepTime': _rushPrepTime.round(),
      'dietaryOptions': _selectedDietary,
    };

    try {
      final svc = RestaurantService();
      await svc.updateRestaurant(_restaurantId!, body);

      // Update local cache
      if (!mounted) return;
      final provider = Provider.of<RestoProvider>(context, listen: false);
      await provider.updateSettings(RestaurantSettings(
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
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Text('Profil mis à jour ✓',
            style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold)),
      ));
    } catch (e) {
      setState(() => _error = 'Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cuisineCtrl.dispose();
    _categoryCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C8B3)));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [ Text('Profil Restaurant',
            style: TextStyle(color: context.fast.t1, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 4), Text('Ces informations sont visibles par vos clients.',
            style: TextStyle(color: context.fast.t2, fontSize: 13)),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ),
        ],

              SizedBox(height: 24),
        _section('Personnalisation'),
        _buildThemePicker(),

              SizedBox(height: 24),
        _section('Paiements Stripe Connect'),
        _buildStripeConnectBanner(),
              SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _connectLoading ? null : _configureStripeConnect,
          icon: const Icon(Icons.account_balance),
          label: const Text('Configurer Stripe Connect'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00C8B3),
            side: const BorderSide(color: Color(0xFF00C8B3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

              SizedBox(height: 24),
        _section('Image de couverture'),
        _buildImagePicker(),

              SizedBox(height: 24),
        _section('Identité'),
        _field('Nom du restaurant *', _nameCtrl),
        _field('Description', _descCtrl, maxLines: 3,
            hint: 'Décrivez votre restaurant, votre spécialité...'),

              SizedBox(height: 24),
        _section('Coordonnées & Banque'),
        _field('Ville', _cityCtrl),
        _field('Adresse complète', _addressCtrl, hint: '12 rue des Lilas, 75001 Paris'),
        _field('IBAN', _ibanCtrl, hint: 'FR76 **** **** **** **** 1234'),

              SizedBox(height: 24),
        _section('Cuisine & Catégorie'),
        _field('Type de cuisine', _cuisineCtrl, hint: 'ex: Française, Japonaise, Italienne'),
              SizedBox(height: 12),
        Text('Catégories (plusieurs possibles)',
            style: TextStyle(
                color: context.fast.t2,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final sel = _selectedCategories.contains(c);
            return FilterChip(
              label: Text(
                c,
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
                  borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),

              SizedBox(height: 24),
        _section('Options alimentaires'),
              SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietaryAll.map((key) {
            final selected = _selectedDietary.contains(key);
            return FilterChip(
              label: Text(_dietaryLabels[key] ?? key,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? context.fast.bg : context.fast.t2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  )),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedDietary = [..._selectedDietary, key];
                  } else {
                    _selectedDietary = _selectedDietary.where((k) => k != key).toList();
                  }
                });
              },
              selectedColor: Color(0xFF00C8B3),
              backgroundColor: context.fast.card,
              checkmarkColor: FASTBrand.onAmber,
              side: BorderSide(
                color: selected ?       Color(0xFF00C8B3) : context.fast.faint,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            );
          }).toList(),
        ),

              SizedBox(height: 24),
        _section('Temps de Préparation'),
        _timeSlider('Temps Normal', _normalPrepTime, 5, 60,
            const Color(0xFF00C8B3), (v) => setState(() => _normalPrepTime = v)),
              SizedBox(height: 20),
        _timeSlider('Temps Mode Rush', _rushPrepTime, 10, 90,
            const Color(0xFFEF4444), (v) => setState(() => _rushPrepTime = v)),

              SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C8B3),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFF00C8B3).withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),

              SizedBox(height: 32),
              Divider(color: context.fast.line),
        const SizedBox(height: 16),
        // Proper logout button — only signs out, does not reset data
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return OutlinedButton(
              onPressed: auth.isLoggingOut ? null : () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: auth.isLoggingOut
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                    )
                  : const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        children: [ Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? 'Stripe Connect actif — paiements activés'
                  : connected
                      ? 'Compte connecté — finalisez l’activation des paiements'
                      : 'Stripe Connect non configuré — requis pour recevoir les paiements',
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFF00C8B3),
                fontSize: 13,
                fontWeight: FontWeight.bold)),
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
              border: Border.all(color: selected ? const Color(0xFF00C8B3) : context.fast.line),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? FASTBrand.onAmber : context.fast.t2, size: 18),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? FASTBrand.onAmber : context.fast.t2,
                    )),
              ],
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        option(ThemeMode.system, Icons.phone_android, 'Auto'),
        const SizedBox(width: 8),
        option(ThemeMode.light, Icons.wb_sunny_outlined, 'Clair'),
        const SizedBox(width: 8),
        option(ThemeMode.dark, Icons.nightlight_outlined, 'Sombre'),
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
                      : MemoryImage(base64Decode(_imageBase64.split(',').last)) as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imageBase64.isEmpty
            ?       Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Icon(Icons.add_a_photo, color: context.fast.t2, size: 40),
                  SizedBox(height: 12), Text('Ajouter une photo', style: TextStyle(color: context.fast.t2)),
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

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, String? hint}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _timeSlider(String title, double value, double min, double max, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [ Text(title,
                style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.w600, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${value.round()} min',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
              SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape:       RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape:       RoundSliderOverlayShape(overlayRadius: 22),
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
