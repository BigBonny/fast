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

  /// Sends a 6-digit code to the signed-in account's email. Returns the
  /// code itself only from a dev backend without a mail provider.
  Future<String?> requestEmailCode() async {
    final data = await _api.post(ApiConfig.emailRequestCode);
    return data is Map<String, dynamic> ? data['devCode'] as String? : null;
  }

  /// Throws [ApiException] with the server message on a wrong code.
  Future<void> verifyEmailCode(String code) async {
    await _api.post(ApiConfig.emailVerifyCode, body: {'code': code});
  }

  /// Sends an SMS code; returns it only from a dev backend without SMS.
  Future<String?> requestPhoneCodeDev(String phone) async {
    final data = await _api.post(
      ApiConfig.phoneRequestCode,
      body: {'phone': phone},
    );
    return data is Map<String, dynamic> ? data['devCode'] as String? : null;
  }

  /// Signed-in: proves the number and saves it as the account's phone.
  Future<void> confirmAccountPhone(String phone, String code) async {
    await _api.post(
      ApiConfig.phoneConfirm,
      body: {'phone': phone, 'code': code},
    );
  }

  /// Returns the new session token: changing the password signs out every
  /// other device, so the old token stops working.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _api.post(
      ApiConfig.changePassword,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    return data is Map<String, dynamic> ? data['token'] as String? : null;
  }
}
