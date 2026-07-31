import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';

final _log = LoggingService.instance.withTag('usernode/AuthRepository');

enum AuthErrorKind {
  invalidCredentials,
  invalidCode,
  rateLimited,
  wrongToken,
  validation,
  network,
}

class AuthException implements Exception {
  AuthException(this.kind, this.message);
  final AuthErrorKind kind;
  final String message;
  @override
  String toString() => 'AuthException($kind, $message)';
}

class AuthRepository {
  AuthRepository({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? AppConfig.authApiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<CheckEmailResult> checkEmail(String email) async {
    final json = await _post('/check-email', body: {'email': email});
    return CheckEmailResult.fromJson(json);
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final json =
        await _post('/login', body: {'email': email, 'password': password});
    return AuthSession.fromJson(json);
  }

  Future<void> requestOtp(String email) async {
    await _post('/otp/request', body: {'email': email});
  }

  Future<OtpTicket> verifyOtp(
      {required String email, required String code}) async {
    final json =
        await _post('/otp/verify', body: {'email': email, 'code': code});
    return OtpTicket.fromJson(json);
  }

  Future<AuthSession> setPassword({
    required String setPasswordToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final json = await _post(
        '/set-password',
        body: {
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        bearer: setPasswordToken,
      );
      return AuthSession.fromJson(json);
    } on AuthException catch (error) {
      // v4 uses 401 when this one-time bearer has expired or was already
      // consumed. `_mapError` must keep mapping ordinary 401s (notably login)
      // to invalidCredentials, so reinterpret it only in this endpoint's
      // set-password-token context.
      if (error.kind == AuthErrorKind.invalidCredentials) {
        throw AuthException(AuthErrorKind.wrongToken, error.message);
      }
      rethrow;
    }
  }

  Future<void> logout(String sessionToken) async {
    try {
      await _post('/logout', body: const {}, bearer: sessionToken);
    } catch (e) {
      // Best-effort: an expired/invalid session still clears locally.
      _log.debug('logout ignored error: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    String? bearer,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    http.Response resp;
    try {
      resp = await _http
          .post(
            url,
            headers: {
              ..._jsonHeaders,
              if (bearer != null) 'Authorization': 'Bearer $bearer',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      _log.warn('auth request failed: $e');
      throw AuthException(
          AuthErrorKind.network, 'Network error. Please try again.');
    }

    final decoded = _tryDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return decoded ?? const {};
    }
    throw _mapError(resp.statusCode, decoded);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  AuthException _mapError(int status, Map<String, dynamic>? json) {
    // v4's error envelope is `{success: false, error, details?}`; `message`
    // is kept as a fallback for older/other servers.
    final serverMsg = (json?['error'] ?? json?['message']) as String?;
    switch (status) {
      case 401:
        return AuthException(AuthErrorKind.invalidCredentials,
            serverMsg ?? 'Invalid email or password.');
      case 403:
        return AuthException(AuthErrorKind.wrongToken,
            serverMsg ?? 'This link is no longer valid.');
      case 422:
        // /otp/verify uses 422 for a bad code; /set-password for validation.
        final kind =
            (serverMsg != null && serverMsg.toLowerCase().contains('code'))
                ? AuthErrorKind.invalidCode
                : AuthErrorKind.validation;
        return AuthException(kind, serverMsg ?? 'Please check your input.');
      case 429:
        return AuthException(
            AuthErrorKind.rateLimited, 'Please try again shortly.');
      default:
        return AuthException(
            AuthErrorKind.network, serverMsg ?? 'Something went wrong.');
    }
  }
}
