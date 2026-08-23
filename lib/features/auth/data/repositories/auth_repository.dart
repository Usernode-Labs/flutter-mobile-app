import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
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
  AuthRepository({
    http.Client? httpClient,
    String? baseUrl,
    SessionAuthorityCredentialRequestSender? credentialRequestSender,
  })  : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? AppConfig.authApiBaseUrl,
        _credentialRequestSender = credentialRequestSender;

  final http.Client _http;
  final String _baseUrl;
  final SessionAuthorityCredentialRequestSender? _credentialRequestSender;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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

    final session = _sessionFromMeResponse(resp, token);
    if (legacyParticipantId != null &&
        legacyParticipantId != session.participant.id) {
      throw AuthException(
        AuthErrorKind.validation,
        'The supplied user does not match the authenticated bearer.',
      );
    }
    return session;
  }

  /// Independently confirms a business-endpoint `401` through the dedicated
  /// exact-lease `/me` path. This never invokes an unauthorized callback.
  Future<AuthSession> confirmBearerSession(
    AuthCredentialLease credential,
  ) async {
    final sender = _credentialRequestSender;
    if (sender == null) {
      throw AuthException(
        AuthErrorKind.network,
        'Credential confirmation transport is unavailable.',
      );
    }
    final mobileBase = _baseUrl.endsWith('/auth')
        ? _baseUrl.substring(0, _baseUrl.length - 5)
        : _baseUrl;
    final request = http.Request('GET', Uri.parse('$mobileBase/me'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${credential.token}',
      });
    late final http.Response response;
    try {
      final streamed = await sender(
        credential: credential,
        request: request,
      ).timeout(const Duration(seconds: 15));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      _log.warn('credential confirmation failed: $error');
      throw AuthException(
        AuthErrorKind.network,
        'Could not validate the session. Please try again.',
      );
    }
    return _sessionFromMeResponse(response, credential.token);
  }

  AuthSession _sessionFromMeResponse(http.Response response, String token) {
    final decoded = _tryDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response.statusCode, decoded);
    }
    final data = decoded?['data'];
    if (decoded?['success'] != true || data is! Map<String, dynamic>) {
      throw AuthException(
        AuthErrorKind.network,
        'Unexpected session validation response.',
      );
    }
    try {
      return AuthSession(
        token: token,
        participant: Participant.fromJson(data),
      );
    } catch (_) {
      throw AuthException(
        AuthErrorKind.network,
        'Unexpected session validation response.',
      );
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
