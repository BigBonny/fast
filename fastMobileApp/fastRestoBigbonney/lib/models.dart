// lib/models.dart
import 'dart:convert';

/// Tolerant scalar coercion for API payloads. Some backend responses
/// deliver related entities as objects (`{"id": …}` / `{"code": …}`)
/// instead of plain strings — extract a usable scalar instead of
/// throwing `'_Map<String, dynamic>' is not a subtype of 'String?'`.
String? strOrNull(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  if (v is Map<String, dynamic>) {
    return strOrNull(v['id']) ??
        strOrNull(v['code']) ??
        strOrNull(v['name']) ??
        strOrNull(v['status']) ??
        strOrNull(v['message']) ??
        strOrNull(v['url']);
  }
  return null;
}

enum DietaryPreference {
  vegan('Végétalien', 'VEGAN'),
  vegetarian('Végétarien', 'VEGETARIAN'),
  glutenFree('Sans Gluten', 'GLUTEN_FREE'),
  halal('Halal', 'HALAL'),
  keto('Céto', 'KETO'),
  dairyFree('Sans Lactose', 'DAIRY_FREE');

  final String label;
  /// Exact backend enum value — `name.toUpperCase()` produced
  /// "GLUTENFREE"/"DAIRYFREE" which the API rejects.
  final String apiValue;
  const DietaryPreference(this.label, this.apiValue);

  static DietaryPreference fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return DietaryPreference.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == value.toLowerCase() ||
          e.apiValue.toLowerCase() == value.toLowerCase() ||
          e.name.toLowerCase() == normalized,
      orElse: () => DietaryPreference.vegan,
    );
  }
}

/// FAST markup grid (F03) — mirror of backend `fastPricing.ts` so the
/// owner sees the live final price while typing the base price.
double computeFastPrice(double basePrice) {
  if (!basePrice.isFinite || basePrice <= 0) return basePrice;
  final rate = basePrice < 10
      ? 0.125
      : basePrice < 15
          ? 0.10
          : basePrice <= 25
              ? 0.07
              : basePrice <= 100
                  ? 0.05
                  : basePrice <= 500
                      ? 0.02
                      : basePrice <= 1000
                          ? 0.01
                          : 0.005;
  return (basePrice * (1 + rate) * 100).roundToDouble() / 100;
}

