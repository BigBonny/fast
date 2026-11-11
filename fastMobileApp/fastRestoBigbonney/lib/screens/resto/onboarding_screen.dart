import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../providers/auth_provider.dart';
import '../../api/api_client.dart';
import '../../api/api_config.dart';
import '../../api/api_exceptions.dart';
import 'resto_shell.dart';
import 'pro_intro_slides.dart';
import '../../widgets/intro_carousel.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/fast_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 0: RGPD, 1: Tutorial, 2: Splash, 3: Form
  int _currentStep = -1; // -1 = checking
  bool _checkingBackend = true;
  bool _ready = false;
  // Branded intro carousel shown every time the Pro workspace is
  // entered — after setup, on login, on cold start, and when coming
  // back from client mode.
  bool _showIntro = false;
  String? _formError;
  bool _formLoading = false;

  final _formKey = GlobalKey<FormState>();
  String _managerFirstName = '';
  // ignore: prefer_final_fields
  String _managerPhone = '';
  String _restoName = '';
  final Set<String> _cuisineTypes = {'Burger'};
  String _city = '';
  final _cityOnboardingCtrl = TextEditingController();
  // Controllers, not bare onSaved: controller-less fields lose their
  // text when the form rebuilds (loading state, step change), which is
  // exactly how an empty restaurant name reached the API.
  final _managerNameCtrl = TextEditingController();
  final _restoNameCtrl = TextEditingController();
  double _normalPrepTime = 15;
  double _rushPrepTime = 25;

  // Same list as the client app's category strip — a restaurant can
  // pick several (e.g. "Burgers, Tacos").
  final List<String> _cuisines = [
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

  @override
  void dispose() {
    _cityOnboardingCtrl.dispose();
    _managerNameCtrl.dispose();
    _restoNameCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<RestoProvider>();

    // Primary check: does user already have a restaurant on the backend?
    final hasRestaurantOnBackend = await _checkBackendRestaurant(auth, prov);
    if (!mounted) return;

    if (hasRestaurantOnBackend) {
      // Already set up — play the intro slides unless the user ticked
      // "don't show again", then the dashboard.
      final dismissed = await ProIntroSlides.isDismissed();
      if (!mounted) return;
      if (dismissed) {
        _finishOnboarding();
      } else {
        setState(() {
          _checkingBackend = false;
          _showIntro = true;
        });
      }
      return;
    }

    // Otherwise run local onboarding steps
    setState(() {
      _checkingBackend = false;
      if (!prov.isRgpdAccepted) {
        _currentStep = 0;
      } else if (!prov.isTutorialDone) {
        _currentStep = 1;
      } else if (!prov.skipSplash) {
        _currentStep = 2;
      } else {
        _currentStep = 3;
      }
    });
  }

  /// Returns true if a restaurant already exists for this user on the backend.
  Future<bool> _checkBackendRestaurant(
    AuthProvider auth,
    RestoProvider prov,
  ) async {
    // 1. Fast path: auth user object already has restaurant data
    if (auth.user?.restaurant != null) {
      final restoId = auth.user!.restaurant!['id'] as String?;
      if (restoId != null) {
        await prov.updateSettings(
          RestaurantSettings.fromApiJson(auth.user!.restaurant!),
        );
        await prov.loadFromApi(restaurantId: restoId);
        return true;
      }
    }

    // 2. Try fetching from backend
    try {
      final data = await ApiClient().get(ApiConfig.myRestaurant);
      if (data != null) {
        final restoId = (data as Map<String, dynamic>)['id'] as String?;
        if (restoId != null) {
          await prov.updateSettings(RestaurantSettings.fromApiJson(data));
          await prov.loadFromApi(restaurantId: restoId);
          return true;
        }
      }
    } catch (e) {
      // 404 = no restaurant yet, anything else is a network issue but we'll
      // still show the form rather than blocking the user forever.
      if (e is! NotFoundException) {
        // Not a 404 — could be offline; check local settings as fallback
        if (prov.settings != null) return true;
      }
    }
    return false;
  }

  void _nextStep() {
    final prov = context.read<RestoProvider>();
    if (_currentStep == 0) {
      prov.acceptRgpd();
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      prov.completeTutorial();
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      prov.skipSplashLogic();
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _submitForm();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    // Read controllers directly — authoritative source of what the
    // user typed, immune to form-save/rebuild ordering.
    _managerFirstName = _managerNameCtrl.text.trim();
    _restoName = _restoNameCtrl.text.trim();
    _city = _cityOnboardingCtrl.text.trim();
    if (_restoName.isEmpty) {
      setState(() => _formError = tr(context, 'required_f'));
      return;
    }
    setState(() {
      _formLoading = true;
      _formError = null;
    });

    try {
      final data = await ApiClient().post(
        ApiConfig.restaurants,
        body: {
          'name': _restoName,
          'description': '',
          'category': _cuisineTypes.join(', '),
          'address': _city,
          'normalPrepTime': _normalPrepTime.toInt(),
          'rushPrepTime': _rushPrepTime.toInt(),
        },
      );

      final restoId = (data as Map<String, dynamic>)['id'] as String?;

      // Save local settings too (for offline fallback)
      final settings = RestaurantSettings(
        managerFirstName: _managerFirstName,
        managerPhone: _managerPhone,
        name: _restoName,
        cuisineType: _cuisineTypes.join(', '),
        city: _city,
        normalPrepTime: _normalPrepTime.toInt(),
        rushPrepTime: _rushPrepTime.toInt(),
      );
      if (mounted) {
        final prov = context.read<RestoProvider>();
        await prov.updateSettings(settings);
        prov.loadFromApi(restaurantId: restoId);
        setState(() => _showIntro = true);
      }
    } catch (e) {
      if (!mounted) return;
      // 409 "déjà un restaurant" — the account already owns one (e.g.
      // account/mine wasn't reachable earlier). Load it and move on
      // instead of trapping the user on this form.
      if (e is ApiException && e.message.contains('déjà')) {
        final ok = await _checkBackendRestaurant(
          context.read<AuthProvider>(),
          context.read<RestoProvider>(),
        );
        if (ok && mounted) {
          setState(() => _showIntro = true);
          return;
        }
      }
      if (!mounted) return;
      String msg = tr(context, 'create_resto_err');
      if (e is ApiException) msg = e.message;
      if (e is ValidationException) msg = e.message;
      setState(() {
        _formError = msg;
        _formLoading = false;
      });
    }
  }

  void _finishOnboarding() {
    if (!mounted) return;
    setState(() {
      _ready = true;
      _checkingBackend = false;
      _showIntro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) return _proIntro(onDone: _finishOnboarding);
    if (_ready) return const RestoMainShell();
    if (_checkingBackend) {
      return Scaffold(
        backgroundColor: context.fast.bg,
        body: const Center(
          child: CircularProgressIndicator(color: FASTPro.teal),
        ),
      );
    }

    // The intro slides manage their own full-bleed layout — skip the
    // SafeArea/Center chrome for that step.
    if (_currentStep == 1) return _buildTutorial();

    Widget content;
    switch (_currentStep) {
      case 0:
        content = _buildRgpd();
        break;
      case 2:
        content = _buildSplash();
        break;
      case 3:
        content = _buildForm();
        break;
      default:
        content = const Center(
          child: CircularProgressIndicator(color: FASTPro.teal),
        );
    }

    return Scaffold(
      backgroundColor: context.fast.bg,
      body: SafeArea(child: Center(child: content)),
    );
  }

  /// Centred column for the two single-message steps, capped in width so
  /// it does not stretch across a tablet.
  Widget _stepColumn(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FASTSpace.s24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _buildRgpd() {
    return _stepColumn([
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FASTPro.teal.withValues(alpha: 0.12),
          border: Border.all(color: FASTPro.teal.withValues(alpha: 0.3)),
        ),
        child: const Icon(
          Icons.privacy_tip_outlined,
          size: 32,
          color: FASTPro.teal,
        ),
      ),
      const SizedBox(height: FASTSpace.s24),
      Text(
        tr(context, 'privacy_cgu'),
        textAlign: TextAlign.center,
        style: FASTText.display.copyWith(color: context.fast.t1),
      ),
      const SizedBox(height: FASTSpace.s16),
      Text(
        tr(context, 'accept_terms'),
        textAlign: TextAlign.center,
        style: FASTText.body.copyWith(color: context.fast.t2, height: 1.5),
      ),
      const SizedBox(height: FASTSpace.s40),
      FastButton(
        label: tr(context, 'accept_continue'),
        onPressed: _nextStep,
        kind: FastButtonKind.ink,
      ),
    ]);
  }

  /// Branded FAST Pro intro — same native carousel as the client side
  /// (icon medallions, per-slide accent, localized titles). The copy is
  /// lifted from the previous baked artwork: visibilité → menu IA →
  /// gain de temps. Finishing or skipping counts the tutorial as done.
  Widget _buildTutorial() {
    return _proIntro(
      onDone: _nextStep,
      onBack: () => setState(() => _currentStep = 0),
    );
  }

  Widget _proIntro({required VoidCallback onDone, VoidCallback? onBack}) {
    return FastIntroCarousel(
      onDone: onDone,
      onBack: onBack,
      dismissedPrefKey: ProIntroSlides.proDismissedKey,
      slides: [
        FastIntroSlide(
          icon: Icons.visibility_rounded,
          title: tr(context, 'pi1_t'),
          accentPart: tr(context, 'pi1_ta'),
          description: tr(context, 'pi1_d'),
          accent: const Color(0xFFF59E0B),
          glow: const Color(0xFFF97316),
        ),
        FastIntroSlide(
          icon: Icons.auto_awesome,
          title: tr(context, 'pi2_t'),
          accentPart: tr(context, 'pi2_ta'),
          description: tr(context, 'pi2_d'),
          accent: const Color(0xFFA855F7),
          glow: const Color(0xFF7C3AED),
        ),
        FastIntroSlide(
          icon: Icons.bolt_rounded,
          title: tr(context, 'pi3_t'),
          accentPart: tr(context, 'pi3_ta'),
          description: tr(context, 'pi3_d'),
          accent: const Color(0xFF00C8B3),
          glow: const Color(0xFF10B981),
          bannerText: tr(context, 'pi3_w'),
        ),
      ],
    );
  }

  Widget _buildSplash() {
    return _stepColumn([
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FASTRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Transform.scale(
          scale: 1.35,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: FASTSpace.s24),
      Text(
        tr(context, 'grow_title'),
        textAlign: TextAlign.center,
        style: FASTText.display.copyWith(color: context.fast.t1),
      ),
      const SizedBox(height: FASTSpace.s40),
      FastButton(
        label: tr(context, 'create_space'),
        onPressed: _nextStep,
        kind: FastButtonKind.ink,
      ),
    ]);
  }

  /// Inputs: radius 12 on cardHigh, teal focus border.
  InputDecoration _input(String label) {
    final fast = context.fast;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: FASTText.body.copyWith(color: fast.t2),
      floatingLabelStyle: FASTText.body.copyWith(
        color: Theme.of(context).brightness == Brightness.dark
            ? FASTPro.teal
            : FASTPro.tealDark,
      ),
      filled: true,
      fillColor: fast.cardHigh,
      border: border(fast.line),
      enabledBorder: border(fast.line),
      focusedBorder: border(FASTPro.teal, 1.5),
      errorBorder: border(FASTBrand.error),
      focusedErrorBorder: border(FASTBrand.error, 1.5),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          FASTSpace.s16,
          FASTSpace.s8,
          FASTSpace.s16,
          FASTSpace.s40,
        ),
        children: [
          // Escape hatch — without it a failed creation traps the user
          // on this form with no way back to login/role selection.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                // AuthProvider rebuild sends the app back to role selection.
              },
              icon: Icon(Icons.logout, size: 18, color: context.fast.t2),
              label: Text(
                tr(context, 'logout'),
                style: FASTText.body.copyWith(color: context.fast.t2),
              ),
            ),
          ),
          Text(
            tr(context, 'configuration'),
            style: FASTText.display.copyWith(color: context.fast.t1),
          ),
          const SizedBox(height: FASTSpace.s24),
          TextFormField(
            controller: _managerNameCtrl,
            style: FASTText.body.copyWith(fontSize: 16, color: context.fast.t1),
            cursorColor: FASTPro.teal,
            decoration: _input(tr(context, 'manager_name')),
          ),
          const SizedBox(height: FASTSpace.s16),
          TextFormField(
            controller: _restoNameCtrl,
            style: FASTText.body.copyWith(fontSize: 16, color: context.fast.t1),
            cursorColor: FASTPro.teal,
            decoration: _input(tr(context, 'resto_name_lbl')),
            validator: (val) => val == null || val.trim().isEmpty
                ? tr(context, 'required_f')
                : null,
          ),
          const SizedBox(height: FASTSpace.s16),
          AddressAutocompleteField(
            controller: _cityOnboardingCtrl,
            label: tr(context, 'city'),
            onChanged: (v) => _city = v,
            onSelected: (s) => _city = s.label,
          ),
          const SizedBox(height: FASTSpace.s24),
          Text(
            fastLabelCase(context, tr(context, 'cuisine_types_lbl')),
            style: FASTText.label.copyWith(color: context.fast.t2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisines.map((c) {
              final sel = _cuisineTypes.contains(c);
              final onSel = Theme.of(context).brightness == Brightness.dark
                  ? FASTPro.teal
                  : FASTPro.tealDark;
              return FilterChip(
                label: Text(
                  catLabel(context, c),
                  style: FASTText.caption.copyWith(
                    color: sel ? onSel : context.fast.t2,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: sel,
                onSelected: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (v) {
                      _cuisineTypes.add(c);
                    } else if (_cuisineTypes.length > 1) {
                      _cuisineTypes.remove(c);
                    }
                  });
                },
                selectedColor: FASTPro.teal.withValues(alpha: 0.14),
                backgroundColor: context.fast.card,
                checkmarkColor: onSel,
                side: BorderSide(color: sel ? FASTPro.teal : context.fast.line),
                shape: const StadiumBorder(),
              );
            }).toList(),
          ),
          const SizedBox(height: FASTSpace.s40),
          _buildTimeSlider(
            tr(context, 'normal_prep'),
            _normalPrepTime,
            5,
            60,
            FASTPro.teal,
            (val) => setState(() => _normalPrepTime = val),
          ),
          const SizedBox(height: 24),
          _buildTimeSlider(
            tr(context, 'rush_prep'),
            _rushPrepTime,
            10,
            90,
            FASTBrand.error,
            (val) => setState(() => _rushPrepTime = val),
          ),
          const SizedBox(height: 24),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _formError!,
                textAlign: TextAlign.center,
                style: FASTText.body.copyWith(color: FASTBrand.error),
              ),
            ),
          const SizedBox(height: 8),
          FastButton(
            label: tr(context, 'save_dashboard'),
            onPressed: _formLoading ? null : _nextStep,
            loading: _formLoading,
            kind: FastButtonKind.ink,
          ),
          const SizedBox(height: 20),
          // Assistant path — a staff member redeems the owner's code here
          // instead of creating their own restaurant.
          Center(
            child: TextButton.icon(
              onPressed: _formLoading ? null : _showInviteCodeSheet,
              icon: Icon(
                Icons.vpn_key_outlined,
                size: 18,
                color: context.fast.t2,
              ),
              label: Text(
                tr(context, 'have_invite_code'),
                style: FASTText.body.copyWith(
                  color: context.fast.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeSheet() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
          side: BorderSide(color: context.fast.line),
        ),
        title: Text(
          tr(context, 'join_with_code'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          cursorColor: FASTPro.teal,
          style: FASTText.price.copyWith(color: context.fast.t1),
          // Invite codes look like FAST-XXXX-XXXX (backend staff.controller).
          decoration: _input(
            tr(context, 'invite_code'),
          ).copyWith(hintText: 'FAST-XXXX-XXXX'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: context.fast.t2),
            child: Text(
              tr(context, 'cancel'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (ctx2, auth, _) => FilledButton(
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      final ok = await auth.redeemInviteCode(
                        codeCtrl.text.trim(),
                      );
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        _finishOnboarding();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: FASTPro.teal,
                foregroundColor: FASTBrand.onAmber,
                shape: const StadiumBorder(),
              ),
              child: Text(
                tr(context, 'join_with_code'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(
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
            Expanded(
              child: Text(
                title,
                style: FASTText.item.copyWith(color: context.fast.t1),
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            Text(
              '${value.round()} min',
              style: FASTText.price.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: FASTSpace.s8),
        Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: FASTSpace.s8),
              child: Text(
                '${min.round()}',
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24.0,
                  ),
                  activeTrackColor: color,
                  inactiveTrackColor: context.fast.line,
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.15),
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
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: FASTSpace.s8),
              child: Text(
                '${max.round()}',
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
