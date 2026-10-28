import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

enum AuthState { idle, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.idle;
  UserData? _user;
  String? _error;

  AuthState get state => _state;
  UserData? get user => _user;
  String? get error => _error;
  bool get isLoggedIn => _state == AuthState.authenticated && _user != null;
  bool get isRestaurant => _user?.isRestaurant ?? false;
  bool get isLivreur => _user?.isLivreur ?? false;
  bool get isBusy => _state == AuthState.loading || _isLoggingOut;

  static const String _cachedUserKey = 'fast_cached_user';

  /// Cache the session user so the next cold start skips the /auth/me
  /// round-trip — splash ends instantly, backend refresh happens behind.
  Future<void> _cacheUser() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(_user!.toJson()));
    } catch (_) {}
  }

  /// Try auto-login on app start using stored token
  Future<void> autoLogin() async {
    _state = AuthState.loading;
    notifyListeners();

    await ApiClient().init();
    if (!ApiClient().isAuthenticated) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    // Fast path: restore the cached session and return immediately —
    // splash ends without waiting for the network, /auth/me refreshes
    // behind the scenes.
    UserData? cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);
      if (raw != null) {
        cached = UserData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    if (cached != null && cached.id.isNotEmpty) {
      _user = cached;
      _state = AuthState.authenticated;
      notifyListeners();
      unawaited(_refreshMe());
      return;
    }

    // No cached session — the token must be validated before opening.
    await _refreshMe();
  }

  /// Validates the stored token against /auth/me and refreshes the
  /// cached user. Only a real 401 kills the session — a network blip
  /// keeps the cached user (kicking them out for being offline is worse).
  Future<void> _refreshMe() async {
    try {
      final me = await AuthService().getMe();
      _user = me;
      _state = AuthState.authenticated;
      notifyListeners();
      await _cacheUser();
    } catch (e) {
      if (e is UnauthorizedException || _user == null) {
        await ApiClient().setToken(null);
        _user = null;
        _state = AuthState.unauthenticated;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_cachedUserKey);
        } catch (_) {}
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService().login(
        LoginRequest(email: email, password: password),
      );
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      await _cacheUser();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Sign in with a Google account.
  /// Requires OAuth client IDs configured in Google Cloud Console
  /// (Android: SHA-1 of the signing key; iOS: reversed client ID).
  /// Returns true on success, false on cancel/failure (see [error]).
  Future<bool> signInWithGoogle({String role = 'CLIENT'}) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      // Clear the cached account so the picker is always shown —
      // otherwise signIn() silently returns the previous account.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled — back to idle without an error
        _state = AuthState.idle;
        notifyListeners();
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Token Google introuvable');
      }

      final response = await AuthService().loginWithGoogle(idToken, role);
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      await _cacheUser();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? driverType,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService().register(
        RegisterRequest(
          email: email,
          password: password,
          name: name,
          phone: phone,
          role: role,
          driverType: driverType,
        ),
      );
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      await _cacheUser();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Redeem an owner's invite code inside an existing account — the
  /// assistant keeps their professional login and joins as a GUEST.
  Future<bool> redeemInviteCode(String code) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService().redeemInviteCode(code);
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      await _cacheUser();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  // GoogleSignIn is a singleton-backed plugin; keep one instance so
  // signOut() clears the cached account before the next sign-in.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Web client ID is required on Android for idToken to be returned.
    serverClientId:
        '792298746020-ssfs311jl0k5qt2cdh32hs66p5uooko9.apps.googleusercontent.com',
    scopes: const ['email', 'profile'],
  );

  bool _isLoggingOut = false;
  bool get isLoggingOut => _isLoggingOut;

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    notifyListeners();

    // Fire-and-forget the backend logout with a short timeout.
    // We don't want to block the user if the network is slow.
    final revoke = AuthService().logout().timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    ).catchError((_) {});
    try {
      // Clear only the token, not all secure storage
      await ApiClient().clearSecureData();
      _user = null;
      _state = AuthState.unauthenticated;
      _error = null;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cachedUserKey);
      } catch (_) {}
      try {
        await revoke;
      } catch (_) {
        // Proceed with local logout even if API call fails
      }

      // Forget the Google account too so the next login shows the picker
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      await AuthService().deleteAccount();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await ApiClient().clearSecureData();
      _user = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cachedUserKey);
      } catch (_) {}
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await AuthService().changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  String _extractError(dynamic e) {
    final msg = e.toString();
    // Clean up common exception wrappers
    if (msg.contains('ApiException(')) {
      final start = msg.indexOf('): ') + 3;
      if (start < msg.length) return msg.substring(start);
    }
    if (msg.contains('ValidationException(')) {
      final start = msg.indexOf('): ') + 3;
      if (start < msg.length) return msg.substring(start);
    }
    return msg;
  }
}