/// Locale-safe amount parsing: French keyboards emit `,` for decimals
/// and users may include `€`/spaces — normalize before parsing so
/// "12,50" works like "12.50" instead of failing validation.
double? parseAmount(String input) {
  final cleaned = input
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String image;
  final String category;
  final List<DietaryPreference> dietaryTags;
  final double rating;
  final bool available;
  final List<MenuItemSupplement> supplements;
  final int prepTime; // minutes, 0 = restaurant default
  final int prepTimeRush; // minutes during rush, 0 = fall back to prepTime
  final String videoUrl; // optional story/preview video (mp4…)
  /// The restaurateur's own price — `price` is the FAST-marked-up customer
  /// price. Falls back to `price` for items saved before markup existed.
  final double? basePrice;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.category,
    required this.dietaryTags,
    required this.rating,
    this.available = true,
    this.supplements = const [],
    this.prepTime = 0,
    this.prepTimeRush = 0,
    this.videoUrl = '',
    this.basePrice,
  });

  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? image,
    String? category,
    List<DietaryPreference>? dietaryTags,
    bool? available,
    List<MenuItemSupplement>? supplements,
  }) => MenuItem(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    image: image ?? this.image,
    category: category ?? this.category,
    dietaryTags: dietaryTags ?? this.dietaryTags,
    rating: rating,
    available: available ?? this.available,
    supplements: supplements ?? this.supplements,
    prepTime: prepTime,
    prepTimeRush: prepTimeRush,
    videoUrl: videoUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'image': image,
    'category': category,
    'dietaryTags': dietaryTags.map((t) => t.label).toList(),
    'rating': rating,
    'available': available,
    'prepTime': prepTime,
    'prepTimeRush': prepTimeRush,
    'videoUrl': videoUrl,
    if (basePrice != null) 'basePrice': basePrice,
  };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    price: (json['price'] as num).toDouble(),
    image: json['image'] as String,
    category: json['category'] as String,
    dietaryTags:
        (json['dietaryTags'] as List<dynamic>?)
            ?.map((e) => DietaryPreference.fromString(e as String))
            .toList() ??
        [],
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    available: json['available'] as bool? ?? true,
    prepTime: json['prepTime'] as int? ?? 0,
    prepTimeRush: json['prepTimeRush'] as int? ?? 0,
    videoUrl: json['videoUrl'] as String? ?? '',
    basePrice: (json['basePrice'] as num?)?.toDouble(),
  );

  /// Parse from backend API JSON format
  /// Handles dietaryTags as [{"option": "HALAL"}] and camelCase fields
  factory MenuItem.fromApiJson(Map<String, dynamic> json) => MenuItem(
    id: strOrNull(json['id']) ?? '',
    name: strOrNull(json['name']) ?? '',
    description: strOrNull(json['description']) ?? '',
    price: (json['price'] as num).toDouble(),
    image: strOrNull(json['image']) ?? '',
    category: strOrNull(json['category']) ?? '',
    dietaryTags: _parseDietaryTags(json['dietaryTags']),
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    available:
        json['isAvailable'] as bool? ?? json['available'] as bool? ?? true,
    supplements:
        (json['supplements'] as List<dynamic>?)
            ?.map((s) => MenuItemSupplement.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
    prepTime: json['prepTime'] as int? ?? 0,
    prepTimeRush: json['prepTimeRush'] as int? ?? 0,
    videoUrl: strOrNull(json['videoUrl']) ?? '',
    basePrice: (json['basePrice'] as num?)?.toDouble(),
  );

  static List<DietaryPreference> _parseDietaryTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) {
      return tags.map((e) {
        if (e is String) return DietaryPreference.fromString(e);
        if (e is Map<String, dynamic>) {
          return DietaryPreference.fromString(e['option'] as String? ?? '');
        }
        return DietaryPreference.vegan;
      }).toList();
    }
    return [];
  }
}

class MenuItemSupplement {
  final String id;
  final String name;
  final double price;

  const MenuItemSupplement({
    required this.id,
    required this.name,
    required this.price,
  });

