class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String role;
  final String? driverType;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
    this.driverType,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'name': name,
    'role': role,
    'phone': phone,
    if (driverType != null) 'driverType': driverType,
  };
}

class AuthResponse {
  final String token;
  final UserData user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: strOrNull(json['token']) ?? '',
    user: UserData.fromJson(json['user'] as Map<String, dynamic>),
  );
}

/// Tolerant scalar coercion — see models.dart's version. Some backends
/// deliver related entities as objects where a plain string is expected
/// (this is what crashed Google sign-in).
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

class UserData {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;
  final int points;
  final Map<String, dynamic>? restaurant;
  final DriverProfileData? driverProfile;
  // For STAFF/GUEST kitchen accounts — the restaurant they're assigned to
  final String? restaurantId;
  final String? staffRole;

  UserData({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.points,
    this.restaurant,
    this.driverProfile,
    this.restaurantId,
    this.staffRole,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    id: strOrNull(json['id']) ?? '',
    email: strOrNull(json['email']) ?? '',
    name: strOrNull(json['name']) ?? '',
    phone: strOrNull(json['phone']) ?? '',
    role: strOrNull(json['role']) ?? 'CLIENT',
    points: json['points'] as int? ?? 0,
    restaurant: json['restaurant'] as Map<String, dynamic>?,
    driverProfile: json['driverProfile'] is Map<String, dynamic>
        ? DriverProfileData.fromJson(
            json['driverProfile'] as Map<String, dynamic>,
          )
        : null,
    restaurantId: strOrNull(json['restaurantId']) ??
        strOrNull(
          (json['staffAssignment'] as Map<String, dynamic>?)?['restaurantId'],
        ),
    staffRole: strOrNull(json['staffRole']) ??
        strOrNull(
          (json['staffAssignment'] as Map<String, dynamic>?)?['staffRole'],
        ),
  );

  bool get isRestaurant => role == 'RESTAURANT';
  bool get isClient => role == 'CLIENT';
  bool get isLivreur => role == 'LIVREUR';
  bool get isAdmin => role == 'ADMIN';
  // Kitchen/guest accounts — orders board only, no stats/payments/settings
  bool get isStaff => role == 'STAFF' || role == 'GUEST';
  bool get isGuest => role == 'GUEST' || staffRole == 'GUEST';
}

class DriverProfileData {
  final String id;
  final String type;
  final bool isOnline;
  final bool isPaused;
  final String timezone;
  final List<Map<String, dynamic>> schedules;

  const DriverProfileData({
    required this.id,
    required this.type,
    required this.isOnline,
    required this.isPaused,
    required this.timezone,
    this.schedules = const [],
  });

  factory DriverProfileData.fromJson(Map<String, dynamic> json) =>
      DriverProfileData(
        id: strOrNull(json['id']) ?? '',
        type: strOrNull(json['type']) ?? 'OCCASIONAL',
        isOnline: json['isOnline'] as bool? ?? false,
        isPaused: json['isPaused'] as bool? ?? false,
        timezone: strOrNull(json['timezone']) ?? 'Europe/Paris',
        schedules: (json['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}
