import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services/order_service.dart';
import 'services/menu_service.dart';
import 'services/restaurant_service.dart';
import 'services/stats_service.dart';
import 'models/resto_stats.dart';
import 'api/api_exceptions.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'l10n/app_strings.dart';
import 'services/local_push_service.dart';

class RestoProvider extends ChangeNotifier {
  RestaurantSettings? _settings;
  bool _isRgpdAccepted = false;
  bool _isTutorialDone = false;
  bool _skipSplash = false;
  bool _isRushMode = false;
  DateTime? _rushEndsAt;
  Timer? _rushTimer;
  String _theme = 'dark'; // data-theme equivalent

  // Orders specific to Resto
  List<Order> _restoOrders = [];
  /// Order IDs already surfaced to the owner — new ones trigger an alert.
  /// Null until the first successful fetch so a restart never re-alerts.
  Set<String>? _seenOrderIds;

  // Menu
  List<MenuItem> _menu = [];
  bool _menuLoading = false;

  // Restaurant analytics
  RestoStats? _stats;
  bool _statsLoading = false;
  String? _statsError;
  int _statsPeriodDays = 7;
  int _statsRequestId = 0;

  // API state
  bool _isApiLoaded = false;
  String? _restaurantId;
  String? _error;
  Timer? _pollTimer;
  int _sessionGeneration = 0;
  bool _menuOnly = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void resetSession() {
    _sessionGeneration++;
    _statsRequestId++;
    _seenOrderIds = null;
    stopPolling();
    _settings = null;
    _restaurantId = null;
    _restoOrders = [];
    _menu = [];
    _stats = null;
    _statsError = null;
    _menuLoading = false;
    _statsLoading = false;
    _isApiLoaded = false;
    _isRushMode = false;
    _rushEndsAt = null;
    _rushTimer?.cancel();
    _rushTimer = null;
    _error = null;
    notifyListeners();
  }

  final _orderService = OrderService();
  final _menuService = MenuService();
  final _statsService = StatsService();

  // Getters
  RestaurantSettings? get settings => _settings;
  bool get isRgpdAccepted => _isRgpdAccepted;
  bool get isTutorialDone => _isTutorialDone;
  bool get skipSplash => _skipSplash;
  bool get isRushMode => _isRushMode;

