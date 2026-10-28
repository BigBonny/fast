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

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.fast.bg,
          // extendBody stays off: the Scaffold reserves the nav pill's
          // footprint so page content (save/disconnect buttons) can
          // never scroll underneath it and get hidden.
          extendBody: false,
          appBar: AppBar(
            backgroundColor: FASTPro.header,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 52,
            titleSpacing: 16,
            iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          FASTPro.logoGradient.createShader(b),
                      child: const Text(
                        '⚡ FAST',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: FASTPro.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: FASTPro.teal.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: FASTPro.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Green live dot
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'RESTAURATEUR PRO',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                key: _kitchenKey,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KitchenScreen()),
                  );
                },
                icon: Icon(Icons.soup_kitchen, size: 18),
                label: Text(
                  tr(context, 'kitchen_btn'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FASTPro.teal.withValues(alpha: 0.15),
                  foregroundColor: FASTPro.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
            accent: FASTPro.teal,
            surface: FASTPro.header,
            line: const Color(0xFF1E293B),
            inactive: const Color(0xFF94A3B8),
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
          colors: [
            Color(0xFFF87171),
            Color(0xFFEF4444),
            Color(0xFFB91C1C),
          ],
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
        backgroundColor: FASTPro.header,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining != null
                      ? tr(
                          context,
                          'rush_off_desc_timed',
                        ).replaceAll('{m}', '$remaining')
                      : tr(context, 'rush_off_desc'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
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
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    tr(context, 'cancel'),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
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
      backgroundColor: FASTPro.header,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'rush_confirm_desc'),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, 'rush_duration'),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
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
                          onSelected: (_) => setSheetState(() => selected = m),
                          selectedColor: const Color(0xFFEF4444),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: selected == m
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide(
                            color: selected == m
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ChoiceChip(
                        label: Text(tr(context, 'rush_until_off')),
                        selected: selected == null,
                        onSelected: (_) => setSheetState(() => selected = null),
                        selectedColor: const Color(0xFFEF4444),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: selected == null
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide(
                          color: selected == null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF334155),
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
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(
                      tr(context, 'cancel'),
                      style: const TextStyle(color: Color(0xFF94A3B8)),
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
        _ready =
            _connected && (status['chargesEnabled'] as bool? ?? false);
      });
    } catch (_) {
      // Status check failing (e.g. Stripe not configured server-side)
      // shouldn't nag the owner — the settings banner still shows it.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        widget.onSetup();
        _refresh();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: const Color(0xFFF59E0B),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(
                  context,
                  _connected ? 'stripe_connected' : 'stripe_required',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
