import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/resto_drawer.dart';
import '../../widgets/resto_spotlight_tutorial.dart';
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
          appBar: AppBar(
            backgroundColor: FASTPro.header,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
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
                          fontSize: 20,
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
                    fontSize: 9,
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
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: FASTPro.header,
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _navItem(
                      0,
                      Icons.receipt_long,
                      tr(context, 'nav_orders'),
                      key: _ordersKey,
                    ),
                    _navItem(
                      1,
                      Icons.restaurant_menu,
                      tr(context, 'menu'),
                      key: _menuKey,
                    ),
                    _rushItem(provider),
                    _navItem(
                      3,
                      Icons.settings,
                      tr(context, 'nav_settings'),
                      key: _settingsKey,
                    ),
                    _navItem(
                      4,
                      Icons.storefront,
                      tr(context, 'nav_profile'),
                      key: _profileKey,
                    ),
                  ],
                ),
              ),
            ),
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

  Widget _navItem(int index, IconData icon, String label, {Key? key}) {
    final active = _currentIndex == index;
    return Expanded(
      child: KeyedSubtree(
        key: key,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? FASTPro.teal : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? FASTPro.teal : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Big glossy red circle raised slightly above the nav bar — opens a
  /// confirmation sheet so Rush Mode can't be toggled accidentally.
  Widget _rushItem(RestoProvider provider) {
    final active = provider.isRushMode;
    return Expanded(
      child: KeyedSubtree(
        key: _statsKey,
        child: InkWell(
          onTap: () => _showRushSheet(provider),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  width: 52,
                  height: 52,
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
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1.5,
                    ),
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
                        top: 6,
                        child: Container(
                          width: 26,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
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
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'RUSH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: active
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
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
