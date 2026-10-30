import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class StripeCheckoutSession {
  final String sessionId;
  final String url;

  StripeCheckoutSession({required this.sessionId, required this.url});

  factory StripeCheckoutSession.fromJson(Map<String, dynamic> json) {
    return StripeCheckoutSession(
      sessionId: json['sessionId'] as String,
      url: json['url'] as String,
    );
  }
}

/// Public Stripe configuration the app needs to bootstrap the native
/// SDK — the publishable key is public by design.
class StripePaymentConfig {
  final String publishableKey;
  final String merchantCountryCode;
  final String? applePayMerchantId;
  final bool googlePayEnabled;
  final bool googlePayTestEnv;

  StripePaymentConfig({
    required this.publishableKey,
    required this.merchantCountryCode,
    this.applePayMerchantId,
    this.googlePayEnabled = false,
    this.googlePayTestEnv = true,
  });

  factory StripePaymentConfig.fromJson(Map<String, dynamic> json) {
    final merchant = json['applePayMerchantId'];
    return StripePaymentConfig(
      publishableKey: json['publishableKey'] as String? ?? '',
      merchantCountryCode:
          json['merchantCountryCode'] as String? ?? 'fr',
      applePayMerchantId:
          merchant is String && merchant.isNotEmpty ? merchant : null,
      googlePayEnabled: json['googlePayEnabled'] as bool? ?? false,
      googlePayTestEnv: json['googlePayTestEnv'] as bool? ?? true,
    );
  }
}

/// Payload for the native PaymentSheet flow — same checkout as the
/// hosted-session path, but confirmed in-app via a PaymentIntent.
class StripePaymentIntent {
  final String paymentIntentId;
  final String clientSecret;
  final String ephemeralKeySecret;
  final String customerId;
  final String checkoutId;

  StripePaymentIntent({
    required this.paymentIntentId,
    required this.clientSecret,
    required this.ephemeralKeySecret,
    required this.customerId,
    required this.checkoutId,
  });

  factory StripePaymentIntent.fromJson(Map<String, dynamic> json) {
    return StripePaymentIntent(
      paymentIntentId: json['paymentIntentId'] as String,
      clientSecret: json['paymentIntentClientSecret'] as String,
      ephemeralKeySecret: json['ephemeralKeySecret'] as String,
      customerId: json['customerId'] as String,
      checkoutId: json['checkoutId'] as String,
    );
  }
}

/// Thrown when the backend can't produce a PaymentIntent (older deploy
/// that still answers with a hosted session) — the caller falls back
/// to the browser Checkout flow.
class PaymentSheetUnavailable implements Exception {}

class PaymentService {
  final ApiClient _api = ApiClient();

  Future<StripePaymentConfig> getPaymentConfig() async {
    final data = await _api.get(ApiConfig.paymentConfig);
    return StripePaymentConfig.fromJson(data as Map<String, dynamic>);
  }

  Future<StripeCheckoutSession> createCheckoutSession({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required int userWalkTimeMin,
    String? groupId,
    FulfillmentType fulfillmentType = FulfillmentType.pickup,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final data = await _api.post(
      ApiConfig.createCheckoutSession,
      body: {
        'restaurantId': restaurantId,
        'items': items,
        'userWalkTimeMin': userWalkTimeMin,
        if (groupId != null) 'groupId': groupId,
        'fulfillmentType': fulfillmentType.apiValue,
        if (fulfillmentType == FulfillmentType.delivery) ...{
          'deliveryAddress': deliveryAddress,
          if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
          if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        },
      },
    );
    return StripeCheckoutSession.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> confirmCheckoutSession(String sessionId) async {
    final data = await _api.post(
      ApiConfig.confirmCheckoutSession(sessionId),
      body: {},
    );
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  /// Native PaymentSheet path — same server-side pricing/checkout row,
  /// but the app confirms a PaymentIntent in-app instead of being sent
  /// to a hosted Checkout page.
  Future<StripePaymentIntent> createPaymentIntent({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required int userWalkTimeMin,
    String? groupId,
    FulfillmentType fulfillmentType = FulfillmentType.pickup,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final data = await _api.post(
      ApiConfig.createCheckoutSession,
      body: {
        'restaurantId': restaurantId,
        'items': items,
        'userWalkTimeMin': userWalkTimeMin,
        'usePaymentSheet': true,
        if (groupId != null) 'groupId': groupId,
        'fulfillmentType': fulfillmentType.apiValue,
        if (fulfillmentType == FulfillmentType.delivery) ...{
          'deliveryAddress': deliveryAddress,
          if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
          if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        },
      },
    );
    final map = data as Map<String, dynamic>;
    if (map['paymentIntentClientSecret'] == null) {
      throw PaymentSheetUnavailable();
    }
    return StripePaymentIntent.fromJson(map);
  }

  Future<Order> confirmPaymentIntent(String intentId) async {
    final data = await _api.post(
      ApiConfig.confirmPaymentIntent(intentId),
      body: {},
    );
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createConnectAccountLink() async {
    final data = await _api.post(ApiConfig.stripeConnectAccountLink, body: {});
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConnectStatus() async {
    final data = await _api.get(ApiConfig.stripeConnectStatus);
    return data as Map<String, dynamic>;
  }
}
