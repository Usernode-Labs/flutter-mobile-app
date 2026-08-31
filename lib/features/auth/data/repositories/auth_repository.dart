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

  /// Sends the shared mobile one-time code used for passwordless sign-in and
  /// legacy programme-wallet recovery. The backend deliberately returns the
  /// same success response whether or not the email belongs to an account.
  Future<void> requestOtp(String email) async {
    await _post('/otp/request', body: {'email': email.trim().toLowerCase()});
  }

  Future<void> logout(String sessionToken) async {
    try {
      await _post('/logout', body: const {}, bearer: sessionToken);
    } catch (e) {
      // Best-effort: an expired/invalid session still clears locally.
      _log.debug('logout ignored error: $e');
    }
  }

  /// Resolves the owner of an opaque mobile bearer through authenticated
  /// `/me`. Bridge callers may supply a legacy `user` object for compatibility,
  /// but only this response is authoritative for the native participant.
  Future<AuthSession> resolveBearerSession(
    String token, {
    int? legacyParticipantId,
  }) async {
    final mobileBase = _baseUrl.endsWith('/auth')
        ? _baseUrl.substring(0, _baseUrl.length - 5)
        : _baseUrl;
    final url = Uri.parse('$mobileBase/me');
    http.Response resp;
    try {
      resp = await _http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      _log.warn('bearer validation failed: $e');
      throw AuthException(
        AuthErrorKind.network,
        'Could not validate the session. Please try again.',
      );
    }

    final decoded = _tryDecode(resp.body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw _mapError(resp.statusCode, decoded);
    }
    final data = decoded?['data'];
    if (decoded?['success'] != true || data is! Map<String, dynamic>) {
      throw AuthException(
        AuthErrorKind.network,
        'Unexpected session validation response.',
      );
    }
    late final AuthSession session;
    try {
      session = AuthSession(
        token: token,
        participant: Participant.fromJson(data),
      );
    } catch (_) {
      throw AuthException(
        AuthErrorKind.network,
        'Unexpected session validation response.',
      );
    }
    if (legacyParticipantId != null &&
        legacyParticipantId != session.participant.id) {
      throw AuthException(
        AuthErrorKind.validation,
        'The supplied user does not match the authenticated bearer.',
      );
    }
    return session;
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
