import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/resto_drawer.dart';
import '../../widgets/resto_spotlight_tutorial.dart';
import '../../widgets/fast_ui.dart';
import 'kitchen_screen.dart';
import 'resto_orders_screen.dart';
import 'resto_menu_screen.dart';
import 'resto_stats_screen.dart';
import 'resto_settings_screen.dart';
import 'resto_profile_screen.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';

class RestoMainShell extends StatefulWidget {
  const RestoMainShell({super.key});

  @override
  State<RestoMainShell> createState() => _RestoMainShellState();
}

class _RestoMainShellState extends State<RestoMainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int _tutorialStep = 0;
  bool _showTutorial = false;

  final _ordersKey = GlobalKey();
  final _kitchenKey = GlobalKey();
  final _menuKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _profileKey = GlobalKey();

  final List<Widget> _pages = [
    const RestoOrdersScreen(),
    const RestoMenuScreen(),
    const RestoStatsScreen(),
    const RestoSettingsScreen(),
    const RestoProfileScreen(),
  ];

  // Nav shows 5 slots — orders, menu, RUSH (action, never selected),
  // settings, profile. The stats page (2) highlights Menu, like before.
  static const _navMap = [0, 1, -1, 3, 4];
  int get _navIndex => _currentIndex == 2 ? 1 : _currentIndex;

  List<_TutorialStep> get _tutorialSteps => [
    _TutorialStep(
      key: _ordersKey,
      navigationIndex: 0,
      title: tr(context, 'tuto1_t'),
      description: tr(context, 'tuto1_d'),
    ),
    _TutorialStep(
      key: _kitchenKey,
      navigationIndex: 0,
      title: tr(context, 'tuto2_t'),
      description: tr(context, 'tuto2_d'),
    ),
    _TutorialStep(
      key: _menuKey,
      navigationIndex: 1,
      title: tr(context, 'tuto3_t'),
      description: tr(context, 'tuto3_d'),
    ),
    _TutorialStep(
      key: _statsKey,
      navigationIndex: 1,
      title: tr(context, 'tuto4_t'),
      description: tr(context, 'tuto4_d'),
    ),
    _TutorialStep(
      key: _settingsKey,
      navigationIndex: 3,
      title: tr(context, 'tuto5_t'),
      description: tr(context, 'tuto5_d'),
    ),
    _TutorialStep(
      key: _profileKey,
      navigationIndex: 4,
      title: tr(context, 'tuto6_t'),
      description: tr(context, 'tuto6_d'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showTutorialIfNeeded(),
    );
  }

  String? get _tutorialPreferenceKey {
    final userId = context.read<AuthProvider>().user?.id;
    return userId == null ? null : 'fast_resto_spotlight_v1_$userId';
  }

  Future<void> _showTutorialIfNeeded() async {
    final key = _tutorialPreferenceKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(key) ?? false)) return;
    _startTutorial();
  }

  void _startTutorial() {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _tutorialStep = 0;
      _currentIndex = _tutorialSteps.first.navigationIndex;
      _showTutorial = true;
    });
  }

  Future<void> _finishTutorial() async {
    final key = _tutorialPreferenceKey;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    }
    if (!mounted) return;
    setState(() {
      _showTutorial = false;
      _currentIndex = 0;
    });
  }

  void _nextTutorialStep() {
    if (_tutorialStep == _tutorialSteps.length - 1) {
      _finishTutorial();
      return;
    }
    final nextStep = _tutorialStep + 1;
    setState(() {
      _tutorialStep = nextStep;
      _currentIndex = _tutorialSteps[nextStep].navigationIndex;
    });
  }

  Rect? _targetRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestoProvider>(context);
    final tutorial = _tutorialSteps[_tutorialStep];
    final fast = context.fast;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: fast.bg,
          // extendBody stays off: the Scaffold reserves the nav pill's
          // footprint so page content (save/disconnect buttons) can
          // never scroll underneath it and get hidden.
          extendBody: false,
          appBar: AppBar(
            backgroundColor: fast.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 56,
            titleSpacing: FASTSpace.s4,
            iconTheme: IconThemeData(color: fast.t1),
            // Scales down instead of overflowing when a long kitchen
            // label leaves the wordmark little room.
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            FASTBrand.neonGradient.createShader(b),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: Colors.white,
                              size: 20,
                            ),
                            Text(
                              'FAST',
                              style: FASTText.title.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FASTSpace.s8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FASTPro.teal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          border: Border.all(
                            color: FASTPro.teal.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'PRO',
                          style: FASTText.label.copyWith(
                            color: isDark ? FASTPro.teal : FASTPro.tealDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: FASTBrand.success, // Green live dot
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'RESTAURATEUR PRO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FASTText.caption.copyWith(
                      color: fast.t3,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                key: _kitchenKey,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KitchenScreen()),
                  );
                },
                icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
                label: Text(
                  tr(context, 'kitchen_btn'),
                  style: FASTText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: fast.t1,
                  side: BorderSide(color: fast.line),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FASTSpace.s12,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(width: FASTSpace.s16),
            ],
          ),
          drawer: RestoDrawer(
            onNavigate: (index) => setState(() => _currentIndex = index),
            onReplayTutorial: _startTutorial,
          ),
          body: Column(
            children: [
              if (provider.isRushMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: FASTPro.magenta,
                  child: Text(
                    provider.rushMinutesRemaining != null
                        ? '${tr(context, 'rush_banner')}  ·  ${tr(context, 'rush_remaining').replaceAll('{m}', '${provider.rushMinutesRemaining}')}'
                        : tr(context, 'rush_banner'),
                    textAlign: TextAlign.center,
                    style: FASTText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              _StripeSetupBanner(
                onSetup: () => setState(() => _currentIndex = 3),
              ),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
          bottomNavigationBar: FastNavBar(
            // Same calm bar as the customer shell: flat pill behind the
            // selected tab, 12 pt labels that ellipsize when tight.
            calm: true,
            calmPill: FASTPro.teal,
            calmOnPill: FASTBrand.onAmber,
            currentIndex: _navIndex,
            onTap: (i) {
              if (i == 2) {
                _showRushSheet(provider);
                return;
              }
              setState(() => _currentIndex = _navMap[i]);
            },
            itemKeys: [
              _ordersKey,
              _menuKey,
              _statsKey,
              _settingsKey,
              _profileKey,
            ],
            items: [
              FastNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: tr(context, 'nav_orders'),
              ),
              FastNavItem(
                icon: Icons.restaurant_menu_outlined,
                activeIcon: Icons.restaurant_menu,
                label: tr(context, 'menu'),
              ),
              FastNavItem(
                icon: Icons.warning_rounded,
                label: 'RUSH',
                customIcon: _rushButton(provider),
              ),
              FastNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: tr(context, 'nav_settings'),
              ),
              FastNavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: tr(context, 'nav_profile'),
              ),
            ],
          ),
        ),
        if (_showTutorial)
          RestoSpotlightTutorial(
            targetRect: _targetRect(tutorial.key),
            title: tutorial.title,
            description: tutorial.description,
            step: _tutorialStep,
            totalSteps: _tutorialSteps.length,
            onNext: _nextTutorialStep,
            onSkip: _finishTutorial,
          ),
      ],
    );
  }

  /// Glossy red dome rendered inside the RUSH nav tab — same level as the
  /// other tabs, still visually distinct. Tap opens a confirmation sheet
  /// so Rush Mode can't be toggled accidentally.
  Widget _rushButton(RestoProvider provider) {
    final active = provider.isRushMode;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.9,
          colors: [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFEF4444,
            ).withValues(alpha: active ? 0.65 : 0.35),
            blurRadius: active ? 18 : 10,
            spreadRadius: active ? 2 : 0,
          ),
          const BoxShadow(
            color: Color(0xFF7F1D1D),
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Specular highlight — glossy dome look
          Positioned(
            top: 4,
            child: Container(
              width: 18,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
        ],
      ),
    );
  }

  /// Activation requires a confirm + picks a duration; deactivation is
  /// a single confirm with the remaining time shown.
  Future<void> _showRushSheet(RestoProvider provider) async {
    if (provider.isRushMode) {
      final remaining = provider.rushMinutesRemaining;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: context.fast.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FASTRadius.md),
          ),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, 'rush_off_title'),
                  style: FASTText.title.copyWith(color: context.fast.t1),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining != null
                      ? tr(
                          context,
                          'rush_off_desc_timed',
                        ).replaceAll('{m}', '$remaining')
                      : tr(context, 'rush_off_desc'),
                  style: FASTText.body.copyWith(color: context.fast.t2),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: Text(
                    tr(context, 'rush_deactivate_cta'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FASTBrand.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    tr(context, 'cancel'),
                    style: FASTText.body.copyWith(color: context.fast.t2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed == true) await provider.setRushMode(false);
      return;
    }

    int? selected = 30;
    final confirmed = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: context.fast.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          const durations = [15, 30, 45, 60, 90];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'rush_confirm_title'),
                    style: FASTText.title.copyWith(color: context.fast.t1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'rush_confirm_desc'),
                    style: FASTText.body.copyWith(color: context.fast.t2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fastLabelCase(context, tr(context, 'rush_duration')),
                    style: FASTText.label.copyWith(color: context.fast.t2),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in durations)
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: selected == m,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setSheetState(() => selected = m);
                          },
                          selectedColor: FASTBrand.error,
                          showCheckmark: false,
                          shape: const StadiumBorder(),
                          backgroundColor: context.fast.cardHigh,
                          labelStyle: TextStyle(
                            color: selected == m
                                ? Colors.white
                                : context.fast.t2,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide(
                            color: selected == m
                                ? FASTBrand.error
                                : context.fast.line,
                          ),
                        ),
                      ChoiceChip(
                        label: Text(tr(context, 'rush_until_off')),
                        selected: selected == null,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => selected = null);
                        },
                        selectedColor: FASTBrand.error,
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        backgroundColor: context.fast.cardHigh,
                        labelStyle: TextStyle(
                          color: selected == null
                              ? Colors.white
                              : context.fast.t2,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide(
                          color: selected == null
                              ? FASTBrand.error
                              : context.fast.line,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, selected ?? -1),
                    icon: const Icon(Icons.warning_rounded, size: 18),
                    label: Text(
                      tr(context, 'rush_activate_cta'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FASTBrand.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(
                      tr(context, 'cancel'),
                      style: FASTText.body.copyWith(color: context.fast.t2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != null) {
      await provider.setRushMode(
        true,
        minutes: confirmed == -1 ? null : confirmed,
      );
    }
  }
}

class _TutorialStep {
  final GlobalKey key;
  final int navigationIndex;
  final String title;
  final String description;

  const _TutorialStep({
    required this.key,
    required this.navigationIndex,
    required this.title,
    required this.description,
  });
}

/// Persistent warning shown until the restaurant's Stripe Connect account
/// can receive charges — payouts can't happen without it, so it stays
/// visible instead of being dismissible. Tapping opens Settings; the
/// status re-fetches whenever the app returns to the foreground so
/// finishing onboarding in the browser is picked up immediately.
class _StripeSetupBanner extends StatefulWidget {
  final VoidCallback onSetup;

  const _StripeSetupBanner({required this.onSetup});

  @override
  State<_StripeSetupBanner> createState() => _StripeSetupBannerState();
}

class _StripeSetupBannerState extends State<_StripeSetupBanner>
    with WidgetsBindingObserver {
  bool _ready = true; // optimistic until the first status check resolves
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await PaymentService().getConnectStatus();
      if (!mounted) return;
      setState(() {
        _connected = status['connected'] as bool? ?? false;
        _ready = _connected && (status['chargesEnabled'] as bool? ?? false);
      });
    } catch (_) {
      // Status check failing (e.g. Stripe not configured server-side)
      // shouldn't nag the owner — the settings banner still shows it.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const SizedBox.shrink();
    final fast = context.fast;
    // Action needed keeps a status colour (red), on a quiet tint so it
    // cannot be mistaken for the proximity colour of an order below it.
    return Material(
      color: Color.alphaBlend(FASTBrand.error.withValues(alpha: 0.12), fast.bg),
      child: InkWell(
        onTap: () {
          widget.onSetup();
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: FASTSpace.s8,
            horizontal: FASTSpace.s16,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: FASTBrand.error,
                size: 18,
              ),
              const SizedBox(width: FASTSpace.s8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    _connected ? 'stripe_connected' : 'stripe_required',
                  ),
                  style: FASTText.caption.copyWith(
                    color: fast.t1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: fast.t2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
