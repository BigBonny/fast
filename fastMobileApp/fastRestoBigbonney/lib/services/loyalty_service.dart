import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

/// Loyalty cards — progress is computed by the backend from paid,
/// completed orders; the app only displays it and asks to use a reward.
class LoyaltyService {
  final ApiClient _api = ApiClient();

  Future<List<LoyaltyCard>> myCards() async {
    final data = await _api.get(ApiConfig.loyaltyCards);
    return (data as List<dynamic>)
        .map((e) => LoyaltyCard.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Uses the completed card at [restaurantId]. Throws when the card
  /// isn't complete (or the programme was switched off meanwhile).
  Future<void> redeem(String restaurantId) async {
    await _api.post(ApiConfig.redeemLoyalty(restaurantId), body: const {});
  }
}
