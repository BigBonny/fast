import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import 'local_push_service.dart';

/// Firebase Cloud Messaging — the only path that reaches the device when
/// the app is closed or killed (local notifications die with the process,
/// and the serverless backend cannot hold a socket).
///
/// Degrades gracefully: until google-services.json / GoogleService-Info.plist
/// are dropped into the project, [init] quietly no-ops and the app works
/// exactly as before.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  String? _lastToken;

  /// Initialize Firebase + FCM for this signed-in user. Safe to call on
  /// every login/cold start — heavy work happens once per process.
  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      // Reads the bundled google-services.json / GoogleService-Info.plist.
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      // No Firebase config bundled yet — stay silent, polling still works.
      if (kDebugMode) debugPrint('[FCM] init skipped: $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await _registerToken(messaging);

      // Re-register whenever FCM rotates the token.
      messaging.onTokenRefresh.listen((_) => _registerToken(messaging));

      // FCM does not show system UI while the app is in the foreground —
      // mirror the payload through the local channel so it still pops.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        LocalPushService.instance.show(
          title: n.title ?? 'FAST',
          body: n.body ?? '',
        );
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] setup failed: $e');
    }
  }

  /// Forget this device at logout so pushes stop reaching it.
  Future<void> unregister() async {
    if (!_ready) return;
    _ready = false;
    _lastToken = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null || token.isEmpty || token == _lastToken) return;
    try {
      await ApiClient().post(
        ApiConfig.fcmToken,
        body: {'token': token, 'platform': defaultTargetPlatform.name},
      );
      _lastToken = token;
    } catch (_) {
      // Transient — the next refresh/login retries.
    }
  }
}