  /// Minutes left in the current timed rush — null when the rush is
  /// open-ended ("until turned off") or inactive.
  int? get rushMinutesRemaining {
    if (!_isRushMode || _rushEndsAt == null) return null;
    final seconds = _rushEndsAt!.difference(DateTime.now()).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 60).ceil();
  }

  String get theme => _theme;
  List<Order> get restoOrders => _restoOrders;
  List<MenuItem> get menu => _menu;
  bool get menuLoading => _menuLoading;
  RestoStats? get stats => _stats;
  bool get statsLoading => _statsLoading;
  String? get statsError => _statsError;
  int get statsPeriodDays => _statsPeriodDays;
  bool get isApiLoaded => _isApiLoaded;
  String? get restaurantId => _restaurantId;
  String? get error => _error;

  RestoProvider() {
    _loadState();
  }

  /// Clear error so UI can dismiss it
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load orders from API and start polling
  Future<void> loadFromApi({
    String? restaurantId,
    bool menuOnly = false,
  }) async {
    final generation = ++_sessionGeneration;
    stopPolling();
    _restaurantId = restaurantId;
    _menuOnly = menuOnly;
    if (menuOnly) {
      _restoOrders = [];
      await loadMenu();
    } else {
      await Future.wait([refreshOrders(), loadMenu()]);
    }
    if (_disposed || generation != _sessionGeneration) return;
    _isApiLoaded = true;
    if (!menuOnly) _startPolling();
    _reconcileRushWithServer();
    notifyListeners();
  }

  /// Aligns the local rush flag with the server's `isRushMode` — covers
  /// a timed rush that expired while the app was closed and any drift
  /// between this device and the backend.
  Future<void> _reconcileRushWithServer() async {
    final generation = _sessionGeneration;
    try {
      final data = await RestaurantService().getMyRestaurant();
      if (_disposed || generation != _sessionGeneration) return;
      final serverRush = data['isRushMode'] == true;
      if (serverRush == _isRushMode) return;
      final res = await ApiClient().post(ApiConfig.toggleRush);
      if (_disposed || generation != _sessionGeneration) return;
      if (res is Map && res['isRushMode'] is bool) {
        _isRushMode = res['isRushMode'] as bool;
      } else {
        _isRushMode = !_isRushMode;
      }
      if (!_isRushMode) _rushEndsAt = null;
      _scheduleRushTimer();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fast_rush', _isRushMode);
      notifyListeners();
    } catch (_) {}
  }

  // ─── Menu CRUD ──────────────────────────────────────────────

  Future<void> loadMenu() async {
    if (_restaurantId == null) return;
    _menuLoading = true;
    notifyListeners();
    try {
      final generation = _sessionGeneration;
      final items = await _menuService.getMenuByRestaurant(_restaurantId!);
      if (_disposed || generation != _sessionGeneration) return;
      _menu = items;
      _error = null;
    } catch (e) {
      _error = _extractErrorMessage(e);
    }
    _menuLoading = false;
    notifyListeners();
  }

  Future<void> loadStats({int? periodDays}) async {
    final nextPeriod = periodDays ?? _statsPeriodDays;
    if (nextPeriod != 7 && nextPeriod != 30 && nextPeriod != 90) return;

    _statsPeriodDays = nextPeriod;
    _statsLoading = true;
    _statsError = null;
    final requestId = ++_statsRequestId;
    notifyListeners();

    try {
      final result = await _statsService.getRestaurantStats(nextPeriod);
      if (requestId != _statsRequestId) return;
      _stats = result;
    } catch (e) {
      if (requestId != _statsRequestId) return;
      _statsError = _extractErrorMessage(e);
    } finally {
      if (requestId == _statsRequestId) {
        _statsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<MenuItem?> addMenuItem(Map<String, dynamic> body) async {
    if (_restaurantId == null) return null;
    try {
      final item = await _menuService.createItem(_restaurantId!, body);
      _menu.add(item);
      notifyListeners();
      return item;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateMenuItem(String id, Map<String, dynamic> body) async {
    try {
      final updated = await _menuService.updateItem(id, body);
      final idx = _menu.indexWhere((m) => m.id == id);
      if (idx != -1) _menu[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Applies backend-generated photo URLs in place. Faster than a menu
  /// refetch and cannot resurrect items deleted earlier in the session.
  int applyMenuPhotos(Map<String, String> photos) {
    var applied = 0;
    for (var i = 0; i < _menu.length; i++) {
      final url = photos[_menu[i].id];
      if (url == null) continue;
      _menu[i] = _menu[i].copyWith(image: url);
      applied++;
    }
    if (applied > 0) notifyListeners();
    return applied;
  }

  /// Replaces an item already in the loaded menu (e.g. after attaching
  /// supplements to a freshly created dish).
  void replaceMenuItem(MenuItem item) {
    final idx = _menu.indexWhere((m) => m.id == item.id);
    if (idx != -1) {
      _menu[idx] = item;
      notifyListeners();
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      await _menuService.deleteItem(id);
      _menu.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleMenuItemAvailability(String id, bool available) async {
    // Optimistic update
    final idx = _menu.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _menu[idx] = _menu[idx].copyWith(available: available);
      notifyListeners();
    }
    try {
      await _menuService.toggleAvailability(id, available);
    } catch (e) {
      // Rollback on failure
      if (idx != -1) {
        _menu[idx] = _menu[idx].copyWith(available: !available);
      }
      _error = _extractErrorMessage(e);
      notifyListeners();
    }
  }

  /// Fetch the latest orders from the API
  Future<void> refreshOrders() async {
    if (_menuOnly || _restaurantId == null) return;
    final generation = _sessionGeneration;
    try {
      final orders = await _orderService.getRestaurantOrders();
      if (_disposed || generation != _sessionGeneration) return;
      _error = null;
      _alertNewOrders(orders);
      // Skip rebuild when nothing changed — the 15s poll otherwise
      // repaints the whole screen for no reason.
      if (_ordersSignature(orders) == _ordersSignature(_restoOrders)) return;
      _restoOrders = orders;
      notifyListeners();
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
    }
  }

  /// System notification (sound + banner) for every order that appeared
  /// since the last poll. The backend has no push channel on Vercel, so
  /// the 15 s poll is the kitchen's only wake-up call.
  void _alertNewOrders(List<Order> orders) {
    final seen = _seenOrderIds;
    final ids = orders.map((o) => o.id).toSet();
    if (seen == null) {
      _seenOrderIds = ids;
      return;
    }
    for (final o in newPlacedOrders(seen, orders)) {
      unawaited(
        LocalPushService.instance.show(
          title: AppStrings.trNow('notif_new_order_title'),
          body: AppStrings.trNow('notif_new_order_body')
              .replaceAll('{n}', o.items.length.toString())
              .replaceAll('{total}', o.total.toStringAsFixed(2)),
        ),
      );
    }
    _seenOrderIds = ids;
  }

  /// Pure: orders not in [seen] that still await acceptance.
  @visibleForTesting
  static List<Order> newPlacedOrders(Set<String> seen, List<Order> orders) =>
      orders
          .where((o) => !seen.contains(o.id) && o.status == OrderStatus.placed)
          .toList();

  static String _ordersSignature(List<Order> orders) => orders
      .map(
        (o) =>
            '${o.id}:${o.status}:${o.prepTimerSeconds}:${o.prepStartedAt}:${o.gpsProgress}:${o.isReadyAtEntrance}:${o.clientDelayMin}',
      )
      .join('|');

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshOrders();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadState() async {
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || generation != _sessionGeneration) return;

    // Load Settings
    final settingsJson = prefs.getString('fast_resto_settings');
    if (settingsJson != null) {
      try {
        _settings = RestaurantSettings.fromJson(json.decode(settingsJson));
      } catch (e) {
        _settings = null;
      }
    }

    _isRgpdAccepted = prefs.getBool('fast_rgpd_accepted') ?? false;
    _isTutorialDone = prefs.getBool('fast_tutorial_done') ?? false;
    _skipSplash = prefs.getBool('fast_skip_splash') ?? false;
    _isRushMode = prefs.getBool('fast_rush') ?? false;
    final rushUntil = prefs.getInt('fast_rush_until');
    _rushEndsAt = rushUntil != null
        ? DateTime.fromMillisecondsSinceEpoch(rushUntil)
        : null;
    if (_isRushMode &&
        _rushEndsAt != null &&
        !DateTime.now().isBefore(_rushEndsAt!)) {
      // Timed rush expired while the app was closed — restore normal
      // prep locally; the server flag is reconciled on API load.
      _isRushMode = false;
      _rushEndsAt = null;
      await prefs.setBool('fast_rush', false);
      await prefs.remove('fast_rush_until');
    }
    _scheduleRushTimer();
    _theme = prefs.getString('fast_r_theme') ?? 'dark';

    notifyListeners();
  }

  Future<void> updateSettings(RestaurantSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fast_resto_settings',
      json.encode(settings.toJson()),
    );
    notifyListeners();
  }

  Future<void> acceptRgpd() async {
    _isRgpdAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_rgpd_accepted', true);
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    _isTutorialDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_tutorial_done', true);
    notifyListeners();
  }

  Future<void> skipSplashLogic() async {
    _skipSplash = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_skip_splash', true);
    notifyListeners();
  }

  /// Turns Rush Mode on or off. When [minutes] is provided the rush
  /// auto-deactivates at the end of the window — including after an app
  /// restart, via the restored [rushEndsAt].
  Future<void> setRushMode(bool on, {int? minutes}) async {
    _isRushMode = on;
    _rushEndsAt = on && minutes != null
        ? DateTime.now().add(Duration(minutes: minutes))
        : null;
    _scheduleRushTimer();

    // Sync with API — the response is authoritative for the real state.
    if (_isApiLoaded) {
      try {
        final res = await ApiClient().post(ApiConfig.toggleRush);
        if (res is Map && res['isRushMode'] is bool) {
          _isRushMode = res['isRushMode'] as bool;
          if (!_isRushMode) _rushEndsAt = null;
          _scheduleRushTimer();
        }
      } catch (e) {
        _error = _extractErrorMessage(e);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_rush', _isRushMode);
    if (_rushEndsAt != null) {
      await prefs.setInt(
        'fast_rush_until',
        _rushEndsAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('fast_rush_until');
    }
    notifyListeners();
  }

  Future<void> toggleRushMode() => setRushMode(!_isRushMode);

  /// Auto-deactivates a timed rush when its window ends and refreshes
  /// the countdown shown in the UI once a minute.
  void _scheduleRushTimer() {
    _rushTimer?.cancel();
    if (!_isRushMode || _rushEndsAt == null) {
      _rushTimer = null;
      return;
    }
    _rushTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_rushEndsAt == null || !DateTime.now().isBefore(_rushEndsAt!)) {
        setRushMode(false);
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> clearAllSettingsAndRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fast_resto_settings');
    await prefs.remove('fast_rgpd_accepted');
    await prefs.remove('fast_tutorial_done');
    await prefs.remove('fast_skip_splash');

    _settings = null;
    _isRgpdAccepted = false;
    _isTutorialDone = false;
    _skipSplash = false;

    notifyListeners();
  }

  String _extractErrorMessage(dynamic e) {
    if (e is ApiException) return e.message;
    if (e is String) return e;
    return AppStrings.trNow('generic_error');
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    stopPolling();
    super.dispose();
  }
}