  factory MenuItemSupplement.fromJson(Map<String, dynamic> json) =>
      MenuItemSupplement(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

class Review {
  final String id;
  final String userName;
  final String userEmail;
  final double rating;
  final String comment;
  final String date;

  Review({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userName': userName,
    'userEmail': userEmail,
    'rating': rating,
    'comment': comment,
    'date': date,
  };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    userName: json['userName'] as String,
    userEmail: json['userEmail'] as String,
    rating: (json['rating'] as num).toDouble(),
    comment: json['comment'] as String,
    date: json['date'] as String,
  );

  /// Parse from backend API JSON format
  /// Backend uses "createdAt" instead of "date", no "userEmail"
  factory Review.fromApiJson(Map<String, dynamic> json) => Review(
    id: strOrNull(json['id']) ?? '',
    userName:
        strOrNull(json['userName']) ??
        strOrNull((json['user'] as Map<String, dynamic>?)?['name']) ??
        '',
    userEmail: strOrNull(json['userEmail']) ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    comment: strOrNull(json['comment']) ?? '',
    date: strOrNull(json['createdAt']) ?? strOrNull(json['date']) ?? '',
  );
}

enum FulfillmentType {
  pickup('Retrait'),
  dineIn('Sur place'),
  delivery('Livraison');

  final String label;
  const FulfillmentType(this.label);

  static FulfillmentType fromApi(String value) {
    switch (value.toUpperCase()) {
      case 'DELIVERY':
        return FulfillmentType.delivery;
      case 'DINE_IN':
        return FulfillmentType.dineIn;
      default:
        return FulfillmentType.pickup;
    }
  }

  String get apiValue => switch (this) {
    FulfillmentType.delivery => 'DELIVERY',
    FulfillmentType.dineIn => 'DINE_IN',
    _ => 'PICKUP',
  };
}

/// Emplacement programmé d'un food truck (ex. lundi → Champigny).
/// `weekday` suit la convention Dart : 1 = lundi … 7 = dimanche.
class TruckStop {
  final int weekday;
  final String label;
  final String address;
  final String city;
  final double latitude;
  final double longitude;

  const TruckStop({
    required this.weekday,
    this.label = '',
    this.address = '',
    this.city = '',
    this.latitude = 0,
    this.longitude = 0,
  });

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'label': label,
    'address': address,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// `dayOfWeek` est stocké au format ISO (1 = lundi … 7 = dimanche),
  /// identique à `DateTime.weekday`.
  factory TruckStop.fromJson(Map<String, dynamic> json) {
    return TruckStop(
      weekday: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      label: strOrNull(json['label']) ?? '',
      address: strOrNull(json['address']) ?? '',
      city: strOrNull(json['city']) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Restaurant {
  final String id;
  final String name;
  final String description;
  final String image;
  final String category;
  final String cuisineType;
  final double rating;
  final int reviewsCount;
  final List<Review> reviews;
  final int pickupPrepTime; // in minutes
  final double distance; // in miles
  final List<DietaryPreference> dietaryOptions;
  final List<MenuItem> menu;
  final String address;
  final double latitude;
  final double longitude;
  final bool deliveryEnabled;
  final double deliveryFee;
  final double deliveryRadiusKm;
  final bool paymentsReady;
  final bool allowDineIn;
  final bool reservationsEnabled;
  final bool reservationOnly;
  final bool isFoodTruck;
  final int seatingCapacity;
  final List<TruckStop> truckStops;
  final TruckStop? todayStop;

  Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.category,
    this.cuisineType = '',
    required this.rating,
    required this.reviewsCount,
    required this.reviews,
    required this.pickupPrepTime,
    required this.distance,
    required this.dietaryOptions,
    required this.menu,
    required this.address,
    this.latitude = 48.8566,
    this.longitude = 2.3522,
    this.deliveryEnabled = true,
    this.deliveryFee = 2.99,
    this.deliveryRadiusKm = 5.0,
    this.paymentsReady = true,
    this.allowDineIn = false,
    this.reservationsEnabled = false,
    this.reservationOnly = false,
    this.isFoodTruck = false,
    this.seatingCapacity = 0,
    this.truckStops = const [],
    this.todayStop,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'image': image,
    'category': category,
    'cuisineType': cuisineType,
    'rating': rating,
    'reviewsCount': reviewsCount,
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'pickupPrepTime': pickupPrepTime,
    'distance': distance,
    'latitude': latitude,
    'longitude': longitude,
    'dietaryOptions': dietaryOptions.map((o) => o.label).toList(),
    'menu': menu.map((m) => m.toJson()).toList(),
    'address': address,
    'paymentsReady': paymentsReady,
    'allowDineIn': allowDineIn,
    'reservationsEnabled': reservationsEnabled,
    'reservationOnly': reservationOnly,
    'isFoodTruck': isFoodTruck,
    'seatingCapacity': seatingCapacity,
    'truckStops': truckStops.map((s) => s.toJson()).toList(),
  };

  static List<TruckStop> _parseTruckStops(dynamic list) =>
      (list as List<dynamic>?)
          ?.map((e) => TruckStop.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    image: json['image'] as String,
    category: json['category'] as String,
    cuisineType: json['cuisineType'] as String? ?? '',
    rating: (json['rating'] as num).toDouble(),
    reviewsCount: json['reviewsCount'] as int? ?? 0,
    reviews:
        (json['reviews'] as List<dynamic>?)
            ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    pickupPrepTime: json['pickupPrepTime'] as int? ?? 15,
    distance: (json['distance'] as num?)?.toDouble() ?? 1.0,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 48.8566,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 2.3522,
    dietaryOptions:
        (json['dietaryOptions'] as List<dynamic>?)
            ?.map((e) => DietaryPreference.fromString(e as String))
            .toList() ??
        [],
    menu:
        (json['menu'] as List<dynamic>?)
            ?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    address: strOrNull(json['address']) ?? '',
    deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
    deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 2.99,
    deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
    // Cached entries predate the flag — don't block ordering on stale data.
    paymentsReady: json['paymentsReady'] as bool? ?? true,
    allowDineIn: json['allowDineIn'] as bool? ?? false,
    reservationsEnabled: json['reservationsEnabled'] as bool? ?? false,
    reservationOnly: json['reservationOnly'] as bool? ?? false,
    isFoodTruck: json['isFoodTruck'] as bool? ?? false,
    seatingCapacity: json['seatingCapacity'] as int? ?? 0,
    truckStops: _parseTruckStops(json['truckStops']),
    todayStop: json['todayStop'] != null
        ? TruckStop.fromJson(json['todayStop'] as Map<String, dynamic>)
        : null,
  );

  /// Parse from backend API JSON format
  /// Backend uses "menuItems" key, dietaryOptions as [{"option": "HALAL"}], no reviews in list
  factory Restaurant.fromApiJson(Map<String, dynamic> json) => Restaurant(
    id: strOrNull(json['id']) ?? '',
    name: strOrNull(json['name']) ?? '',
    description: strOrNull(json['description']) ?? '',
    image: strOrNull(json['image']) ?? '',
    category: strOrNull(json['category']) ?? '',
    cuisineType: strOrNull(json['cuisineType']) ?? '',
    rating: (json['rating'] as num).toDouble(),
    reviewsCount: json['reviewsCount'] as int? ?? 0,
    reviews:
        (json['reviews'] as List<dynamic>?)
            ?.map((e) => Review.fromApiJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    pickupPrepTime: json['pickupPrepTime'] as int? ?? 15,
    distance: (json['distance'] as num?)?.toDouble() ?? 1.0,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 48.8566,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 2.3522,
    dietaryOptions: _parseDietaryOptions(json['dietaryOptions']),
    menu:
        (json['menuItems'] as List<dynamic>?)
            ?.map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
            .toList() ??
        (json['menu'] as List<dynamic>?)
            ?.map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    address: strOrNull(json['address']) ?? '',
    deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
    deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 2.99,
    deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
    paymentsReady: json['paymentsReady'] as bool? ?? false,
    allowDineIn: json['allowDineIn'] as bool? ?? false,
    reservationsEnabled: json['reservationsEnabled'] as bool? ?? false,
    reservationOnly: json['reservationOnly'] as bool? ?? false,
    isFoodTruck: json['isFoodTruck'] as bool? ?? false,
    seatingCapacity: json['seatingCapacity'] as int? ?? 0,
    truckStops: _parseTruckStops(json['truckStops']),
    todayStop: json['todayStop'] != null
        ? TruckStop.fromJson(json['todayStop'] as Map<String, dynamic>)
        : null,
  );

  static List<DietaryPreference> _parseDietaryOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) {
      return options.map((e) {
        if (e is String) return DietaryPreference.fromString(e);
        if (e is Map<String, dynamic>) {
          return DietaryPreference.fromString(e['option'] as String? ?? '');
        }
        return DietaryPreference.vegan;
      }).toList();
    }
    return [];
  }
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  final List<String> selectedOptions;
  String allergyNotes;
  CartItem({
    required this.menuItem,
    required this.quantity,
    this.selectedOptions = const [],
    this.allergyNotes = '',
  });

  Map<String, dynamic> toJson() => {
    'menuItem': menuItem.toJson(),
    'quantity': quantity,
    'selectedOptions': selectedOptions,
    'allergyNotes': allergyNotes,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
    selectedOptions:
        (json['selectedOptions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    allergyNotes: json['allergyNotes'] as String? ?? '',
  );

  /// Parse from backend API JSON format
  /// Backend selectedOptions is a JSON string "[]" not a List
  factory CartItem.fromApiJson(
    Map<String, dynamic> json, {
    MenuItem? menuItem,
  }) => CartItem(
    menuItem:
        menuItem ??
        MenuItem.fromApiJson(json['menuItem'] as Map<String, dynamic>? ?? {}),
    quantity: json['quantity'] as int? ?? 1,
    selectedOptions: _parseSelectedOptions(json['selectedOptions']),
    allergyNotes: json['allergyNotes'] as String? ?? '',
  );

  static List<String> _parseSelectedOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) return options.cast<String>();
    if (options is String) {
      try {
        final parsed = jsonDecode(options);
        if (parsed is List) return parsed.cast<String>();
      } catch (_) {}
    }
    return [];
  }
}

enum OrderStatus {
  placed('Commandé'),
  preparing('En préparation'),
  readyForPickup('Prêt pour retrait'),
  completed('Récupéré'),
  cancelled('Annulé');

  final String label;
  const OrderStatus(this.label);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == value.toLowerCase() ||
          e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => OrderStatus.placed,
    );
  }

  /// Parse backend UPPER_SNAKE format (e.g. "READY_FOR_PICKUP")
  static OrderStatus fromApiJson(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => OrderStatus.placed,
    );
  }
}

