import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models/auth_models.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<AuthResponse> login(LoginRequest request) async {
    final data = await _api.post(ApiConfig.login, body: request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> loginWithGoogle(String idToken, String role) async {
    final data = await _api.post(
      ApiConfig.googleAuth,
      body: {'idToken': idToken, 'role': role},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> loginWithApple(
    String identityToken,
    String role, {
    String? name,
  }) async {
    final data = await _api.post(
      ApiConfig.appleAuth,
      body: {
        'identityToken': identityToken,
        'role': role,
        if (name != null) 'name': name,
      },
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final data = await _api.post(ApiConfig.register, body: request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Redeem an invite code inside an existing authenticated account —
  /// the user attaches to the restaurant as a limited GUEST without
  /// creating a separate account.
  Future<AuthResponse> redeemInviteCode(String code) async {
    final data = await _api.post(
      ApiConfig.staffRedeem,
      body: {'code': code.trim().toUpperCase()},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<UserData> getMe() async {
    final data = await _api.get(ApiConfig.me);
    // Backend returns user data at root level
    if (data is Map<String, dynamic> && data.containsKey('id')) {
      return UserData.fromJson(data);
    }
    // Fallback for nested format
    return UserData.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _api.post(ApiConfig.logout);
  }

  Future<void> deleteAccount() async {
    await _api.delete(ApiConfig.deleteAccount);
  }

  Future<UserData> updateProfile(Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.updateProfile, body: body);
    if (data is Map<String, dynamic> && data.containsKey('id')) {
      return UserData.fromJson(data);
    }
    return UserData.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// F11 — whether SMS verification is required at signup.
  Future<bool> phoneVerificationEnabled() async {
    try {
      final data = await _api.get(ApiConfig.phoneStatus);
      return (data as Map<String, dynamic>)['enabled'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPhoneCode(String phone) async {
    await _api.post(ApiConfig.phoneRequestCode, body: {'phone': phone});
  }

  Future<bool> verifyPhoneCode(String phone, String code) async {
    try {
      final data = await _api.post(
        ApiConfig.phoneVerifyCode,
        body: {'phone': phone, 'code': code},
      );
      return (data as Map<String, dynamic>)['verified'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      ApiConfig.changePassword,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
