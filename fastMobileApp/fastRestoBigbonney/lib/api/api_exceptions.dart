import '../l10n/app_strings.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String? message])
    : super(message ?? AppStrings.trNow('unauthorized'), 401);
}

class NotFoundException extends ApiException {
  NotFoundException([String? message])
    : super(message ?? AppStrings.trNow('not_found'), 404);
}

/// Connectivity-level failure (DNS, socket, timeout) — message is already
/// localized so call sites that show `$e` read correctly in any language.
class NetworkException extends ApiException {
  NetworkException([String? message])
    : super(message ?? AppStrings.trNow('network_error'), 0);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException([String? message, this.errors])
    : super(message ?? AppStrings.trNow('validation_err'), 400);
}
