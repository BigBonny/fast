import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

// Runs on a background isolate — the restaurant list embeds every menu
// and mapping it on the UI thread noticeably stalls the first frames.
List<Restaurant> _restaurantsFromApi(List<dynamic> data) => data
    .map((e) => Restaurant.fromApiJson(e as Map<String, dynamic>))
    .toList();

class RestaurantService {
  final ApiClient _api = ApiClient();

  Future<List<Restaurant>> listRestaurants({
    String? category,
    String? search,
    String? dietary,
  }) async {
    final params = <String, String>{};
    if (category != null && category != 'all') params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dietary != null) params['dietary'] = dietary;

    final data = await _api.get(
      ApiConfig.restaurants,
      queryParams: params.isNotEmpty ? params : null,
    );
    return compute(_restaurantsFromApi, data as List<dynamic>);
  }

  Future<Restaurant> getRestaurant(String id) async {
    final data = await _api.get(ApiConfig.restaurant(id));
    return Restaurant.fromApiJson(data as Map<String, dynamic>);
  }

  Future<List<MenuItem>> listMenuItems(String restaurantId) async {
    final data = await _api.get(ApiConfig.menuByRestaurant(restaurantId));
    final list = (data as List<dynamic>)
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<MenuItem> createMenuItem(
    String restaurantId,
    Map<String, dynamic> itemData,
  ) async {
    final data = await _api.post(
      ApiConfig.menuByRestaurant(restaurantId),
      body: itemData,
    );
    return MenuItem.fromApiJson(data as Map<String, dynamic>);
  }

  Future<List<MenuItem>> scanMenu(
    String restaurantId,
    String imageBase64,
  ) async {
    final data = await _api.post(
      ApiConfig.scanMenu(restaurantId),
      body: {'imageBase64': imageBase64},
    );
    final list = (data as List<dynamic>)
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// Video menu import — send several frames at once; the backend scans
  /// them all and merges/dedupes the dishes before writing to the DB.
  Future<List<MenuItem>> scanMenuFrames(
    String restaurantId,
    List<String> framesBase64,
  ) async {
    final data = await _api.post(
      ApiConfig.scanMenu(restaurantId),
      body: {'imagesBase64': framesBase64},
    );
    final list = (data as List<dynamic>)
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Map<String, dynamic>> getMyRestaurant() async {
    final data = await _api.get(ApiConfig.myRestaurant);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRestaurant(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.patch(ApiConfig.updateRestaurant(id), body: body);
    return data as Map<String, dynamic>;
  }

  /// Client suggests a restaurant that isn't on FAST yet — ops calls the
  /// restaurant and onboards it.
  Future<void> requestRestaurant({
    required String name,
    String city = '',
    String address = '',
    String phone = '',
    String note = '',
  }) async {
    await _api.post(
      ApiConfig.restaurantRequests,
      body: {
        'name': name,
        'city': city,
        'address': address,
        'phone': phone,
        'note': note,
      },
    );
  }

  /// Admin pipeline — every client suggestion with the requester's
  /// contact info, so ops can call the restaurant and track progress.
  Future<List<Map<String, dynamic>>> listRestaurantRequests({
    String? status,
  }) async {
    final data = await _api.get(
      ApiConfig.restaurantRequests,
      queryParams: status == null ? null : {'status': status},
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateRestaurantRequestStatus(String id, String status) async {
    await _api.patch(
      ApiConfig.restaurantRequestStatus(id),
      body: {'status': status},
    );
  }
}