class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final List<CartItem> items;
  final double subtotal;
  final double serviceFee; // flat €1.50
  final double total;
  OrderStatus status;
  final String createdAt;

  // Client side tracking
  int userWalkTimeMinutes; // Countdown of walk progress
  bool isReadyAtEntrance;
  bool userRatingSubmitted;

  // Resto side tracking (Dashboard & Kitchen)
  String? prepStartedAt;
  int prepTimerSeconds;
  double gpsProgress; // 0 to 100
  bool isBilledAnyway; // For cancelled orders where prep already started
  bool isUrgent; // Green to Orange to Red
  final String? groupCode;
  final String? pickupToken;
  final FulfillmentType fulfillmentType;
  final String deliveryAddress;
  final double deliveryFee;
  final String? deliveryStatus;

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.items,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.userWalkTimeMinutes,
    this.isReadyAtEntrance = false,
    this.userRatingSubmitted = false,
    this.prepStartedAt,
    this.prepTimerSeconds = 0,
    this.gpsProgress = 0.0,
    this.isBilledAnyway = false,
    this.isUrgent = false,
    this.groupCode,
    this.pickupToken,
    this.fulfillmentType = FulfillmentType.pickup,
    this.deliveryAddress = '',
    this.deliveryFee = 0,
    this.deliveryStatus,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'restaurantImage': restaurantImage,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'serviceFee': serviceFee,
    'total': total,
    'status': status.name,
    'createdAt': createdAt,
    'userWalkTimeMinutes': userWalkTimeMinutes,
    'isReadyAtEntrance': isReadyAtEntrance,
    'userRatingSubmitted': userRatingSubmitted,
    'prepStartedAt': prepStartedAt,
    'prepTimerSeconds': prepTimerSeconds,
    'gpsProgress': gpsProgress,
    'isBilledAnyway': isBilledAnyway,
    'isUrgent': isUrgent,
    'groupCode': groupCode,
    'pickupToken': pickupToken,
    'fulfillmentType': fulfillmentType.name,
    'deliveryAddress': deliveryAddress,
    'deliveryFee': deliveryFee,
    'deliveryStatus': deliveryStatus,
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    restaurantId: json['restaurantId'] as String,
    restaurantName: json['restaurantName'] as String,
    restaurantImage: json['restaurantImage'] as String,
    items: (json['items'] as List<dynamic>)
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    subtotal: (json['subtotal'] as num).toDouble(),
    serviceFee: (json['serviceFee'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
    status: OrderStatus.fromString(json['status'] as String),
    createdAt: json['createdAt'] as String,
    userWalkTimeMinutes: json['userWalkTimeMinutes'] as int,
    isReadyAtEntrance: json['isReadyAtEntrance'] as bool? ?? false,
    userRatingSubmitted: json['userRatingSubmitted'] as bool? ?? false,
    prepStartedAt: strOrNull(json['prepStartedAt']),
    prepTimerSeconds: json['prepTimerSeconds'] as int? ?? 0,
    gpsProgress: (json['gpsProgress'] as num?)?.toDouble() ?? 0.0,
    isBilledAnyway: json['isBilledAnyway'] as bool? ?? false,
    isUrgent: json['isUrgent'] as bool? ?? false,
    groupCode: strOrNull(json['groupCode']),
    pickupToken: strOrNull(json['pickupToken']),
    fulfillmentType: FulfillmentType.fromApi(
      strOrNull(json['fulfillmentType']) ?? 'PICKUP',
    ),
    deliveryAddress: strOrNull(json['deliveryAddress']) ?? '',
    deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
    deliveryStatus: strOrNull(
      (json['delivery'] as Map<String, dynamic>?)?['status'],
    ),
  );

  /// Parse from backend API JSON format
  /// Maps userWalkTimeMin → userWalkTimeMinutes, nested restaurant object,
  /// UPPER_SNAKE status, JSON-string selectedOptions
  factory Order.fromApiJson(Map<String, dynamic> json) {
    final restaurantData = json['restaurant'] as Map<String, dynamic>?;
    final itemsData =
        (json['items'] as List<dynamic>?)
            ?.map((e) => CartItem.fromApiJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Order(
      id: strOrNull(json['id']) ?? '',
      restaurantId: strOrNull(json['restaurantId']) ?? '',
      restaurantName:
          strOrNull(restaurantData?['name']) ??
          strOrNull(json['restaurantName']) ??
          '',
      restaurantImage:
          strOrNull(restaurantData?['image']) ??
          strOrNull(json['restaurantImage']) ??
          '',
      items: itemsData,
      subtotal: (json['subtotal'] as num).toDouble(),
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      status: OrderStatus.fromApiJson(strOrNull(json['status']) ?? 'PLACED'),
      createdAt: strOrNull(json['createdAt']) ?? '',
      userWalkTimeMinutes:
          json['userWalkTimeMin'] as int? ??
          json['userWalkTimeMinutes'] as int? ??
          10,
      isReadyAtEntrance: json['isReadyAtEntrance'] as bool? ?? false,
      userRatingSubmitted: json['ratingSubmitted'] as bool? ?? false,
      prepStartedAt: strOrNull(json['prepStartedAt']),
      prepTimerSeconds: json['prepTimerSeconds'] as int? ?? 0,
      gpsProgress: (json['gpsProgress'] as num?)?.toDouble() ?? 0.0,
      isBilledAnyway: json['isBilledAnyway'] as bool? ?? false,
      isUrgent: json['isUrgent'] as bool? ?? false,
      groupCode:
          strOrNull((json['groupOrder'] as Map<String, dynamic>?)?['code']) ??
          strOrNull(json['groupCode']),
      pickupToken: strOrNull(json['pickupToken']),
      fulfillmentType: FulfillmentType.fromApi(
        strOrNull(json['fulfillmentType']) ?? 'PICKUP',
      ),
      deliveryAddress: strOrNull(json['deliveryAddress']) ?? '',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
      deliveryStatus: strOrNull(
        (json['delivery'] as Map<String, dynamic>?)?['status'],
      ),
    );
  }

  bool get isDelivery => fulfillmentType == FulfillmentType.delivery;
}

class PushNotification {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  bool isRead;
  final String type; // 'status' | 'info' | 'success' | 'rating'

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp,
    'isRead': isRead,
    'type': type,
  };

  factory PushNotification.fromJson(Map<String, dynamic> json) =>
      PushNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: json['timestamp'] as String,
        isRead: json['isRead'] as bool? ?? false,
        type: json['type'] as String,
      );

  /// Parse from backend API JSON format
  /// Backend uses "createdAt" instead of "timestamp", type is UPPERCASE
  factory PushNotification.fromApiJson(Map<String, dynamic> json) =>
      PushNotification(
        id: strOrNull(json['id']) ?? '',
        title: strOrNull(json['title']) ?? '',
        body: strOrNull(json['body']) ?? '',
        timestamp:
            strOrNull(json['createdAt']) ?? strOrNull(json['timestamp']) ?? '',
        isRead: json['isRead'] as bool? ?? false,
        type: (strOrNull(json['type']))?.toLowerCase() ?? 'info',
      );
}

