// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'models.dart';
import 'provider.dart';
import 'resto_provider.dart';
import 'theme.dart';
import 'api/api_client.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/commandes_screen.dart';
import 'screens/account_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/resto/onboarding_screen.dart' as resto_onboarding;
import 'screens/resto/kitchen_screen.dart';
import 'screens/group_screen.dart';
import 'screens/livreur_screen.dart';
import 'screens/driver_account_screen.dart';
import 'widgets/client_drawer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Set up 401 auto-logout handler
  ApiClient.onUnauthorized = () {
    // This will be connected to AuthProvider after providers are created
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => FASTProvider()),
        ChangeNotifierProvider(create: (context) => RestoProvider()),
      ],
      child: const FASTApp(),
    ),
  );
}

class FASTApp extends StatefulWidget {
  const FASTApp({super.key});

  @override
  State<FASTApp> createState() => _FASTAppState();
}

class _FASTAppState extends State<FASTApp> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _onboardingDone = false;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleStripeReturn();
    }
  }

  Future<void> _initDeepLinks() async {
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _processStripeUri(uri);
    });
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _processStripeUri(initial);
    } catch (_) {}
  }

  void _processStripeUri(Uri uri) {
    if (uri.scheme != 'fast' || uri.host != 'checkout') return;
    final sessionId = uri.queryParameters['session_id'] ??
        uri.queryParameters['sessionId'];
    if (sessionId != null && sessionId.isNotEmpty) {
      _confirmStripeSession(sessionId);
    }
  }

  Future<void> _handleStripeReturn() async {
    final pending = await FASTProvider.loadPendingStripeSession();
    if (pending != null && pending.isNotEmpty) {
      await _confirmStripeSession(pending);
    }
  }

  Future<void> _confirmStripeSession(String sessionId) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.isRestaurant || auth.isLivreur) return;
    final fastProv = context.read<FASTProvider>();
    final ok = await fastProv.confirmStripeCheckout(sessionId);
    if (ok && mounted) {
      fastProv.navigateToScreen('commandes');
    }
  }

  Future<void> _initApp() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('fast_onboarding_done') ?? false;

    if (!mounted) return;

    // Theme is loaded by FASTProvider from 'fast_theme_mode' (auto is the
    // default and persists). The legacy 'fast_theme_dark' bool is ignored —
    // it used to override the choice on every cold start.
    final fastProv = context.read<FASTProvider>();
    if (prefs.containsKey('fast_theme_dark')) {
      await prefs.remove('fast_theme_dark');
    }

    // Connect 401 handler to trigger logout (guard against re-entrancy)
    ApiClient.onUnauthorized = () {
      if (!auth.isLoggedIn) return;
      auth.logout();
    };

    await auth.autoLogin();

    // Sync user data from AuthProvider to FASTProvider on cold start
    if (auth.isLoggedIn && mounted) {
      final user = auth.user;
      if (user != null) {
        fastProv.syncFromAuth(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          points: user.points,
        );
      }
      // Load restaurants, orders, notifications from API
      fastProv.loadFromApi();
    }

    if (mounted) {
      await _handleStripeReturn();
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.watch<FASTProvider>();
    return MaterialApp(
      title: 'FAST - Click & Collect',
      debugShowCheckedModeBanner: false,
      themeMode: fast.themeMode,
      theme: FASTTheme.light(),
      darkTheme: FASTTheme.dark(),
      locale: Locale(fast.appLanguage),
      supportedLocales: const [
        Locale('fr'), Locale('en'), Locale('tr'), Locale('ar'),
        Locale('hi'), Locale('bn'), Locale('ur'), Locale('bm'),
        Locale('wo'), Locale('ln'), Locale('es'), Locale('pt'),
        Locale('it'), Locale('zh'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const _SplashScreen();
    }

    // Show onboarding on first install
    if (!_onboardingDone) {
      return OnboardingScreen(
        onDone: () {
          setState(() {
            _onboardingDone = true;
          });
        },
      );
    }

    final auth = context.watch<AuthProvider>();
    final fast = context.watch<FASTProvider>();
    if (auth.isLoggedIn) {
      // Cook/guest accounts land straight on the kitchen board —
      // no stats, no payments, no settings.
      if (auth.user?.isStaff ?? false) {
        return const KitchenScreen();
      }
      if (auth.isRestaurant && !fast.viewAsClient) {
        return const resto_onboarding.OnboardingScreen();
      }
      if (auth.isLivreur) {
        return const DriverShell();
      }
      return const MainShell();
    }

    return const RoleSelectionScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return       Scaffold(
      backgroundColor: context.fast.bg,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late AnimationController _toastController;
  late Animation<Offset> _toastSlide;
  String _toastTitle = '';
  String _toastBody = '';
  bool _toastVisible = false;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _toastSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _toastController.dispose();
    super.dispose();
  }

  void _showTopToast(String title, String body) {
    setState(() {
      _toastTitle = title;
      _toastBody = body;
      _toastVisible = true;
    });
    _toastController.forward(from: 0);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _toastController.reverse().then((_) {
        if (mounted) setState(() => _toastVisible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);

    // Top toast trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.toast != null) {
        _showTopToast(provider.toast!['title']!, provider.toast!['body']!);
        provider.dismissToast();
      }
    });

    Widget activeBody;
    switch (provider.currentScreen) {
      case 'restaurant':
        activeBody = const RestaurantScreen();
        break;
      case 'cart':
        activeBody = const CartScreen();
        break;
      case 'commandes':
        activeBody = const CommandesScreen();
        break;
      case 'group':
        activeBody = const GroupScreen();
        break;
      case 'home':
      default:
        activeBody = const HomeScreen();
        break;
    }

    return Scaffold(
      drawer: const ClientDrawer(),
      appBar: AppBar(
        backgroundColor: context.fast.bg.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: context.fast.t1),
        title: GestureDetector(
          onTap: () {
            provider.selectRestaurant(null);
            provider.navigateToScreen('home');
          },
          child: Row(
            children: [
              // Logo mark: zap + gradient FAST wordmark (matches website Navbar)
              const Icon(Icons.bolt, color: FASTBrand.amber, size: 22),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFF59E0B),
                    Color(0xFFFBBF24),
                    Color(0xFFF97316),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'FAST',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.bolt, color: FASTBrand.amber, size: 22),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8B3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C8B3).withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                provider.userInitial.isNotEmpty ? provider.userInitial : 'D',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: FASTBrand.onAmber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Screen content
          Positioned.fill(
            child: activeBody,
          ),

          // Top iOS-style toast overlay
          if (_toastVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SlideTransition(
                    position: _toastSlide,
                    child: GestureDetector(
                      onTap: () {
                        _toastController.reverse().then((_) {
                          if (mounted) setState(() => _toastVisible = false);
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.fast.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.fast.line),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [ Icon( Icons.notifications_active,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                                  SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [ Text(
                                    _toastTitle,
                                    style: TextStyle(
                                      color: context.fast.t1,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (_toastBody.isNotEmpty) ...[
                                          SizedBox(height: 2), Text(
                                      _toastBody,
                                      style: TextStyle(
                                        color: context.fast.t3,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Persistent Floating Basket summary (when on home screen and cart count > 0)
          if (provider.currentScreen == 'home' && provider.cartCount > 0 && provider.selectedRestaurant != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: GestureDetector(
                onTap: () => provider.navigateToScreen('cart'),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${provider.cartCount}',
                              style: TextStyle(
                                color: FASTBrand.onAmber,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                                SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [ Text(
                                provider.tr('view_cart'),
                                style: TextStyle(
                                  color: FASTBrand.onAmber,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ), Text(
                                '${provider.tr('at_restaurant')} ${provider.selectedRestaurant!.name}',
                                style: TextStyle(
                                  color: FASTBrand.onAmber.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [ Text(
                            '€${provider.cartTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: FASTBrand.onAmber,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                                SizedBox(width: 4), Icon( Icons.chevron_right,
                            color: FASTBrand.onAmber,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.fast.card,
          border:       Border(
            top: BorderSide(color: context.fast.line, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _getBottomNavIndex(provider.currentScreen),
          onTap: (index) {
            final screen = _getScreenFromIndex(index);
            provider.navigateToScreen(screen);
          },
          backgroundColor: context.fast.card,
          selectedItemColor: Color(0xFFF59E0B),
          unselectedItemColor: context.fast.t3,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: [
                  BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.restaurant),
              ),
              label: provider.tr('nav_restaurants'),
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Stack(
                  children: [ Icon(Icons.shopping_bag_outlined),
                    if (provider.cartCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints:       BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '${provider.cartCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              label: provider.tr('nav_cart'),
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Stack(
                  children: [
                    const Icon(Icons.assignment_outlined),
                    if (provider.orders.any((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled))
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              label: provider.tr('nav_orders'),
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.group_outlined),
              ),
              label: provider.tr('nav_group'),
            ),
          ],
        ),
      ),
    );
  }

  int _getBottomNavIndex(String currentScreen) {
    switch (currentScreen) {
      case 'home':
      case 'restaurant':
        return 0;
      case 'cart':
        return 1;
      case 'commandes':
        return 2;
      case 'group':
        return 3;
      default:
        return 0;
    }
  }

  String _getScreenFromIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'cart';
      case 2:
        return 'commandes';
      case 3:
        return 'group';
      default:
        return 'home';
    }
  }

}

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final fast = context.watch<FASTProvider>();
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          LivreurScreen(),
          DriverAccountScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: context.fast.bg,
        selectedItemColor: Color(0xFF10B981),
        unselectedItemColor: context.fast.t3,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: fast.tr('nav_deliver')),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: fast.tr('my_account')),
        ],
      ),
    );
  }
}

