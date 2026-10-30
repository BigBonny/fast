import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';
import 'upload_service.dart';

class MenuService {
  final _api = ApiClient();

  Future<List<MenuItem>> getMenuByRestaurant(String restaurantId) async {
    final data = await _api.get(ApiConfig.managedMenuByRestaurant(restaurantId));
    final list = data as List<dynamic>;
    return list
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuItem> createItem(
    String restaurantId,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post(
      ApiConfig.menuByRestaurant(restaurantId),
      body: body,
    );
    return MenuItem.fromApiJson(data as Map<String, dynamic>);
  }

  Future<MenuItem> updateItem(String id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.menuItem(id), body: body);
    return MenuItem.fromApiJson(data as Map<String, dynamic>);
  }

  /// F06 — AI-proposed description (reviewed by the owner, never
  /// auto-saved; allergens are never invented server-side).
  Future<String> enhanceDescription(String id) async {
    final data = await _api.post(ApiConfig.enhanceMenuItem(id));
    return (data as Map<String, dynamic>)['description'] as String? ?? '';
  }

  /// AI-generated realistic photo for a dish — used when the owner
  /// hasn't uploaded their own. Returns an absolute URL.
  Future<String> generateDishPhoto({
    required String name,
    String? description,
    String? category,
  }) async {
    final data = await _api.post(
      ApiConfig.menuAiPhoto,
      body: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return UploadService.absoluteUrl(
      (data as Map<String, dynamic>)['imageUrl'] as String? ?? '',
    );
  }

  /// One tap: AI photos for every dish still missing one. The backend
  /// bakes a small chunk per call (real image bytes take seconds each),
  /// so this loops while `remaining` > 0; [onBatch] fires per chunk so
  /// the caller can patch the local menu progressively. Returns the
  /// generated image URL keyed by item id — a full refetch would also
  /// resurrect rows deleted earlier in the session before `deletedAt`.
  Future<Map<String, String>> generateMenuPhotos(
    String restaurantId, {
    void Function(Map<String, String> batch)? onBatch,
  }) async {
    final photos = <String, String>{};
    for (var guard = 0; guard < 50; guard++) {
      final data = await _api.post(
        ApiConfig.menuAiPhotos(restaurantId),
        timeout: const Duration(seconds: 60),
      );
      final map = data as Map<String, dynamic>;
      final items = map['items'] as List<dynamic>? ?? const [];
      final batch = {
        for (final e in items)
          (e as Map<String, dynamic>)['id'] as String:
              e['imageUrl'] as String,
      };
      photos.addAll(batch);
      onBatch?.call(batch);
      final remaining = (map['remaining'] as num?)?.toInt() ?? 0;
      // Older deploys have no `remaining` — one call fills everything.
      if (remaining <= 0 || batch.isEmpty) break;
    }
    return photos;
  }

  Future<void> deleteItem(String id) async {
    await _api.delete(ApiConfig.menuItem(id));
  }

  Future<MenuItem> toggleAvailability(String id, bool available) async {
    final data = await _api.patch(
      ApiConfig.menuItem(id),
      body: {'isAvailable': available},
    );
    return MenuItem.fromApiJson(data as Map<String, dynamic>);
  }

  Future<MenuItemSupplement> addSupplement(
    String menuItemId,
    String name,
    double price,
  ) async {
    final data = await _api.post(
      ApiConfig.menuItemSupplements(menuItemId),
      body: {'name': name, 'price': price},
    );
    return MenuItemSupplement.fromJson(data as Map<String, dynamic>);
  }

  Future<MenuItemSupplement> updateSupplement(
    String supplementId,
    String name,
    double price,
  ) async {
    final data = await _api.patch(
      ApiConfig.menuSupplement(supplementId),
      body: {'name': name, 'price': price},
    );
    return MenuItemSupplement.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSupplement(String supplementId) async {
    await _api.delete(ApiConfig.menuSupplement(supplementId));
  }
}
