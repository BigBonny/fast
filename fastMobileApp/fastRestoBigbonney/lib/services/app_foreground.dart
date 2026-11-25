import 'package:flutter/widgets.dart';

/// Whether the app is on screen. Polling timers check this and skip
/// their API calls while the app is backgrounded: FCM push covers alerts
/// there, and iOS background location would otherwise keep the timers
/// hitting the API with the phone in a pocket. Updated from the root
/// lifecycle observer in `main.dart`; the screens refresh on resume.
class AppForeground {
  AppForeground._();

  static bool _active = true;

  static bool get isActive => _active;

  /// `inactive` is a transient state (control centre, system sheets,
  /// PaymentSheet) and still counts as foreground.
  static void update(AppLifecycleState state) {
    _active =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }
}
