import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// System-level notifications shown by the app itself (no FCM needed):
/// fired when a realtime socket event lands, or by the proximity watcher.
class LocalPushService {
  LocalPushService._();
  static final LocalPushService instance = LocalPushService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1;

  /// Notification action tapped (e.g. "J'arrive dans 5 min") —
  /// (actionId, payload = orderId).
  void Function(String actionId, String? payload)? onAction;

  static const String _channelId = 'fast_updates';
  static const String _channelName = 'FAST';
  static const String _channelDesc =
      'Commandes, restaurants et mises à jour FAST';
  static const String etaCategory = 'fast_order_eta';
  static const String eta5Action = 'eta5';
  static const String eta15Action = 'eta15';

  /// Deterministic id per order for scheduled reminders (cancel on
  /// completion without tracking a map).
  static int reminderIdFor(String orderId) =>
      0x40000000 + (orderId.hashCode & 0x3FFFFFFF);

  Future<void> init({String eta5Label = '', String eta15Label = ''}) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      tzdata.initializeTimeZones();
      final iosSettings = DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            etaCategory,
            actions: [
              DarwinNotificationAction.plain(eta5Action, eta5Label),
              DarwinNotificationAction.plain(eta15Action, eta15Label),
            ],
            options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
          ),
        ],
      );
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          final actionId = response.actionId;
          if (actionId != null && actionId.isNotEmpty) {
            onAction?.call(actionId, response.payload);
          }
        },
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    } catch (_) {
      // No plugin implementation on this platform (tests, desktop) —
      // system notifications are a bonus, never a blocker.
      _initialized = false;
    }
  }

  bool _permissionRequested = false;

  /// Runtime permission — asked lazily the first time a real notification
  /// is about to appear, not over the intro slides at first login.
  Future<void> requestPermission() async {
    if (!_initialized || _permissionRequested || kIsWeb) return;
    _permissionRequested = true;
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  NotificationDetails _details({List<AndroidNotificationAction>? actions}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          actions: actions,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: actions != null ? etaCategory : null,
        ),
      );

  /// Show a system notification now. Silently no-ops before [init].
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await requestPermission();
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: _details(),
        payload: payload,
      );
    } catch (_) {}
  }

  /// Interactive order notification with ETA action buttons —
  /// "J'arrive dans 5 min" / "Dans 15 min". Payload carries the orderId
  /// so the tap can be relayed to the restaurant via the delay endpoint.
  Future<void> showOrderActions({
    required String title,
    required String body,
    required String orderId,
    required String eta5Label,
    required String eta15Label,
  }) async {
    if (!_initialized) return;
    await requestPermission();
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: _details(
          actions: [
            AndroidNotificationAction(eta5Action, eta5Label),
            AndroidNotificationAction(eta15Action, eta15Label),
          ],
        ),
        payload: orderId,
      );
    } catch (_) {}
  }

  /// Schedule the responsibility reminder a few minutes out ("your order
  /// is still waiting") — cancelled when the order completes.
  Future<void> scheduleReminder({
    required String orderId,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    if (!_initialized) return;
    await requestPermission();
    try {
      await _plugin.zonedSchedule(
        id: reminderIdFor(orderId),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelReminderFor(String orderId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: reminderIdFor(orderId));
    } catch (_) {}
  }
}
