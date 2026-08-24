import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

final _log = LoggingService.instance.withTag('usernode/AccountApiService');

class AccountApiException implements Exception {
  AccountApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'AccountApiException($statusCode, $message)';
}

/// Client for the session-scoped account endpoints under `/api/v3/mobile`.
class AccountApiService {
  AccountApiService({
    http.Client? httpClient,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
    SessionAuthorityCredentialIssuer? credentialIssuer,
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? _deriveV3Base(),
        _tokenProvider = tokenProvider,
        _credentialIssuer =
            credentialIssuer ?? SessionAuthorityGateway.captureCredential,
        _onUnauthorized = onUnauthorized,
        _onCredentialMissing = onCredentialMissing;

  final http.Client _http;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;
  final SessionAuthorityCredentialIssuer _credentialIssuer;

  /// Invoked with the exact identity/token pair carried by a failed request.
  final Future<void> Function(AuthCredentialLease credential)? _onUnauthorized;

  final Future<void> Function(int epoch)? _onCredentialMissing;

  /// The v3 mobile base is the parent of the auth base (`…/api/v3/mobile/auth`).
  static String _deriveV3Base() {
    final auth = AppConfig.authApiBaseUrl;
    const suffix = '/auth';
    return auth.endsWith(suffix)
        ? auth.substring(0, auth.length - suffix.length)
        : auth;
  }

  Future<AuthCredentialLease?> _credential() async {
    final identity = IdentitySnapshots.current;
    final token = await _tokenProvider?.call();
    if (!identity.sameScopeAs(IdentitySnapshots.current)) {
      throw const StaleAuthCredentialException();
    }
    if (token == null || token.isEmpty) {
      if (identity.isAuthenticated) {
        _detachSessionInvalidation(
          _onCredentialMissing?.call(identity.epoch),
        );
        throw const StaleAuthCredentialException();
      }
      return null;
    }
    if (!identity.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    return _credentialIssuer(
      identity: identity,
      token: token,
    );
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  /// Fetches the authenticated participant profile (including `level`).
  Future<Me> getMe() async {
    final credential = await _credential();
    final url = Uri.parse('$_baseUrl/me');
    _log.trace('GET $url');
    final request = http.Request('GET', url)
      ..headers.addAll({
        'Accept': 'application/json',
        if (credential != null) 'Authorization': 'Bearer ${credential.token}',
      });
    http.Response resp;
    try {
      resp = await _send(request).timeout(const Duration(seconds: 15));
    } catch (e) {
      _log.warn('GET /me failed: $e');
      throw AccountApiException(0, 'Network error.');
    }

    if (resp.statusCode == 401 && credential != null) {
      _detachSessionInvalidation(_onUnauthorized?.call(credential));
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AccountApiException(resp.statusCode, 'Request failed.');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw AccountApiException(resp.statusCode, 'Unexpected response format.');
    }
    return Me.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  void _detachSessionInvalidation(Future<void>? invalidation) {
    if (invalidation == null) return;
    // Invalidation starts global retirement. Keep it out of this request
    // Future so the request does not wait on disposal of its own host.
    unawaited(invalidation.catchError((Object error, StackTrace stackTrace) {
      _log.warn('Session invalidation failed: $error');
    }));
  }

  void dispose() => _http.close();
}
