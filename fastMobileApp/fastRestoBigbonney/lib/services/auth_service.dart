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

  Future<AuthResponse> register(RegisterRequest request) async {
    final data = await _api.post(ApiConfig.register, body: request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  /// F13 — self-serve guest join via the restaurant's invite code.
  /// Creates the account on the fly and returns a ready session;
  /// repeated calls with the same name act as a re-login.
  Future<AuthResponse> joinWithInviteCode({
    required String inviteCode,
    required String firstName,
    required String lastName,
  }) async {
    final data = await _api.post(
      ApiConfig.staffJoin,
      body: {
        'code': inviteCode.trim().toUpperCase(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      },
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