class RestaurantSettings {
  final String? id;
  final String managerFirstName;
  final String managerPhone;
  final String managerIban;
  final String name;
  final String description;
  final String image;
  final String cuisineType;
  final String category;
  final String city;
  final String address;
  final int normalPrepTime;
  final int rushPrepTime;
  final List<String> dietaryOptions;

  RestaurantSettings({
    this.id,
    required this.managerFirstName,
    required this.managerPhone,
    this.managerIban = '',
    required this.name,
    this.description = '',
    this.image = '',
    required this.cuisineType,
    this.category = '',
    required this.city,
    this.address = '',
    required this.normalPrepTime,
    required this.rushPrepTime,
    this.dietaryOptions = const [],
  });

  Map<String, dynamic> toJson() => {
    'managerFirstName': managerFirstName,
    'managerPhone': managerPhone,
    'managerIban': managerIban,
    'name': name,
    'description': description,
    'image': image,
    'cuisineType': cuisineType,
    'category': category,
    'city': city,
    'address': address,
    'normalPrepTime': normalPrepTime,
    'rushPrepTime': rushPrepTime,
    'dietaryOptions': dietaryOptions,
  };

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) =>
      RestaurantSettings(
        id: json['id'] as String?,
        managerFirstName: json['managerFirstName'] as String? ?? '',
        managerPhone: json['managerPhone'] as String? ?? '',
        managerIban: json['managerIban'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        image: json['image'] as String? ?? '',
        cuisineType: json['cuisineType'] as String? ?? '',
        category: json['category'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        normalPrepTime: json['normalPrepTime'] as int? ?? 15,
        rushPrepTime: json['rushPrepTime'] as int? ?? 25,
        dietaryOptions:
            (json['dietaryOptions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  /// Build from backend API response (dietaryOptions as [{option: "HALAL"}])
  factory RestaurantSettings.fromApiJson(Map<String, dynamic> json) =>
      RestaurantSettings(
        id: strOrNull(json['id']),
        managerFirstName: strOrNull(json['managerFirstName']) ?? '',
        managerPhone: strOrNull(json['managerPhone']) ?? '',
        managerIban: strOrNull(json['managerIban']) ?? '',
        name: strOrNull(json['name']) ?? '',
        description: strOrNull(json['description']) ?? '',
        image: strOrNull(json['image']) ?? '',
        cuisineType: strOrNull(json['cuisineType']) ?? '',
        category: strOrNull(json['category']) ?? '',
        city: strOrNull(json['city']) ?? '',
        address: strOrNull(json['address']) ?? '',
        normalPrepTime: json['normalPrepTime'] as int? ?? 15,
        rushPrepTime: json['rushPrepTime'] as int? ?? 25,
        dietaryOptions: _parseDietaryList(json['dietaryOptions']),
      );

  static List<String> _parseDietaryList(dynamic options) {
    if (options == null) return [];
    if (options is List) {
      return options
          .map((e) {
            if (e is String) return e;
            if (e is Map<String, dynamic>) return e['option'] as String? ?? '';
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}

/// Table reservation (F10) — customer requests a slot, the restaurant
/// confirms or declines.
class Reservation {
  final String id;
  final String restaurantId;
  final String customerName;
  final int partySize;
  final DateTime dateTime;
  final String status; // PENDING | CONFIRMED | DECLINED | CANCELLED | COMPLETED
  final String? note;
  final String? tableNumber;
  final String restaurantName;
  final String restaurantImage;

  const Reservation({
    required this.id,
    required this.restaurantId,
    required this.customerName,
    required this.partySize,
    required this.dateTime,
    required this.status,
    this.note,
    this.tableNumber,
    this.restaurantName = '',
    this.restaurantImage = '',
  });

  bool get isPending => status == 'PENDING';
  bool get isUpcoming => dateTime.isAfter(DateTime.now());

  factory Reservation.fromApiJson(Map<String, dynamic> json) => Reservation(
    id: strOrNull(json['id']) ?? '',
    restaurantId: strOrNull(json['restaurantId']) ?? '',
    restaurantName:
        strOrNull((json['restaurant'] as Map<String, dynamic>?)?['name']) ?? '',
    restaurantImage:
        strOrNull((json['restaurant'] as Map<String, dynamic>?)?['image']) ?? '',
    customerName:
        strOrNull(json['userName']) ??
            strOrNull(
              (json['customer'] as Map<String, dynamic>?)?['name'],
            ) ??
            strOrNull(json['customerName']) ??
            '',
    partySize: json['partySize'] as int? ?? 2,
    dateTime: DateTime.tryParse(strOrNull(json['dateTime']) ?? '') ??
        DateTime.now(),
    status: strOrNull(json['status']) ?? 'PENDING',
    note: strOrNull(json['note']),
    tableNumber: strOrNull(json['tableNumber']),
  );
}
