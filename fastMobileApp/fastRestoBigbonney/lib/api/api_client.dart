import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'api_exceptions.dart';
import '../l10n/app_strings.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'fast_api_token';

  String? _token;

  /// Called on 401 responses to redirect to login
  static void Function()? onUnauthorized;

  Future<void> init() async {
    _token = await _secureStorage.read(key: _tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      await _secureStorage.write(key: _tokenKey, value: token);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  /// Clear only the auth token (used on logout)
  Future<void> clearSecureData() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    ).replace(queryParameters: queryParams);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .patch(
          uri,
          headers: _headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .put(
          uri,
          headers: _headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    required String field,
    required String filePath,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(
        await http.MultipartFile.fromPath(
          field,
          filePath,
          filename: filename,
        ),
      );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    final streamed = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = json.decode(response.body);
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage;
    if (body is Map<String, dynamic>) {
      errorMessage =
          _errorText(body['error']) ??
          _errorText(body['message']) ??
          'Erreur serveur';
    } else {
      errorMessage = 'Erreur serveur (${response.statusCode})';
    }

    if (body is Map<String, dynamic> && body['code'] is String) {
      final key = (body['code'] as String).toLowerCase();
      final translated = AppStrings.trNow(key);
      if (translated != key) errorMessage = translated;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw UnauthorizedException(errorMessage);
    }

    if (response.statusCode == 404) {
      throw NotFoundException(errorMessage);
    }

    if (response.statusCode == 429) {
      throw ApiException(errorMessage, response.statusCode);
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      throw ValidationException(
        errorMessage,
        body is Map<String, dynamic> ? body['details'] : null,
      );
    }

    throw ApiException(errorMessage, response.statusCode);
  }

  /// Error payloads can be a plain string, a nested {message} object, or a
  /// validation map — coerce any of those to readable text without throwing.
  static String? _errorText(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    if (v is Map) {
      final inner = _errorText(v['message']) ?? _errorText(v['error']);
      if (inner != null) return inner;
      try {
        return json.encode(v);
      } catch (_) {
        return null;
      }
    }
    if (v is List) return v.map(_errorText).whereType<String>().join(', ');
    return v.toString();
  }
}
