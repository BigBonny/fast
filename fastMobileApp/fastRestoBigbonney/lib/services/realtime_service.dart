import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

/// Live Socket.IO link to the backend — server-side events (notifications,
/// order status changes) land here instead of waiting for the next poll.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  String? _userId;

  /// Fired for every `notification` event (already-created Notification row).
  void Function(PushNotification notification)? onNotification;

  /// Fired on `order:status` — lets the provider refresh the order list.
  void Function(String orderId, String status)? onOrderStatus;

  bool get isConnected => _socket?.connected ?? false;

  /// Socket.IO runs at the API origin — strip the '/api' suffix.
  static String get _socketUrl {
    const base = ApiConfig.baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  void connect(String userId) {
    if (kIsWeb) return;
    final token = ApiClient().token;
    if (token == null || token.isEmpty) return;
    if (_socket != null && _userId == userId) return;
    disconnect();

    _userId = userId;
    try {
      _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .build(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] socket init failed: $e');
      _socket = null;
      return;
    }

    _socket!
      ..onConnect((_) {
        _socket!.emit('join:user', userId);
      })
      ..on('notification', (data) {
        if (data is Map<String, dynamic>) {
          try {
            onNotification?.call(PushNotification.fromApiJson(data));
          } catch (_) {}
        }
      })
      ..on('order:status', (data) {
        if (data is Map) {
          final orderId = '${data['orderId'] ?? ''}';
          final status = '${data['status'] ?? ''}';
          if (orderId.isNotEmpty) onOrderStatus?.call(orderId, status);
        }
      })
      ..onConnectError((e) {
        if (kDebugMode) debugPrint('[WS] connect error: $e');
      });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _userId = null;
  }
}
